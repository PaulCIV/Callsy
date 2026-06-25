import AiAutomationCard from "./AiAutomationCard";
import ClassificationSummaryCard from "./ClassificationSummaryCard";
import QuickInsightsCard from "./QuickInsightsCard";
import RecentActivityPreview from "./RecentActivityPreview";
import StatCard from "./StatCard";
import WeeklyActivityCard from "./WeeklyActivityCard";
import { MessageCircleReply, MessageSquareText, Phone } from "lucide-react";

type MessageTone = "friendly" | "professional" | "casual" | "direct";
type FirstResponseStyle = "conversational" | "menu" | "appointment";
type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

type Stat = {
  label: string;
  value: string;
  hint?: string;
  icon: "call" | "sms" | "reply";
  trend: number[];
};

type FeedItem = {
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

type DayBucket = {
  key: string;
  label: string;
  calls: number;
  followups: number;
  replies: number;
};

function FunnelCard({
  missedCalls,
  followupsSent,
  customerReplies,
  contactRate,
  replyRate
}: {
  missedCalls: number;
  followupsSent: number;
  customerReplies: number;
  contactRate: string;
  replyRate: string;
}) {
  const steps = [
    {
      label: "Missed calls",
      value: missedCalls,
      icon: <Phone size={16} />,
      widthClass: "w-full"
    },
    {
      label: "Follow-ups sent",
      value: followupsSent,
      icon: <MessageSquareText size={16} />,
      widthClass: "w-[82%]"
    },
    {
      label: "Replies received",
      value: customerReplies,
      icon: <MessageCircleReply size={16} />,
      widthClass: "w-[64%]"
    }
  ];

  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm font-medium text-zinc-900">Lead funnel</div>
          <div className="mt-1 text-sm text-zinc-600">
            How missed calls move through follow-up and reply.
          </div>
        </div>
        <div className="rounded-full bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-700">
          7 day view
        </div>
      </div>

      <div className="mt-6 space-y-3">
        {steps.map((step) => (
          <div key={step.label} className={step.widthClass}>
            <div className="rounded-2xl border border-zinc-200 bg-zinc-50 px-4 py-4">
              <div className="flex items-center justify-between gap-3">
                <div className="inline-flex items-center gap-2 text-sm font-medium text-zinc-800">
                  {step.icon}
                  {step.label}
                </div>
                <div className="text-lg font-semibold text-zinc-900">{step.value}</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <div className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-3">
          <div className="text-xs text-zinc-500">Contact rate</div>
          <div className="mt-1 text-xl font-semibold text-zinc-900">{contactRate}</div>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-3">
          <div className="text-xs text-zinc-500">Reply rate</div>
          <div className="mt-1 text-xl font-semibold text-zinc-900">{replyRate}</div>
        </div>
      </div>
    </div>
  );
}

type OverviewTabProps = {
  stats: Stat[];
  days: DayBucket[];
  feed: FeedItem[];
  leadsCount: number;
  missedCalls: number;
  followupsSent: number;
  customerReplies: number;
  contactRate: string;
  replyRate: string;
  aiEnabled: boolean;
  classifyLeads: boolean;
  autoFollowupEnabled: boolean;
  useAiGeneratedMessage: boolean;
  tone: MessageTone;
  style: FirstResponseStyle;
  previewMessage: string;
  classificationSummary: Record<LeadCategory, number>;
};

export default function OverviewTab(props: OverviewTabProps) {
  return (
    <div className="mt-6 space-y-6">
      <div className="grid gap-4 md:grid-cols-3">
        {props.stats.map((stat) => (
          <StatCard key={stat.label} stat={stat} />
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-[1.1fr_1.4fr]">
        <FunnelCard
          missedCalls={props.missedCalls}
          followupsSent={props.followupsSent}
          customerReplies={props.customerReplies}
          contactRate={props.contactRate}
          replyRate={props.replyRate}
        />
        <WeeklyActivityCard days={props.days} />
      </div>

      <div className="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <RecentActivityPreview feed={props.feed.slice(0, 5)} />
        <QuickInsightsCard
          leads={props.leadsCount}
          missedCalls={props.missedCalls}
          followupsSent={props.followupsSent}
          customerReplies={props.customerReplies}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-[1fr_1fr]">
        <AiAutomationCard
          aiEnabled={props.aiEnabled}
          classifyLeads={props.classifyLeads}
          autoFollowupEnabled={props.autoFollowupEnabled}
          useAiGeneratedMessage={props.useAiGeneratedMessage}
          tone={props.tone}
          style={props.style}
          previewMessage={props.previewMessage}
        />
        <ClassificationSummaryCard summary={props.classificationSummary} />
      </div>
    </div>
  );
}