type DayBucket = {
  key: string;
  label: string;
  calls: number;
  followups: number;
  replies: number;
};

function ChartBar({
  value,
  max,
  color
}: {
  value: number;
  max: number;
  color: string;
}) {
  const height = value > 0 ? Math.max((value / max) * 100, 10) : 0;

  return (
    <div
      className={`w-full max-w-4 rounded-t-md transition-all ${color}`}
      style={{ height: `${height}%` }}
      title={`${value}`}
    />
  );
}

export default function WeeklyActivityCard({ days }: { days: DayBucket[] }) {
  const max = Math.max(
    ...days.map((day) => Math.max(day.calls, day.followups, day.replies)),
    1
  );
  const isEmpty = days.every(
    (day) => day.calls === 0 && day.followups === 0 && day.replies === 0
  );

  return (
    <div className="flex h-full min-h-[430px] flex-col rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-sm font-medium text-zinc-900">Weekly activity</div>
          <div className="mt-1 text-sm leading-6 text-zinc-600">
            Calls, follow-ups, and replies across the last 7 days.
          </div>
        </div>
        <div className="shrink-0 whitespace-nowrap rounded-full bg-zinc-100 px-3 py-1.5 text-xs font-medium text-zinc-600">
          7 days
        </div>
      </div>

      <div className="mt-6 flex flex-1 flex-col">
        <div className="relative flex min-h-60 flex-1 items-end overflow-hidden rounded-xl border border-zinc-100 bg-zinc-50/60 px-3 pt-5">
          <div aria-hidden className="pointer-events-none absolute inset-x-3 top-1/4 border-t border-dashed border-zinc-200" />
          <div aria-hidden className="pointer-events-none absolute inset-x-3 top-1/2 border-t border-dashed border-zinc-200" />
          <div aria-hidden className="pointer-events-none absolute inset-x-3 top-3/4 border-t border-dashed border-zinc-200" />

          {isEmpty ? (
            <div className="absolute inset-0 flex items-center justify-center px-6 text-center">
              <div>
                <div className="text-sm font-medium text-zinc-700">No activity yet</div>
                <div className="mt-1 text-xs leading-5 text-zinc-500">
                  Your first captured call or reply will appear here.
                </div>
              </div>
            </div>
          ) : null}

          <div className="relative z-10 flex h-56 w-full items-end gap-2 sm:gap-4">
            {days.map((day) => (
              <div key={day.key} className="flex h-full min-w-0 flex-1 flex-col items-center justify-end gap-3">
                <div className="flex h-44 w-full items-end justify-center gap-1">
                  <ChartBar value={day.calls} max={max} color="bg-zinc-900" />
                  <ChartBar value={day.followups} max={max} color="bg-zinc-500" />
                  <ChartBar value={day.replies} max={max} color="bg-emerald-400" />
                </div>
                <div className="pb-3 text-[11px] font-medium text-zinc-500 sm:text-xs">
                  {day.label}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-5 flex flex-wrap justify-center gap-x-5 gap-y-2 text-xs text-zinc-500">
          <div className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm bg-zinc-900" />
            Calls
          </div>
          <div className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm bg-zinc-500" />
            Follow-ups
          </div>
          <div className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm bg-emerald-400" />
            Replies
          </div>
        </div>
      </div>
    </div>
  );
}
