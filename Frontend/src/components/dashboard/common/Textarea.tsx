type TextareaProps = {
    value: string;
    onChange: (v: string) => void;
    placeholder?: string;
    rows?: number;
  };
  
  export default function Textarea({
    value,
    onChange,
    placeholder,
    rows = 5
  }: TextareaProps) {
    return (
      <textarea
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        rows={rows}
        className="w-full rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-zinc-900/10"
      />
    );
  }