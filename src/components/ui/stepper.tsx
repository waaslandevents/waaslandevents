import { cn } from "@/lib/cn";

/**
 * Voortgang in de aanvraagwizard. Op mobiel enkel "Stap 3 van 8" + balk,
 * op desktop de volledige lijst. De nummering is hier terecht: het is
 * een echte volgorde.
 */
export function Stepper({ steps, current }: { steps: string[]; current: number }) {
  const pct = Math.round(((current + 1) / steps.length) * 100);
  return (
    <nav aria-label="Voortgang van je aanvraag">
      <div className="flex items-baseline justify-between text-sm sm:hidden">
        <span className="font-semibold text-polder">{steps[current]}</span>
        <span className="text-ink-muted">
          Stap {current + 1} van {steps.length}
        </span>
      </div>
      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-line sm:hidden" aria-hidden>
        <div className="h-full rounded-full bg-polder transition-[width] duration-300" style={{ width: `${pct}%` }} />
      </div>
      <ol className="hidden gap-1 sm:flex">
        {steps.map((label, i) => (
          <li key={label} className="flex-1" aria-current={i === current ? "step" : undefined}>
            <div className={cn("h-1.5 rounded-full", i <= current ? "bg-polder" : "bg-line")} />
            <span
              className={cn(
                "mt-2 block text-xs",
                i === current ? "font-semibold text-polder" : i < current ? "text-ink" : "text-ink-muted",
              )}
            >
              {i + 1}. {label}
            </span>
          </li>
        ))}
      </ol>
    </nav>
  );
}
