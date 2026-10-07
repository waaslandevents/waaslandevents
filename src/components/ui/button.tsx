import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";
import { cn } from "@/lib/cn";

/**
 * primary   → feest-geel. Eén per scherm: "Start je aanvraag" (spec §43).
 * secondary → polder-groen, voor de tweede route ("Ik weet wat ik zoek").
 * outline   → rustige actie in formulieren en dashboards.
 * ghost     → tertiaire acties (annuleren, terug).
 */
type Variant = "primary" | "secondary" | "outline" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

const base =
  "inline-flex items-center justify-center gap-2 rounded-md font-semibold transition-colors duration-150 " +
  "disabled:cursor-not-allowed disabled:opacity-50 select-none whitespace-nowrap";

const variants: Record<Variant, string> = {
  primary: "bg-feest text-ink hover:bg-feest-strong",
  secondary: "bg-polder text-white hover:bg-polder-strong",
  outline: "border border-line-strong bg-surface text-polder hover:border-polder hover:bg-polder-soft/40",
  ghost: "text-polder hover:bg-polder-soft/60",
  danger: "bg-bad text-white hover:brightness-95",
};

const sizes: Record<Size, string> = {
  sm: "h-9 px-3.5 text-sm",
  md: "h-11 px-5 text-base",
  lg: "h-14 px-7 text-lg",
};

type Common = { variant?: Variant; size?: Size; className?: string; children: ReactNode };

export function buttonClasses({ variant = "primary", size = "md", className }: Omit<Common, "children">) {
  return cn(base, variants[variant], sizes[size], className);
}

export function Button({ variant, size, className, ...props }: Common & ComponentProps<"button">) {
  return <button className={buttonClasses({ variant, size, className })} {...props} />;
}

export function ButtonLink({ variant, size, className, ...props }: Common & ComponentProps<typeof Link>) {
  return <Link className={buttonClasses({ variant, size, className })} {...props} />;
}
