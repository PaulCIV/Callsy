import { Sparkles } from "lucide-react";

type MessageTone = "friendly" | "professional" | "casual" | "direct";
type FirstResponseStyle = "conversational" | "menu" | "appointment";

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

export default function AiAutomationCard({
  aiEnabled,
  classifyLeads,
  autoFollowupEnabled,
  useAiGeneratedMessage,
  tone,
  style,
  previewMessage
}: {
  aiEnabled: boolean;
  classifyLeads: boolean;
  autoFollowupEnabled: boolean;
  useAiGeneratedMessage: boolean;
  tone: MessageTone;
  style: FirstResponseStyle;
  previewMessage: string;
}) {
  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-2">
        <Sparkles size={16} className="text-zinc-900" />
        <div className="text-sm font-medium text-zinc-900">AI automation</div>
      </div>
      <div className="mt-1 text-sm text-zinc-600">
        Current behavior for classification and first-response drafting.
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <InsightRow
          label="AI master switch"
          value={aiEnabled ? "On" : "Off"}
          tone={aiEnabled ? "success" : "warning"}
        />
        <InsightRow
          label="Lead classifier"
          value={classifyLeads ? "Active" : "Off"}
          tone={classifyLeads ? "success" : "warning"}
        />
        <InsightRow
          label="Auto follow-up"
          value={autoFollowupEnabled ? "Enabled" : "Disabled"}
          tone={autoFollowupEnabled ? "success" : "neutral"}
        />
        <InsightRow
          label="Message source"
          value={useAiGeneratedMessage ? "AI-generated" : "Manual template"}
          tone={useAiGeneratedMessage ? "success" : "neutral"}
        />
        <InsightRow label="Tone" value={tone} tone="neutral" />
        <InsightRow label="Style" value={style} tone="neutral" />
      </div>

      <div className="mt-6 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
        <div className="text-xs font-medium uppercase tracking-wide text-zinc-500">
          Current preview
        </div>
        <div className="mt-2 whitespace-pre-wrap rounded-xl border border-zinc-200 bg-white p-4 text-sm text-zinc-800">
          {previewMessage}
        </div>
      </div>
    </div>
  );
}