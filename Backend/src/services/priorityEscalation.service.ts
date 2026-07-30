import { env } from "../config/env";
import { twilioClient } from "../config/twilio";
import { Business } from "../models/business";
import { EscalationEvent } from "../models/escalationevent";
import { normalizePhone } from "../utils/normalizePhone";
import { sendSms } from "./sms.service";

const DEFAULT_KEYWORDS = [
  "tow", "towing", "stranded", "broke down", "roadside", "accident",
  "not drivable", "won't start", "wont start", "stuck"
];
const SAFETY_TERMS = ["injury", "injured", "fire", "smoke", "unsafe", "911"];

function cleanSpeech(value: unknown) {
  return String(value ?? "")
    .replace(/[<>]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 420);
}

export function detectPriorityMessage(message: string, configuredKeywords?: string[]) {
  const normalized = String(message || "").toLowerCase();
  const keywords = [...DEFAULT_KEYWORDS, ...(configuredKeywords || [])]
    .map((item) => String(item).trim().toLowerCase())
    .filter(Boolean);
  const matchedKeyword = keywords.find((keyword) => normalized.includes(keyword));
  const safetyTerm = SAFETY_TERMS.find((term) => normalized.includes(term));
  const flashingVehicleWarning =
    (normalized.includes("flashing") || normalized.includes("blinking")) &&
    (normalized.includes("check engine") || normalized.includes("warning light") || normalized.includes("engine light"));

  return {
    isUrgent: Boolean(matchedKeyword || safetyTerm || flashingVehicleWarning),
    reason: flashingVehicleWarning
      ? "Potential vehicle safety issue: flashing warning light"
      : safetyTerm
      ? `Potential safety issue: ${safetyTerm}`
      : matchedKeyword
        ? `Priority keyword detected: ${matchedKeyword}`
        : "",
    isSafetyRelated: Boolean(safetyTerm || flashingVehicleWarning)
  };
}

function publicBaseUrl() {
  return String(env.PUBLIC_WEBHOOK_BASE_URL || "").replace(/\/+$/, "");
}

function voiceTwiml(eventId: string, businessName: string, summary: string, role: string) {
  const action = `${publicBaseUrl()}/twilio/escalations/${eventId}/respond?role=${role}`;
  return [
    "<Response>",
    `<Gather numDigits="1" timeout="8" actionOnEmptyResult="true" method="POST" action="${action}">`,
    `<Say voice="Polly.Joanna">Priority Callsy alert for ${cleanSpeech(businessName)}. ${cleanSpeech(summary)}. Press 1 to acknowledge. Press 2 to send this alert to the backup contact.</Say>`,
    "</Gather>",
    "<Hangup/>",
    "</Response>"
  ].join("");
}

async function placeAttempt(event: any, business: any, role: "primary" | "backup") {
  const phone = normalizePhone(
    role === "primary"
      ? business.priorityEscalation?.primaryPhone
      : business.priorityEscalation?.backupPhone
  );
  const from = normalizePhone(business.twilioNumber || env.TWILIO_DEFAULT_FROM || "");
  const dryRun = String(process.env.VOICE_DRY_RUN || "").toLowerCase() === "true";

  if (!phone || !from || (!dryRun && !publicBaseUrl())) return false;

  const attempt = { role, phone, status: "queued", startedAt: new Date() };
  event.attempts.push(attempt);
  await event.save();

  if (dryRun) {
    event.attempts[event.attempts.length - 1].callSid = `DRY_CALL_${Date.now()}`;
    await event.save();
    return true;
  }

  const call = await twilioClient.calls.create({
    to: phone,
    from,
    twiml: voiceTwiml(String(event._id), business.name, event.summary, role),
    timeout: Math.max(10, Math.min(30, Number(business.priorityEscalation?.ringTimeoutSeconds || 20))),
    statusCallback: `${publicBaseUrl()}/twilio/escalations/${event._id}/status?role=${role}`,
    statusCallbackMethod: "POST",
    statusCallbackEvent: ["initiated", "ringing", "answered", "completed"]
  });

  event.attempts[event.attempts.length - 1].callSid = String(call.sid);
  event.attempts[event.attempts.length - 1].status = String(call.status || "queued");
  await event.save();
  return true;
}

export async function startPriorityEscalation(params: {
  business: any;
  lead: any;
  customerPhone: string;
  customerMessage: string;
  reason: string;
}) {
  const existing = await EscalationEvent.findOne({
    leadId: params.lead._id,
    status: "calling",
    createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) }
  });
  if (existing) return existing;

  const summary = `A customer at ${cleanSpeech(params.customerPhone)} wrote: ${cleanSpeech(params.customerMessage)}`;
  const event = await EscalationEvent.create({
    businessId: params.business._id,
    leadId: params.lead._id,
    customerPhone: params.customerPhone,
    customerMessage: params.customerMessage,
    reason: params.reason,
    summary,
    status: "calling"
  });

  await placeAttempt(event, params.business, "primary");
  return event;
}

export async function acknowledgeOrAdvance(eventId: string, role: string, digit: string) {
  const event: any = await EscalationEvent.findById(eventId);
  if (!event || event.status !== "calling") return { event, action: "ignored" };

  if (digit === "1") {
    event.status = "acknowledged";
    event.acknowledgedBy = role;
    event.acknowledgedAt = new Date();
    await event.save();
    const business: any = await Business.findById(event.businessId);
    if (business?.priorityEscalation?.customerConfirmationEnabled !== false) {
      await sendSms(
        event.customerPhone,
        `${business?.name || "The team"} has received your priority request and will contact you directly.`,
        business?.twilioNumber
      ).catch((error) => console.error("Priority acknowledgment SMS failed:", error));
    }
    return { event, action: "acknowledged" };
  }

  const business: any = await Business.findById(event.businessId);
  const alreadyCalledBackup = event.attempts.some((attempt: any) => attempt.role === "backup");
  if (business && !alreadyCalledBackup && business.priorityEscalation?.backupPhone) {
    await placeAttempt(event, business, "backup");
    return { event, action: "backup" };
  }

  event.status = "unanswered";
  await event.save();
  return { event, action: "unanswered" };
}

export async function updateEscalationCallStatus(
  eventId: string,
  role: string,
  callSid: string,
  callStatus: string
) {
  const event: any = await EscalationEvent.findById(eventId);
  if (!event) return null;

  const attempt = event.attempts.find(
    (item: any) => item.callSid === callSid || (!item.callSid && item.role === role)
  );
  if (attempt) {
    attempt.callSid = callSid || attempt.callSid;
    attempt.status = callStatus;
    if (["completed", "busy", "failed", "no-answer", "canceled"].includes(callStatus)) {
      attempt.completedAt = new Date();
    }
  }
  await event.save();

  if (
    event.status === "calling" &&
    role === "primary" &&
    ["busy", "failed", "no-answer"].includes(callStatus)
  ) {
    return acknowledgeOrAdvance(eventId, role, "2");
  }
  return event;
}
