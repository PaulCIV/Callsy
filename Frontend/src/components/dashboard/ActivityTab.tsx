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

function FeedRow({ item }: { item: FeedItem }) {
  const icon =
    item.kind === "call" ? (
      <PhoneMissed size={18} />
    ) : item.kind === "sms" ? (
      <MessageSquareText size={18} />
    ) : (
      <Activity size={18} />
    );

  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
      <div className="flex items-start gap-3">
        <div className="mt-0.5 inline-flex h-9 w-9 items-center justify-center rounded-xl bg-zinc-900 text-white">
          {icon}
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex flex-col gap-1 md:flex-row md:items-start md:justify-between">
            <div className="min-w-0 flex-1">
              <div className="text-sm font-medium text-zinc-900">{item.title}</div>
              <div className="mt-1 text-sm text-zinc-700">{item.detail}</div>

              {item.secondary ? (
                <div className="mt-1 text-xs text-zinc-500">{item.secondary}</div>
              ) : null}

              {item.tertiary ? (
                <div className="mt-3 rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-xs text-zinc-700">
                  {item.tertiary}
                </div>
              ) : null}
            </div>

            <div className="text-xs text-zinc-500">{item.time}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ActivityTab({ feed }: { feed: FeedItem[] }) {
  return (
    <div className="mt-6">
      <div className="text-sm font-medium text-zinc-900">Recent activity</div>
      <div className="mt-3 space-y-3">
        {feed.length > 0 ? (
          feed.map((item) => <FeedRow key={item.id} item={item} />)
        ) : (
          <div className="rounded-xl border border-zinc-200 bg-white px-4 py-4 text-sm text-zinc-600 shadow-sm">
            No activity yet.
          </div>
        )}
      </div>
    </div>
  );
}