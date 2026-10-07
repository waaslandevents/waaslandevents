"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { buttonClasses } from "@/components/ui/button";

/** Sticky "Start je aanvraag" op mobiel (spec §31). Verborgen waar het geen zin heeft. */
const HIDDEN_ON = ["/aanvraag", "/partner", "/admin", "/login", "/word-partner"];

export function MobileCta() {
  const pathname = usePathname();
  if (HIDDEN_ON.some((p) => pathname === p || pathname.startsWith(`${p}/`))) return null;
  return (
    <div className="fixed inset-x-0 bottom-0 z-40 border-t border-line bg-paper/95 p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] backdrop-blur sm:hidden">
      <Link href="/aanvraag" className={buttonClasses({ size: "lg", className: "w-full" })}>
        Start je aanvraag
      </Link>
    </div>
  );
}
