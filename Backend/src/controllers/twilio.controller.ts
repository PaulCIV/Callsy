import { Request, Response } from "express";
import { env } from "../config/env";
import { Business } from "../models/business";
import { Lead } from "../models/lead";
import { CallEvent } from "../models/callevent";
import { SmsEvent } from "../models/smsevent";
import {
  upsertLead,
  isCooldownActive,
  markFollowupSent
} from "../services/lead.service";
import { sendSms } from "../services/sms.service";
import {
  buildFollowupMessage,
  appendMenuOptions
} from "../services/call.service";
import { classifyLead } from "../services/aiClassifier.service";
import { generateInitialFollowupMessage } from "../services/aiMessage.service";
import { normalizePhone } from "../utils/normalizePhone";
import {
  acknowledgeOrAdvance,
  detectPriorityMessage,
  startPriorityEscalation,
  updateEscalationCallStatus
} from "../services/priorityEscalation.service";

function twiml(inner: string) {
  return `<Response>${inner}</Response>`;
}

const MISSED_CALL_DISCLOSURE_VERSION = "missed-call-sms-v1";

function escapeXml(value: unknown) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function voiceConsentActionUrl() {
  const base = String(env.PUBLIC_WEBHOOK_BASE_URL || "").replace(/\/$/, "");
  return `${base}/twilio/voice/consent`;
}

function consentPromptTwiml(businessName: string) {
  const action = escapeXml(voiceConsentActionUrl());
  const name = escapeXml(businessName || "the business");
  return twiml(
    `<Gather input="dtmf speech" numDigits="1" timeout="6" speechTimeout="auto" ` +
      `hints="yes,yeah,yep,sure,okay" actionOnEmptyResult="true" method="POST" action="${action}">` +
      `<Say>Sorry we missed your call. To receive a text from ${name} so we can help, press 1 or say yes.</Say>` +
      `</Gather><Hangup/>`
  );
}

function cleanLine(value: unknown): string {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function getAiFlags(business: any) {
  const aiEnabled = business?.aiConfig?.enabled ?? true;
  const classifyLeads = business?.aiConfig?.classifyLeads ?? true;
  const autoFollowupEnabled = business?.aiConfig?.autoFollowupEnabled ?? true;
  const useAiGeneratedMessage = business?.useAiGeneratedMessage ?? true;
  const aiConversationRepliesEnabled =
    business?.aiConfig?.conversationRepliesEnabled ?? aiEnabled;

  return {
    aiEnabled,
    classifyLeads,
    autoFollowupEnabled,
    useAiGeneratedMessage,
    aiConversationRepliesEnabled
  };
}

function getMenuOptions(business: any): string[] {
  if (!Array.isArray(business?.menuOptions)) return [];
  return business.menuOptions.map((option: unknown) => String(option).trim()).filter(Boolean);
}

function containsAny(text: string, values: string[]) {
  const lowered = text.toLowerCase();
  return values.some((value) => lowered.includes(value));
}

function getHumanReplyDelayMs() {
  const minSeconds = Math.max(3, Number(process.env.AI_REPLY_DELAY_MIN_SECONDS || 12));
  const maxSeconds = Math.max(minSeconds, Number(process.env.AI_REPLY_DELAY_MAX_SECONDS || 35));
  return Math.round((minSeconds + Math.random() * (maxSeconds - minSeconds)) * 1000);
}

function extractAppointmentWindow(message: string) {
  const text = cleanLine(message);
  const match = text.match(/\b(today|tomorrow|this week|next week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(morning|afternoon|evening))?\b/i);
  if (!match) return "";
  const schedulingLanguage = /\b(work|works|prefer|bring|come in|available|schedule|appointment|morning|afternoon|evening)\b/i.test(text);
  const explicitFutureWindow = /\b(today|tomorrow|this week|next week)\b/i.test(match[0]);
  return schedulingLanguage || explicitFutureWindow ? match[0] : "";
}

function buildConversationReplyFallback(params: {
  business: any;
  customerMessage: string;
  classification?: any;
}) {
  const businessName = cleanLine(params.business?.name) || "our team";
  const businessType = cleanLine(params.business?.businessType).toLowerCase();
  const bookingLink = cleanLine(params.business?.bookingLink);
  const message = cleanLine(params.customerMessage).toLowerCase();

  const asksPricing = containsAny(message, [
    "price",
    "pricing",
    "cost",
    "quote",
    "estimate",
    "how much"
  ]);

  const asksBooking = containsAny(message, [
    "book",
    "booking",
    "schedule",
    "tomorrow",
    "today",
    "appointment",
    "available",
    "availability"
  ]);

  const mentionsBrake = containsAny(message, ["brake", "brakes", "rotor", "pads"]);
  const mentionsUrgent = containsAny(message, ["urgent", "asap", "right away", "today"]);

  if (businessType.includes("auto")) {
    if (containsAny(message, ["flashing", "blinking"]) && containsAny(message, ["light", "check engine"])) {
      return `We're sorry you're dealing with this, especially after the recent repair. We recommend getting it back into the shop as soon as possible—what day works for you?`;
    }

    if (mentionsBrake && asksBooking) {
      let reply = `Hi — this is ${businessName}. We can help with brake service. Were you looking for morning or afternoon tomorrow?`;
      if (bookingLink) {
        reply += ` You can also book here: ${bookingLink}`;
      }
      return reply;
    }

    if (mentionsBrake && asksPricing) {
      return `Hi — this is ${businessName}. We do handle brake work. Are you looking for a rough price or trying to get scheduled?`;
    }

    if (mentionsUrgent) {
      return `Hi — this is ${businessName}. We can help with that. Is this something you need looked at today, or are you trying to schedule the next opening?`;
    }

    if (params.classification?.category === "existing_customer") {
      return `Hi — this is ${businessName}. We're sorry you're having another issue after the recent work. We recommend getting it back into the shop as soon as possible—what day works for you?`;
    }

    return `Hi — this is ${businessName}. We can help and would like to get you into the shop. What day this week works for you?`;
  }

  if (asksBooking) {
    let reply = `Hi — this is ${businessName}. We can help with that. Were you looking for morning or afternoon?`;
    if (bookingLink) {
      reply += ` You can also book here: ${bookingLink}`;
    }
    return reply;
  }

  if (asksPricing) {
    return `Hi — this is ${businessName}. We can help with pricing. Are you looking for a rough estimate, or are you trying to get scheduled?`;
  }

  if (params.classification?.category === "existing_customer") {
    return `Hi — this is ${businessName}. We want to get this taken care of. Would you prefer an appointment or a callback from the team?`;
  }

  return `Hi — this is ${businessName}. We can help with that. Are you looking to book, get pricing, or ask a quick question?`;
}

function normalizeConversationReply(text: unknown, fallback: string) {
  let message = cleanLine(text);

  if (!message) {
    return fallback;
  }

  if (
    (message.startsWith('"') && message.endsWith('"')) ||
    (message.startsWith("'") && message.endsWith("'"))
  ) {
    message = message.slice(1, -1).trim();
  }

  message = message
    .replace(/reply stop to opt out\.?/gi, "")
    .replace(/\s{2,}/g, " ")
    .trim();

  const lowered = message.toLowerCase();

  if (
    lowered.includes("sorry we missed your call") ||
    lowered.includes("we missed your call") ||
    lowered.split(/\s+/).filter(Boolean).length < 8
  ) {
    return fallback;
  }

  return message;
}

async function generateConversationReplyMessage(params: {
  business: any;
  customerMessage: string;
  classification?: any;
  priorFollowupMessage?: string;
}) {
  const fallback = buildConversationReplyFallback({
    business: params.business,
    customerMessage: params.customerMessage,
    classification: params.classification
  });

  const apiKey = env.OPENAI_API_KEY || "";
  if (!apiKey) {
    return {
      message: fallback,
      usedAi: false
    };
  }

  try {
    const model = process.env.OPENAI_MODEL_REPLY || process.env.OPENAI_MODEL_MESSAGE || "gpt-4o-mini";

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        temperature: 0.4,
        messages: [
          {
            role: "system",
            content: [
              "You write SMS replies for small businesses.",
              "This is NOT the first follow-up after a missed call.",
              "The customer has already texted back, so continue the conversation naturally.",
              "Do not say 'sorry we missed your call' or restart the conversation.",
              "Reply in 1-2 short sentences.",
              "Your primary goal is to recover revenue by moving a legitimate new or existing customer toward an appointment or human callback.",
              "Do not diagnose, troubleshoot, or conduct an interview over text.",
              "Acknowledge the issue briefly, then make a concrete next-step offer.",
              "Ask at most one question, preferably a choice such as today or tomorrow, morning or afternoon, appointment or callback.",
              "If the customer has already answered a diagnostic question, do not ask a narrower diagnostic question; move to service immediately.",
              "Never claim an appointment is confirmed unless the input explicitly says the business confirmed it.",
              "Never claim a day or time is available. Callsy does not know the shop calendar.",
              "Never invent or output a placeholder booking link.",
              "For urgent issues or a possible comeback after recent work, recommend getting it in as soon as possible and ask what day works.",
              "For non-urgent work, ask what day this week works.",
              "If the customer proposes a day or time window, say the team will contact them to confirm the exact time; do not ask another scheduling question.",
              "If an existing customer reports a problem related to recent work, apologize once without admitting legal liability, take ownership of helping, and offer to get it back into the shop as soon as possible.",
              "Do not tell the customer to pull over, stop driving, tow the vehicle, or attempt a repair unless the business explicitly configured that instruction.",
              "Mention the business name naturally if helpful.",
              "Do not mention AI or automation.",
              "No emojis.",
              "Return only the message text."
            ].join("\n")
          },
          {
            role: "user",
            content: [
              `Business name: ${cleanLine(params.business?.name)}`,
              `Business type: ${cleanLine(params.business?.businessType)}`,
              `Business description: ${cleanLine(params.business?.businessDescription)}`,
              `Tone: ${cleanLine(params.business?.tone || "friendly")}`,
              `Customer message: ${cleanLine(params.customerMessage)}`,
              `Lead classification: ${cleanLine(params.classification?.category)}`,
              `Classification reason: ${cleanLine(params.classification?.reason)}`,
              `Previous outgoing message: ${cleanLine(params.priorFollowupMessage)}`,
              `Booking link: ${cleanLine(params.business?.bookingLink)}`,
              "",
              "Write the best next reply as a real business owner or receptionist would."
            ].join("\n")
          }
        ]
      })
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => "");
      throw new Error(
        `OpenAI conversation reply request failed: ${response.status} ${response.statusText} ${errorText}`
      );
    }

    const data = (await response.json()) as any;
    const content = data?.choices?.[0]?.message?.content;
    const normalized = normalizeConversationReply(content, fallback);

    return {
      message: normalized,
      usedAi: normalized !== fallback
    };
  } catch (error) {
    console.error("AI conversation reply generation failed:", error);
    return {
      message: fallback,
      usedAi: false
    };
  }
}

async function saveLeadClassification(leadId: string, classification: any) {
  await Lead.updateOne(
    { _id: leadId },
    {
      $set: {
        "classification.category": classification.category,
        "classification.confidence": classification.confidence,
        "classification.reason": classification.reason,
        "classification.shouldAutoFollowup": classification.shouldAutoFollowup,
        "classification.classifiedAt": new Date()
      }
    }
  );
}

async function saveLeadFollowupBlocked(leadId: string, reason: string) {
  await Lead.updateOne(
    { _id: leadId },
    {
      $set: {
        "followup.blocked": true,
        "followup.blockedReason": reason
      }
    }
  );
}

async function saveLeadReplyMetadata(leadId: string, message: string) {
  await Lead.updateOne(
    { _id: leadId },
    {
      $inc: { smsReplyCount: 1 },
      $set: {
        lastSeenAt: new Date(),
        lastCustomerMessage: message,
        lastMessageDirection: "inbound_sms",
        "smsConsent.status": "granted",
        "smsConsent.source": "inbound_sms",
        "smsConsent.capturedAt": new Date()
      }
    }
  );
}

async function findOrCreateSmsLead(businessId: string, phone: string) {
  const now = new Date();

  return Lead.findOneAndUpdate(
    { businessId, phone },
    {
      $setOnInsert: {
        businessId,
        phone,
        firstSeenAt: now,
        callCount: 0,
        smsReplyCount: 0,
        status: "new",
        "followup.blocked": false,
        "followup.sent": false
      },
      $set: {
        lastSeenAt: now
      }
    },
    { new: true, upsert: true }
  );
}

async function sendConsentedMissedCallFollowup(params: {
  business: any;
  lead: any;
  customerPhone: string;
}) {
  const { business, lead, customerPhone: from } = params;
  const cooldownMinutes = Number(business.cooldownMinutes ?? 120);
  const lastFollowupAt = lead?.lastFollowupAt as Date | undefined;
  const { aiEnabled, autoFollowupEnabled, useAiGeneratedMessage } =
    getAiFlags(business);

  if (!autoFollowupEnabled) {
    await saveLeadFollowupBlocked(String(lead._id), "auto_followup_disabled");
    return { sent: false, reason: "auto_followup_disabled" };
  }

  if (isCooldownActive(lastFollowupAt, cooldownMinutes)) {
    return { sent: false, reason: "cooldown_active" };
  }

  let messageBody = "";
  if (aiEnabled && useAiGeneratedMessage) {
    const generated = await generateInitialFollowupMessage({
      businessName: String(business.name ?? ""),
      businessType: String(business.businessType ?? ""),
      businessDescription: String(business.businessDescription ?? ""),
      tone: business.tone ?? "friendly",
      style: business.firstResponseStyle ?? "conversational",
      bookingLink: String(business.bookingLink ?? ""),
      menuOptions: getMenuOptions(business)
    });
    messageBody = generated.message;
  } else {
    const template = String(
      business.followupTemplate ??
        "Hi — this is {{business}}. Sorry we missed your call. How can we help?"
    );
    messageBody = buildFollowupMessage(template, {
      caller: from,
      business: String(business.name ?? ""),
      link: String(business.bookingLink ?? "")
    });
    if (
      business.firstResponseStyle === "menu" &&
      Array.isArray(business.menuOptions) &&
      business.menuOptions.length > 0
    ) {
      messageBody = appendMenuOptions(messageBody, business.menuOptions);
    }
  }

  if (!/\bstop\b/i.test(messageBody)) {
    messageBody = `${messageBody} Reply STOP to unsubscribe.`;
  }

  const smsResult: any = await sendSms(from, messageBody, business.twilioNumber);
  const messageSid = String(smsResult?.sid ?? `DRY_RUN_${Date.now()}`);

  await SmsEvent.findOneAndUpdate(
    { messageSid },
    {
      $setOnInsert: {
        businessId: business._id,
        leadId: lead?._id,
        messageSid,
        direction: "outbound-followup",
        from: normalizePhone(String(business.twilioNumber ?? "")),
        to: from,
        body: messageBody,
        status: String(smsResult?.status ?? "sent"),
        raw: smsResult ?? { dryRun: true }
      }
    },
    { new: true, upsert: true }
  );

  await markFollowupSent(String(lead._id), messageBody);
  return { sent: true, reason: "sent" };
}

export const voiceWebhook = async (req: Request, res: Response) => {
  const from = normalizePhone(req.body?.From);
  const to = normalizePhone(req.body?.To);
  const callSid = String(req.body?.CallSid ?? "");

  console.log("VOICE WEBHOOK HIT", { from, to, callSid, raw: req.body });

  if (!from || !to || !callSid) {
    console.log("VOICE WEBHOOK MISSING REQUIRED FIELDS", { from, to, callSid });
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  const business: any = await Business.findOne({
    twilioNumber: to,
    isActive: true
  });

  console.log(
    "VOICE BUSINESS FOUND",
    business
      ? {
          id: String(business._id),
          name: business.name,
          twilioNumber: business.twilioNumber
        }
      : null
  );

  if (!business) {
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  const lead: any = await upsertLead(String(business._id), from);

  console.log(
    "VOICE LEAD",
    lead
      ? {
          id: String(lead._id),
          businessId: String(lead.businessId),
          phone: lead.phone
        }
      : null
  );

  await CallEvent.findOneAndUpdate(
    {
      businessId: business._id,
      callSid
    },
    {
      $setOnInsert: {
        businessId: business._id,
        leadId: lead?._id,
        callSid,
        from,
        to,
        callStatus: String(req.body?.CallStatus ?? "forwarded"),
        direction: String(req.body?.Direction ?? "inbound"),
        raw: req.body
      }
    },
    { new: true, upsert: true }
  );

  console.log("VOICE CALLEVENT WRITTEN", {
    businessId: String(business._id),
    callSid
  });

  // A missed call contains no intent. Keep the lead unclassified until the
  // customer replies with actual message content.
  if (Number(lead?.smsReplyCount || 0) === 0) {
    await Lead.updateOne(
      { _id: lead._id },
      {
        $set: {
          "classification.category": "unknown",
          "classification.confidence": 0,
          "classification.reason": "Awaiting customer reply",
          "classification.shouldAutoFollowup": true
        },
        $unset: { "classification.classifiedAt": 1 }
      }
    );
  }

  const { autoFollowupEnabled } = getAiFlags(business);
  if (!autoFollowupEnabled) {
    await saveLeadFollowupBlocked(String(lead._id), "auto_followup_disabled");
    await Lead.updateOne({ _id: lead._id }, { $set: { status: "callback_required" } });
    await CallEvent.updateOne(
      { businessId: business._id, callSid },
      { $set: { callbackRequired: true } }
    );
    res.type("text/xml");
    return res.send(twiml("<Say>Sorry we missed your call. The team will see your callback request.</Say><Hangup/>"));
  }

  const now = new Date();
  await Promise.all([
    CallEvent.updateOne(
      { businessId: business._id, callSid },
      {
        $set: {
          "consent.status": "pending",
          "consent.disclosureVersion": MISSED_CALL_DISCLOSURE_VERSION,
          "consent.requestedAt": now,
          callbackRequired: false
        }
      }
    ),
    Lead.updateOne(
      { _id: lead._id },
      {
        $set: {
          status: "awaiting_consent",
          "smsConsent.status": "pending",
          "smsConsent.callSid": callSid,
          "smsConsent.disclosureVersion": MISSED_CALL_DISCLOSURE_VERSION
        }
      }
    )
  ]);

  res.type("text/xml");
  return res.send(consentPromptTwiml(String(business.name ?? "")));
};

export const voiceConsentWebhook = async (req: Request, res: Response) => {
  const callSid = String(req.body?.CallSid ?? "");
  const digits = String(req.body?.Digits ?? "").trim();
  const speech = cleanLine(req.body?.SpeechResult).toLowerCase();
  const acceptedSpeech = /^(yes|yeah|yep|sure|okay|ok|please|yes please)\b/.test(speech);
  const granted = digits === "1" || acceptedSpeech;
  const method = digits ? "keypress" : speech ? "speech" : "";
  const responseValue = digits || speech;

  const event: any = await CallEvent.findOne({ callSid });
  if (!event) {
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  if (event?.consent?.status === "granted") {
    res.type("text/xml");
    return res.send(twiml("<Say>Thanks. Your text is on its way.</Say><Hangup/>"));
  }

  const resolvedAt = new Date();
  const consentStatus = granted ? "granted" : responseValue ? "declined" : "no_response";
  await CallEvent.updateOne(
    { _id: event._id },
    {
      $set: {
        "consent.status": consentStatus,
        "consent.method": method,
        "consent.response": responseValue,
        "consent.disclosureVersion": MISSED_CALL_DISCLOSURE_VERSION,
        "consent.resolvedAt": resolvedAt,
        callbackRequired: !granted
      }
    }
  );

  const lead: any = event.leadId ? await Lead.findById(event.leadId) : null;
  const business: any = await Business.findById(event.businessId);
  if (!lead || !business) {
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  if (!granted) {
    await Lead.updateOne(
      { _id: lead._id },
      {
        $set: {
          status: "callback_required",
          "smsConsent.status": responseValue ? "declined" : "unknown",
          "smsConsent.source": "",
          "followup.blocked": true,
          "followup.blockedReason": responseValue ? "sms_consent_declined" : "sms_consent_not_received"
        }
      }
    );
    res.type("text/xml");
    return res.send(
      twiml("<Say>No problem. The team will see that you called and can return your call.</Say><Hangup/>")
    );
  }

  await Lead.updateOne(
    { _id: lead._id },
    {
      $set: {
        status: "new",
        "smsConsent.status": "granted",
        "smsConsent.source": method === "keypress" ? "voice_keypress" : "voice_speech",
        "smsConsent.callSid": callSid,
        "smsConsent.disclosureVersion": MISSED_CALL_DISCLOSURE_VERSION,
        "smsConsent.capturedAt": resolvedAt,
        "followup.blocked": false,
        "followup.blockedReason": ""
      }
    }
  );

  const result = await sendConsentedMissedCallFollowup({
    business,
    lead,
    customerPhone: String(event.from)
  });

  res.type("text/xml");
  return res.send(
    result.sent
      ? twiml("<Say>Thanks. Your text is on its way.</Say><Hangup/>")
      : twiml("<Say>Thanks. The team has your request.</Say><Hangup/>")
  );
};

export const smsInboundWebhook = async (req: Request, res: Response) => {
  console.log("=== SMS INBOUND WEBHOOK REACHED ===");
  console.log("RAW BODY:", req.body);

  const from = normalizePhone(req.body?.From);
  const to = normalizePhone(req.body?.To);
  const body = String(req.body?.Body ?? "").trim();
  const messageSid = String(req.body?.MessageSid ?? "");

  console.log("SMS WEBHOOK HIT", { from, to, body, messageSid, raw: req.body });

  if (!from || !to) {
    console.log("SMS WEBHOOK MISSING REQUIRED FIELDS", { from, to, messageSid });
    return res.status(200).json({ ok: true });
  }

  if (messageSid) {
    const duplicate = await SmsEvent.exists({ messageSid });
    if (duplicate) {
      console.log("SMS WEBHOOK DUPLICATE IGNORED", { messageSid });
      return res.status(200).json({ ok: true, duplicate: true });
    }
  }

  const business: any = await Business.findOne({
    twilioNumber: to,
    isActive: true
  });

  console.log(
    "SMS BUSINESS FOUND",
    business
      ? {
          id: String(business._id),
          name: business.name,
          twilioNumber: business.twilioNumber
        }
      : null
  );

  if (!business) {
    return res.status(200).json({ ok: true });
  }

  const lead: any = await findOrCreateSmsLead(String(business._id), from);
  const inboundMessageSid = messageSid || `SM_${Date.now()}`;

  await SmsEvent.findOneAndUpdate(
    { messageSid: inboundMessageSid },
    {
      $setOnInsert: {
        businessId: business._id,
        leadId: lead?._id,
        messageSid: inboundMessageSid,
        direction: "inbound-reply",
        from,
        to,
        body,
        status: "received",
        raw: req.body
      }
    },
    { new: true, upsert: true }
  );

  console.log("SMS INBOUND EVENT WRITTEN", {
    businessId: String(business._id),
    messageSid: inboundMessageSid
  });

  await saveLeadReplyMetadata(String(lead._id), body);

  const requestedWindow = extractAppointmentWindow(body);
  if (requestedWindow) {
    await Lead.updateOne(
      { _id: lead._id },
      { $set: {
        "appointment.status": "requested",
        "appointment.requestedWindow": requestedWindow,
        "appointment.requestedAt": new Date(),
        status: "appointment_requested"
      } }
    );
  }

  const recentCustomerMessages: any[] = await SmsEvent.find({
    businessId: business._id,
    leadId: lead._id,
    direction: "inbound-reply"
  }).sort({ createdAt: -1 }).limit(5).select("body").lean();
  const priorityContext = recentCustomerMessages
    .map((event) => String(event.body || ""))
    .reverse()
    .join(" ");
  const priorityInput = /\b(flashing|blinking)\b/i.test(body)
    ? priorityContext
    : body;

  const priority = detectPriorityMessage(
    priorityInput,
    business.priorityEscalation?.urgentKeywords
  );
  let priorityEvent: any = null;

  if (
    priority.isUrgent &&
    business.priorityEscalation?.enabled &&
    normalizePhone(String(business.priorityEscalation?.primaryPhone || ""))
  ) {
    priorityEvent = await startPriorityEscalation({
      business,
      lead,
      customerPhone: from,
      customerMessage: body,
      reason: priority.reason
    });

    await Lead.updateOne(
      { _id: lead._id },
      {
        $set: {
          status: "priority",
          "urgency.isUrgent": true,
          "urgency.reason": priority.reason,
          "urgency.detectedAt": new Date(),
          "urgency.escalationEventId": priorityEvent._id
        }
      }
    );

    if (business.priorityEscalation?.customerConfirmationEnabled !== false) {
      const flashingWarning = priority.reason.includes("flashing warning light");
      const safetyLine = flashingWarning
        ? " We're sorry you're dealing with this after the recent work. We'd like to get it back into the shop as soon as possible."
        : priority.isSafetyRelated
        ? " If anyone is in immediate danger, call 911 now."
        : "";
      const confirmation = `We flagged this as a priority and are contacting the on-call team now. We will confirm when a person acknowledges it.${safetyLine}`;
      await sendSms(from, confirmation, business.twilioNumber);
    }
  }

  const {
    aiEnabled,
    classifyLeads,
    autoFollowupEnabled,
    useAiGeneratedMessage,
    aiConversationRepliesEnabled
  } = getAiFlags(business);

  let classification: any = null;

  if (aiEnabled && classifyLeads) {
    classification = await classifyLead({
      businessName: String(business.name ?? ""),
      businessType: String(business.businessType ?? ""),
      businessDescription: String(business.businessDescription ?? ""),
      callerPhone: from,
      eventType: "inbound_sms",
      latestMessage: body,
      callCount: Number(lead?.callCount ?? 0),
      smsReplyCount: Number((lead?.smsReplyCount ?? 0) + 1),
      priorStatus: String(lead?.status ?? "")
    });

    console.log("SMS AI CLASSIFICATION RESULT", classification);
    await saveLeadClassification(String(lead._id), classification);
  }

  const notifyTo = normalizePhone(String(business.notifyToNumber ?? ""));
  if (notifyTo) {
    let forwardMsg =
      `📩 New reply for ${business.name}\n` +
      `From: ${from}\n` +
      `Message: ${body}`;

    if (classification) {
      forwardMsg +=
        `\n\nAI Category: ${classification.category}` +
        `\nConfidence: ${Math.round(Number(classification.confidence ?? 0) * 100)}%` +
        `\nReason: ${classification.reason}`;
    }


    if (requestedWindow) {
      forwardMsg += `\n\n📅 Appointment requested: ${requestedWindow}\nOpen Callsy to confirm a time or call the customer.`;
    }

    const forwardResult: any = await sendSms(
      notifyTo,
      forwardMsg,
      business.twilioNumber
    );

    console.log("SMS FORWARD RESULT", forwardResult);
  }

  const shouldAutoRespond =
    aiEnabled &&
    autoFollowupEnabled &&
    aiConversationRepliesEnabled &&
    useAiGeneratedMessage &&
    !lead?.manualTakeover?.active &&
    (!classification || classification.shouldAutoFollowup !== false) &&
    !priorityEvent;

  if (shouldAutoRespond) {
    const delayMs = getHumanReplyDelayMs();
    console.log("SMS AI REPLY SCHEDULED", { leadId: String(lead._id), delayMs });

    setTimeout(async () => {
      try {
        const currentLead: any = await Lead.findById(lead._id).lean();
        if (!currentLead || currentLead.manualTakeover?.active) {
          console.log("SMS AI DELAYED REPLY CANCELLED: owner took over", { leadId: String(lead._id) });
          return;
        }

        const generated = requestedWindow
          ? {
              message: `Thanks—I've noted ${requestedWindow}. Someone from ${cleanLine(business.name) || "the team"} will contact you to confirm the exact time.`,
              usedAi: false
            }
          : await generateConversationReplyMessage({
              business,
              customerMessage: body,
              classification,
              priorFollowupMessage: String(lead?.followup?.message ?? "")
            });

        console.log("SMS AI GENERATED MESSAGE AFTER DELAY", generated);
        const smsResult: any = await sendSms(from, generated.message, business.twilioNumber);
        const outboundMessageSid = String(smsResult?.sid ?? `DRY_RUN_${Date.now()}`);

        await SmsEvent.findOneAndUpdate(
          { messageSid: outboundMessageSid },
          { $setOnInsert: {
            businessId: business._id,
            leadId: lead?._id,
            messageSid: outboundMessageSid,
            direction: "outbound-followup",
            from: normalizePhone(String(business.twilioNumber ?? "")),
            to: from,
            body: generated.message,
            status: String(smsResult?.status ?? "sent"),
            raw: smsResult ?? { dryRun: true }
          } },
          { new: true, upsert: true }
        );

        await markFollowupSent(String(lead._id), generated.message);
      } catch (error) {
        console.error("SMS delayed AI reply failed", error);
      }
    }, delayMs);
  } else {
    console.log("SMS AUTO REPLY SKIPPED", {
      businessId: String(business._id),
      aiEnabled,
      autoFollowupEnabled,
      aiConversationRepliesEnabled,
      useAiGeneratedMessage,
      classificationShouldAutoFollowup:
        classification ? classification.shouldAutoFollowup : undefined
    });
  }

  return res.status(200).json({ ok: true });
};

export const escalationResponseWebhook = async (req: Request, res: Response) => {
  const eventId = String(req.params?.eventId || "");
  const role = String(req.query?.role || "primary");
  const digit = String(req.body?.Digits || "");
  const result: any = await acknowledgeOrAdvance(eventId, role, digit);

  res.type("text/xml");
  if (result?.action === "acknowledged") {
    return res.send(twiml("<Say>Priority alert acknowledged. Open Callsy for the customer details.</Say><Hangup/>"));
  }
  if (result?.action === "backup") {
    return res.send(twiml("<Say>The backup contact is being called now.</Say><Hangup/>"));
  }
  return res.send(twiml("<Say>No acknowledgment was recorded. The alert remains visible in Callsy.</Say><Hangup/>"));
};

export const escalationStatusWebhook = async (req: Request, res: Response) => {
  await updateEscalationCallStatus(
    String(req.params?.eventId || ""),
    String(req.query?.role || "primary"),
    String(req.body?.CallSid || ""),
    String(req.body?.CallStatus || "")
  );
  return res.status(200).json({ ok: true });
};

export const callStatusWebhook = async (req: Request, res: Response) => {
  const callSid = String(req.body?.CallSid ?? "");
  const callStatus = String(req.body?.CallStatus ?? "");
  const durationRaw = req.body?.CallDuration;
  const answeredBy = req.body?.AnsweredBy;

  const duration =
    durationRaw != null && durationRaw !== "" ? Number(durationRaw) : undefined;

  if (callSid) {
    await CallEvent.updateOne(
      { callSid },
      {
        $set: {
          callStatus: callStatus || "completed",
          duration,
          answeredBy: answeredBy ? String(answeredBy) : undefined,
          raw: req.body
        }
      }
    ).catch(() => {});
  }

  return res.status(200).json({ ok: true });
};
