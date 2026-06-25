import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardHeader from "../components/dashboard/DashboardHeader";
import OverviewTab from "../components/dashboard/OverviewTab";
import ActivityTab from "../components/dashboard/ActivityTab";
import SettingsTab from "../components/dashboard/SettingsTab";
import { logout } from "../pages/api/auth";
import { useDashboardData } from "../hooks/useDashboardData";

export default function Dashboard() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<"overview" | "activity" | "settings">("overview");
  const [loggingOut, setLoggingOut] = useState(false);

  const {
    loading,
    refreshing,
    saving,
    releasing,
    error,
    notice,
    hasUnsavedSettingsChanges,

    business,
    leads,
    smsEvents,

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

    overviewData,
    classificationSummary,
    feed,
    previewMessage,

    setNotice,
    loadDashboard,
    refreshDashboard,
    saveSettings,
    releaseNumber,

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
  } = useDashboardData();

  useEffect(() => {
    if (tab === "settings") return;

    const interval = setInterval(() => {
      refreshDashboard();
    }, 5000);

    return () => clearInterval(interval);
  }, [tab, refreshDashboard]);

  const restoreScroll = (scrollY: number) => {
    window.requestAnimationFrame(() => {
      window.scrollTo({ top: scrollY, behavior: "auto" });
    });
  };

  const handleManualRefresh = async () => {
    const scrollY = window.scrollY;
    await loadDashboard(false, tab === "settings");
    restoreScroll(scrollY);
  };

  const handleSave = async () => {
    const scrollY = window.scrollY;
    await saveSettings();
    restoreScroll(scrollY);
  };

  const handleReleaseNumber = async () => {
    const confirmed = window.confirm(
      "Release this Callsy number?\n\nThis will stop missed-call forwarding until another number is assigned."
    );

    if (!confirmed) return;

    const scrollY = window.scrollY;
    await releaseNumber();
    restoreScroll(scrollY);
  };

  const handleLogout = async () => {
    try {
      setLoggingOut(true);
      await logout();
      navigate("/login");
    } catch {
      navigate("/login");
    } finally {
      setLoggingOut(false);
    }
  };

  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(""), 2500);
    return () => clearTimeout(timer);
  }, [notice, setNotice]);

  const hasAssignedNumber = Boolean(business?.twilioNumber);
  const onboardingStatus = business?.onboardingStatus || "draft";
  const isSettingsTab = tab === "settings";

  const stats = useMemo(() => overviewData.stats, [overviewData.stats]);

  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-50">
        <div className="mx-auto max-w-6xl px-6 py-10">
          <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
            <div className="text-sm text-zinc-600">Loading dashboard...</div>
          </div>
        </div>
      </div>
    );
  }

  console.log("BUSINESS ID", business?._id);
  console.log("SMS EVENTS FROM HOOK", smsEvents);
  console.log("FEED FROM HOOK", feed);

  return (
    <div className="min-h-screen bg-zinc-50">
      <div className="mx-auto max-w-6xl px-6 py-10">
        <DashboardHeader
          businessName={businessName}
          refreshing={refreshing}
          loggingOut={loggingOut}
          onRefresh={handleManualRefresh}
          onLogout={handleLogout}
          hasAssignedNumber={hasAssignedNumber}
          onboardingStatus={onboardingStatus}
          replyRate={overviewData.replyRate}
          contactRate={overviewData.contactRate}
          aiEnabled={aiEnabled}
          twilioNumber={business?.twilioNumber}
          isSettingsTab={isSettingsTab}
          hasUnsavedSettingsChanges={hasUnsavedSettingsChanges}
        />

        {error && (
          <div className="mt-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {notice && (
          <div className="mt-6 rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm text-zinc-700 shadow-sm">
            {notice}
          </div>
        )}

        <div className="mt-8 flex gap-2 rounded-2xl border border-zinc-200 bg-white p-2 shadow-sm">
          <TabButton active={tab === "overview"} onClick={() => setTab("overview")}>
            Overview
          </TabButton>

          <TabButton active={tab === "activity"} onClick={() => setTab("activity")}>
            Activity
          </TabButton>

          <TabButton active={tab === "settings"} onClick={() => setTab("settings")}>
            Settings
          </TabButton>
        </div>

        {tab === "overview" && (
          <OverviewTab
            stats={stats}
            days={overviewData.days}
            feed={feed}
            leadsCount={leads.length}
            missedCalls={overviewData.missedCalls}
            followupsSent={overviewData.followupsSent}
            customerReplies={overviewData.customerReplies}
            contactRate={overviewData.contactRate}
            replyRate={overviewData.replyRate}
            aiEnabled={aiEnabled}
            classifyLeads={classifyLeads}
            autoFollowupEnabled={autoFollowupEnabled}
            useAiGeneratedMessage={useAiGeneratedMessage}
            tone={tone}
            style={firstResponseStyle}
            previewMessage={previewMessage}
            classificationSummary={classificationSummary}
          />
        )}

        {tab === "activity" && <ActivityTab feed={feed} />}

        {tab === "settings" && (
          <SettingsTab
            saving={saving}
            releasing={releasing}
            hasAssignedNumber={hasAssignedNumber}
            businessName={businessName}
            businessType={businessType}
            businessDescription={businessDescription}
            notifyNumber={notifyNumber}
            cooldownMinutes={cooldownMinutes}
            bookingLink={bookingLink}
            tone={tone}
            firstResponseStyle={firstResponseStyle}
            menuOptionsText={menuOptionsText}
            followupTemplate={followupTemplate}
            previewMessage={previewMessage}
            aiEnabled={aiEnabled}
            classifyLeads={classifyLeads}
            autoFollowupEnabled={autoFollowupEnabled}
            useAiGeneratedMessage={useAiGeneratedMessage}
            conversationRepliesEnabled={conversationRepliesEnabled}
            onSave={handleSave}
            onReleaseNumber={handleReleaseNumber}
            onBusinessNameChange={handleBusinessNameChange}
            onBusinessTypeChange={handleBusinessTypeChange}
            onBusinessDescriptionChange={handleBusinessDescriptionChange}
            onNotifyNumberChange={handleNotifyNumberChange}
            onCooldownMinutesChange={handleCooldownMinutesChange}
            onBookingLinkChange={handleBookingLinkChange}
            onToneChange={handleToneChange}
            onStyleChange={handleStyleChange}
            onMenuOptionsTextChange={handleMenuOptionsTextChange}
            onFollowupTemplateChange={handleFollowupTemplateChange}
            onAiEnabledChange={handleAiEnabledChange}
            onClassifyLeadsChange={handleClassifyLeadsChange}
            onAutoFollowupEnabledChange={handleAutoFollowupEnabledChange}
            onUseAiGeneratedMessageChange={handleUseAiGeneratedMessageChange}
            onConversationRepliesEnabledChange={handleConversationRepliesEnabledChange}
          />
        )}
      </div>
    </div>
  );
}

function TabButton({
  active,
  onClick,
  children
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={[
        "flex-1 rounded-xl px-4 py-2 text-sm font-medium transition",
        active ? "bg-zinc-900 text-white" : "bg-transparent text-zinc-700 hover:bg-zinc-100"
      ].join(" ")}
    >
      {children}
    </button>
  );
}