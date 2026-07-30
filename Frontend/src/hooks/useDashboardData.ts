import { useCallback, useEffect, useMemo, useState } from "react";
import {
  getMyBusiness,
  updateMyBusiness,
  provisionMyBusinessNumber,
  assignMyBusinessTestNumber,
  releaseMyBusinessNumber,
  Business
} from "../pages/api/business";
import { apiFetch } from "../pages/api/client";

export type MessageTone = "friendly" | "professional" | "casual" | "direct";
export type FirstResponseStyle = "conversational" | "menu" | "appointment";
export type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

export type DashboardBusiness = Business & {
  businessType?: string;
  businessDescription?: string;
  tone?: MessageTone;
  firstResponseStyle?: FirstResponseStyle;
  menuOptions?: string[];
  useAiGeneratedMessage?: boolean;
  aiConfig?: {
    enabled?: boolean;
    classifyLeads?: boolean;
    autoFollowupEnabled?: boolean;
    conversationRepliesEnabled?: boolean;
  };
};

export type EscalationEvent = {
  _id: string;
  businessId: string;
  leadId: string;
  customerPhone: string;
  customerMessage: string;
  reason: string;
  summary: string;
  status: "calling" | "acknowledged" | "unanswered" | "failed";
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  attempts?: Array<{ role: "primary" | "backup"; phone: string; status: string }>;
  createdAt?: string;
};

export type Stat = {
  label: string;
  value: string;
  hint?: string;
  icon: "call" | "sms" | "reply";
  trend: number[];
};

export type FeedItem = {
  id: string;
  time: string;
  title: string;
  detail: string;
  secondary?: string;
  tertiary?: string;
  kind: "call" | "sms" | "reply";
  createdAt?: string;
  classificationCategory?: LeadCategory;
  classificationReason?: string;
  followupMessage?: string;
};

export type Lead = {
  _id: string;
  businessId: string;
  phone: string;
  status: string;
  lastFollowupAt?: string;
  createdAt?: string;
  smsReplyCount?: number;
  lastCustomerMessage?: string;
  manualTakeover?: { active?: boolean; activatedAt?: string };
  smsConsent?: {
    status?: "unknown" | "pending" | "granted" | "declined";
    source?: "" | "voice_keypress" | "voice_speech" | "inbound_sms";
    capturedAt?: string;
  };
  urgency?: { isUrgent?: boolean; reason?: string };
  appointment?: { status?: "none" | "requested" | "booked" | "completed"; requestedWindow?: string };
  updatedAt?: string;
  classification?: {
    category?: LeadCategory;
    confidence?: number;
    reason?: string;
    shouldAutoFollowup?: boolean;
    classifiedAt?: string;
  };
  followup?: {
    message?: string;
    style?: string;
    sent?: boolean;
    sentAt?: string;
    blocked?: boolean;
    blockedReason?: string;
  };
};

export type CallEvent = {
  _id: string;
  businessId: string;
  leadId?: string;
  callSid: string;
  from: string;
  to: string;
  callStatus: string;
  direction?: string;
  duration?: number;
  consent?: {
    status?: "pending" | "granted" | "declined" | "no_response";
    method?: "keypress" | "speech" | "";
    response?: string;
    resolvedAt?: string;
  };
  callbackRequired?: boolean;
  createdAt?: string;
  updatedAt?: string;
};

export type SmsEvent = {
  _id: string;
  businessId: string;
  leadId?: string;
  messageSid: string;
  direction: string;
  from: string;
  to: string;
  body: string;
  status?: string;
  createdAt?: string;
  updatedAt?: string;
};

export type DayBucket = {
  key: string;
  label: string;
  calls: number;
  followups: number;
  replies: number;
};

async function getSmsEventsSafe() {
  try {
    return await apiFetch<{ ok: true; events: SmsEvent[] }>("/admin/sms-events", {
      method: "GET"
    });
  } catch {
    return { ok: true as const, events: [] };
  }
}

function timeAgo(input?: string) {
  if (!input) return "Unknown time";
  const ms = new Date(input).getTime();
  const diff = Date.now() - ms;

  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function formatPhone(phone?: string) {
  if (!phone) return "";
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 11 && digits.startsWith("1")) {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  return phone;
}

function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function formatDayKey(date: Date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function formatShortDay(date: Date) {
  return date.toLocaleDateString(undefined, { weekday: "short" });
}

function buildLast7Days(callEvents: CallEvent[], smsEvents: SmsEvent[]): DayBucket[] {
  const today = startOfDay(new Date());
  const buckets: DayBucket[] = [];

  for (let i = 6; i >= 0; i -= 1) {
    const day = new Date(today);
    day.setDate(today.getDate() - i);

    buckets.push({
      key: formatDayKey(day),
      label: formatShortDay(day),
      calls: 0,
      followups: 0,
      replies: 0
    });
  }

  const bucketMap = new Map(buckets.map((bucket) => [bucket.key, bucket]));

  for (const event of callEvents) {
    if (!event.createdAt) continue;
    const key = formatDayKey(new Date(event.createdAt));
    const bucket = bucketMap.get(key);
    if (bucket) bucket.calls += 1;
  }

  for (const event of smsEvents) {
    if (!event.createdAt) continue;
    const key = formatDayKey(new Date(event.createdAt));
    const bucket = bucketMap.get(key);
    if (!bucket) continue;

    if (event.direction === "outbound-followup") {
      bucket.followups += 1;
    } else if (event.direction === "inbound-reply") {
      bucket.replies += 1;
    }
  }

  return buckets;
}

function getPercent(numerator: number, denominator: number) {
  if (!denominator) return "0%";
  return `${Math.round((numerator / denominator) * 100)}%`;
}

function parseMenuOptions(text: string) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 4);
}

function stringifyMenuOptions(options?: string[]) {
  return Array.isArray(options) ? options.join("\n") : "";
}

function getDefaultMenuOptions(businessType?: string) {
  const type = String(businessType || "").toLowerCase();

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
    type.includes("doctor") ||
    type.includes("clinic") ||
    type.includes("medical")
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
    type.includes("roof")
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

  return [
    "Book an appointment",
    "Ask about pricing",
    "General question",
    "Something else"
  ];
}

function buildLocalPreviewMessage(input: {
  businessName: string;
  businessType?: string;
  businessDescription?: string;
  tone: MessageTone;
  style: FirstResponseStyle;
  bookingLink?: string;
  followupTemplate?: string;
  useAiGeneratedMessage: boolean;
  menuOptionsText: string;
}) {
  const businessName = input.businessName.trim() || "Your Business";
  const bookingLink = input.bookingLink?.trim() || "";
  const menuOptions = parseMenuOptions(input.menuOptionsText);
  const options =
    menuOptions.length > 0 ? menuOptions : getDefaultMenuOptions(input.businessType);

  if (!input.useAiGeneratedMessage && input.followupTemplate?.trim()) {
    let manual = input.followupTemplate
      .replace(/\{\{business\}\}/g, businessName)
      .replace(/\{\{caller\}\}/g, "(555) 123-4567")
      .replace(/\{\{link\}\}/g, bookingLink);

    if (input.style === "menu") {
      const hasMenu = /\b1\.\s/.test(manual);
      if (!hasMenu) {
        manual += `\n\n${options.map((option, i) => `${i + 1}. ${option}`).join("\n")}`;
      }
    }

    return manual.trim();
  }

  if (input.style === "appointment") {
    let message =
      input.tone === "direct"
        ? `Hi — this is ${businessName}. Were you trying to book an appointment?`
        : `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to book an appointment?`;

    if (bookingLink) {
      message += ` You can also book here: ${bookingLink}`;
    }

    return message;
  }

  if (input.style === "menu") {
    const intro =
      input.tone === "professional"
        ? `Hi — this is ${businessName}. Sorry we missed your call. How can we help today?`
        : `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;

    return `${intro}\n\n${options.map((option, i) => `${i + 1}. ${option}`).join("\n")}`;
  }

  const type = String(input.businessType || "").toLowerCase();

  if (type.includes("auto")) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you calling about a repair, service, or pricing?`;
  }

  if (
    type.includes("salon") ||
    type.includes("spa") ||
    type.includes("barber") ||
    type.includes("beauty")
  ) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment?`;
  }

  if (
    type.includes("dental") ||
    type.includes("doctor") ||
    type.includes("clinic") ||
    type.includes("medical")
  ) {
    return `Hi — this is ${businessName}. Sorry we missed your call. Were you trying to schedule an appointment or ask a question?`;
  }

  if (input.tone === "direct") {
    return `Hi — this is ${businessName}. What can we help with?`;
  }

  if (input.tone === "casual") {
    return `Hi — this is ${businessName}. Sorry we missed your call. What were you calling about?`;
  }

  if (input.tone === "professional") {
    return `Hi — this is ${businessName}. Sorry we missed your call. How can we help you today?`;
  }

  return `Hi — this is ${businessName}. Sorry we missed your call. What can we help with?`;
}

function formatClassificationLabel(category?: LeadCategory) {
  if (!category) return "Unknown";
  if (category === "existing_customer") return "Existing customer";
  if (category === "wrong_number") return "Wrong number";
  if (category === "spam") return "Spam";
  if (category === "lead") return "Likely new lead";
  return "Awaiting reply";
}

export function useDashboardData() {
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [provisioning, setProvisioning] = useState(false);
  const [releasing, setReleasing] = useState(false);
  const [sendingMessage, setSendingMessage] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [hasUnsavedSettingsChanges, setHasUnsavedSettingsChanges] = useState(false);

  const [business, setBusiness] = useState<DashboardBusiness | null>(null);

  const [businessName, setBusinessName] = useState("");
  const [businessType, setBusinessType] = useState("");
  const [businessDescription, setBusinessDescription] = useState("");
  const [notifyNumber, setNotifyNumber] = useState("");
  const [cooldownMinutes, setCooldownMinutes] = useState(120);
  const [followupTemplate, setFollowupTemplate] = useState("");
  const [bookingLink, setBookingLink] = useState("");
  const [tone, setTone] = useState<MessageTone>("friendly");
  const [firstResponseStyle, setFirstResponseStyle] =
    useState<FirstResponseStyle>("conversational");
  const [menuOptionsText, setMenuOptionsText] = useState("");
  const [useAiGeneratedMessage, setUseAiGeneratedMessage] = useState(true);
  const [aiEnabled, setAiEnabled] = useState(true);
  const [classifyLeads, setClassifyLeads] = useState(true);
  const [autoFollowupEnabled, setAutoFollowupEnabled] = useState(true);
  const [conversationRepliesEnabled, setConversationRepliesEnabled] = useState(true);
  const [priorityEscalationEnabled, setPriorityEscalationEnabled] = useState(false);
  const [priorityPrimaryPhone, setPriorityPrimaryPhone] = useState("");
  const [priorityBackupPhone, setPriorityBackupPhone] = useState("");
  const [priorityKeywordsText, setPriorityKeywordsText] = useState("");
  const [priorityRingTimeout, setPriorityRingTimeout] = useState(20);
  const [priorityCustomerConfirmation, setPriorityCustomerConfirmation] = useState(true);

  const [leads, setLeads] = useState<Lead[]>([]);
  const [callEvents, setCallEvents] = useState<CallEvent[]>([]);
  const [smsEvents, setSmsEvents] = useState<SmsEvent[]>([]);
  const [escalations, setEscalations] = useState<EscalationEvent[]>([]);

  const hydrateBusinessForm = useCallback((b: DashboardBusiness) => {
    setBusinessName(b.name || "");
    setBusinessType(b.businessType || "");
    setBusinessDescription(b.businessDescription || "");
    setNotifyNumber(b.notifyToNumber || "");
    setCooldownMinutes(Number(b.cooldownMinutes ?? 120));
    setFollowupTemplate(
      b.followupTemplate ||
        "Hi — this is {{business}}. Sorry we missed your call. How can we help?"
    );
    setBookingLink(b.bookingLink || "");
    setTone((b.tone as MessageTone) || "friendly");
    setFirstResponseStyle(
      (b.firstResponseStyle as FirstResponseStyle) || "conversational"
    );
    setMenuOptionsText(
      stringifyMenuOptions(
        b.menuOptions && b.menuOptions.length > 0
          ? b.menuOptions
          : getDefaultMenuOptions(b.businessType)
      )
    );
    setUseAiGeneratedMessage(
      typeof b.useAiGeneratedMessage === "boolean" ? b.useAiGeneratedMessage : true
    );
    setAiEnabled(typeof b.aiConfig?.enabled === "boolean" ? !!b.aiConfig.enabled : true);
    setClassifyLeads(
      typeof b.aiConfig?.classifyLeads === "boolean" ? !!b.aiConfig.classifyLeads : true
    );
    setAutoFollowupEnabled(
      typeof b.aiConfig?.autoFollowupEnabled === "boolean"
        ? !!b.aiConfig.autoFollowupEnabled
        : true
    );
    setConversationRepliesEnabled(
      typeof b.aiConfig?.conversationRepliesEnabled === "boolean"
        ? !!b.aiConfig.conversationRepliesEnabled
        : true
    );
    setPriorityEscalationEnabled(Boolean(b.priorityEscalation?.enabled));
    setPriorityPrimaryPhone(b.priorityEscalation?.primaryPhone || "");
    setPriorityBackupPhone(b.priorityEscalation?.backupPhone || "");
    setPriorityKeywordsText(
      (b.priorityEscalation?.urgentKeywords || [
        "tow", "towing", "stranded", "broke down", "roadside", "accident"
      ]).join(", ")
    );
    setPriorityRingTimeout(Number(b.priorityEscalation?.ringTimeoutSeconds || 20));
    setPriorityCustomerConfirmation(
      b.priorityEscalation?.customerConfirmationEnabled !== false
    );
  }, []);

  const loadDashboard = useCallback(
    async (showInitialLoader = false, preserveSettingsDraft = false) => {
      try {
        if (showInitialLoader) {
          setLoading(true);
        } else {
          setRefreshing(true);
        }

        setError("");

        const businessResult = await getMyBusiness();
        const b = businessResult.business as DashboardBusiness;

        setBusiness(b);

        if (!preserveSettingsDraft) {
          hydrateBusinessForm(b);
          setHasUnsavedSettingsChanges(false);
        }

        const [leadResult, eventResult, smsResult, escalationResult] = await Promise.all([
          apiFetch<{ ok: true; leads: Lead[] }>("/admin/leads", { method: "GET" }),
          apiFetch<{ ok: true; events: CallEvent[] }>("/admin/events", { method: "GET" }),
          getSmsEventsSafe(),
          apiFetch<{ ok: true; events: EscalationEvent[] }>("/admin/escalations", { method: "GET" })
        ]);

        const businessId = String(b._id);

        setLeads(leadResult.leads.filter((lead) => String(lead.businessId) === businessId));
        setCallEvents(
          eventResult.events.filter((event) => String(event.businessId) === businessId)
        );
        setSmsEvents(
          smsResult.events.filter((event) => String(event.businessId) === businessId)
        );
        setEscalations(escalationResult.events);
      } catch (err: any) {
        setError(err.message || "Failed to load dashboard");
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [hydrateBusinessForm]
  );

  useEffect(() => {
    loadDashboard(true, false);
  }, [loadDashboard]);

  const refreshDashboard = useCallback(async () => {
    await loadDashboard(false, false);
  }, [loadDashboard]);

  const markSettingsDirty = useCallback(() => {
    setHasUnsavedSettingsChanges(true);
  }, []);

  const handleBusinessNameChange = useCallback(
    (value: string) => {
      setBusinessName(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleBusinessTypeChange = useCallback(
    (value: string) => {
      setBusinessType(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleBusinessDescriptionChange = useCallback(
    (value: string) => {
      setBusinessDescription(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleNotifyNumberChange = useCallback(
    (value: string) => {
      setNotifyNumber(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleCooldownMinutesChange = useCallback(
    (value: string) => {
      setCooldownMinutes(Number(value) || 0);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleBookingLinkChange = useCallback(
    (value: string) => {
      setBookingLink(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleToneChange = useCallback(
    (value: string) => {
      setTone(value as MessageTone);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleStyleChange = useCallback(
    (value: string) => {
      setFirstResponseStyle(value as FirstResponseStyle);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleMenuOptionsTextChange = useCallback(
    (value: string) => {
      setMenuOptionsText(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleFollowupTemplateChange = useCallback(
    (value: string) => {
      setFollowupTemplate(value);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleUseAiGeneratedMessageChange = useCallback(
    (checked: boolean) => {
      setUseAiGeneratedMessage(checked);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleAiEnabledChange = useCallback(
    (checked: boolean) => {
      setAiEnabled(checked);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleClassifyLeadsChange = useCallback(
    (checked: boolean) => {
      setClassifyLeads(checked);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleAutoFollowupEnabledChange = useCallback(
    (checked: boolean) => {
      setAutoFollowupEnabled(checked);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const handleConversationRepliesEnabledChange = useCallback(
    (checked: boolean) => {
      setConversationRepliesEnabled(checked);
      markSettingsDirty();
    },
    [markSettingsDirty]
  );

  const updatePriorityField = useCallback((field: string, value: string | number | boolean) => {
    if (field === "enabled") setPriorityEscalationEnabled(Boolean(value));
    if (field === "primaryPhone") setPriorityPrimaryPhone(String(value));
    if (field === "backupPhone") setPriorityBackupPhone(String(value));
    if (field === "keywords") setPriorityKeywordsText(String(value));
    if (field === "timeout") setPriorityRingTimeout(Number(value) || 20);
    if (field === "confirmation") setPriorityCustomerConfirmation(Boolean(value));
    markSettingsDirty();
  }, [markSettingsDirty]);

  const saveSettings = useCallback(async () => {
    try {
      setSaving(true);
      setError("");

      const payload = {
        name: businessName,
        businessType,
        businessDescription,
        notifyToNumber: notifyNumber,
        cooldownMinutes,
        followupTemplate,
        bookingLink,
        tone,
        firstResponseStyle,
        menuOptions: parseMenuOptions(menuOptionsText),
        useAiGeneratedMessage,
        aiConfig: {
          enabled: aiEnabled,
          classifyLeads,
          autoFollowupEnabled,
          conversationRepliesEnabled
        },
        priorityEscalation: {
          enabled: priorityEscalationEnabled,
          primaryPhone: priorityPrimaryPhone,
          backupPhone: priorityBackupPhone,
          urgentKeywords: priorityKeywordsText.split(",").map((item) => item.trim()).filter(Boolean),
          ringTimeoutSeconds: priorityRingTimeout,
          customerConfirmationEnabled: priorityCustomerConfirmation
        }
      };

      const result = await updateMyBusiness(payload as any);
      const updatedBusiness = result.business as DashboardBusiness;

      setBusiness(updatedBusiness);
      hydrateBusinessForm(updatedBusiness);
      setHasUnsavedSettingsChanges(false);
      setNotice("Saved successfully");
    } catch (err: any) {
      setError(err.message || "Failed to save settings");
    } finally {
      setSaving(false);
    }
  }, [
    aiEnabled,
    autoFollowupEnabled,
    bookingLink,
    businessDescription,
    businessName,
    businessType,
    classifyLeads,
    conversationRepliesEnabled,
    cooldownMinutes,
    firstResponseStyle,
    followupTemplate,
    hydrateBusinessForm,
    menuOptionsText,
    notifyNumber,
    priorityBackupPhone,
    priorityCustomerConfirmation,
    priorityEscalationEnabled,
    priorityKeywordsText,
    priorityPrimaryPhone,
    priorityRingTimeout,
    tone,
    useAiGeneratedMessage
  ]);

  const releaseNumber = useCallback(async () => {
    try {
      setReleasing(true);
      setError("");

      const result = await releaseMyBusinessNumber();
      const updatedBusiness = result.business as DashboardBusiness;

      setBusiness(updatedBusiness);
      hydrateBusinessForm(updatedBusiness);
      setHasUnsavedSettingsChanges(false);
      setNotice("Callsy number released");
    } catch (err: any) {
      setError(err.message || "Failed to release number");
    } finally {
      setReleasing(false);
    }
  }, [hydrateBusinessForm]);

  const provisionNumber = useCallback(async (areaCode?: number) => {
    try {
      setProvisioning(true);
      setError("");
      const result = await provisionMyBusinessNumber(areaCode);
      const updatedBusiness = result.business as DashboardBusiness;
      setBusiness(updatedBusiness);
      hydrateBusinessForm(updatedBusiness);
      setNotice(`Callsy number ${formatPhone(updatedBusiness.twilioNumber)} is ready`);
    } catch (err: any) {
      setError(err.message || "Failed to set up a Callsy number");
    } finally {
      setProvisioning(false);
    }
  }, [hydrateBusinessForm]);

  const sendManualMessage = useCallback(async (leadId: string, body: string) => {
    try {
      setSendingMessage(true);
      setError("");
      await apiFetch(`/admin/leads/${leadId}/messages`, { method: "POST", json: { body } });
      await loadDashboard(false, false);
      setNotice("Reply sent — AI paused for this conversation");
      return true;
    } catch (err: any) {
      setError(err.message || "Failed to send reply");
      return false;
    } finally { setSendingMessage(false); }
  }, [loadDashboard]);

  const resumeAutomation = useCallback(async (leadId: string) => {
    try {
      setError("");
      await apiFetch(`/admin/leads/${leadId}/resume-automation`, { method: "POST" });
      await loadDashboard(false, false);
      setNotice("AI replies resumed for this conversation");
    } catch (err: any) { setError(err.message || "Failed to resume AI"); }
  }, [loadDashboard]);

  const updateAppointmentStatus = useCallback(async (leadId: string, status: "booked" | "completed") => {
    try {
      setError("");
      await apiFetch(`/admin/leads/${leadId}/appointment`, { method: "PATCH", json: { status } });
      await loadDashboard(false, false);
      setNotice(status === "booked" ? "Appointment marked booked" : "Job marked completed");
    } catch (err: any) { setError(err.message || "Failed to update appointment"); }
  }, [loadDashboard]);

  const assignTestNumber = useCallback(async () => {
    try {
      setProvisioning(true);
      setError("");
      const result = await assignMyBusinessTestNumber();
      const updatedBusiness = result.business as DashboardBusiness;
      setBusiness(updatedBusiness);
      hydrateBusinessForm(updatedBusiness);
      setNotice(`Test number ${formatPhone(updatedBusiness.twilioNumber)} connected — no Twilio charge`);
    } catch (err: any) {
      setError(err.message || "Failed to connect a test number");
    } finally {
      setProvisioning(false);
    }
  }, [hydrateBusinessForm]);

  const overviewData = useMemo(() => {
    const days = buildLast7Days(callEvents, smsEvents);
  
    const missedCalls = callEvents.length;
    const followupsSent = smsEvents.filter(
      (event) => event.direction === "outbound-followup"
    ).length;
    const customerReplies = smsEvents.filter(
      (event) => event.direction === "inbound-reply"
    ).length;
  
    const leadsWithFollowupSent = leads.filter((lead) => lead.followup?.sent).length;
    const leadsWithReply = leads.filter(
      (lead) => lead.followup?.sent && (lead.smsReplyCount ?? 0) > 0
    ).length;
    const uniqueLeadCount = leads.length;
  
    const stats: Stat[] = [
      {
        label: "Missed calls captured",
        value: String(missedCalls),
        hint: `${uniqueLeadCount} unique leads`,
        icon: "call",
        trend: days.map((day) => day.calls)
      },
      {
        label: "Follow-up texts sent",
        value: String(followupsSent),
        hint: autoFollowupEnabled ? "Automated follow-ups" : "Follow-up automation off",
        icon: "sms",
        trend: days.map((day) => day.followups)
      },
      {
        label: "Customer replies",
        value: String(customerReplies),
        hint: "Inbound SMS replies",
        icon: "reply",
        trend: days.map((day) => day.replies)
      }
    ];
  
    return {
      days,
      stats,
      missedCalls,
      followupsSent,
      customerReplies,
      uniqueLeadCount,
      leadsWithFollowupSent,
      leadsWithReply,
      replyRate: getPercent(leadsWithReply, leadsWithFollowupSent),
      contactRate: getPercent(leadsWithFollowupSent, uniqueLeadCount)
    };
  }, [callEvents, smsEvents, leads, autoFollowupEnabled]);

  const classificationSummary = useMemo(() => {
    const counts: Record<LeadCategory, number> = {
      lead: 0,
      existing_customer: 0,
      wrong_number: 0,
      spam: 0,
      unknown: 0
    };

    for (const lead of leads) {
      const category = lead.classification?.category || "unknown";
      counts[category] += 1;
    }

    return counts;
  }, [leads]);

  const feed: FeedItem[] = useMemo(() => {
    const leadMap = new Map<string, Lead>();

    for (const lead of leads) {
      leadMap.set(String(lead._id), lead);
    }

    const callFeed: FeedItem[] = callEvents.map((event) => {
      const linkedLead = event.leadId ? leadMap.get(String(event.leadId)) : undefined;
      const consentStatus = event.consent?.status;
      const consentMethod = event.consent?.method;

      return {
        id: `call-${event._id}`,
        time: timeAgo(event.createdAt),
        title: event.callbackRequired ? "Callback needed" : consentStatus === "granted" ? "Caller requested a text" : "Missed call captured",
        detail: event.callbackRequired
          ? `${formatPhone(event.from)} did not provide text consent. Return the call directly.`
          : `Customer ${formatPhone(event.from)} called your forwarded Callsy number.`,
        secondary: consentStatus === "granted"
          ? `SMS consent recorded by ${consentMethod === "keypress" ? "keypress" : "spoken response"}.`
          : consentStatus === "pending"
            ? "Waiting for the caller to press 1 or say yes."
            : `Call status: ${event.callStatus || "ringing"}`,
        tertiary:
          aiEnabled && linkedLead?.classification?.category
            ? `Classified as: ${formatClassificationLabel(linkedLead.classification.category)}`
            : undefined,
        kind: "call",
        createdAt: event.createdAt,
        classificationCategory: linkedLead?.classification?.category,
        classificationReason: linkedLead?.classification?.reason
      };
    });

    const smsFeed: FeedItem[] = smsEvents.map((event) => {
      const linkedLead = event.leadId ? leadMap.get(String(event.leadId)) : undefined;
      const classificationCategory = linkedLead?.classification?.category;
      const classificationReason = linkedLead?.classification?.reason;
      const followupMessage = linkedLead?.followup?.message;

      if (event.direction === "outbound-followup") {
        return {
          id: `sms-${event._id}`,
          time: timeAgo(event.createdAt),
          title: aiEnabled ? "AI follow-up sent" : "Automated follow-up sent",
          detail: `Callsy sent your saved follow-up message to ${formatPhone(event.to)}.`,
          secondary: event.status ? `Message status: ${event.status}` : undefined,
          tertiary:
            aiEnabled && followupMessage
              ? `Reply sent: "${followupMessage}"`
              : event.body
                ? `Reply sent: "${event.body}"`
                : undefined,
          kind: "sms" as const,
          createdAt: event.createdAt,
          classificationCategory,
          classificationReason,
          followupMessage: followupMessage || event.body
        };
      }

      if (event.direction === "inbound-reply") {
        const classificationText =
          aiEnabled && classificationCategory
            ? `Classified as: ${formatClassificationLabel(classificationCategory)}${
                classificationReason ? ` — ${classificationReason}` : ""
              }`
            : "";

        const replyText =
          aiEnabled && followupMessage ? `AI reply sent: "${followupMessage}"` : "";

        const tertiary =
          [classificationText, replyText].filter(Boolean).join("\n\n") || undefined;

        return {
          id: `sms-${event._id}`,
          time: timeAgo(event.createdAt),
          title: "Customer replied",
          detail: `"${event.body}"`,
          secondary: `Reply received from ${formatPhone(event.from)} and linked to this business.`,
          tertiary,
          kind: "reply" as const,
          createdAt: event.createdAt,
          classificationCategory,
          classificationReason,
          followupMessage
        };
      }

      return {
        id: `sms-${event._id}`,
        time: timeAgo(event.createdAt),
        title: "Message activity",
        detail: event.body || "SMS activity recorded.",
        secondary: undefined,
        tertiary:
          aiEnabled && classificationCategory
            ? `Classified as: ${formatClassificationLabel(classificationCategory)}`
            : undefined,
        kind: "sms" as const,
        createdAt: event.createdAt,
        classificationCategory,
        classificationReason,
        followupMessage
      };
    });

    return [...callFeed, ...smsFeed]
      .sort((a, b) => {
        return new Date(b.createdAt || "").getTime() - new Date(a.createdAt || "").getTime();
      })
      .slice(0, 20);
  }, [callEvents, smsEvents, leads, aiEnabled]);

  const previewMessage = useMemo(
    () =>
      buildLocalPreviewMessage({
        businessName,
        businessType,
        businessDescription,
        tone,
        style: firstResponseStyle,
        bookingLink,
        followupTemplate,
        useAiGeneratedMessage,
        menuOptionsText
      }),
    [
      bookingLink,
      businessDescription,
      businessName,
      businessType,
      firstResponseStyle,
      followupTemplate,
      menuOptionsText,
      tone,
      useAiGeneratedMessage
    ]
  );

  useEffect(() => {
    if (!notice) return;
    const t = setTimeout(() => setNotice(""), 2500);
    return () => clearTimeout(t);
  }, [notice]);

  return {
    loading,
    refreshing,
    saving,
    provisioning,
    releasing,
    sendingMessage,
    error,
    notice,
    hasUnsavedSettingsChanges,

    business,
    leads,
    callEvents,
    smsEvents,
    escalations,

    businessName,
    businessType,
    businessDescription,
    notifyNumber,
    cooldownMinutes,
    followupTemplate,
    bookingLink,
    tone,
    firstResponseStyle,
    menuOptionsText,
    useAiGeneratedMessage,
    aiEnabled,
    classifyLeads,
    autoFollowupEnabled,
    conversationRepliesEnabled,
    priorityEscalationEnabled,
    priorityPrimaryPhone,
    priorityBackupPhone,
    priorityKeywordsText,
    priorityRingTimeout,
    priorityCustomerConfirmation,

    overviewData,
    classificationSummary,
    feed,
    previewMessage,

    setNotice,
    setError,
    setHasUnsavedSettingsChanges,

    loadDashboard,
    refreshDashboard,
    saveSettings,
    provisionNumber,
    assignTestNumber,
    releaseNumber,
    sendManualMessage,
    resumeAutomation,
    updateAppointmentStatus,

    handleBusinessNameChange,
    handleBusinessTypeChange,
    handleBusinessDescriptionChange,
    handleNotifyNumberChange,
    handleCooldownMinutesChange,
    handleBookingLinkChange,
    handleToneChange,
    handleStyleChange,
    handleMenuOptionsTextChange,
    handleFollowupTemplateChange,
    handleUseAiGeneratedMessageChange,
    handleAiEnabledChange,
    handleClassifyLeadsChange,
    handleAutoFollowupEnabledChange,
    handleConversationRepliesEnabledChange
    ,updatePriorityField
  };
}
