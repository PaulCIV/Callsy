import { twilioClient } from "../config/twilio";
import { env } from "../config/env";

function ensureTwilioProvisioningConfig() {
  const hasApiKey = Boolean(env.TWILIO_API_KEY_SID && env.TWILIO_API_KEY_SECRET);
  if (!env.TWILIO_ACCOUNT_SID || (!env.TWILIO_AUTH_TOKEN && !hasApiKey)) {
    throw new Error("Twilio is not configured. Add an auth token or API key credentials.");
  }

  if (!env.PUBLIC_WEBHOOK_BASE_URL) {
    throw new Error("Missing PUBLIC_WEBHOOK_BASE_URL for Twilio webhook configuration.");
  }
}

function normalizeBaseUrl(url: string) {
  return url.replace(/\/+$/, "");
}

export async function provisionIncomingNumber(options?: {
  areaCode?: number;
  country?: string;
  friendlyName?: string;
}) {
  ensureTwilioProvisioningConfig();

  const country = options?.country || env.TWILIO_NUMBER_COUNTRY || "US";
  const baseUrl = normalizeBaseUrl(env.PUBLIC_WEBHOOK_BASE_URL);

  let availableNumbers: any[] = [];

  if (country === "US") {
    availableNumbers = await twilioClient
      .availablePhoneNumbers("US")
      .local.list({
        limit: 1,
        ...(options?.areaCode ? { areaCode: options.areaCode } : {})
      });
  } else {
    availableNumbers = await twilioClient
      .availablePhoneNumbers(country)
      .local.list({ limit: 1 });
  }

  if (!availableNumbers.length) {
    throw new Error("No available Twilio numbers found.");
  }

  const selected = availableNumbers[0];

  const incomingNumber = await twilioClient.incomingPhoneNumbers.create({
    phoneNumber: selected.phoneNumber,
    friendlyName: options?.friendlyName || "Callsy Customer Number",
    voiceUrl: `${baseUrl}/twilio/voice`,
    voiceMethod: "POST",
    smsUrl: `${baseUrl}/twilio/sms-inbound`,
    smsMethod: "POST"
  });

  return {
    sid: incomingNumber.sid,
    phoneNumber: incomingNumber.phoneNumber
  };
}

export async function releaseIncomingNumber(phoneSid: string) {
  ensureTwilioProvisioningConfig();

  if (!phoneSid || !phoneSid.trim()) {
    throw new Error("Phone SID is required to release a Twilio number.");
  }

  const removed = await twilioClient.incomingPhoneNumbers(phoneSid).remove();

  if (!removed) {
    throw new Error("Failed to release Twilio number.");
  }

  return { ok: true };
}

export async function connectExistingIncomingNumber(phoneNumber: string) {
  ensureTwilioProvisioningConfig();
  const normalized = String(phoneNumber || "").replace(/[^\d+]/g, "");
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) {
    throw new Error("Phone number must use E.164 format, for example +13158590469.");
  }

  const matches = await twilioClient.incomingPhoneNumbers.list({
    phoneNumber: normalized,
    limit: 2
  });
  const incomingNumber = matches.find((item: any) => item.phoneNumber === normalized);
  if (!incomingNumber) {
    const error = new Error("That number was not found in this Twilio account.") as Error & { status?: number };
    error.status = 404;
    throw error;
  }

  const baseUrl = normalizeBaseUrl(env.PUBLIC_WEBHOOK_BASE_URL);
  const updated = await twilioClient.incomingPhoneNumbers(incomingNumber.sid).update({
    voiceUrl: `${baseUrl}/twilio/voice`,
    voiceMethod: "POST",
    smsUrl: `${baseUrl}/twilio/sms-inbound`,
    smsMethod: "POST"
  });

  return { sid: String(updated.sid), phoneNumber: String(updated.phoneNumber) };
}
