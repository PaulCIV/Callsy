import twilio from "twilio";
import { env } from "../config/env";
import { normalizePhone } from "../utils/normalizePhone";

type SendSmsResult = {
  sid: string;
  status: string;
  to: string;
  from: string;
  body: string;
  dryRun?: boolean;
};

function getTwilioClient() {
  const hasApiKey = Boolean(env.TWILIO_API_KEY_SID && env.TWILIO_API_KEY_SECRET);
  if (!env.TWILIO_ACCOUNT_SID || (!env.TWILIO_AUTH_TOKEN && !hasApiKey)) {
    return null;
  }

  return hasApiKey
    ? twilio(env.TWILIO_API_KEY_SID, env.TWILIO_API_KEY_SECRET, {
        accountSid: env.TWILIO_ACCOUNT_SID
      })
    : twilio(env.TWILIO_ACCOUNT_SID, env.TWILIO_AUTH_TOKEN);
}

function getDefaultFromNumber(): string {
  return normalizePhone(env.TWILIO_PHONE_NUMBER || "");
}

function shouldDryRun() {
  return String(process.env.SMS_DRY_RUN || "").toLowerCase() === "true";
}

export async function sendSms(
  to: string,
  body: string,
  fromOverride?: string
): Promise<SendSmsResult> {
  const toNumber = normalizePhone(to);
  const fromNumber = normalizePhone(fromOverride || getDefaultFromNumber());

  if (!toNumber) {
    throw new Error("Missing or invalid destination phone number.");
  }

  if (!fromNumber) {
    throw new Error("Missing or invalid source phone number.");
  }

  const cleanBody = String(body ?? "").trim();

  if (!cleanBody) {
    throw new Error("SMS body cannot be empty.");
  }

  const client = getTwilioClient();

  if (!client || shouldDryRun()) {
    const dryRunResult: SendSmsResult = {
      sid: `DRY_RUN_${Date.now()}`,
      status: "sent",
      to: toNumber,
      from: fromNumber,
      body: cleanBody,
      dryRun: true
    };

    console.log("📩 [DRY RUN SMS]", {
      from: dryRunResult.from,
      to: dryRunResult.to,
      body: dryRunResult.body
    });

    return dryRunResult;
  }

  const result = await client.messages.create({
    to: toNumber,
    from: fromNumber,
    body: cleanBody
  });

  return {
    sid: String(result.sid),
    status: String(result.status || "queued"),
    to: toNumber,
    from: fromNumber,
    body: cleanBody,
    dryRun: false
  };
}
