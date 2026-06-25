import { twilioClient } from "../config/twilio";
import { env } from "../config/env";

function ensureTwilioProvisioningConfig() {
  if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN) {
    throw new Error("Twilio is not configured. Missing account SID or auth token.");
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