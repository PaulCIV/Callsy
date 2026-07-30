/// src/services/aiClassifier.service.ts

import { env } from "../config/env";

export type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

export type ClassificationResult = {
  category: LeadCategory;
  confidence: number;
  reason: string;
  shouldAutoFollowup: boolean;
};

export type ClassifyLeadInput = {
  businessName: string;
  businessType?: string;
  businessDescription?: string;
  callerPhone?: string;
  eventType?: "missed_call" | "inbound_sms" | "reply" | "unknown";
  latestMessage?: string;
  callCount?: number;
  smsReplyCount?: number;
  priorStatus?: string;
};

const DEFAULT_CLASSIFICATION: ClassificationResult = {
  category: "unknown",
  confidence: 0.25,
  reason: "No classification available.",
  shouldAutoFollowup: true
};

function getOpenAiApiKey(): string {
  const apiKey = env.OPENAI_API_KEY || "";

  if (!apiKey) {
    throw new Error("Missing OPENAI_API_KEY.");
  }

  return apiKey;
}

function getClassifierModel(): string {
  return process.env.OPENAI_MODEL_CLASSIFIER || "gpt-4o-mini";
}

function clampConfidence(value: unknown): number {
  const num = Number(value);

  if (!Number.isFinite(num)) return DEFAULT_CLASSIFICATION.confidence;
  if (num < 0) return 0;
  if (num > 1) return 1;

  return num;
}

function normalizeCategory(value: unknown): LeadCategory {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();

  if (
    raw === "lead" ||
    raw === "existing_customer" ||
    raw === "wrong_number" ||
    raw === "spam" ||
    raw === "unknown"
  ) {
    return raw;
  }

  return "unknown";
}

function normalizeBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") return value;

  if (typeof value === "string") {
    const lowered = value.trim().toLowerCase();
    if (lowered === "true") return true;
    if (lowered === "false") return false;
  }

  if (typeof value === "number") {
    if (value === 1) return true;
    if (value === 0) return false;
  }

  return fallback;
}

function sanitizeReason(value: unknown): string {
  const reason = String(value ?? "").trim();
  return reason || DEFAULT_CLASSIFICATION.reason;
}

function categoryAllowsAutoFollowup(category: LeadCategory): boolean {
  return category !== "spam" && category !== "wrong_number";
}

function normalizeClassificationResult(value: unknown): ClassificationResult {
  const obj =
    value && typeof value === "object"
      ? (value as Record<string, unknown>)
      : {};

  const category = normalizeCategory(obj.category);
  const confidence = clampConfidence(obj.confidence);

  let shouldAutoFollowup = normalizeBoolean(
    obj.shouldAutoFollowup,
    categoryAllowsAutoFollowup(category)
  );

  if (!categoryAllowsAutoFollowup(category)) {
    shouldAutoFollowup = false;
  }

  return {
    category,
    confidence,
    reason: sanitizeReason(obj.reason),
    shouldAutoFollowup
  };
}

function buildSystemPrompt(): string {
  return [
    "You classify missed-call and SMS leads for a small business follow-up system.",
    "Return only valid JSON matching the provided schema.",
    "Choose exactly one category from:",
    "- lead: likely a real potential customer or booking inquiry",
    "- existing_customer: likely a current or repeat customer asking about ongoing service",
    "- wrong_number: clearly reached the wrong business or person",
    "- spam: robocall, telemarketer, scam, solicitation, or obvious junk",
    "- unknown: not enough evidence",
    "Guidelines:",
    "- A missed call alone has no intent and should remain unknown until a customer message exists.",
    "- Use 'spam' only when there are clear spam or solicitation signals.",
    "- Use 'wrong_number' only when there is strong evidence.",
    "- shouldAutoFollowup should be false for spam and wrong_number.",
    "- Keep the reason short and concrete."
  ].join("\n");
}

function buildUserPrompt(input: ClassifyLeadInput): string {
  return [
    "Classify this business contact.",
    "",
    `Business name: ${input.businessName || ""}`,
    `Business type: ${input.businessType || ""}`,
    `Business description: ${input.businessDescription || ""}`,
    `Caller phone: ${input.callerPhone || ""}`,
    `Event type: ${input.eventType || "unknown"}`,
    `Latest message: ${input.latestMessage || ""}`,
    `Call count: ${String(input.callCount ?? 0)}`,
    `SMS reply count: ${String(input.smsReplyCount ?? 0)}`,
    `Prior lead status: ${input.priorStatus || ""}`
  ].join("\n");
}

async function callOpenAiClassifier(
  input: ClassifyLeadInput
): Promise<ClassificationResult> {
  const apiKey = getOpenAiApiKey();
  const model = getClassifierModel();

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      messages: [
        {
          role: "system",
          content: buildSystemPrompt()
        },
        {
          role: "user",
          content: buildUserPrompt(input)
        }
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "lead_classification",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              category: {
                type: "string",
                enum: [
                  "lead",
                  "existing_customer",
                  "wrong_number",
                  "spam",
                  "unknown"
                ]
              },
              confidence: {
                type: "number"
              },
              reason: {
                type: "string"
              },
              shouldAutoFollowup: {
                type: "boolean"
              }
            },
            required: [
              "category",
              "confidence",
              "reason",
              "shouldAutoFollowup"
            ]
          }
        }
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    throw new Error(
      `OpenAI classifier request failed: ${response.status} ${response.statusText} ${errorText}`
    );
  }

  const data = (await response.json()) as any;
  const content = data?.choices?.[0]?.message?.content;

  if (!content || typeof content !== "string") {
    throw new Error("OpenAI classifier returned no message content.");
  }

  const parsed = JSON.parse(content);
  return normalizeClassificationResult(parsed);
}

function quickRuleBasedClassification(
  input: ClassifyLeadInput
): ClassificationResult | null {
  const msg = String(input.latestMessage ?? "").trim().toLowerCase();

  if (!msg) {
    if (input.eventType === "missed_call") {
      return {
        category: "lead",
        confidence: 0.6,
        reason: "Missed call with no negative signal; treat as likely lead.",
        shouldAutoFollowup: true
      };
    }

    return null;
  }

  const spamSignals = [
    "free estimate for seo",
    "google business profile",
    "marketing services",
    "loan approval",
    "press 1",
    "business funding",
    "web traffic",
    "credit card processing",
    "make $",
    "work from home",
    "seo services"
  ];

  for (const signal of spamSignals) {
    if (msg.indexOf(signal) !== -1) {
      return {
        category: "spam",
        confidence: 0.95,
        reason: `Matched spam signal: ${signal}`,
        shouldAutoFollowup: false
      };
    }
  }

  const wrongNumberSignals = [
    "wrong number",
    "sorry wrong number",
    "you have the wrong number",
    "not the right number",
    "stop texting wrong number"
  ];

  for (const signal of wrongNumberSignals) {
    if (msg.indexOf(signal) !== -1) {
      return {
        category: "wrong_number",
        confidence: 0.9,
        reason: `Matched wrong-number signal: ${signal}`,
        shouldAutoFollowup: false
      };
    }
  }

  return null;
}

export async function classifyLead(
  input: ClassifyLeadInput
): Promise<ClassificationResult> {
  try {
    const ruleBased = quickRuleBasedClassification(input);
    if (ruleBased) {
      return ruleBased;
    }

    return await callOpenAiClassifier(input);
  } catch (error) {
    console.error("AI lead classification failed:", error);

    return {
      ...DEFAULT_CLASSIFICATION,
      reason: "Classifier failed; using safe fallback."
    };
  }
}
