import Link from "next/link";
import { ButtonLink, Container, Section } from "@/components/ui";
import { getCategoryTree, getEventTypes } from "@/lib/catalog";
import { home } from "@/content/home";

export default function HomePage() {
  return (
    <>
      <Hero />
      <Steps />
      <Categories />
      <Audiences />
      <Why />
      <ForSuppliers />
      <Closing />
    </>
  );
}

async function Hero() {
  const eventTypes = await getEventTypes();
  return (
    <section className="relative overflow-hidden border-b border-line">
      {/* Polderlandschap: rustige horizontale lijnen als verwijzing naar de Waaslandse velden */}
      <svg aria-hidden className="pointer-events-none absolute inset-x-0 bottom-0 h-40 w-full text-polder/[0.07]" preserveAspectRatio="none" viewBox="0 0 1200 160">
        {Array.from({ length: 9 }, (_, i) => (
          <path key={i} d={`M0 ${40 + i * 14} C 300 ${30 + i * 15}, 900 ${55 + i * 13}, 1200 ${38 + i * 15}`} stroke="currentColor" strokeWidth="2" fill="none" />
        ))}
      </svg>
      <Container className="relative grid gap-12 pb-20 pt-12 sm:pt-20 lg:grid-cols-12 lg:gap-10 lg:pb-28">
        <div className="lg:col-span-7">
          <h1 className="max-w-[14ch] text-4xl sm:text-5xl lg:text-[5.25rem] lg:leading-[0.95]">{home.hero.title}</h1>
          <p className="mt-6 max-w-[58ch] text-lg text-ink-muted">{home.hero.lead}</p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <ButtonLink href="/aanvraag" size="lg">
              {home.hero.primary}
            </ButtonLink>
            <ButtonLink href="/categorieen" size="lg" variant="outline">
              {home.hero.secondary}
            </ButtonLink>
          </div>
        </div>

        <div className="lg:col-span-5 lg:pt-3">
          <div className="rounded-lg border border-line bg-surface p-5 shadow-raise sm:p-7">
            <h2 className="text-2xl">{home.hero.pickerTitle}</h2>
            <p className="mt-1 text-sm text-ink-muted">{home.hero.pickerHint}</p>
            {eventTypes.length > 0 ? (
              <ul className="mt-5 flex flex-wrap gap-2">
                {eventTypes.map((et, i) => (
                  <li key={et.id} className="chip-in" style={{ ["--i" as string]: i }}>
                    <Link
                      href={`/aanvraag?type=${et.slug}`}
                      className="inline-flex items-center rounded-full border border-line-strong bg-paper px-3.5 py-2 text-[0.95rem] font-medium text-ink transition-colors hover:border-polder hover:bg-polder hover:text-white"
                    >
                      {et.name}
                    </Link>
                  </li>
                ))}
                <li className="chip-in" style={{ ["--i" as string]: eventTypes.length }}>
                  <Link
                    href="/aanvraag?type=andere"
                    className="inline-flex items-center rounded-full border border-dashed border-line-strong px-3.5 py-2 text-[0.95rem] font-medium text-ink-muted hover:border-polder hover:text-polder"
                  >
                    Iets anders
                  </Link>
                </li>
              </ul>
            ) : (
              <p className="mt-5 text-ink-muted">
                Start je aanvraag en vertel ons in een paar stappen wat je plant.
              </p>
            )}
          </div>
        </div>
      </Container>
    </section>
  );
}

function Steps() {
  return (
    <Section>
      <Container>
        <h2 className="text-3xl sm:text-4xl">{home.steps.title}</h2>
        <ol className="mt-10 grid gap-10 md:grid-cols-3 md:gap-8">
          {home.steps.items.map((step, i) => (
            <li key={step.title} className="relative border-t-2 border-polder pt-5">
              <span className="font-display text-5xl font-bold leading-none text-feest-strong" aria-hidden>
                {i + 1}
              </span>
              <h3 className="mt-4 text-xl">{step.title}</h3>
              <p className="mt-2 max-w-[38ch] text-ink-muted">{step.body}</p>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

async function Categories() {
  const tree = await getCategoryTree();
  if (tree.length === 0) return null;
  return (
    <Section tone="surface" aria-labelledby="categorieen-titel">
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-4">
          <h2 id="categorieen-titel" className="text-3xl sm:text-4xl">
            Waarmee kunnen we je helpen?
          </h2>
          <Link href="/categorieen" className="font-semibold text-polder underline underline-offset-4 hover:no-underline">
            Alle categorieën bekijken
          </Link>
        </div>
        <ul className="mt-10 grid border-t border-line md:grid-cols-2 md:gap-x-12">
          {tree.map((cat) => (
            <li key={cat.id} className="border-b border-line">
              <Link href={`/categorie/${cat.slug}`} className="group block py-5">
                <span className="flex items-baseline justify-between gap-4">
                  <span className="font-display text-2xl font-bold text-polder group-hover:underline underline-offset-4">
                    {cat.name}
                  </span>
                  <span className="text-sm text-ink-muted">{cat.children.length} soorten</span>
                </span>
                <span className="mt-1 block text-ink-muted">
                  {cat.children.map((c) => c.name).join(", ")}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      </Container>
    </Section>
  );
}

function Audiences() {
  return (
    <Section>
      <Container>
        <h2 className="text-3xl sm:text-4xl">{home.audiences.title}</h2>
        <ul className="mt-10 grid gap-x-8 gap-y-8 sm:grid-cols-2 lg:grid-cols-5">
          {home.audiences.items.map((a) => (
            <li key={a.title}>
              <h3 className="text-xl">{a.title}</h3>
              <p className="mt-2 text-ink-muted">{a.body}</p>
            </li>
          ))}
        </ul>
      </Container>
    </Section>
  );
}

function Why() {
  return (
    <Section tone="surface">
      <Container>
        <h2 className="text-3xl sm:text-4xl">{home.why.title}</h2>
        <dl className="mt-10 grid gap-x-10 gap-y-8 sm:grid-cols-2 lg:grid-cols-3">
          {home.why.items.map((w) => (
            <div key={w.title} className="border-l-2 border-polder-soft pl-5">
              <dt className="font-display text-xl font-bold text-polder">{w.title}</dt>
              <dd className="mt-1 text-ink-muted">{w.body}</dd>
            </div>
          ))}
        </dl>
      </Container>
    </Section>
  );
}

function ForSuppliers() {
  return (
    <Section tone="polder">
      <Container className="grid items-end gap-8 lg:grid-cols-12">
        <div className="lg:col-span-8">
          <p className="font-semibold text-feest">Voor eventleveranciers</p>
          <h2 className="mt-2 text-3xl sm:text-4xl">{home.suppliers.title}</h2>
          <p className="mt-4 max-w-[60ch] text-lg text-white/85">{home.suppliers.body}</p>
        </div>
        <div className="lg:col-span-4 lg:text-right">
          <ButtonLink href="/voor-leveranciers" size="lg" variant="outline" className="border-white/40 bg-transparent text-white hover:border-white hover:bg-white/10">
            {home.suppliers.cta}
          </ButtonLink>
        </div>
      </Container>
    </Section>
  );
}

function Closing() {
  return (
    <Section>
      <Container className="max-w-3xl text-center">
        <h2 className="text-3xl sm:text-5xl">{home.closing.title}</h2>
        <p className="mx-auto mt-5 max-w-[60ch] text-lg text-ink-muted">{home.closing.body}</p>
        <ButtonLink href="/aanvraag" size="lg" className="mt-8">
          {home.closing.cta}
        </ButtonLink>
      </Container>
    </Section>
  );
}
