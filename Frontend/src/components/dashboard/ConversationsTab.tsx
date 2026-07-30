import { useMemo, useState } from "react";
import { ArrowUpDown, Bot, CalendarCheck, CheckCircle2, MessageSquare, Phone, Send, UserRound } from "lucide-react";
import type { Lead, SmsEvent } from "../../hooks/useDashboardData";

type Props = {
  leads: Lead[];
  events: SmsEvent[];
  sending: boolean;
  onSend: (leadId: string, body: string) => Promise<boolean>;
  onResume: (leadId: string) => Promise<void>;
  onAppointmentStatus: (leadId: string, status: "booked" | "completed") => Promise<void>;
};

function phoneLabel(phone: string) {
  const digits = phone.replace(/\D/g, "");
  return digits.length === 11 ? `(${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}` : phone;
}

function classification(item: Lead) {
  if (item.appointment?.status === "completed") return { label: "Completed", classes: "bg-zinc-200 text-zinc-700" };
  if (item.appointment?.status === "booked") return { label: "Booked", classes: "bg-emerald-100 text-emerald-700" };
  if (item.appointment?.status === "requested") return { label: "Booking requested", classes: "bg-fuchsia-100 text-fuchsia-700" };
  if (item.urgency?.isUrgent || item.status === "priority") return { label: "Priority", classes: "bg-red-100 text-red-700" };
  if (item.status === "callback_required") return { label: "Call back", classes: "bg-amber-100 text-amber-800" };
  if (item.status === "awaiting_consent") return { label: "Consent pending", classes: "bg-sky-100 text-sky-800" };
  if (item.manualTakeover?.active) return { label: "Owner handling", classes: "bg-indigo-100 text-indigo-700" };
  const category = item.classification?.category || "unknown";
  if (category === "lead") return { label: "Likely new lead", classes: "bg-emerald-100 text-emerald-700" };
  if (category === "existing_customer") return { label: "Existing customer", classes: "bg-blue-100 text-blue-700" };
  if (category === "wrong_number") return { label: "Wrong number", classes: "bg-amber-100 text-amber-700" };
  if (category === "spam") return { label: "Spam", classes: "bg-zinc-200 text-zinc-700" };
  return { label: "Awaiting reply", classes: "bg-violet-100 text-violet-700" };
}

export default function ConversationsTab({ leads, events, sending, onSend, onResume, onAppointmentStatus }: Props) {
  const [selectedId, setSelectedId] = useState("");
  const [draft, setDraft] = useState("");
  const [sortBy, setSortBy] = useState("recent");
  const sortedLeads = useMemo(() => [...leads].sort((a, b) => {
    if (sortBy === "priority") return Number(Boolean(b.urgency?.isUrgent)) - Number(Boolean(a.urgency?.isUrgent)) || new Date(b.updatedAt || 0).getTime() - new Date(a.updatedAt || 0).getTime();
    if (sortBy === "awaiting") return Number((a.classification?.category || "unknown") !== "unknown") - Number((b.classification?.category || "unknown") !== "unknown") || new Date(b.updatedAt || 0).getTime() - new Date(a.updatedAt || 0).getTime();
    if (sortBy === "callback") return Number(b.status === "callback_required") - Number(a.status === "callback_required") || new Date(b.updatedAt || 0).getTime() - new Date(a.updatedAt || 0).getTime();
    if (sortBy === "owner") return Number(Boolean(b.manualTakeover?.active)) - Number(Boolean(a.manualTakeover?.active)) || new Date(b.updatedAt || 0).getTime() - new Date(a.updatedAt || 0).getTime();
    return new Date(b.updatedAt || b.createdAt || 0).getTime() - new Date(a.updatedAt || a.createdAt || 0).getTime();
  }), [leads, sortBy]);
  const activeId = selectedId || sortedLeads[0]?._id || "";
  const lead = leads.find((item) => item._id === activeId);
  const canText = Boolean(lead && (lead.smsConsent?.status === "granted" || Number(lead.smsReplyCount || 0) > 0));
  const messages = useMemo(() => events.filter((event) => event.leadId === activeId).sort((a, b) => new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime()), [events, activeId]);

  const submit = async () => {
    if (!lead || !draft.trim()) return;
    if (await onSend(lead._id, draft.trim())) setDraft("");
  };

  return (
    <div className="mt-6 overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm lg:grid lg:min-h-[620px] lg:grid-cols-[320px_1fr]">
      <aside className="border-b border-zinc-200 bg-zinc-50 lg:border-b-0 lg:border-r">
        <div className="border-b border-zinc-200 p-5"><div className="flex items-center justify-between gap-3"><h2 className="font-semibold text-zinc-950">Conversations</h2><label className="relative"><span className="sr-only">Sort conversations</span><ArrowUpDown size={13} className="pointer-events-none absolute left-2.5 top-2.5 text-zinc-500"/><select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="appearance-none rounded-lg border border-zinc-200 bg-white py-2 pl-8 pr-7 text-xs font-semibold text-zinc-700 outline-none hover:bg-zinc-50"><option value="recent">Recent</option><option value="callback">Callbacks first</option><option value="priority">Priority first</option><option value="awaiting">Awaiting reply</option><option value="owner">Owner handling</option></select></label></div><p className="mt-2 text-sm text-zinc-500">Reply as your business from the Callsy number.</p></div>
        <div className="max-h-64 overflow-y-auto lg:max-h-[545px]">
          {sortedLeads.map((item) => (
            <button key={item._id} onClick={() => setSelectedId(item._id)} className={`w-full border-b border-zinc-200 p-4 text-left transition ${activeId === item._id ? "bg-white" : "hover:bg-white/70"}`}>
              <div className="flex items-center justify-between gap-2"><span className="text-sm font-semibold text-zinc-900">{phoneLabel(item.phone)}</span><span className={`rounded-full px-2 py-1 text-[10px] font-semibold ${classification(item).classes}`}>{classification(item).label}</span></div>
              <p className="mt-1 truncate text-xs text-zinc-500">{item.lastCustomerMessage || (item.status === "callback_required" ? "No text consent · return this call" : item.status === "awaiting_consent" ? "Waiting for consent response" : "Missed call · awaiting reply")}</p>
            </button>
          ))}
          {!leads.length ? <div className="p-5 text-sm text-zinc-500">No conversations yet.</div> : null}
        </div>
      </aside>

      <section className="flex min-h-[520px] flex-col">
        {lead ? <>
          <header className="flex flex-col gap-3 border-b border-zinc-200 px-5 py-4 xl:flex-row xl:items-center xl:justify-between">
            <div><div className="font-semibold text-zinc-950">{phoneLabel(lead.phone)}</div><div className="mt-1 text-xs text-zinc-500">{lead.appointment?.status === "requested" ? `Requested: ${lead.appointment.requestedWindow || "time not specified"}` : lead.smsReplyCount ? `${lead.smsReplyCount} customer repl${lead.smsReplyCount === 1 ? "y" : "ies"}` : "Awaiting customer reply"}</div></div>
            <div className="flex flex-wrap items-center gap-2">
              <a href={`tel:${lead.phone}`} className="inline-flex items-center gap-1.5 rounded-xl border border-zinc-200 px-3 py-2 text-xs font-semibold text-zinc-700 hover:bg-zinc-50"><Phone size={14}/> Call</a>
              {lead.appointment?.status === "requested" ? <button onClick={() => onAppointmentStatus(lead._id, "booked")} className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-3 py-2 text-xs font-semibold text-white hover:bg-emerald-700"><CalendarCheck size={14}/> Mark booked</button> : null}
              {lead.appointment?.status === "booked" ? <button onClick={() => onAppointmentStatus(lead._id, "completed")} className="inline-flex items-center gap-1.5 rounded-xl bg-zinc-900 px-3 py-2 text-xs font-semibold text-white hover:bg-zinc-800"><CheckCircle2 size={14}/> Mark completed</button> : null}
              {lead.manualTakeover?.active ? <button onClick={() => onResume(lead._id)} className="inline-flex items-center gap-2 rounded-xl border border-zinc-200 px-3 py-2 text-xs font-semibold text-zinc-700 hover:bg-zinc-50"><Bot size={14}/> Return to AI</button> : <span className="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700"><Bot size={13}/> AI active</span>}
            </div>
          </header>
          <div className="flex-1 space-y-3 overflow-y-auto bg-zinc-50 p-5">
            {!messages.length ? <div className="mx-auto mt-16 max-w-sm text-center"><MessageSquare className="mx-auto text-zinc-300"/><p className="mt-3 text-sm text-zinc-500">No texts yet. The missed call is saved, but intent stays unclassified until the customer replies.</p></div> : null}
            {messages.map((message) => {
              const inbound = message.direction === "inbound-reply";
              const manual = message.direction === "outbound-manual";
              return <div key={message._id} className={`flex ${inbound ? "justify-start" : "justify-end"}`}><div className={`max-w-[82%] rounded-2xl px-4 py-3 text-sm shadow-sm ${inbound ? "rounded-bl-md border border-zinc-200 bg-white text-zinc-800" : manual ? "rounded-br-md bg-indigo-600 text-white" : "rounded-br-md bg-zinc-900 text-white"}`}><div className="mb-1 flex items-center gap-1 text-[10px] opacity-70">{inbound ? <UserRound size={11}/> : manual ? <UserRound size={11}/> : <Bot size={11}/>} {inbound ? "Customer" : manual ? "You" : "Callsy AI"}</div><div className="whitespace-pre-wrap">{message.body}</div></div></div>;
            })}
          </div>
          <div className="border-t border-zinc-200 bg-white p-4">{!canText ? <div className="mb-3 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">This caller did not consent to text messages. Use the Call button to return their call.</div> : null}<div className="flex gap-3"><textarea value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); void submit(); } }} disabled={!canText} placeholder={canText ? "Type a reply as the business…" : "Texting unavailable until the customer consents"} rows={2} className="min-h-12 flex-1 resize-none rounded-xl border border-zinc-200 px-3 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100 disabled:bg-zinc-100"/><button onClick={submit} disabled={sending || !draft.trim() || !canText} className="inline-flex items-center gap-2 rounded-xl bg-indigo-600 px-5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-40"><Send size={16}/>{sending ? "Sending…" : "Send"}</button></div><p className="mt-2 text-xs text-zinc-500">Sending steps you into this conversation and pauses AI replies until you return it to AI.</p></div>
        </> : <div className="m-auto text-sm text-zinc-500">Select a conversation.</div>}
      </section>
    </div>
  );
}
