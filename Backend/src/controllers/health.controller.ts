import { Request, Response } from "express";
import { Business } from "../models/business";
import { Lead } from "../models/lead";
import { CallEvent } from "../models/callevent";
import { SmsEvent } from "../models/smsevent";
import { AuthedRequest } from "../middleware/auth.middleware";
import {
  provisionIncomingNumber,
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

  const result: Record<string, boolean> = {};

  if (enabled != null) result.enabled = enabled;
  if (classifyLeads != null) result.classifyLeads = classifyLeads;
  if (autoFollowupEnabled != null) result.autoFollowupEnabled = autoFollowupEnabled;

  return Object.keys(result).length > 0 ? result : undefined;
}

function buildBusinessUpdates(body: any) {
  const updates: any = {};

  const stringFields = [
    "name",
    "forwardToNumber",
    "twilioNumber",
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
export const listBusinesses = async (_req: Request, res: Response) => {
  const businesses = await Business.find().sort({ createdAt: -1 }).lean();
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
export const updateBusiness = async (req: Request, res: Response) => {
  const { id } = req.params;
  const updates = buildBusinessUpdates(req.body);

  const business = await Business.findByIdAndUpdate(id, updates, { new: true }).lean();

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

  const provisioned = await provisionIncomingNumber({
    areaCode: areaCode != null ? Number(areaCode) : undefined,
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
export const listLeads = async (_req: Request, res: Response) => {
  const leads = await Lead.find().sort({ createdAt: -1 }).limit(100).lean();
  return res.status(200).json({ ok: true, leads });
};

/**
 * GET /admin/events
 */
export const listEvents = async (_req: Request, res: Response) => {
  const events = await CallEvent.find().sort({ createdAt: -1 }).limit(100).lean();
  return res.status(200).json({ ok: true, events });
};

/**
 * GET /admin/sms-events
 */
export const listSmsEvents = async (_req: Request, res: Response) => {
  const events = await SmsEvent.find().sort({ createdAt: -1 }).limit(100).lean();
  return res.status(200).json({ ok: true, events });
};