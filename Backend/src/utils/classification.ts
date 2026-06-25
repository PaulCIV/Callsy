// src/utils/classification.ts

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

export const LEAD_CATEGORIES: LeadCategory[] = [
  "lead",
  "existing_customer",
  "wrong_number",
  "spam",
  "unknown"
];

export const DEFAULT_CLASSIFICATION: ClassificationResult = {
  category: "unknown",
  confidence: 0.25,
  reason: "No classification available.",
  shouldAutoFollowup: true
};

export function isLeadCategory(value: unknown): value is LeadCategory {
  return (
    value === "lead" ||
    value === "existing_customer" ||
    value === "wrong_number" ||
    value === "spam" ||
    value === "unknown"
  );
}

export function normalizeLeadCategory(value: unknown): LeadCategory {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();

  if (isLeadCategory(raw)) {
    return raw;
  }

  return "unknown";
}

export function clampConfidence(value: unknown): number {
  const num = Number(value);

  if (!Number.isFinite(num)) {
    return DEFAULT_CLASSIFICATION.confidence;
  }

  if (num < 0) return 0;
  if (num > 1) return 1;

  return num;
}

export function normalizeBoolean(
  value: unknown,
  fallback: boolean = true
): boolean {
  if (typeof value === "boolean") {
    return value;
  }

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

export function sanitizeReason(value: unknown): string {
  const reason = String(value ?? "").trim();
  return reason || DEFAULT_CLASSIFICATION.reason;
}

export function shouldCategoryAutoFollowup(category: LeadCategory): boolean {
  return category !== "spam" && category !== "wrong_number";
}

export function normalizeClassificationResult(
  value: unknown
): ClassificationResult {
  const obj =
    value && typeof value === "object"
      ? (value as Record<string, unknown>)
      : {};

  const category = normalizeLeadCategory(obj.category);
  const confidence = clampConfidence(obj.confidence);
  let shouldAutoFollowup = normalizeBoolean(
    obj.shouldAutoFollowup,
    shouldCategoryAutoFollowup(category)
  );

  if (!shouldCategoryAutoFollowup(category)) {
    shouldAutoFollowup = false;
  }

  return {
    category,
    confidence,
    reason: sanitizeReason(obj.reason),
    shouldAutoFollowup
  };
}

export function buildFallbackClassification(
  overrides?: Partial<ClassificationResult>
): ClassificationResult {
  const merged = {
    ...DEFAULT_CLASSIFICATION,
    ...(overrides ?? {})
  };

  return normalizeClassificationResult(merged);
}