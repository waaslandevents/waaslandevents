import Link from "next/link";
import { Container } from "@/components/ui";
import { Logo } from "./logo";

const COLUMNS = [
  {
    title: "WaaslandEvents",
    links: [
      { href: "/over-ons", label: "Over WaaslandEvents" },
      { href: "/hoe-werkt-het", label: "Hoe werkt het?" },
      { href: "/veelgestelde-vragen", label: "Veelgestelde vragen" },
      { href: "/contact", label: "Contact" },
    ],
  },
  {
    title: "Voor leveranciers",
    links: [
      { href: "/voor-leveranciers", label: "Partner worden" },
      { href: "/login", label: "Inloggen" },
      { href: "/leveranciersvoorwaarden", label: "Leveranciersvoorwaarden" },
    ],
  },
  {
    title: "Juridisch",
    links: [
      { href: "/privacybeleid", label: "Privacybeleid" },
      { href: "/cookiebeleid", label: "Cookiebeleid" },
      { href: "/algemene-voorwaarden", label: "Algemene voorwaarden" },
      { href: "/disclaimer", label: "Disclaimer" },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="bg-polder-strong pb-28 text-white/85 sm:pb-0">
      <Container className="grid gap-10 py-14 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div className="max-w-xs space-y-4">
          <Logo inverse />
          <p className="text-sm text-white/75">
            Het lokale eventplatform van het Waasland. We brengen je in contact met gecontroleerde
            leveranciers. De overeenkomst sluit je rechtstreeks met de leverancier.
          </p>
        </div>
        {COLUMNS.map((col) => (
          <nav key={col.title} aria-label={col.title}>
            <h2 className="font-sans text-sm font-semibold text-white">{col.title}</h2>
            <ul className="mt-3 space-y-2 text-sm">
              {col.links.map((l) => (
                <li key={l.href}>
                  <Link href={l.href} className="hover:text-white hover:underline underline-offset-4">
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </Container>
      <Container className="border-t border-white/15 py-6 text-xs text-white/60">
        WaaslandEvents is een bemiddelend platform en voert zelf geen eventdiensten uit.
      </Container>
    </footer>
  );
}
