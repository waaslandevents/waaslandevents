import Link from "next/link";
import { ButtonLink, Container } from "@/components/ui";
import { Logo } from "./logo";
import { MobileMenu } from "./mobile-menu";

export const NAV = [
  { href: "/categorieen", label: "Categorieën" },
  { href: "/inspiratie", label: "Inspiratie" },
  { href: "/hoe-werkt-het", label: "Hoe werkt het?" },
  { href: "/voor-leveranciers", label: "Voor leveranciers" },
] as const;

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-line/80 bg-paper/90 backdrop-blur supports-[backdrop-filter]:bg-paper/75">
      <Container className="flex h-16 items-center justify-between gap-6">
        <Logo />
        <nav aria-label="Hoofdmenu" className="hidden lg:block">
          <ul className="flex items-center gap-7 text-[0.95rem] font-medium">
            {NAV.map((item) => (
              <li key={item.href}>
                <Link href={item.href} className="text-ink hover:text-polder hover:underline underline-offset-4">
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
        <div className="flex items-center gap-2">
          {/* Wrapper: 'hidden' op de link zelf zou botsen met inline-flex van de knop */}
          <span className="hidden sm:block">
            <ButtonLink href="/aanvraag" size="sm">
              Start je aanvraag
            </ButtonLink>
          </span>
          <MobileMenu items={NAV} />
        </div>
      </Container>
    </header>
  );
}
