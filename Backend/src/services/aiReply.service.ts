import { env } from "../config/env";

export type ConversationTone = "friendly" | "professional" | "casual" | "direct";
export type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

export type GenerateReplyInput = {
  businessName: string;
  businessType?: string;
  businessDescription?: string;
  tone?: ConversationTone;
  bookingLink?: string;
  customerMessage: string;
  classificationCategory?: LeadCategory;
  classificationReason?: string;
  previousOutgoingMessage?: string;
};

export type GenerateReplyResult = {
  message: string;
  usedAi: boolean;
};

function getOpenAiApiKey(): string {
  const apiKey = env.OPENAI_API_KEY || "";

  if (!apiKey) {
    throw new Error("Missing OPENAI_API_KEY.");
  }

  return apiKey;
}

function getReplyModel(): string {
  return process.env.OPENAI_MODEL_REPLY || process.env.OPENAI_MODEL_MESSAGE || "gpt-4o-mini";
}

function cleanLine(value: unknown): string {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function countWords(text: string): number {
  return text
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function stripQuotes(text: string): string {
  let msg = text.trim();

  if (
    (msg.startsWith('"') && msg.endsWith('"')) ||
    (msg.startsWith("'") && msg.endsWith("'"))
  ) {
    msg = msg.slice(1, -1).trim();
  }

  return msg;
}

function ensureNoStopLanguage(text: string): string {
  return text
    .replace(/reply stop to opt out\.?/gi, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function containsAny(text: string, values: string[]) {
  const lowered = text.toLowerCase();
  return values.some((value) => lowered.includes(value));
}

function buildFallbackReply(input: GenerateReplyInput): string {
  const businessName = cleanLine(input.businessName) || "our team";
  const businessType = cleanLine(input.businessType).toLowerCase();
  const bookingLink = cleanLine(input.bookingLink);
  const message = cleanLine(input.customerMessage).toLowerCase();
  const tone = input.tone ?? "friendly";

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
    let reply =
      tone === "direct"
        ? `Hi — this is ${businessName}. Are you looking for morning or afternoon?`
        : `Hi — this is ${businessName}. We can help with that. Were you looking for morning or afternoon?`;

    if (bookingLink) {
      reply += ` You can also book here: ${bookingLink}`;
    }

    return reply;
  }

  if (asksPricing) {
    return `Hi — this is ${businessName}. We can help with pricing. Are you looking for a rough estimate, or are you trying to get scheduled?`;
  }

  if (input.classificationCategory === "existing_customer") {
    return `Hi — this is ${businessName}. Happy to help. What issue are you running into, and do you need a callback or an appointment?`;
  }

  if (tone === "direct") {
    return `Hi — this is ${businessName}. What do you need help with — booking, pricing, or a quick question?`;
  }

  return `Hi — this is ${businessName}. We can help with that. Are you looking to book, get pricing, or ask a quick question?`;
}

function isWeakReply(message: string): boolean {
  const normalized = cleanLine(message).toLowerCase();

  if (!normalized) return true;
  if (countWords(normalized) < 8) return true;

  if (
    normalized.includes("sorry we missed your call") ||
    normalized.includes("missed your call")
  ) {
    return true;
  }

  if (
    normalized === "hi" ||
    normalized === "hello" ||
    normalized === "how can we help" ||
    normalized === "how can we help?"
  ) {
    return true;
  }

  return false;
}

function normalizeGeneratedReply(rawText: unknown, fallback: string): string {
  let message = cleanLine(rawText);

  if (!message) {
    return fallback;
  }

  message = stripQuotes(message);
  message = ensureNoStopLanguage(message);

  if (isWeakReply(message)) {
    return fallback;
  }

  return message;
}

function buildSystemPrompt(): string {
  return [
    "You write SMS replies for small businesses.",
    "The customer has already texted back.",
    "This is an ongoing conversation reply, not the first missed-call follow-up.",
    "Do not say 'sorry we missed your call' or restart the conversation.",
    "Reply in 1-2 short sentences.",
    "Ask one useful next-step question when appropriate.",
    "Do not mention AI or automation.",
    "No emojis.",
    "Return only the message text."
  ].join("\n");
}

function buildUserPrompt(input: GenerateReplyInput): string {
  const fallback = buildFallbackReply(input);

  return [
    `Business name: ${cleanLine(input.businessName)}`,
    `Business type: ${cleanLine(input.businessType)}`,
    `Business description: ${cleanLine(input.businessDescription)}`,
    `Tone: ${cleanLine(input.tone || "friendly")}`,
    `Customer message: ${cleanLine(input.customerMessage)}`,
    `Lead classification: ${cleanLine(input.classificationCategory)}`,
    `Classification reason: ${cleanLine(input.classificationReason)}`,
    `Previous outgoing message: ${cleanLine(input.previousOutgoingMessage)}`,
    `Booking link: ${cleanLine(input.bookingLink)}`,
    "",
    "Write the best next reply as a real business owner or receptionist would.",
    "If useful, follow this structure closely:",
    fallback
  ].join("\n");
}

async function callOpenAiReplyGenerator(
  input: GenerateReplyInput
): Promise<string> {
  const apiKey = getOpenAiApiKey();
  const model = getReplyModel();

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
          content: buildSystemPrompt()
        },
        {
          role: "user",
          content: buildUserPrompt(input)
        }
      ]
    })
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    throw new Error(
      `OpenAI reply request failed: ${response.status} ${response.statusText} ${errorText}`
    );
  }

  const data = (await response.json()) as any;
  const content = data?.choices?.[0]?.message?.content;

  if (!content || typeof content !== "string") {
    throw new Error("OpenAI reply generator returned no message content.");
  }

  return content;
}

export async function generateConversationReply(
  input: GenerateReplyInput
): Promise<GenerateReplyResult> {
  const fallback = buildFallbackReply(input);

  try {
    const aiMessage = await callOpenAiReplyGenerator(input);
    const normalized = normalizeGeneratedReply(aiMessage, fallback);

    return {
      message: normalized,
      usedAi: normalized.trim() !== fallback.trim()
    };
  } catch (error) {
    console.error("AI conversation reply generation failed:", error);

    return {
      message: fallback,
      usedAi: false
    };
  }
}