type InputProps = {
    value: string;
    onChange: (v: string) => void;
    placeholder?: string;
  };
  
  export default function Input({
    value,
    onChange,
    placeholder
  }: InputProps) {
    return (
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-zinc-900/10"
      />
    );
  }