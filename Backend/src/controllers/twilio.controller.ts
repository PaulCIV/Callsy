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

function twiml(inner: string) {
  return `<Response>${inner}</Response>`;
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

    return `Hi — this is ${businessName}. We can help with that. Are you looking to book service, get pricing, or ask a repair question?`;
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
    return `Hi — this is ${businessName}. Happy to help. What issue are you running into, and do you need a callback or an appointment?`;
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
              "Ask one useful next-step question when appropriate.",
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

async function saveLeadReplyMetadata(leadId: string) {
  await Lead.updateOne(
    { _id: leadId },
    {
      $inc: { smsReplyCount: 1 },
      $set: { lastSeenAt: new Date() }
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

  const cooldownMinutes = Number(business.cooldownMinutes ?? 120);
  const lastFollowupAt = lead?.lastFollowupAt as Date | undefined;
  const { aiEnabled, classifyLeads, autoFollowupEnabled, useAiGeneratedMessage } =
    getAiFlags(business);

  let classification: any = null;

  if (aiEnabled && classifyLeads) {
    classification = await classifyLead({
      businessName: String(business.name ?? ""),
      businessType: String(business.businessType ?? ""),
      businessDescription: String(business.businessDescription ?? ""),
      callerPhone: from,
      eventType: "missed_call",
      latestMessage: "",
      callCount: Number(lead?.callCount ?? 0),
      smsReplyCount: Number(lead?.smsReplyCount ?? 0),
      priorStatus: String(lead?.status ?? "")
    });

    console.log("VOICE AI CLASSIFICATION RESULT", classification);
    await saveLeadClassification(String(lead._id), classification);
  }

  if (!autoFollowupEnabled) {
    console.log("VOICE AUTO FOLLOWUP DISABLED", {
      businessId: String(business._id),
      leadId: String(lead._id)
    });
    await saveLeadFollowupBlocked(String(lead._id), "auto_followup_disabled");
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  if (classification && !classification.shouldAutoFollowup) {
    console.log("VOICE FOLLOWUP BLOCKED BY CLASSIFICATION", {
      businessId: String(business._id),
      leadId: String(lead._id),
      classification
    });
    await saveLeadFollowupBlocked(
      String(lead._id),
      classification.reason || "classification_blocked"
    );
    res.type("text/xml");
    return res.send(twiml("<Hangup/>"));
  }

  if (!isCooldownActive(lastFollowupAt, cooldownMinutes)) {
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
      console.log("VOICE AI GENERATED MESSAGE", {
        usedAi: generated.usedAi,
        message: messageBody
      });
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

    console.log("VOICE ABOUT TO SEND SMS", {
      fromNumber: business.twilioNumber,
      toCustomer: from,
      body: messageBody
    });

    const smsResult: any = await sendSms(from, messageBody, business.twilioNumber);

    console.log("VOICE SMS RESULT", smsResult);

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

    console.log("VOICE SMSEVENT WRITTEN");

    await markFollowupSent(String(lead._id), messageBody);
  } else {
    console.log("COOLDOWN ACTIVE", {
      businessId: String(business._id),
      from,
      cooldownMinutes
    });
  }

  res.type("text/xml");
  return res.send(twiml("<Hangup/>"));
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

  await saveLeadReplyMetadata(String(lead._id));

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

    const forwardResult: any = await sendSms(
      notifyTo,
      forwardMsg,
      business.twilioNumber
    );

    console.log("SMS FORWARD RESULT", forwardResult);
  }

  const hasExistingFollowup = Boolean(lead?.lastFollowupAt || lead?.followup?.sent);
  const shouldAutoRespond =
    aiEnabled &&
    autoFollowupEnabled &&
    aiConversationRepliesEnabled &&
    useAiGeneratedMessage &&
    hasExistingFollowup &&
    (!classification || classification.shouldAutoFollowup !== false);

  if (shouldAutoRespond) {
    const generated = await generateConversationReplyMessage({
      business,
      customerMessage: body,
      classification,
      priorFollowupMessage: String(lead?.followup?.message ?? "")
    });

    console.log("SMS AI GENERATED CONVERSATION REPLY", generated);

    const smsResult: any = await sendSms(from, generated.message, business.twilioNumber);
    const outboundMessageSid = String(smsResult?.sid ?? `DRY_RUN_${Date.now()}`);

    await SmsEvent.findOneAndUpdate(
      { messageSid: outboundMessageSid },
      {
        $setOnInsert: {
          businessId: business._id,
          leadId: lead?._id,
          messageSid: outboundMessageSid,
          direction: "outbound-followup",
          from: normalizePhone(String(business.twilioNumber ?? "")),
          to: from,
          body: generated.message,
          status: String(smsResult?.status ?? "sent"),
          raw: smsResult ?? { dryRun: true }
        }
      },
      { new: true, upsert: true }
    );

    console.log("SMS OUTBOUND FOLLOWUP EVENT WRITTEN", {
      businessId: String(business._id),
      messageSid: outboundMessageSid
    });

    await markFollowupSent(String(lead._id), generated.message);
  } else {
    console.log("SMS AUTO REPLY SKIPPED", {
      businessId: String(business._id),
      aiEnabled,
      autoFollowupEnabled,
      aiConversationRepliesEnabled,
      useAiGeneratedMessage,
      hasExistingFollowup,
      classificationShouldAutoFollowup:
        classification ? classification.shouldAutoFollowup : undefined
    });
  }

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