import { Check, CircleAlert, PhoneCall, Radar, ShieldCheck } from "lucide-react";

type Props = {
  enabled: boolean;
  primaryPhone: string;
  backupPhone: string;
  keywordsText: string;
  ringTimeout: number;
  customerConfirmation: boolean;
  saving: boolean;
  hasUnsavedChanges: boolean;
  onSave: () => void;
  onChange: (field: string, value: string | number | boolean) => void;
};

export default function PriorityEscalationCard(props: Props) {
  const ready = props.enabled && Boolean(props.primaryPhone.trim());

  return (
    <section className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="border-b border-slate-200 bg-gradient-to-r from-slate-950 via-slate-900 to-slate-800 px-6 py-6 text-white">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-start gap-3">
            <div className="rounded-xl bg-amber-400 p-2.5 text-slate-950 shadow-lg shadow-amber-500/10">
              <Radar size={20} />
            </div>
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-base font-semibold">Urgent message alerts</h2>
                <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${ready ? "bg-emerald-400/15 text-emerald-300" : "bg-white/10 text-slate-300"}`}>
                  {ready ? "Ready" : "Not active"}
                </span>
              </div>
              <p className="mt-1 max-w-xl text-sm leading-6 text-slate-300">
                Callsy alerts your staff when a customer text looks urgent. It never answers the customer's phone call.
              </p>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <button type="button" onClick={props.onSave} disabled={props.saving || !props.hasUnsavedChanges} className="inline-flex items-center justify-center rounded-xl border border-white/20 bg-white/10 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/20 disabled:cursor-not-allowed disabled:opacity-45">
              {props.saving ? "Saving…" : "Save alerts"}
            </button>
            <button type="button" onClick={() => props.onChange("enabled", !props.enabled)} className={`inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition ${props.enabled ? "bg-emerald-400 text-emerald-950" : "bg-white text-slate-950 hover:bg-slate-100"}`}>
              {props.enabled ? <Check size={16} /> : <ShieldCheck size={16} />}
              {props.enabled ? "Alerts on" : "Turn on alerts"}
            </button>
          </div>
        </div>
      </div>

      <div className="p-6">
        <div className="grid gap-2 sm:grid-cols-3">
          {[
            ["1", "Customer texts", "Callsy detects a saved urgent phrase"],
            ["2", "Your staff is called", "An automated voice reads the customer's message"],
            ["3", "Staff confirms", "Press 1 so Callsy knows a person received it"]
          ].map(([number, title, detail], index) => (
            <div key={title} className="relative rounded-xl border border-slate-200 bg-slate-50 p-4">
              <div className="flex items-center gap-2">
                <span className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${index === 2 ? "bg-emerald-100 text-emerald-700" : "bg-slate-900 text-white"}`}>{number}</span>
                <span className="text-sm font-semibold text-slate-900">{title}</span>
              </div>
              <p className="mt-2 text-xs leading-5 text-slate-500">{detail}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 grid gap-5 md:grid-cols-2">
          <label className="block">
            <span className="text-sm font-medium text-slate-900">First staff member to alert</span>
            <span className="mt-1 block text-xs text-slate-500">Callsy calls this person first—it does not connect the customer to them.</span>
            <input value={props.primaryPhone} onChange={(e) => props.onChange("primaryPhone", e.target.value)} placeholder="+1 555 123 4567" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-amber-400 focus:ring-4 focus:ring-amber-100" />
          </label>
          <label className="block">
            <span className="text-sm font-medium text-slate-900">Backup staff member</span>
            <span className="mt-1 block text-xs text-slate-500">Called only if the first person does not confirm the alert.</span>
            <input value={props.backupPhone} onChange={(e) => props.onChange("backupPhone", e.target.value)} placeholder="+1 555 987 6543" className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-amber-400 focus:ring-4 focus:ring-amber-100" />
          </label>
          <label className="block md:col-span-2">
            <span className="text-sm font-medium text-slate-900">Customer phrases that trigger an alert</span>
            <span className="mt-1 block text-xs text-slate-500">Separate phrases with commas. Use only situations that need fast human attention.</span>
            <input value={props.keywordsText} onChange={(e) => props.onChange("keywords", e.target.value)} className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-amber-400 focus:ring-4 focus:ring-amber-100" />
          </label>
        </div>

        <div className="mt-5 grid gap-3 md:grid-cols-2">
          <label className="flex items-center justify-between gap-4 rounded-xl border border-slate-200 bg-slate-50 p-4">
            <div><div className="text-sm font-medium text-slate-900">Time to answer</div><div className="mt-1 max-w-xs text-xs leading-5 text-slate-500">How long the first staff member's phone rings before Callsy stops that attempt. If nobody confirms, the backup is called.</div></div>
            <select value={props.ringTimeout} onChange={(e) => props.onChange("timeout", Number(e.target.value))} className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-medium">
              <option value={15}>15 sec</option><option value={20}>20 sec</option><option value={25}>25 sec</option><option value={30}>30 sec</option>
            </select>
          </label>
          <button type="button" onClick={() => props.onChange("confirmation", !props.customerConfirmation)} className="flex items-center justify-between gap-4 rounded-xl border border-slate-200 bg-slate-50 p-4 text-left">
            <div><div className="text-sm font-medium text-slate-900">Text the customer an update</div><div className="mt-1 text-xs text-slate-500">Tell the customer their message was flagged and a staff member is being contacted.</div></div>
            <span className={`relative h-7 w-12 rounded-full transition ${props.customerConfirmation ? "bg-emerald-500" : "bg-slate-300"}`}><span className={`absolute top-1 h-5 w-5 rounded-full bg-white transition ${props.customerConfirmation ? "left-6" : "left-1"}`} /></span>
          </button>
        </div>

        {!props.primaryPhone.trim() && props.enabled ? (
          <div className="mt-5 flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4 text-amber-900">
            <CircleAlert className="mt-0.5 shrink-0" size={18} /><p className="text-sm">Add a primary phone number before this workflow can place calls.</p>
          </div>
        ) : (
          <div className="mt-5 rounded-xl border border-blue-200 bg-blue-50 p-4 text-blue-950">
            <div className="flex items-start gap-3"><PhoneCall className="mt-0.5 shrink-0" size={17} /><div><div className="text-sm font-semibold">Why does staff press 1?</div><p className="mt-1 text-xs leading-5 text-blue-800">It confirms a real person heard the alert. Without confirmation, voicemail could look like an answered call and the backup person might never be contacted. The customer does not press anything.</p></div></div>
          </div>
        )}
      </div>
    </section>
  );
}
