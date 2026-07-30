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
  
  export default function QuickInsightsCard({
    leads,
    missedCalls,
    followupsSent,
    customerReplies,
    replyRate
  }: {
    leads: number;
    missedCalls: number;
    followupsSent: number;
    customerReplies: number;
    replyRate: string;
  }) {
    const awaitingReplyCount = Math.max(followupsSent - customerReplies, 0);
    const uncontactedLeads = Math.max(missedCalls - followupsSent, 0);
    return (
      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="text-sm font-medium text-zinc-900">Action items</div>
        <div className="mt-1 text-sm text-zinc-600">What needs attention right now.</div>
  
        <div className="mt-6 space-y-3">
          <InsightRow
            label="Missed calls not followed up"
            value={String(uncontactedLeads)}
            tone={uncontactedLeads > 0 ? "warning" : "neutral"}
          />
          <InsightRow
            label="Texts awaiting reply"
            value={String(awaitingReplyCount)}
            tone={awaitingReplyCount > 0 ? "warning" : "neutral"}
          />
          <InsightRow
            label="Leads handled"
            value={`${Math.min(followupsSent, missedCalls)}/${missedCalls || 0}`}
            tone="neutral"
          />
          <InsightRow
            label="Current reply rate"
            value={replyRate}
            tone={followupsSent > 0 && customerReplies === 0 ? "warning" : "success"}
          />
          <InsightRow label="Unique leads tracked" value={String(leads)} tone="neutral" />
        </div>
      </div>
    );
  }
