import { Link } from "react-router-dom";

export default function AuthShell({
  title,
  subtitle,
  children,
  footer
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-zinc-50">
      <div className="mx-auto flex min-h-screen max-w-6xl items-center justify-center px-6 py-10">
        <div className="grid w-full max-w-5xl gap-8 md:grid-cols-2">
          {/* Left side */}
          <div className="hidden rounded-3xl border border-zinc-200 bg-white p-10 shadow-sm md:block">
            <Link
              to="/"
              className="text-sm font-semibold tracking-tight text-zinc-900"
            >
              Callsy
            </Link>

            <div className="mt-16">
              <div className="inline-flex items-center rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-600">
                Missed-call follow-up
              </div>

              <h1 className="mt-4 text-4xl font-semibold tracking-tight text-zinc-900">
                Recover missed calls automatically.
              </h1>

              <p className="mt-4 max-w-md text-sm leading-relaxed text-zinc-600">
                Clean, simple follow-up for appointment businesses. Text customers
                back when calls are missed and keep everything visible in one place.
              </p>
            </div>
          </div>

          {/* Right side */}
          <div className="rounded-3xl border border-zinc-200 bg-white p-8 shadow-sm">
            <Link
              to="/"
              className="text-sm font-semibold tracking-tight text-zinc-900 md:hidden"
            >
              Callsy
            </Link>

            <div className="mt-6">
              <h2 className="text-2xl font-semibold tracking-tight text-zinc-900">
                {title}
              </h2>
              <p className="mt-2 text-sm text-zinc-600">{subtitle}</p>
            </div>

            <div className="mt-8">{children}</div>

            {footer ? <div className="mt-6">{footer}</div> : null}
          </div>
        </div>
      </div>
    </div>
  );
}