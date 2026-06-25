type ToggleRowProps = {
    title: string;
    description: string;
    checked: boolean;
    onChange: (checked: boolean) => void;
    disabled?: boolean;
  };
  
  export default function ToggleRow({
    title,
    description,
    checked,
    onChange,
    disabled
  }: ToggleRowProps) {
    return (
      <div className="flex items-start justify-between gap-4 rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-4">
        <div className="min-w-0">
          <div className="text-sm font-medium text-zinc-900">{title}</div>
          <div className="mt-1 text-sm text-zinc-600">{description}</div>
        </div>
  
        <button
          type="button"
          disabled={disabled}
          onClick={() => onChange(!checked)}
          className={[
            "relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition",
            checked ? "bg-zinc-900" : "bg-zinc-300",
            disabled ? "cursor-not-allowed opacity-50" : ""
          ].join(" ")}
        >
          <span
            className={[
              "inline-block h-5 w-5 transform rounded-full bg-white transition",
              checked ? "translate-x-6" : "translate-x-1"
            ].join(" ")}
          />
        </button>
      </div>
    );
  }