import { Link } from "react-router-dom";
import { PhoneMissed, MessageSquareText, Calendar, ArrowRight } from "lucide-react";

export default function Explanation() {
  return (
    <div className="min-h-screen bg-white">
      <div className="mx-auto max-w-4xl px-6 py-12">

        {/* Top bar */}
        <div className="flex items-center justify-between">
          <div className="text-2xl font-semibold tracking-tight text-zinc-900">
            How Callsy Works
          </div>
          <Link
            to="/"
            className="text-sm font-medium text-zinc-600 hover:text-zinc-900"
          >
            Back to Landing
          </Link>
        </div>

        {/* Intro */}
        <div className="mt-8 text-zinc-600 leading-relaxed">
          Callsy captures missed calls and gives callers a fast way to request a text.
          No replacement phone system—just a clear handoff into follow-up.
        </div>

        {/* Steps */}
        <div className="mt-12 space-y-10">

          <Step
            icon={<PhoneMissed size={20} />}
            title="1. A customer calls your business"
            text="They dial your regular business number like normal."
          />

          <Step
            icon={<MessageSquareText size={20} />}
            title="2. You miss the call"
            text="Instead of losing that lead, Callsy detects the missed call through call forwarding."
          />

          <Step
            icon={<Calendar size={20} />}
            title="3. The caller requests a text"
            text="Callsy asks them to press 1 or say yes. After consent is recorded, the professional follow-up is sent immediately."
          />

        </div>

        {/* Why it matters */}
        <div className="mt-16 rounded-2xl border border-zinc-200 bg-zinc-50 p-6">
          <div className="text-lg font-semibold text-zinc-900">
            Why this matters
          </div>
          <div className="mt-4 space-y-3 text-zinc-600 text-sm leading-relaxed">
            <p>
              Most customers won’t call twice. If you miss the call, the lead is gone.
            </p>
            <p>
              Callsy gives that caller a quick path into text follow-up while recording their choice.
            </p>
            <p>
              You stay focused on running your business while Callsy handles follow-up.
            </p>
          </div>

          <Link
            to="/dashboard"
            className="mt-6 inline-flex items-center gap-2 rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-zinc-800"
          >
            View demo dashboard <ArrowRight size={16} />
          </Link>
        </div>

      </div>
    </div>
  );
}

function Step({
  icon,
  title,
  text
}: {
  icon: React.ReactNode;
  title: string;
  text: string;
}) {
  return (
    <div className="flex items-start gap-4">
      <div className="inline-flex h-10 w-10 items-center justify-center rounded-xl bg-zinc-900 text-white">
        {icon}
      </div>
      <div>
        <div className="text-base font-medium text-zinc-900">{title}</div>
        <div className="mt-2 text-sm text-zinc-600 leading-relaxed">
          {text}
        </div>
      </div>
    </div>
  );
}
