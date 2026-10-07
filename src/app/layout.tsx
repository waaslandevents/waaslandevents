import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { SiteHeader } from "@/components/layout/site-header";
import { SiteFooter } from "@/components/layout/site-footer";
import { MobileCta } from "@/components/layout/mobile-cta";
import { isIndexable, publicEnv } from "@/lib/env";
import "./globals.css";

// Lokaal gehost (OFL-licentie): geen verbinding met Google Fonts → GDPR-vriendelijk.
const bricolage = localFont({
  src: [
    { path: "../fonts/bricolage-grotesque-latin-wght-normal.woff2", weight: "200 800" },
    { path: "../fonts/bricolage-grotesque-latin-ext-wght-normal.woff2", weight: "200 800" },
  ],
  variable: "--font-bricolage",
  display: "swap",
});

const instrument = localFont({
  src: [
    { path: "../fonts/instrument-sans-latin-wght-normal.woff2", weight: "400 700" },
    { path: "../fonts/instrument-sans-latin-ext-wght-normal.woff2", weight: "400 700" },
  ],
  variable: "--font-instrument",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(publicEnv.NEXT_PUBLIC_SITE_URL),
  title: {
    default: "WaaslandEvents: alles voor jouw event, lokaal geregeld",
    template: "%s | WaaslandEvents",
  },
  description:
    "Organiseer je een feest, bedrijfsevent, schoolfeest of huwelijk in het Waasland? Eén aanvraag en we brengen je in contact met maximaal 3 passende lokale leveranciers per onderdeel.",
  openGraph: { type: "website", locale: "nl_BE", siteName: "WaaslandEvents" },
  robots: isIndexable ? { index: true, follow: true } : { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#0f4a45",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="nl-BE" className={`${bricolage.variable} ${instrument.variable}`}>
      <body className="flex min-h-dvh flex-col antialiased">
        <a
          href="#inhoud"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-polder focus:px-4 focus:py-2 focus:text-white"
        >
          Naar de inhoud
        </a>
        <SiteHeader />
        <main id="inhoud" className="flex-1">
          {children}
        </main>
        <SiteFooter />
        <MobileCta />
      </body>
    </html>
  );
}
