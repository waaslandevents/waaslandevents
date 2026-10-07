const euro = new Intl.NumberFormat("nl-BE", { style: "currency", currency: "EUR" });
const euroRound = new Intl.NumberFormat("nl-BE", { style: "currency", currency: "EUR", maximumFractionDigits: 0 });
const dateLong = new Intl.DateTimeFormat("nl-BE", { day: "numeric", month: "long", year: "numeric" });
const dateShort = new Intl.DateTimeFormat("nl-BE", { day: "2-digit", month: "2-digit", year: "numeric" });

/** € 1.250,00 */
export const formatEuro = (n: number | null | undefined) => (n == null ? "—" : euro.format(n));
/** € 1.250 — voor vanaf-prijzen en KPI's */
export const formatEuroRound = (n: number | null | undefined) => (n == null ? "—" : euroRound.format(n));
/** 15 juni 2027 */
export const formatDate = (d: string | Date | null | undefined) => (d ? dateLong.format(new Date(d)) : "—");
/** 15/06/2027 */
export const formatDateShort = (d: string | Date | null | undefined) => (d ? dateShort.format(new Date(d)) : "—");

export type PriceInfo = {
  price_type: "vanaf" | "range" | "op_aanvraag";
  price_from: number | null;
  price_to: number | null;
};

/** "vanaf € 299", "€ 90 – € 2.500" of "Prijs op aanvraag" */
export function formatPrice(p: PriceInfo) {
  if (p.price_type === "vanaf" && p.price_from != null) return `vanaf ${formatEuroRound(p.price_from)}`;
  if (p.price_type === "range" && p.price_from != null && p.price_to != null)
    return `${formatEuroRound(p.price_from)} – ${formatEuroRound(p.price_to)}`;
  return "Prijs op aanvraag";
}

export const PRICE_DISCLAIMER =
  "Vanaf-prijzen zijn indicatief. De uiteindelijke prijs hangt onder meer af van datum, locatie, duur, type product en je extra wensen.";
