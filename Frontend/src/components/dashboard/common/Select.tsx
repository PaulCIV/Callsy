type SelectOption = {
    value: string;
    label: string;
  };
  
  type SelectProps = {
    value: string;
    onChange: (v: string) => void;
    options: SelectOption[];
  };
  
  export default function Select({
    value,
    onChange,
    options
  }: SelectProps) {
    return (
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-zinc-900/10"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    );
  }