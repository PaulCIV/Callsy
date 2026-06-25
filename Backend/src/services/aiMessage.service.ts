/// src/services/aiMessage.service.ts

import { env } from "../config/env";

export type MessageTone = "friendly" | "professional" | "casual" | "direct";
export type FirstResponseStyle = "conversational" | "menu" | "appointment";

export type GenerateInitialMessageInput = {
  businessName: string;
  businessType?: string;
  businessDescription?: string;
  tone?: MessageTone;
  style?: FirstResponseStyle;
  bookingLink?: string;
  menuOptions?: string[];
};

export type GenerateInitialMessageResult = {
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

function getMessageModel(): string {
  return process.env.OPENAI_MODEL_MESSAGE || "gpt-4o-mini";
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

function limitSentenceCount(text: string, maxSentences: number): string {
  const parts = text
    .split(/(?<=[.!?])\s+/)
    .map((p) => p.trim())
    .filter(Boolean);

  if (parts.length <= maxSentences) {
    return text.trim();
  }

  return parts.slice(0, maxSentences).join(" ").trim();
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

function buildMenuBlock(options: string[]): string {
  return options
    .map((option, index) => `${index + 1}. ${cleanLine(option)}`)
    .filter(Boolean)
    .join("\n");
}

function getDefaultMenuOptions(
  businessType?: string,
  provided?: string[]
): string[] {
  const cleanedProvided = Array.isArray(provided)
    ? provided.map(cleanLine).filter(Boolean)
    : [];

  if (cleanedProvided.length > 0) {
    return cleanedProvided.slice(0, 4);
  }

  const type = cleanLine(businessType).toLowerCase();

  if (type.includes("auto")) {
    return [
      "Schedule service",
      "Ask about pricing",
      "Repair question",
      "Something else"
    ];
  }

  if (
    type.includes("dental") ||
    type.includes("dentist") ||
    type.includes("doctor") ||
    type.includes("clinic") ||
    type.includes("med")
  ) {
    return [
      "Book an appointment",
      "Ask about availability",
      "Insurance or pricing",
      "Something else"
    ];
  }

  if (
    type.includes("plumb") ||
    type.includes("electric") ||
    type.includes("hvac") ||
    type.includes("roof") ||
    type.includes("contract")
  ) {
    return [
      "Need service",
      "Ask about pricing",
      "Urgent issue",
      "Something else"
    ];
  }

  if (
    type.includes("salon") ||
    type.includes("spa") ||
    type.includes("barber") ||
    type.includes("beauty")
  ) {
    return [
      "Book an appointment",
      "Ask about pricing",
      "Ask about services",
      "Something else"
    ];
  }

  if (
    type.includes("restaurant") ||
    type.includes("cafe") ||
    type.includes("food")
  ) {
    return [
      "Place an order",
      "Ask about hours",
      "Ask about menu",
      "Something else"
    ];
  }

  return [
    "Book an appointment",
    "Ask about pricing",
    "General question",
    "Something else"
  ];
}

function buildFallbackMessage(input: GenerateInitialMessageInput): string {
  const businessName = cleanLine(input.businessName) || "our team";
  const businessType = cleanLine(input.businessType).toLowerCase();
  const style = input.style ?? "conversational";
  const tone = input.tone ?? "friendly";
  const bookingLink = cleanLine(input.bookingLink);

  if (style === "appointment") {
    let message =
      tone === "direct"
        ? `Hi — this is ${businessName}. Were you trying to book an appointment?`
        : `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to book an appointment?`;

    if (bookingLink) {
      message += ` You can also book here: ${bookingLink}`;
    }

    return message.trim();
  }

  if (style === "menu") {
    const options = getDefaultMenuOptions(input.businessType, input.menuOptions);
    const intro =
      tone === "professional"
        ? `Hi — this is ${businessName}. Sorry we missed your call. How can we help today?`
        : `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;

    return `${intro}\n\n${buildMenuBlock(options)}`;
  }

  if (businessType.includes("auto")) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you calling about a repair, service, or pricing?`;
  }

  if (
    businessType.includes("plumb") ||
    businessType.includes("electric") ||
    businessType.includes("hvac")
  ) {
    return `Hi — this is ${businessName}. Sorry we missed your call. What can we help with today?`;
  }

  if (
    businessType.includes("salon") ||
    businessType.includes("spa") ||
    businessType.includes("barber")
  ) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment?`;
  }

  if (
    businessType.includes("dental") ||
    businessType.includes("doctor") ||
    businessType.includes("clinic")
  ) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment or ask a question?`;
  }

  if (businessType.includes("restaurant") || businessType.includes("cafe")) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to place an order or ask a quick question?`;
  }

  if (tone === "professional") {
    return `Hi — this is ${businessName}. Sorry we missed your call. How can we help you today?`;
  }

  if (tone === "direct") {
    return `Hi — this is ${businessName}. What can we help with?`;
  }

  if (tone === "casual") {
    return `Hi — this is ${businessName}. Sorry we missed your call. What were you calling about?`;
  }

  return `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;
}

function containsBusinessName(text: string, businessName: string): boolean {
  const cleanedName = cleanLine(businessName);
  if (!cleanedName) return false;
  return text.toLowerCase().includes(cleanedName.toLowerCase());
}

function hasQuestion(text: string): boolean {
  return text.includes("?");
}

function isWeakGeneratedMessage(
  message: string,
  input: GenerateInitialMessageInput
): boolean {
  const normalized = cleanLine(message).toLowerCase();
  const style = input.style ?? "conversational";

  if (!normalized) {
    return true;
  }

  if (countWords(normalized) < 8) {
    return true;
  }

  if (
    normalized === "hi sorry we missed your call" ||
    normalized === "hi! sorry we missed your call." ||
    normalized === "sorry we missed your call" ||
    normalized === "sorry we missed your call."
  ) {
    return true;
  }

  if (
    normalized.includes("sorry we missed your call") &&
    countWords(normalized) <= 10
  ) {
    return true;
  }

  if (style !== "menu" && !hasQuestion(normalized) && !normalized.includes("book here:")) {
    return true;
  }

  if (style === "appointment") {
    const mentionsBooking =
      normalized.includes("book") ||
      normalized.includes("appointment") ||
      normalized.includes("schedule");

    if (!mentionsBooking) {
      return true;
    }
  }

  if (style === "menu" && !/\b1\.\s/.test(message)) {
    return true;
  }

  if (style !== "menu" && !containsBusinessName(message, input.businessName)) {
    return true;
  }

  return false;
}

function normalizeGeneratedMessage(
  rawText: unknown,
  input: GenerateInitialMessageInput
): string {
  let message = cleanLine(rawText);

  if (!message) {
    return buildFallbackMessage(input);
  }

  message = stripQuotes(message);
  message = ensureNoStopLanguage(message);
  message = limitSentenceCount(message, input.style === "menu" ? 3 : 2);

  if (input.style === "menu") {
    const options = getDefaultMenuOptions(input.businessType, input.menuOptions);
    const hasNumberedMenu = /\b1\.\s/.test(message);

    if (!hasNumberedMenu) {
      message = `${message}\n\n${buildMenuBlock(options)}`;
    }
  }

  if (isWeakGeneratedMessage(message, input)) {
    return buildFallbackMessage(input);
  }

  return message.trim();
}

function buildSystemPrompt(): string {
  return [
    "You write first-response SMS messages for small businesses that missed a phone call.",
    "This is the first outgoing text after a missed call, not an ongoing conversation reply.",
    "Your goal is to maximize reply rate.",
    "Write a short, human, natural text message.",
    "Do not sound robotic, corporate, or overly formal.",
    "Do not mention AI, automation, or that this is an automated message.",
    "Do not include 'Reply STOP to opt out'.",
    "Keep the message concise and easy to reply to.",
    "Always include the business name naturally in the message.",
    "The message must ask a concrete reply-friendly question unless style is menu.",
    "If style is 'menu', include a short intro followed by a numbered list with 4 options.",
    "If style is 'appointment', bias toward booking language and ask if they were trying to book.",
    "Avoid weak generic replies like 'Hi, sorry we missed your call.' by itself.",
    "Return only the message text. No explanation."
  ].join("\n");
}

function buildUserPrompt(input: GenerateInitialMessageInput): string {
  const menuOptions = getDefaultMenuOptions(input.businessType, input.menuOptions);
  const fallback = buildFallbackMessage(input);

  return [
    "Write a first-response SMS for this business.",
    "",
    `Business name: ${cleanLine(input.businessName)}`,
    `Business type: ${cleanLine(input.businessType)}`,
    `Business description: ${cleanLine(input.businessDescription)}`,
    `Tone: ${cleanLine(input.tone || "friendly")}`,
    `Style: ${cleanLine(input.style || "conversational")}`,
    `Booking link: ${cleanLine(input.bookingLink)}`,
    `Menu options: ${menuOptions.join(" | ")}`,
    "",
    "Requirements:",
    "- Must sound human and helpful.",
    "- Must be short.",
    "- Must make it easy for the customer to reply.",
    "- Must include the business name naturally.",
    "- Must ask a useful question unless style is menu.",
    "- No emojis.",
    "- No signatures other than the business name if needed.",
    "",
    "Here is a strong example structure to follow closely if helpful:",
    fallback
  ].join("\n");
}

async function callOpenAiMessageGenerator(
  input: GenerateInitialMessageInput
): Promise<string> {
  const apiKey = getOpenAiApiKey();
  const model = getMessageModel();

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
      `OpenAI message request failed: ${response.status} ${response.statusText} ${errorText}`
    );
  }

  const data = (await response.json()) as any;
  const content = data?.choices?.[0]?.message?.content;

  if (!content || typeof content !== "string") {
    throw new Error("OpenAI message generator returned no message content.");
  }

  return content;
}

export async function generateInitialFollowupMessage(
  input: GenerateInitialMessageInput
): Promise<GenerateInitialMessageResult> {
  try {
    const aiMessage = await callOpenAiMessageGenerator(input);
    const normalizedMessage = normalizeGeneratedMessage(aiMessage, input);
    const fallbackMessage = buildFallbackMessage(input);
    const usedAi = normalizedMessage.trim() !== fallbackMessage.trim();

    return {
      message: normalizedMessage,
      usedAi
    };
  } catch (error) {
    console.error("AI message generation failed:", error);

    return {
      message: buildFallbackMessage(input),
      usedAi: false
    };
  }
}