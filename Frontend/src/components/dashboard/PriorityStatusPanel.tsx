import { CheckCircle2, Clock3, PhoneCall, Siren } from "lucide-react";
import type { EscalationEvent } from "../../hooks/useDashboardData";

function phone(value: string) {
  const digits = value.replace(/\D/g, "");
  return digits.length === 11 && digits[0] === "1"
    ? `(${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`
    : value;
}

export default function PriorityStatusPanel({ events, enabled }: { events: EscalationEvent[]; enabled: boolean }) {
  const active = events.filter((event) => event.status === "calling");
  const acknowledged = events.filter((event) => event.status === "acknowledged");
  const latest = active[0] || events[0];

  return (
    <section className={`rounded-2xl border p-6 shadow-sm ${active.length ? "border-red-200 bg-red-50" : "border-slate-200 bg-white"}`}>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <div className={`rounded-xl p-2.5 ${active.length ? "bg-red-600 text-white shadow-lg shadow-red-200" : "bg-slate-900 text-white"}`}>
            {active.length ? <Siren size={20} /> : <PhoneCall size={20} />}
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-sm font-semibold text-slate-950">Priority response</h2>
              <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${active.length ? "bg-red-600 text-white" : enabled ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-600"}`}>
                {active.length ? `${active.length} needs attention` : enabled ? "Standing by" : "Not configured"}
              </span>
            </div>
            <p className="mt-1 text-sm text-slate-600">
              {active.length ? "Callsy is contacting your on-call team now." : "Urgent messages are separated from routine follow-up."}
            </p>
          </div>
        </div>
        <div className="flex gap-3 text-center">
          <div className="min-w-20 rounded-xl border border-slate-200 bg-white px-3 py-2"><div className="text-lg font-bold text-slate-950">{events.length}</div><div className="text-[10px] uppercase tracking-wide text-slate-500">Detected</div></div>
          <div className="min-w-20 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2"><div className="text-lg font-bold text-emerald-700">{acknowledged.length}</div><div className="text-[10px] uppercase tracking-wide text-emerald-700">Owned</div></div>
        </div>
      </div>

      {latest ? (
        <div className={`mt-5 rounded-xl border p-4 ${latest.status === "calling" ? "border-red-200 bg-white" : "border-slate-200 bg-slate-50"}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="min-w-0">
              <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-500">
                {latest.status === "acknowledged" ? <CheckCircle2 size={14} className="text-emerald-600" /> : <Clock3 size={14} className="text-red-600" />}
                Latest priority message
              </div>
              <p className="mt-2 text-sm font-medium text-slate-900">“{latest.customerMessage}”</p>
              <p className="mt-1 text-xs text-slate-500">From {phone(latest.customerPhone)} · {latest.reason}</p>
            </div>
            <span className={`shrink-0 rounded-lg px-3 py-2 text-xs font-semibold ${latest.status === "acknowledged" ? "bg-emerald-100 text-emerald-700" : latest.status === "calling" ? "bg-red-600 text-white" : "bg-amber-100 text-amber-800"}`}>
              {latest.status === "acknowledged" ? `Acknowledged by ${latest.acknowledgedBy || "team"}` : latest.status === "calling" ? "Calling now" : "Needs review"}
            </span>
          </div>
        </div>
      ) : null}
    </section>
  );
}
