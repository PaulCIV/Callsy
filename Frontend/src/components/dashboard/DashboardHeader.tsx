import { Bot, LogOut, RefreshCw } from "lucide-react";

type DashboardHeaderProps = {
  businessName: string;
  refreshing: boolean;
  loggingOut: boolean;
  onRefresh: () => void;
  onLogout: () => void;
  hasAssignedNumber: boolean;
  onboardingStatus: string;
  replyRate: string;
  contactRate: string;
  aiEnabled: boolean;
  twilioNumber?: string;
  isSettingsTab?: boolean;
  hasUnsavedSettingsChanges?: boolean;
};

export default function DashboardHeader({
  businessName,
  refreshing,
  loggingOut,
  onRefresh,
  onLogout,
  hasAssignedNumber,
  onboardingStatus,
  replyRate,
  contactRate,
  aiEnabled,
  twilioNumber,
  isSettingsTab = false,
  hasUnsavedSettingsChanges = false
}: DashboardHeaderProps) {
  return (
    <>
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <div className="text-sm font-semibold tracking-tight text-zinc-900">
            Callsy Dashboard
          </div>
          <div className="mt-1 text-sm text-zinc-600">{businessName}</div>
        </div>

        <div className="flex flex-wrap items-center gap-4">
          {refreshing ? <div className="text-xs text-zinc-500">Refreshing...</div> : null}

          <button
            type="button"
            onClick={onRefresh}
            disabled={refreshing}
            className="inline-flex items-center gap-2 text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-50"
          >
            <RefreshCw size={16} className={refreshing ? "animate-spin" : ""} />
            Refresh
          </button>

          <button
            type="button"
            onClick={onLogout}
            disabled={loggingOut}
            className="inline-flex items-center gap-2 text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-50"
          >
            <LogOut size={16} />
            {loggingOut ? "Logging out..." : "Logout"}
          </button>
        </div>
      </div>

      <div className="mt-6 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
          <div className="min-w-0">
            <div className="text-sm font-medium text-zinc-900">Personalized number</div>
            <div className="mt-1 text-sm text-zinc-600">
              {hasAssignedNumber
                ? "Number has been assigned. This will be used to communicate with customers."
                : "Assign a Callsy number, then forward missed calls from your business number to it."}
            </div>

            <div className="mt-3 flex flex-wrap items-center gap-3">
              <div className="inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
                Status: {onboardingStatus}
              </div>
              <div className="inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
                Reply rate: {replyRate}
              </div>
              <div className="inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
                Contact rate: {contactRate}
              </div>
              <div className="inline-flex items-center gap-1 rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
                <Bot size={12} />
                AI {aiEnabled ? "enabled" : "off"}
              </div>

              {isSettingsTab && hasUnsavedSettingsChanges ? (
                <div className="inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800">
                  Unsaved changes
                </div>
              ) : null}

              {isSettingsTab ? (
                <div className="inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-700">
                  Live refresh paused while editing
                </div>
              ) : null}
            </div>
          </div>

          {hasAssignedNumber ? (
            <div className="flex items-center gap-3">
              <div className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-2 text-sm text-zinc-800">
                {twilioNumber}
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </>
  );
}