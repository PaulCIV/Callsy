import React from "react";
import { ArrowRight, PhoneMissed, MessageSquareText, Calendar } from "lucide-react";
import { Link } from "react-router-dom";

export default function Landing() {
  return (
    <div className="min-h-screen bg-white">
      <div className="mx-auto max-w-6xl px-6 py-10">
        {/* Top bar */}
        <div className="flex items-center justify-between">
          <div className="text-3xl font-semibold tracking-tight text-zinc-900">
            Callsy
          </div>

          <div className="flex items-center gap-3">
            <Link
              to="/login"
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900"
            >
              Log in
            </Link>

            <Link
              to="/signup"
              className="inline-flex items-center rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-zinc-800"
            >
              Sign up
            </Link>
          </div>
        </div>

        {/* Hero */}
        <div className="mt-16 grid gap-10 md:grid-cols-2 md:items-center">
          <div>
            <div className="inline-flex items-center rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-600">
              Missed-call follow-up for appointment businesses
            </div>

            <h1 className="mt-4 text-4xl font-semibold tracking-tight text-zinc-900">
              Turn missed calls into booked appointments.
            </h1>

            <p className="mt-4 text-base leading-relaxed text-zinc-600">
              When you miss a call, Callsy instantly texts the caller so you don’t lose
              the lead. Add a booking link so they can schedule immediately.
            </p>

            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                to="/dashboard"
                className="inline-flex items-center gap-2 rounded-xl bg-zinc-900 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-zinc-800"
              >
                View demo dashboard <ArrowRight size={16} />
              </Link>

              <Link
                to="/explanation"
                className="inline-flex items-center gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-2 text-sm font-medium text-zinc-900 shadow-sm hover:bg-zinc-50"
              >
                How it works <ArrowRight size={16} />
              </Link>
            </div>

            <div className="mt-6 text-xs text-zinc-500">
              MVP: simple, fast, no nonsense.
            </div>
          </div>

          {/* Right-side demo card */}
          <div className="rounded-3xl border border-zinc-200 bg-zinc-50 p-6">
            <div className="text-sm font-medium text-zinc-900">Example follow-up</div>

            <div className="mt-3 rounded-2xl bg-white p-4 shadow-sm">
              <div className="text-xs text-zinc-500">Auto text</div>
              <div className="mt-2 text-sm leading-relaxed text-zinc-800">
                Sorry we missed your call — book here:{" "}
                <span className="underline">https://your-booking-link.com</span>
                <br />
                Reply STOP to opt out.
              </div>
            </div>

            <div className="mt-4 text-xs text-zinc-500">
              You already built the backend — this makes it visible.
            </div>
          </div>
        </div>

        {/* How it works */}
        <div id="how" className="mt-16 grid gap-4 md:grid-cols-3">
          <Feature
            icon={<PhoneMissed size={18} />}
            title="Customer calls"
            text="They call your business like normal."
          />
          <Feature
            icon={<MessageSquareText size={18} />}
            title="You miss it"
            text="Forward missed calls to Callsy using your carrier’s forwarding feature."
          />
          <Feature
            icon={<Calendar size={18} />}
            title="Callsy follows up"
            text="Instant text-back, optionally with a booking link."
          />
        </div>

        {/* Footer */}
        <div className="mt-16 border-t border-zinc-200 pt-8 text-xs text-zinc-500">
          © {new Date().getFullYear()} Callsy
        </div>
      </div>
    </div>
  );
}

function Feature({
  icon,
  title,
  text
}: {
  icon: React.ReactNode;
  title: string;
  text: string;
}) {
  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
      <div className="flex items-center gap-2 text-sm font-medium text-zinc-900">
        <span className="inline-flex h-8 w-8 items-center justify-center rounded-xl bg-zinc-900 text-white">
          {icon}
        </span>
        {title}
      </div>
      <p className="mt-3 text-sm leading-relaxed text-zinc-600">{text}</p>
    </div>
  );
}