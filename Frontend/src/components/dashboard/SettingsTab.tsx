import { AlertTriangle, Bot, Check, Phone, Sparkles } from "lucide-react";
import { useState } from "react";
import Field from "./common/Field";
import Input from "./common/Input";
import Select from "./common/Select";
import Textarea from "./common/Textarea";
import ToggleRow from "./common/ToggleRow";
import PriorityEscalationCard from "./PriorityEscalationCard";

type MessageTone = "friendly" | "professional" | "casual" | "direct";
type FirstResponseStyle = "conversational" | "menu" | "appointment";

type SettingsTabProps = {
  saving: boolean;
  provisioning: boolean;
  releasing: boolean;
  assignedNumber?: string;
  hasAssignedNumber: boolean;
  hasUnsavedChanges: boolean;
  businessName: string;
  businessType: string;
  businessDescription: string;
  notifyNumber: string;
  cooldownMinutes: number;
  bookingLink: string;
  tone: MessageTone;
  firstResponseStyle: FirstResponseStyle;
  menuOptionsText: string;
  followupTemplate: string;
  previewMessage: string;
  aiEnabled: boolean;
  classifyLeads: boolean;
  autoFollowupEnabled: boolean;
  useAiGeneratedMessage: boolean;
  conversationRepliesEnabled: boolean;
  priorityEscalationEnabled: boolean;
  priorityPrimaryPhone: string;
  priorityBackupPhone: string;
  priorityKeywordsText: string;
  priorityRingTimeout: number;
  priorityCustomerConfirmation: boolean;
  onSave: () => void;
  onProvisionNumber: (areaCode?: number) => void;
  onAssignTestNumber: () => void;
  onReleaseNumber: () => void;
  onBusinessNameChange: (v: string) => void;
  onBusinessTypeChange: (v: string) => void;
  onBusinessDescriptionChange: (v: string) => void;
  onNotifyNumberChange: (v: string) => void;
  onCooldownMinutesChange: (v: string) => void;
  onBookingLinkChange: (v: string) => void;
  onToneChange: (v: string) => void;
  onStyleChange: (v: string) => void;
  onMenuOptionsTextChange: (v: string) => void;
  onFollowupTemplateChange: (v: string) => void;
  onAiEnabledChange: (checked: boolean) => void;
  onClassifyLeadsChange: (checked: boolean) => void;
  onAutoFollowupEnabledChange: (checked: boolean) => void;
  onUseAiGeneratedMessageChange: (checked: boolean) => void;
  onConversationRepliesEnabledChange: (checked: boolean) => void;
  onPriorityChange: (field: string, value: string | number | boolean) => void;
};

export default function SettingsTab(props: SettingsTabProps) {
  const [areaCode, setAreaCode] = useState("");
  const saveButton = (label = "Save") => (
    <button type="button" onClick={props.onSave} disabled={props.saving || !props.hasUnsavedChanges} className="inline-flex shrink-0 items-center justify-center rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-40">
      {props.saving ? "Saving…" : label}
    </button>
  );

  const handleProvision = () => {
    const digits = areaCode.replace(/\D/g, "");
    props.onProvisionNumber(digits.length === 3 ? Number(digits) : undefined);
  };

  return (
    <div className="mt-6 space-y-6">
      <section className="overflow-hidden rounded-2xl border border-indigo-200 bg-white shadow-sm">
        <div className="flex flex-col gap-5 bg-gradient-to-r from-indigo-950 via-indigo-900 to-violet-900 p-6 text-white md:flex-row md:items-center md:justify-between">
          <div className="flex items-start gap-3">
            <div className="rounded-xl bg-white/10 p-2.5"><Phone size={20} /></div>
            <div><h2 className="font-semibold">Your Callsy number</h2><p className="mt-1 max-w-xl text-sm leading-6 text-indigo-100">Customers call this number, and Callsy handles missed-call follow-up and text replies for this business.</p></div>
          </div>
          {props.hasAssignedNumber ? <div className="rounded-xl border border-white/20 bg-white/10 px-4 py-3 font-semibold tracking-wide">{props.assignedNumber}</div> : null}
        </div>
        {!props.hasAssignedNumber ? (
          <div className="grid gap-5 p-6 md:grid-cols-[1fr_auto] md:items-end">
            <div>
              <label className="text-sm font-medium text-zinc-900" htmlFor="callsy-area-code">Preferred area code <span className="font-normal text-zinc-500">(optional)</span></label>
              <input id="callsy-area-code" inputMode="numeric" maxLength={3} value={areaCode} onChange={(event) => setAreaCode(event.target.value.replace(/\D/g, "").slice(0, 3))} placeholder="313" className="mt-2 w-full rounded-xl border border-zinc-200 px-3 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100 md:max-w-xs" />
              <p className="mt-2 text-xs leading-5 text-zinc-500">A number is purchased from your connected Twilio account. If that area code is unavailable, Callsy selects another local number. Your public webhook URL must be running.</p>
            </div>
            <div className="flex flex-col gap-2">
              <button type="button" onClick={handleProvision} disabled={props.provisioning || (areaCode.length > 0 && areaCode.length !== 3)} className="inline-flex items-center justify-center gap-2 rounded-xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-50">
                <Phone size={16} />{props.provisioning ? "Setting up…" : "Buy Twilio number"}
              </button>
              <button type="button" onClick={props.onAssignTestNumber} disabled={props.provisioning} className="inline-flex items-center justify-center rounded-xl border border-indigo-200 bg-indigo-50 px-5 py-2.5 text-sm font-semibold text-indigo-800 hover:bg-indigo-100 disabled:opacity-50">
                Use free test number
              </button>
              <span className="text-center text-[11px] text-zinc-500">Local development only · no charge</span>
            </div>
          </div>
        ) : <div className="flex items-center gap-2 p-6 text-sm text-emerald-700"><Check size={17} /> Number assigned and ready for Twilio webhooks.</div>}
      </section>

      <PriorityEscalationCard
        enabled={props.priorityEscalationEnabled}
        primaryPhone={props.priorityPrimaryPhone}
        backupPhone={props.priorityBackupPhone}
        keywordsText={props.priorityKeywordsText}
        ringTimeout={props.priorityRingTimeout}
        customerConfirmation={props.priorityCustomerConfirmation}
        saving={props.saving}
        hasUnsavedChanges={props.hasUnsavedChanges}
        onSave={props.onSave}
        onChange={props.onPriorityChange}
      />

      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-sm font-medium text-zinc-900">Settings</div>
            <div className="mt-1 text-sm text-zinc-600">
              Customize AI lead handling, messaging, and notifications.
            </div>
          </div>

          {saveButton("Save business")}
        </div>

        <div className="mt-6 grid gap-5 md:grid-cols-2">
          <Field label="Business name">
            <Input
              value={props.businessName}
              onChange={props.onBusinessNameChange}
              placeholder="My Business"
            />
          </Field>

          <Field label="Business type">
            <Input
              value={props.businessType}
              onChange={props.onBusinessTypeChange}
              placeholder="Auto shop, dentist, salon..."
            />
          </Field>

          <Field label="Notify number">
            <Input
              value={props.notifyNumber}
              onChange={props.onNotifyNumberChange}
              placeholder="+1555..."
            />
          </Field>

          <Field label="Cooldown (minutes)">
            <Input
              value={String(props.cooldownMinutes)}
              onChange={props.onCooldownMinutesChange}
              placeholder="120"
            />
          </Field>

          <Field label="Booking link (optional)">
            <Input
              value={props.bookingLink}
              onChange={props.onBookingLinkChange}
              placeholder="https://..."
            />
          </Field>

          <Field label="Tone">
            <Select
              value={props.tone}
              onChange={props.onToneChange}
              options={[
                { value: "friendly", label: "Friendly" },
                { value: "professional", label: "Professional" },
                { value: "casual", label: "Casual" },
                { value: "direct", label: "Direct" }
              ]}
            />
          </Field>

          <div className="md:col-span-2">
            <Field label="Business description (optional)">
              <Textarea
                value={props.businessDescription}
                onChange={props.onBusinessDescriptionChange}
                placeholder="A short description of what your business does."
              />
            </Field>
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2"><Sparkles size={16} className="text-zinc-900" /><div className="text-sm font-medium text-zinc-900">AI behavior</div></div>
          {saveButton("Save AI")}
        </div>

        <div className="mt-1 text-sm text-zinc-600">
          Control how Callsy classifies leads, drafts the first follow-up, and continues the conversation.
        </div>

        <div className="mt-6 space-y-3">
          <ToggleRow
            title="Enable AI features"
            description="Master switch for AI lead classification and AI-generated messaging."
            checked={props.aiEnabled}
            onChange={props.onAiEnabledChange}
          />

          <ToggleRow
            title="AI classify leads"
            description="Use AI to separate likely leads from spam, wrong numbers, and existing customers."
            checked={props.classifyLeads}
            onChange={props.onClassifyLeadsChange}
            disabled={!props.aiEnabled}
          />

          <ToggleRow
            title="Auto follow-up enabled"
            description="Send the first follow-up after the caller presses 1 or says yes."
            checked={props.autoFollowupEnabled}
            onChange={props.onAutoFollowupEnabledChange}
            disabled={!props.aiEnabled}
          />

          <ToggleRow
            title="Use AI-generated first message"
            description="Have Callsy draft the first response after a missed call based on your business type and message style."
            checked={props.useAiGeneratedMessage}
            onChange={props.onUseAiGeneratedMessageChange}
            disabled={!props.aiEnabled}
          />

          <ToggleRow
            title="AI continue conversation"
            description="After a customer replies, let AI send the next text in the conversation instead of stopping after the first message."
            checked={props.conversationRepliesEnabled}
            onChange={props.onConversationRepliesEnabledChange}
            disabled={!props.aiEnabled || !props.autoFollowupEnabled}
          />
        </div>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="flex items-center justify-between gap-3"><div className="text-sm font-medium text-zinc-900">First response setup</div>{saveButton("Save message")}</div>
        <div className="mt-1 text-sm text-zinc-600">
          Choose how the first follow-up should feel and whether customers get quick-reply options.
        </div>

        <div className="mt-6 grid gap-5 md:grid-cols-2">
          <Field label="Message style">
            <Select
              value={props.firstResponseStyle}
              onChange={props.onStyleChange}
              options={[
                { value: "conversational", label: "Conversational" },
                { value: "menu", label: "Menu options" },
                { value: "appointment", label: "Appointment focused" }
              ]}
            />
          </Field>

          <div>
            <div className="text-sm font-medium text-zinc-900">Menu options</div>
            <div className="mt-2 rounded-xl border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm text-zinc-600">
              Used when style is set to <span className="font-medium">Menu options</span>.
              One option per line, up to 4.
            </div>
          </div>

          <div className="md:col-span-2">
            <Field label="Menu options list">
              <Textarea
                value={props.menuOptionsText}
                onChange={props.onMenuOptionsTextChange}
                placeholder={`Book an appointment\nAsk about pricing\nGeneral question\nSomething else`}
              />
            </Field>
          </div>

          <div className="md:col-span-2">
            <Field label="Manual follow-up template">
              <Textarea
                value={props.followupTemplate}
                onChange={props.onFollowupTemplateChange}
                placeholder="Hi — this is {{business}}. Sorry we missed your call. How can we help?"
              />
              <div className="mt-2 text-xs text-zinc-500">
                Used when AI-generated messaging is off. Supported placeholders:{" "}
                <code className="rounded bg-zinc-100 px-1">{"{{business}}"}</code>,{" "}
                <code className="rounded bg-zinc-100 px-1">{"{{caller}}"}</code>,{" "}
                <code className="rounded bg-zinc-100 px-1">{"{{link}}"}</code>.
              </div>
            </Field>
          </div>
        </div>

        <div className="mt-6 grid gap-4 lg:grid-cols-[1fr_0.95fr]">
          <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-700">
            <div className="flex items-center gap-2 font-medium text-zinc-900">
              <Bot size={16} />
              Message preview
            </div>

            <div className="mt-3 whitespace-pre-wrap rounded-xl border border-zinc-200 bg-white p-4 text-sm text-zinc-800">
              {props.previewMessage}
            </div>
          </div>

          <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-4">
            <div className="text-sm font-medium text-zinc-900">How this works</div>

            <div className="mt-3 space-y-3 text-sm text-zinc-600">
              <div className="rounded-lg border border-zinc-200 bg-white px-3 py-2">
                <span className="font-medium text-zinc-900">AI first message:</span> Callsy drafts the first text after a missed call using your business profile.
              </div>

              <div className="rounded-lg border border-zinc-200 bg-white px-3 py-2">
                <span className="font-medium text-zinc-900">AI continue conversation:</span> After a customer texts back, AI can send the next reply instead of repeating the first-message style.
              </div>

              <div className="rounded-lg border border-zinc-200 bg-white px-3 py-2">
                <span className="font-medium text-zinc-900">Menu style:</span> Customers can reply with simple choices to increase response rate.
              </div>

              <div className="rounded-lg border border-zinc-200 bg-white px-3 py-2">
                <span className="font-medium text-zinc-900">Manual template:</span> Use your own exact wording if you want tighter control over the first message.
              </div>
            </div>
          </div>
        </div>
      </div>

      {props.hasAssignedNumber ? (
        <div className="rounded-2xl border border-red-200 bg-red-50 p-6 shadow-sm">
          <div className="flex items-start gap-3">
            <div className="mt-0.5 inline-flex h-9 w-9 items-center justify-center rounded-xl bg-red-600 text-white">
              <AlertTriangle size={18} />
            </div>

            <div className="flex-1">
              <div className="text-sm font-medium text-red-900">Danger zone</div>
              <div className="mt-1 text-sm text-red-800">
                Releasing this number removes the assigned Callsy number from this
                business and stops missed-call forwarding until another number is assigned.
              </div>

              <div className="mt-4">
                <button
                  type="button"
                  onClick={props.onReleaseNumber}
                  disabled={props.releasing}
                  className="inline-flex items-center justify-center rounded-xl bg-red-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-red-700 disabled:opacity-50"
                >
                  {props.releasing ? "Releasing..." : "Release number"}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      <div className="sticky bottom-4 z-20 flex items-center justify-between gap-4 rounded-2xl border border-zinc-200 bg-white/95 px-4 py-3 shadow-xl backdrop-blur">
        <div className="text-sm text-zinc-600">{props.hasUnsavedChanges ? "You have unsaved changes" : "Everything is saved"}</div>
        {saveButton("Save all changes")}
      </div>
    </div>
  );
}
