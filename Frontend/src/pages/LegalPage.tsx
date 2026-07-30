import { ArrowLeft } from "lucide-react";
import { Link } from "react-router-dom";

export function LegalPage({
  title,
  updated,
  children
}: {
  title: string;
  updated: string;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-zinc-50 px-5 py-10 text-zinc-800">
      <article className="mx-auto max-w-3xl rounded-3xl border border-zinc-200 bg-white px-6 py-8 shadow-sm md:px-10 md:py-12">
        <Link to="/" className="inline-flex items-center gap-2 text-sm font-medium text-zinc-600 hover:text-zinc-950">
          <ArrowLeft size={16} /> Back to Callsy
        </Link>
        <h1 className="mt-8 text-3xl font-semibold tracking-tight text-zinc-950">{title}</h1>
        <p className="mt-2 text-sm text-zinc-500">Last updated: {updated}</p>
        <div className="prose-legal mt-10 space-y-8 text-sm leading-7 text-zinc-700">{children}</div>
      </article>
    </main>
  );
}

export function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="text-lg font-semibold text-zinc-950">{title}</h2>
      <div className="mt-3 space-y-3">{children}</div>
    </section>
  );
}
