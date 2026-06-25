import { Activity, MessageSquareText, PhoneMissed } from "lucide-react";

type Stat = {
  label: string;
  value: string;
  hint?: string;
  icon: "call" | "sms" | "reply";
  trend: number[];
};

function getStatIcon(icon: Stat["icon"]) {
  if (icon === "call") return <PhoneMissed size={18} />;
  if (icon === "sms") return <MessageSquareText size={18} />;
  return <Activity size={18} />;
}

function MiniBars({ values }: { values: number[] }) {
  const max = Math.max(...values, 1);

  return (
    <div className="flex h-16 items-end gap-2">
      {values.map((value, index) => {
        const height = Math.max((value / max) * 100, value > 0 ? 18 : 8);
        return (
          <div key={index} className="flex flex-1 flex-col items-center justify-end gap-2">
            <div
              className="w-full rounded-md bg-zinc-900/85"
              style={{ height: `${height}%` }}
              title={`${value}`}
            />
          </div>
        );
      })}
    </div>
  );
}

export default function StatCard({ stat }: { stat: Stat }) {
  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm text-zinc-500">{stat.label}</div>
          <div className="mt-2 text-3xl font-semibold text-zinc-900">{stat.value}</div>
          {stat.hint ? <div className="mt-2 text-xs text-zinc-500">{stat.hint}</div> : null}
        </div>

        <div className="inline-flex h-10 w-10 items-center justify-center rounded-xl bg-zinc-900 text-white">
          {getStatIcon(stat.icon)}
        </div>
      </div>

      <div className="mt-5">
        <MiniBars values={stat.trend} />
      </div>

      <div className="mt-2 text-[11px] text-zinc-400">Last 7 days</div>
    </div>
  );
}