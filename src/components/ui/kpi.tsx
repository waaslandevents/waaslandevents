import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

/** Kerncijfer in dashboards. Het getal is het belangrijkste, het label legt uit. */
export function Kpi({
  label,
  value,
  hint,
  emphasis,
  className,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  emphasis?: boolean;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-lg border p-5",
        emphasis ? "border-polder bg-polder text-white" : "border-line bg-surface",
        className,
      )}
    >
      <p className={cn("text-sm", emphasis ? "text-white/80" : "text-ink-muted")}>{label}</p>
      <p className={cn("mt-1 font-display text-3xl font-bold tabular-nums", emphasis ? "text-white" : "text-polder")}>
        {value}
      </p>
      {hint && <p className={cn("mt-1 text-sm", emphasis ? "text-white/80" : "text-ink-muted")}>{hint}</p>}
    </div>
  );
}
