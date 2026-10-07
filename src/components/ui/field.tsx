"use client";

import type { ComponentProps, ReactNode } from "react";
import { useId } from "react";
import { cn } from "@/lib/cn";

/**
 * Formuliervelden: label altijd zichtbaar, hint en fout gekoppeld via
 * aria-describedby, foutmelding zegt wat er mis is en hoe je het oplost.
 */
const control =
  "block w-full rounded-sm border border-line-strong bg-surface px-3.5 py-2.5 text-base text-ink " +
  "placeholder:text-ink-muted/70 transition-colors hover:border-polder/60 " +
  "focus:border-polder focus:outline-none focus:ring-2 focus:ring-polder/25 " +
  "aria-[invalid=true]:border-bad aria-[invalid=true]:ring-bad/20 disabled:bg-paper";

type FieldProps = {
  label: ReactNode;
  hint?: ReactNode;
  error?: string;
  optional?: boolean;
  children: (ids: { id: string; describedBy?: string; invalid: boolean }) => ReactNode;
  className?: string;
};

export function Field({ label, hint, error, optional, children, className }: FieldProps) {
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  const describedBy = [hintId, errorId].filter(Boolean).join(" ") || undefined;
  return (
    <div className={cn("space-y-1.5", className)}>
      <label htmlFor={id} className="block text-sm font-semibold text-ink">
        {label}
        {optional && <span className="ml-1.5 font-normal text-ink-muted">(optioneel)</span>}
      </label>
      {hint && (
        <p id={hintId} className="text-sm text-ink-muted">
          {hint}
        </p>
      )}
      {children({ id, describedBy, invalid: Boolean(error) })}
      {error && (
        <p id={errorId} role="alert" className="text-sm font-medium text-bad">
          {error}
        </p>
      )}
    </div>
  );
}

export function Input({ className, ...props }: ComponentProps<"input">) {
  return <input className={cn(control, className)} {...props} />;
}

export function Textarea({ className, ...props }: ComponentProps<"textarea">) {
  return <textarea className={cn(control, "min-h-32", className)} {...props} />;
}

export function Select({ className, ...props }: ComponentProps<"select">) {
  return <select className={cn(control, "select-chevron appearance-none pr-10", className)} {...props} />;
}

/**
 * Keuzechip: een echte radio of checkbox, visueel als chip.
 * Gebruikt in de aanvraagwizard (eventtype, categorieën).
 */
export function ChoiceChip({
  type = "checkbox",
  label,
  description,
  className,
  ...props
}: Omit<ComponentProps<"input">, "type"> & { type?: "checkbox" | "radio"; label: ReactNode; description?: ReactNode }) {
  return (
    <label
      className={cn(
        "group relative flex cursor-pointer items-start gap-3 rounded-lg border border-line-strong bg-surface px-4 py-3",
        "transition-colors hover:border-polder has-[:checked]:border-polder has-[:checked]:bg-polder-soft",
        "has-[:focus-visible]:outline has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-polder",
        className,
      )}
    >
      <input type={type} className="peer sr-only" {...props} />
      <span
        aria-hidden
        className={cn(
          "mt-0.5 grid size-5 shrink-0 place-items-center border-2 border-line-strong bg-surface text-white",
          "peer-checked:border-polder peer-checked:bg-polder",
          type === "radio" ? "rounded-full" : "rounded-[5px]",
        )}
      >
        <svg viewBox="0 0 16 16" className="size-3 opacity-0 group-has-[:checked]:opacity-100" fill="none" stroke="currentColor" strokeWidth="2.6">
          <path d="M3 8.5l3 3 7-7" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </span>
      <span className="min-w-0">
        <span className="block font-semibold text-ink">{label}</span>
        {description && <span className="mt-0.5 block text-sm text-ink-muted">{description}</span>}
      </span>
    </label>
  );
}
