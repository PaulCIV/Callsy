import { Activity, MessageSquareText, PhoneMissed } from "lucide-react";

type LeadCategory =
  | "lead"
  | "existing_customer"
  | "wrong_number"
  | "spam"
  | "unknown";

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

function CompactFeedRow({ item }: { item: FeedItem }) {
  const icon =
    item.kind === "call" ? (
      <PhoneMissed size={16} />
    ) : item.kind === "sms" ? (
      <MessageSquareText size={16} />
    ) : (
      <Activity size={16} />
    );

  return (
    <div className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-3">
      <div className="flex items-start gap-3">
        <div className="mt-0.5 inline-flex h-8 w-8 items-center justify-center rounded-lg bg-zinc-900 text-white">
          {icon}
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0 flex-1">
              <div className="text-sm font-medium text-zinc-900">{item.title}</div>
              <div className="truncate text-xs text-zinc-500">{item.detail}</div>

              {item.tertiary ? (
                <div className="mt-2 line-clamp-2 text-[11px] text-zinc-600">
                  {item.tertiary}
                </div>
              ) : null}
            </div>

            <div className="shrink-0 text-xs text-zinc-400">{item.time}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function RecentActivityPreview({ feed }: { feed: FeedItem[] }) {
  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-sm font-medium text-zinc-900">Recent performance</div>
          <div className="mt-1 text-sm text-zinc-600">
            Latest captured calls and text activity.
          </div>
        </div>
      </div>

      <div className="mt-5 space-y-3">
        {feed.length > 0 ? (
          feed.map((item) => <CompactFeedRow key={item.id} item={item} />)
        ) : (
          <div className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-4 text-sm text-zinc-600">
            No activity yet.
          </div>
        )}
      </div>
    </div>
  );
}