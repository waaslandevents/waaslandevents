import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import type { Tone } from "@/lib/status";

const tones: Record<Tone, string> = {
  neutral: "bg-line/60 text-ink-muted",
  info: "bg-info-soft text-info",
  warn: "bg-warn-soft text-warn",
  ok: "bg-ok-soft text-ok",
  bad: "bg-bad-soft text-bad",
  brand: "bg-polder text-white",
};

/** Statuslabel voor leads, commissies, leveranciers. Kleur is nooit de enige drager: er staat altijd tekst. */
export function StatusPill({ tone, children, className }: { tone: Tone; children: ReactNode; className?: string }) {
  return (
    <span className={cn("inline-flex items-center rounded-sm px-2 py-0.5 text-xs font-semibold", tones[tone], className)}>
      {children}
    </span>
  );
}

export function StatusFor<T extends Record<string, { label: string; tone: Tone }>>({
  map,
  value,
}: {
  map: T;
  value: keyof T;
}) {
  const meta = map[value];
  return <StatusPill tone={meta?.tone ?? "neutral"}>{meta?.label ?? String(value)}</StatusPill>;
}
