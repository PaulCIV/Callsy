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
    color = "bg-zinc-300"
  }: {
    value: number;
    max: number;
    color?: string;
  }) {
    const height = value > 0 ? Math.max((value / max) * 100, 10) : 4;
  
    return (
      <div
        className={`w-full max-w-4 rounded-md ${color}`}
        style={{ height: `${height}%` }}
      />
    );
  }
  
  export default function WeeklyActivityCard({ days }: { days: DayBucket[] }) {
    const max = Math.max(
      ...days.map((day) => Math.max(day.calls, day.followups, day.replies)),
      1
    );
  
    return (
      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div>
          <div className="text-sm font-medium text-zinc-900">Weekly activity</div>
          <div className="mt-1 text-sm text-zinc-600">
            Calls, follow-ups, and replies across the last 7 days.
          </div>
        </div>
  
        <div className="mt-6">
          <div className="flex h-56 items-end gap-4">
            {days.map((day) => (
              <div key={day.key} className="flex flex-1 flex-col items-center gap-3">
                <div className="flex h-44 w-full items-end justify-center gap-1">
                  <ChartBar value={day.calls} max={max} color="bg-zinc-900" />
                  <ChartBar value={day.followups} max={max} color="bg-zinc-500" />
                  <ChartBar value={day.replies} max={max} color="bg-zinc-300" />
                </div>
                <div className="text-xs text-zinc-500">{day.label}</div>
              </div>
            ))}
          </div>
  
          <div className="mt-5 flex flex-wrap gap-4 text-xs text-zinc-500">
            <div className="flex items-center gap-2">
              <span className="inline-block h-3 w-3 rounded-sm bg-zinc-900" />
              Calls
            </div>
            <div className="flex items-center gap-2">
              <span className="inline-block h-3 w-3 rounded-sm bg-zinc-500" />
              Follow-ups
            </div>
            <div className="flex items-center gap-2">
              <span className="inline-block h-3 w-3 rounded-sm bg-zinc-300" />
              Replies
            </div>
          </div>
        </div>
      </div>
    );
  }