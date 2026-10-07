import type { Metadata } from "next";
import { Button, ButtonLink, Container, EmptyState, Kpi, PartnerBadge, StatusFor } from "@/components/ui";
import { COMMISSION_STATUS, LEAD_STATUS, SUPPLIER_STATUS } from "@/lib/status";
import { formatEuro, formatEuroRound, formatPrice, PRICE_DISCLAIMER } from "@/lib/format";
import { FormDemo } from "./form-demo";

export const metadata: Metadata = {
  title: "Design system",
  robots: { index: false, follow: false },
};

const SWATCHES = [
  ["polder", "#0f4a45", "Merk, koppen, navigatie"],
  ["feest", "#f5b82e", "Enkel de hoofdactie"],
  ["ink", "#172321", "Lopende tekst"],
  ["ink-muted", "#55625e", "Secundaire tekst"],
  ["paper", "#f7f8f5", "Paginagrond"],
  ["line", "#d9e1dd", "Randen"],
] as const;

export default function DesignSystemPage() {
  return (
    <Container className="space-y-16 py-14">
      <header>
        <h1 className="text-4xl">Design system</h1>
        <p className="mt-3 max-w-[62ch] text-lg text-ink-muted">
          Interne referentie voor WaaslandEvents. Feest-geel is voorbehouden aan één actie per scherm: Start je aanvraag.
        </p>
      </header>

      <section className="space-y-5">
        <h2 className="text-2xl">Kleur</h2>
        <ul className="grid gap-4 sm:grid-cols-3 lg:grid-cols-6">
          {SWATCHES.map(([name, hex, use]) => (
            <li key={name}>
              <div className="h-20 rounded-lg border border-line" style={{ background: hex }} />
              <p className="mt-2 font-semibold">{name}</p>
              <p className="text-sm text-ink-muted">
                {hex} · {use}
              </p>
            </li>
          ))}
        </ul>
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Typografie</h2>
        <p className="font-display text-5xl font-bold text-polder">Alles voor jouw event.</p>
        <p className="font-display text-3xl font-bold text-polder">Bricolage Grotesque voor koppen</p>
        <p className="max-w-[62ch]">
          Instrument Sans voor lopende tekst en formulieren. Regellengte blijft onder de 75 tekens, zodat ook lange
          uitleg over voorwaarden en commissie prettig leest.
        </p>
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Knoppen</h2>
        <div className="flex flex-wrap items-center gap-3">
          <ButtonLink href="/aanvraag">Start je aanvraag</ButtonLink>
          <ButtonLink href="/categorieen" variant="secondary">
            Ik weet wat ik zoek
          </ButtonLink>
          <Button variant="outline">Opslaan</Button>
          <Button variant="ghost">Annuleren</Button>
          <Button variant="danger">Leverancier deactiveren</Button>
          <Button disabled>Niet beschikbaar</Button>
        </div>
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Statussen</h2>
        <div className="space-y-3">
          {[LEAD_STATUS, COMMISSION_STATUS, SUPPLIER_STATUS].map((map, i) => (
            <div key={i} className="flex flex-wrap gap-2">
              {Object.keys(map).map((k) => (
                <StatusFor key={k} map={map} value={k as keyof typeof map} />
              ))}
            </div>
          ))}
        </div>
        <PartnerBadge />
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Cijfers</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi label="Nieuwe leads" value="3" />
          <Kpi label="Gewonnen opdrachten" value="8" />
          <Kpi label="Omzet via WaaslandEvents" value={formatEuroRound(12450)} />
          <Kpi label="Openstaande commissie" value={formatEuro(1556.25)} hint="12,5% van de netto omzet" emphasis />
        </div>
        <p className="text-sm text-ink-muted">
          Prijzen: {formatPrice({ price_type: "vanaf", price_from: 299, price_to: null })} ·{" "}
          {formatPrice({ price_type: "range", price_from: 90, price_to: 2500 })} ·{" "}
          {formatPrice({ price_type: "op_aanvraag", price_from: null, price_to: null })}. {PRICE_DISCLAIMER}
        </p>
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Formulier en voortgang</h2>
        <FormDemo />
      </section>

      <section className="space-y-5">
        <h2 className="text-2xl">Leeg scherm</h2>
        <EmptyState
          title="Nog geen leads"
          action={
            <ButtonLink href="/partner/profiel" variant="outline">
              Werkgebied aanvullen
            </ButtonLink>
          }
        >
          Zodra een aanvraag bij je aanbod en werkgebied past, verschijnt ze hier. Een volledig werkgebied helpt ons je
          sneller te koppelen.
        </EmptyState>
      </section>
    </Container>
  );
}
