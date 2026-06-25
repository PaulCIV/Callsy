import { useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { me } from "../api/auth";

export default function ProtectedRoute({
  children
}: {
  children: React.ReactNode;
}) {
  const [loading, setLoading] = useState(true);
  const [allowed, setAllowed] = useState(false);

  useEffect(() => {
    let mounted = true;

    async function checkAuth() {
      try {
        await me();
        if (mounted) setAllowed(true);
      } catch {
        if (mounted) setAllowed(false);
      } finally {
        if (mounted) setLoading(false);
      }
    }

    checkAuth();

    return () => {
      mounted = false;
    };
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-50">
        <div className="mx-auto max-w-6xl px-6 py-10">
          <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
            <div className="text-sm text-zinc-600">Loading session...</div>
          </div>
        </div>
      </div>
    );
  }

  if (!allowed) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}