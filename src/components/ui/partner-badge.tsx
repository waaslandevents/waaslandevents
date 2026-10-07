/**
 * ✓ WaaslandEvents Partner (spec §24). De title-tekst maakt duidelijk dat het
 * een controle van gegevens is, geen kwaliteitsgarantie.
 */
export function PartnerBadge() {
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full border border-polder/25 bg-polder-soft px-2.5 py-1 text-xs font-semibold text-polder"
      title="Bedrijfsgegevens en aanbod zijn door WaaslandEvents gecontroleerd. Dit is geen kwaliteitsgarantie of certificering."
    >
      <svg aria-hidden viewBox="0 0 16 16" className="size-3.5" fill="none" stroke="currentColor" strokeWidth="2.2">
        <path d="M3 8.5l3 3 7-7" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      WaaslandEvents Partner
    </span>
  );
}
