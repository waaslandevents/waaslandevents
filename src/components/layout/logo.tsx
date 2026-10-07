import Link from "next/link";

/** Woordmerk + vlaggetje (feestslinger). Tijdelijk tot er een definitief logo is. */
export function Logo({ inverse = false }: { inverse?: boolean }) {
  return (
    <Link href="/" className="group inline-flex items-center gap-2.5" aria-label="WaaslandEvents, naar de homepage">
      <svg aria-hidden viewBox="0 0 32 32" className="size-8 shrink-0">
        <rect width="32" height="32" rx="8" fill={inverse ? "#ffffff" : "var(--color-polder)"} />
        <path d="M7 10h18l-9 13z" fill="var(--color-feest)" />
        <path d="M7 10h18" stroke={inverse ? "var(--color-polder)" : "#ffffff"} strokeWidth="2" strokeLinecap="round" />
      </svg>
      <span
        className={`font-display text-xl font-bold tracking-tight ${inverse ? "text-white" : "text-polder"}`}
      >
        WaaslandEvents
      </span>
    </Link>
  );
}
