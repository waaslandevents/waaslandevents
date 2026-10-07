/**
 * Eén bron voor statuslabels en -tonen. Waarden = Postgres-enums.
 * Tonen: neutral | info | warn | ok | bad | brand
 */
export type Tone = "neutral" | "info" | "warn" | "ok" | "bad" | "brand";
type Meta = { label: string; tone: Tone };

export const LEAD_STATUS = {
  nieuw: { label: "Nieuw", tone: "brand" },
  contact_opgenomen: { label: "Contact opgenomen", tone: "info" },
  offerte_voorbereiding: { label: "Offerte in voorbereiding", tone: "info" },
  offerte_verstuurd: { label: "Offerte verstuurd", tone: "info" },
  onderhandeling: { label: "In onderhandeling", tone: "warn" },
  gewonnen: { label: "Gewonnen", tone: "ok" },
  verloren: { label: "Verloren", tone: "neutral" },
  event_gepland: { label: "Event gepland", tone: "ok" },
  event_afgerond: { label: "Event afgerond", tone: "warn" },
  omzet_geregistreerd: { label: "Omzet geregistreerd", tone: "ok" },
} as const satisfies Record<string, Meta>;

export const COMMISSION_STATUS = {
  nog_niet_verschuldigd: { label: "Nog niet verschuldigd", tone: "neutral" },
  wacht_op_event: { label: "Wacht op event", tone: "neutral" },
  omzet_opvragen: { label: "Omzet bevestigen", tone: "warn" },
  omzet_bevestigd: { label: "Omzet bevestigd", tone: "info" },
  commissie_berekend: { label: "Commissie berekend", tone: "info" },
  factuur_opgesteld: { label: "Gefactureerd", tone: "brand" },
  betaald: { label: "Betaald", tone: "ok" },
  betwist: { label: "Betwist", tone: "bad" },
  gecrediteerd: { label: "Gecrediteerd", tone: "neutral" },
  vervallen: { label: "Geen commissie", tone: "neutral" },
} as const satisfies Record<string, Meta>;

export const SUPPLIER_STATUS = {
  concept: { label: "Concept", tone: "neutral" },
  aanvraag_ontvangen: { label: "Aanvraag ontvangen", tone: "info" },
  in_controle: { label: "In controle", tone: "info" },
  info_nodig: { label: "Aanvullende info nodig", tone: "warn" },
  goedgekeurd: { label: "Goedgekeurd", tone: "ok" },
  actief: { label: "Actief", tone: "ok" },
  tijdelijk_verborgen: { label: "Tijdelijk verborgen", tone: "warn" },
  afgewezen: { label: "Afgewezen", tone: "bad" },
  gedeactiveerd: { label: "Gedeactiveerd", tone: "neutral" },
} as const satisfies Record<string, Meta>;

export const REQUEST_STATUS = {
  nieuw: { label: "Nieuw", tone: "brand" },
  in_behandeling: { label: "In behandeling", tone: "info" },
  info_nodig: { label: "Vraag aan klant", tone: "warn" },
  gematcht: { label: "Gematcht", tone: "ok" },
  afgesloten: { label: "Afgesloten", tone: "neutral" },
  geannuleerd: { label: "Geannuleerd", tone: "neutral" },
  spam: { label: "Spam", tone: "bad" },
} as const satisfies Record<string, Meta>;

export const PRODUCT_STATUS = {
  draft: { label: "Concept", tone: "neutral" },
  pending_review: { label: "Wacht op controle", tone: "warn" },
  approved: { label: "Goedgekeurd", tone: "ok" },
  rejected: { label: "Afgekeurd", tone: "bad" },
  archived: { label: "Gearchiveerd", tone: "neutral" },
} as const satisfies Record<string, Meta>;

export type LeadStatus = keyof typeof LEAD_STATUS;
export type CommissionStatus = keyof typeof COMMISSION_STATUS;
export type SupplierStatus = keyof typeof SUPPLIER_STATUS;
export type RequestStatus = keyof typeof REQUEST_STATUS;
export type ProductStatus = keyof typeof PRODUCT_STATUS;
