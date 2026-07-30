import { apiFetch } from "./client";

export type Business = {
  _id: string;
  ownerId: string;
  name: string;
  forwardToNumber?: string;
  twilioNumber?: string;
  twilioPhoneSid?: string;
  notifyToNumber?: string;
  destinationNumber?: string;
  bookingLink?: string;
  followupTemplate: string;
  isActive: boolean;
  cooldownMinutes: number;
  callHandlingMode?: string;
  onboardingStatus?: string;
  businessType?: string;
  businessDescription?: string;
  tone?: "friendly" | "professional" | "casual" | "direct";
  firstResponseStyle?: "conversational" | "menu" | "appointment";
  menuOptions?: string[];
  useAiGeneratedMessage?: boolean;
  aiConfig?: {
    enabled?: boolean;
    classifyLeads?: boolean;
    autoFollowupEnabled?: boolean;
    conversationRepliesEnabled?: boolean;
  };
  priorityEscalation?: {
    enabled?: boolean;
    primaryPhone?: string;
    backupPhone?: string;
    urgentKeywords?: string[];
    ringTimeoutSeconds?: number;
    customerConfirmationEnabled?: boolean;
  };
  createdAt?: string;
  updatedAt?: string;
};

export async function getMyBusiness() {
  return apiFetch<{ ok: true; business: Business }>("/admin/businesses/me", {
    method: "GET"
  });
}

export async function updateMyBusiness(updates: Partial<Business>) {
  return apiFetch<{ ok: true; business: Business }>("/admin/businesses/me", {
    method: "PATCH",
    json: updates
  });
}

export async function provisionMyBusinessNumber(areaCode?: number) {
  return apiFetch<{ ok: true; business: Business }>("/admin/businesses/me/provision-number", {
    method: "POST",
    json: areaCode ? { areaCode } : {}
  });
}

export async function assignMyBusinessTestNumber(phoneNumber = "+15005550006") {
  return apiFetch<{ ok: true; testMode: true; business: Business }>(
    "/admin/businesses/me/assign-test-number",
    { method: "POST", json: { phoneNumber } }
  );
}

export async function releaseMyBusinessNumber() {
  return apiFetch<{ ok: true; business: Business }>("/admin/businesses/me/release-number", {
    method: "POST"
  });
}
