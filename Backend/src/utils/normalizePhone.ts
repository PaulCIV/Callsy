export function normalizePhone(input: string): string {
    // For MVP, assume Twilio gives E.164 like +15551234567.
    // We still trim and collapse spaces.
    return String(input ?? "").trim().replace(/\s+/g, "");
  }