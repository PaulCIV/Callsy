import { Request, Response } from "express";
import { Business } from "../models/business";
import { Lead } from "../models/lead";
import { CallEvent } from "../models/callevent";
import { SmsEvent } from "../models/smsevent";
import { EscalationEvent } from "../models/escalationevent";
import { sendSms } from "../services/sms.service";
import { normalizePhone } from "../utils/normalizePhone";
import { AuthedRequest } from "../middleware/auth.middleware";
import {
  provisionIncomingNumber,
  connectExistingIncomingNumber,
  releaseIncomingNumber
} from "../services/phoneNumber.service";

function hasOwn(obj: unknown, key: string) {
  return Object.prototype.hasOwnProperty.call(obj ?? {}, key);
}

function cleanString(value: unknown) {
  return value == null ? undefined : String(value).trim();
}

function cleanNumber(value: unknown) {
  if (value == null || value === "") return undefined;
  const num = Number(value);
  return Number.isFinite(num) ? num : undefined;
}

function cleanBoolean(value: unknown) {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const lowered = value.trim().toLowerCase();
    if (lowered === "true") return true;
    if (lowered === "false") return false;
  }
  return undefined;
}

function cleanStringArray(value: unknown) {
  if (!Array.isArray(value)) return undefined;
  return value.map((item) => String(item).trim()).filter(Boolean).slice(0, 4);
}

function normalizeAiConfig(value: unknown) {
  const obj = value && typeof value === "object" ? (value as Record<string, unknown>) : {};

  const enabled = cleanBoolean(obj.enabled);
  const classifyLeads = cleanBoolean(obj.classifyLeads);
  const autoFollowupEnabled = cleanBoolean(obj.autoFollowupEnabled);
  const conversationRepliesEnabled = cleanBoolean(obj.conversationRepliesEnabled);

  const result: Record<string, boolean> = {};

  if (enabled != null) result.enabled = enabled;
  if (classifyLeads != null) result.classifyLeads = classifyLeads;
  if (autoFollowupEnabled != null) result.autoFollowupEnabled = autoFollowupEnabled;
  if (conversationRepliesEnabled != null) {
    result.conversationRepliesEnabled = conversationRepliesEnabled;
  }

  return Object.keys(result).length > 0 ? result : undefined;
}

function normalizePriorityEscalation(value: unknown) {
  const obj = value && typeof value === "object" ? (value as Record<string, unknown>) : {};
  const result: Record<string, unknown> = {};
  const enabled = cleanBoolean(obj.enabled);
  const confirmation = cleanBoolean(obj.customerConfirmationEnabled);
  const timeout = cleanNumber(obj.ringTimeoutSeconds);
  const keywords = Array.isArray(obj.urgentKeywords)
    ? obj.urgentKeywords.map((item) => String(item).trim()).filter(Boolean).slice(0, 12)
    : undefined;

  if (enabled != null) result.enabled = enabled;
  if (confirmation != null) result.customerConfirmationEnabled = confirmation;
  if (timeout != null) result.ringTimeoutSeconds = Math.max(10, Math.min(30, timeout));
  if (hasOwn(obj, "primaryPhone")) result.primaryPhone = cleanString(obj.primaryPhone) || "";
  if (hasOwn(obj, "backupPhone")) result.backupPhone = cleanString(obj.backupPhone) || "";
  if (keywords) result.urgentKeywords = keywords;
  return Object.keys(result).length ? result : undefined;
}

function buildBusinessUpdates(body: any) {
  const updates: any = {};

  const stringFields = [
    "name",
    "forwardToNumber",
    "notifyToNumber",
    "destinationNumber",
    "followupTemplate",
    "callHandlingMode",
    "bookingLink",
    "onboardingStatus",
    "businessType",
    "businessDescription",
    "tone",
    "firstResponseStyle"
  ];

  for (const key of stringFields) {
    if (hasOwn(body, key)) {
      updates[key] = cleanString(body[key]);
    }
  }

  if (hasOwn(body, "cooldownMinutes")) {
    const value = cleanNumber(body.cooldownMinutes);
    if (value != null) updates.cooldownMinutes = value;
  }

  if (hasOwn(body, "isActive")) {
    const value = cleanBoolean(body.isActive);
    if (value != null) updates.isActive = value;
  }

  if (hasOwn(body, "useAiGeneratedMessage")) {
    const value = cleanBoolean(body.useAiGeneratedMessage);
    if (value != null) updates.useAiGeneratedMessage = value;
  }

  if (hasOwn(body, "menuOptions")) {
    const value = cleanStringArray(body.menuOptions);
    if (value != null) updates.menuOptions = value;
  }

  if (hasOwn(body, "aiConfig")) {
    const value = normalizeAiConfig(body.aiConfig);
    if (value != null) {
      if (value.enabled != null) updates["aiConfig.enabled"] = value.enabled;
      if (value.classifyLeads != null) {
        updates["aiConfig.classifyLeads"] = value.classifyLeads;
      }
      if (value.autoFollowupEnabled != null) {
        updates["aiConfig.autoFollowupEnabled"] = value.autoFollowupEnabled;
      }
      if (value.conversationRepliesEnabled != null) {
        updates["aiConfig.conversationRepliesEnabled"] = value.conversationRepliesEnabled;
      }
    }
  }

  if (hasOwn(body, "priorityEscalation")) {
    const value = normalizePriorityEscalation(body.priorityEscalation);
    if (value) {
      for (const [key, item] of Object.entries(value)) {
        updates[`priorityEscalation.${key}`] = item;
      }
    }
  }

  return updates;
}

/**
 * GET /health
 * Simple uptime / deploy health check
 */
export const healthCheck = (_req: Request, res: Response) => {
  res.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString()
  });
};

/**
 * GET /admin/businesses
 * List all businesses
 */
export const listBusinesses = async (req: AuthedRequest, res: Response) => {
  const businesses = await Business.find({ ownerId: req.user?.userId })
    .sort({ createdAt: -1 })
    .lean();
  res.status(200).json({ ok: true, businesses });
};

/**
 * GET /admin/businesses/me
 * Return the currently logged-in user's business
 */
export const getMyBusiness = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const business = await Business.findOne({ ownerId: userId }).lean();

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  return res.status(200).json({ ok: true, business });
};

/**
 * POST /admin/businesses
 * Create a new business
 */
export const createBusiness = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const {
    name,
    forwardToNumber,
    twilioNumber,
    notifyToNumber,
    destinationNumber,
    followupTemplate,
    cooldownMinutes,
    callHandlingMode,
    bookingLink,
    onboardingStatus,
    businessType,
    businessDescription,
    tone,
    firstResponseStyle,
    menuOptions,
    useAiGeneratedMessage,
    aiConfig
  } = req.body ?? {};

  if (!name) {
    return res.status(400).json({
      ok: false,
      error: "name is required"
    });
  }

  const normalizedAiConfig = normalizeAiConfig(aiConfig);

  const business = await Business.create({
    ownerId: userId,
    name: String(name).trim(),
    forwardToNumber: cleanString(forwardToNumber),
    twilioNumber: cleanString(twilioNumber),
    notifyToNumber: cleanString(notifyToNumber),
    destinationNumber: cleanString(destinationNumber),
    followupTemplate: cleanString(followupTemplate),
    cooldownMinutes: cleanNumber(cooldownMinutes),
    callHandlingMode: cleanString(callHandlingMode),
    bookingLink: cleanString(bookingLink),
    onboardingStatus: cleanString(onboardingStatus),
    businessType: cleanString(businessType),
    businessDescription: cleanString(businessDescription),
    tone: cleanString(tone),
    firstResponseStyle: cleanString(firstResponseStyle),
    menuOptions: cleanStringArray(menuOptions),
    useAiGeneratedMessage: cleanBoolean(useAiGeneratedMessage),
    aiConfig: normalizedAiConfig
  });

  return res.status(201).json({ ok: true, business });
};

/**
 * PATCH /admin/businesses/:id
 * Update allowed fields for a business by id
 */
export const updateBusiness = async (req: AuthedRequest, res: Response) => {
  const { id } = req.params;
  const updates = buildBusinessUpdates(req.body);

  const business = await Business.findOneAndUpdate(
    { _id: id, ownerId: req.user?.userId },
    updates,
    { new: true }
  ).lean();

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  return res.status(200).json({ ok: true, business });
};

/**
 * PATCH /admin/businesses/me
 * Update the currently logged-in user's business
 */
export const updateMyBusiness = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const updates = buildBusinessUpdates(req.body);

  const business = await Business.findOneAndUpdate({ ownerId: userId }, updates, {
    new: true
  }).lean();

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  return res.status(200).json({ ok: true, business });
};

/**
 * POST /admin/businesses/me/provision-number
 */
export const provisionMyBusinessNumber = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const business: any = await Business.findOne({ ownerId: userId });

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  if (business.twilioNumber || business.twilioPhoneSid) {
    return res.status(409).json({
      ok: false,
      error: "Business already has a Twilio number assigned"
    });
  }

  const { areaCode } = req.body ?? {};

  const normalizedAreaCode = areaCode == null || areaCode === "" ? undefined : Number(areaCode);
  if (normalizedAreaCode !== undefined && (!Number.isInteger(normalizedAreaCode) || normalizedAreaCode < 200 || normalizedAreaCode > 999)) {
    return res.status(400).json({
      ok: false,
      error: "Area code must be a valid 3-digit number"
    });
  }

  const provisioned = await provisionIncomingNumber({
    areaCode: normalizedAreaCode,
    friendlyName: `Callsy - ${business.name || "Customer"}`
  });

  business.twilioNumber = String(provisioned.phoneNumber);
  business.twilioPhoneSid = String(provisioned.sid);
  business.onboardingStatus = "number_assigned";

  await business.save();

  return res.status(200).json({
    ok: true,
    business: business.toObject()
  });
};

/**
 * POST /admin/businesses/me/assign-test-number
 * Local-development helper. Does not contact Twilio or purchase anything.
 */
export const assignMyBusinessTestNumber = async (req: AuthedRequest, res: Response) => {
  if (process.env.NODE_ENV === "production") {
    return res.status(404).json({ ok: false, error: "Not found" });
  }

  const userId = req.user?.userId;
  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const requested = cleanString(req.body?.phoneNumber) || "+15005550006";
  if (!/^\+[1-9]\d{7,14}$/.test(requested)) {
    return res.status(400).json({
      ok: false,
      error: "Test number must use E.164 format, for example +15005550006"
    });
  }

  const numberOwner: any = await Business.findOne({
    twilioNumber: requested,
    ownerId: { $ne: userId }
  }).select("_id").lean();

  if (numberOwner) {
    return res.status(409).json({
      ok: false,
      error: "That test number is already assigned to another business"
    });
  }

  const business: any = await Business.findOneAndUpdate(
    { ownerId: userId },
    {
      $set: {
        twilioNumber: requested,
        onboardingStatus: "test_number_assigned"
      },
      $unset: { twilioPhoneSid: 1 }
    },
    { new: true }
  ).lean();

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  return res.status(200).json({ ok: true, testMode: true, business });
};

export const connectMyExistingTwilioNumber = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;
  if (!userId) return res.status(401).json({ ok: false, error: "Not authenticated" });

  const business: any = await Business.findOne({ ownerId: userId });
  if (!business) return res.status(404).json({ ok: false, error: "Business not found" });

  const phoneNumber = cleanString(req.body?.phoneNumber) || "";
  const alreadyAssigned: any = await Business.findOne({
    twilioNumber: phoneNumber,
    ownerId: { $ne: userId }
  }).select("_id").lean();
  if (alreadyAssigned) {
    return res.status(409).json({ ok: false, error: "That number is assigned to another Callsy business" });
  }

  const connected = await connectExistingIncomingNumber(phoneNumber);
  business.twilioNumber = connected.phoneNumber;
  business.twilioPhoneSid = connected.sid;
  business.onboardingStatus = "number_assigned";
  await business.save();

  return res.status(200).json({ ok: true, business: business.toObject() });
};

/**
 * POST /admin/businesses/me/release-number
 */
export const releaseMyBusinessNumber = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;

  if (!userId) {
    return res.status(401).json({ ok: false, error: "Not authenticated" });
  }

  const business: any = await Business.findOne({ ownerId: userId });

  if (!business) {
    return res.status(404).json({ ok: false, error: "Business not found" });
  }

  if (!business.twilioPhoneSid) {
    if (process.env.NODE_ENV !== "production" && business.twilioNumber) {
      business.twilioNumber = undefined;
      business.onboardingStatus = "draft";
      await business.save();
      return res.status(200).json({
        ok: true,
        testMode: true,
        business: business.toObject()
      });
    }

    return res.status(400).json({
      ok: false,
      error: "Business does not have a Twilio number to release"
    });
  }

  await releaseIncomingNumber(String(business.twilioPhoneSid));

  business.twilioPhoneSid = undefined;
  business.twilioNumber = undefined;
  business.onboardingStatus = "draft";

  await business.save();

  return res.status(200).json({
    ok: true,
    business: business.toObject()
  });
};

/**
 * GET /admin/leads
 */
async function getOwnedBusinessId(req: AuthedRequest) {
  const business: any = await Business.findOne({ ownerId: req.user?.userId })
    .select("_id")
    .lean();
  return business?._id;
}

export const listLeads = async (req: AuthedRequest, res: Response) => {
  const businessId = await getOwnedBusinessId(req);
  const leads = businessId
    ? await Lead.find({ businessId }).sort({ createdAt: -1 }).limit(100).lean()
    : [];
  return res.status(200).json({ ok: true, leads });
};

/**
 * GET /admin/events
 */
export const listEvents = async (req: AuthedRequest, res: Response) => {
  const businessId = await getOwnedBusinessId(req);
  const events = businessId
    ? await CallEvent.find({ businessId }).sort({ createdAt: -1 }).limit(100).lean()
    : [];
  return res.status(200).json({ ok: true, events });
};

/**
 * GET /admin/sms-events
 */
export const listSmsEvents = async (req: AuthedRequest, res: Response) => {
  const businessId = await getOwnedBusinessId(req);
  const events = businessId
    ? await SmsEvent.find({ businessId }).sort({ createdAt: -1 }).limit(100).lean()
    : [];
  return res.status(200).json({ ok: true, events });
};

export const sendManualLeadMessage = async (req: AuthedRequest, res: Response) => {
  const business: any = await Business.findOne({ ownerId: req.user?.userId });
  if (!business) return res.status(404).json({ ok: false, error: "Business not found" });

  const lead: any = await Lead.findOne({ _id: req.params.id, businessId: business._id });
  if (!lead) return res.status(404).json({ ok: false, error: "Conversation not found" });

  const body = cleanString(req.body?.body) || "";
  if (!body) return res.status(400).json({ ok: false, error: "Message cannot be empty" });
  if (body.length > 1000) return res.status(400).json({ ok: false, error: "Message is too long" });
  if (!business.twilioNumber) return res.status(400).json({ ok: false, error: "Assign a Callsy number first" });
  if (lead?.smsConsent?.status !== "granted" && Number(lead.smsReplyCount || 0) === 0) {
    return res.status(409).json({
      ok: false,
      error: "This caller has not consented to texts. Call them back instead."
    });
  }

  const result: any = await sendSms(lead.phone, body, business.twilioNumber);
  const event: any = await SmsEvent.create({
    businessId: business._id,
    leadId: lead._id,
    messageSid: String(result.sid || `MANUAL_${Date.now()}`),
    direction: "outbound-manual",
    from: normalizePhone(business.twilioNumber),
    to: normalizePhone(lead.phone),
    body,
    status: String(result.status || "sent"),
    raw: result
  });

  lead.manualTakeover = { active: true, activatedAt: new Date() };
  lead.lastMessageDirection = "outbound_sms";
  lead.lastSeenAt = new Date();
  lead.status = "owner_handling";
  await lead.save();

  return res.status(201).json({ ok: true, event, lead: lead.toObject() });
};

export const resumeLeadAutomation = async (req: AuthedRequest, res: Response) => {
  const businessId = await getOwnedBusinessId(req);
  const lead: any = businessId
    ? await Lead.findOneAndUpdate(
        { _id: req.params.id, businessId },
        { $set: { "manualTakeover.active": false, status: "contacted" } },
        { new: true }
      ).lean()
    : null;
  if (!lead) return res.status(404).json({ ok: false, error: "Conversation not found" });
  return res.status(200).json({ ok: true, lead });
};

export const updateLeadAppointmentStatus = async (req: AuthedRequest, res: Response) => {
  const status = cleanString(req.body?.status);
  if (status !== "booked" && status !== "completed") {
    return res.status(400).json({ ok: false, error: "Status must be booked or completed" });
  }
  const businessId = await getOwnedBusinessId(req);
  const now = new Date();
  const updates: Record<string, unknown> = {
    "appointment.status": status,
    status
  };
  updates[status === "booked" ? "appointment.bookedAt" : "appointment.completedAt"] = now;
  const lead: any = businessId
    ? await Lead.findOneAndUpdate({ _id: req.params.id, businessId }, { $set: updates }, { new: true }).lean()
    : null;
  if (!lead) return res.status(404).json({ ok: false, error: "Conversation not found" });
  return res.status(200).json({ ok: true, lead });
};

export const listMyEscalations = async (req: AuthedRequest, res: Response) => {
  const userId = req.user?.userId;
  if (!userId) return res.status(401).json({ ok: false, error: "Not authenticated" });
  const business: any = await Business.findOne({ ownerId: userId }).select("_id").lean();
  if (!business) return res.status(404).json({ ok: false, error: "Business not found" });
  const events = await EscalationEvent.find({ businessId: business._id })
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();
  return res.status(200).json({ ok: true, events });
};
