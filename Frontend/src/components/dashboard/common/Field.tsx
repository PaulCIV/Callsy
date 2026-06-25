import React from "react";

type FieldProps = {
  label: string;
  children: React.ReactNode;
};

export default function Field({ label, children }: FieldProps) {
  return (
    <label className="block">
      <div className="text-sm font-medium text-zinc-900">{label}</div>
      <div className="mt-2">{children}</div>
    </label>
  );
}