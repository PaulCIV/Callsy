import { ShieldCheck } from "lucide-react";

type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

function InsightRow({
  label,
  value,
  tone = "neutral"
}: {
  label: string;
  value: string;
  tone?: "neutral" | "warning" | "success";
}) {
  const toneClasses =
    tone === "warning"
      ? "border-amber-200 bg-amber-50"
      : tone === "success"
      ? "border-emerald-200 bg-emerald-50"
      : "border-zinc-200 bg-zinc-50";

  const valueClasses =
    tone === "warning"
      ? "text-amber-700"
      : tone === "success"
      ? "text-emerald-700"
      : "text-zinc-900";

  return (
    <div className={`flex items-center justify-between rounded-xl border px-4 py-3 ${toneClasses}`}>
      <div className="text-sm text-zinc-600">{label}</div>
      <div className={`text-sm font-semibold ${valueClasses}`}>{value}</div>
    </div>
  );
}

export default function ClassificationSummaryCard({
  summary
}: {
  summary: Record<LeadCategory, number>;
}) {
  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-2">
        <ShieldCheck size={16} className="text-zinc-900" />
        <div className="text-sm font-medium text-zinc-900">Lead classification</div>
      </div>
      <div className="mt-1 text-sm text-zinc-600">
        How AI is currently sorting leads in your account.
      </div>

      <div className="mt-6 space-y-3">
        <InsightRow label="Likely new leads" value={String(summary.lead)} tone="success" />
        <InsightRow label="Existing customers" value={String(summary.existing_customer)} tone="neutral" />
        <InsightRow label="Wrong numbers" value={String(summary.wrong_number)} tone="warning" />
        <InsightRow label="Spam / junk" value={String(summary.spam)} tone="warning" />
        <InsightRow label="Unknown" value={String(summary.unknown)} tone="neutral" />
      </div>
    </div>
  );
}