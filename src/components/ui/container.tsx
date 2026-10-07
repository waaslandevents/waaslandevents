import type { ComponentProps } from "react";
import { cn } from "@/lib/cn";

export function Container({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8", className)} {...props} />;
}

/** Paginasectie met consistente verticale ritmiek. */
export function Section({
  className,
  tone = "paper",
  ...props
}: ComponentProps<"section"> & { tone?: "paper" | "surface" | "polder" }) {
  const tones = {
    paper: "",
    surface: "bg-surface",
    polder: "bg-polder text-white [&_h2]:text-white [&_h3]:text-white",
  };
  return <section className={cn("py-16 sm:py-24", tones[tone], className)} {...props} />;
}
