import { z } from "zod";

/**
 * Publieke variabelen (mogen in de browser). Ontbreken ze, dan draait de site
 * in "demo zonder database": catalogusdata is leeg maar alles rendert.
 */
const publicSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url().optional(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1).optional(),
  NEXT_PUBLIC_SITE_URL: z.string().url().default("http://localhost:3000"),
  /** Pas op "true" zetten bij livegang: tot dan staat de site op noindex. */
  NEXT_PUBLIC_SITE_INDEXABLE: z.enum(["true", "false"]).default("false"),
});

export const publicEnv = publicSchema.parse({
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL || undefined,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || undefined,
  NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL || undefined,
  NEXT_PUBLIC_SITE_INDEXABLE: process.env.NEXT_PUBLIC_SITE_INDEXABLE || undefined,
});

export const hasSupabase = Boolean(
  publicEnv.NEXT_PUBLIC_SUPABASE_URL && publicEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY,
);

export const isIndexable = publicEnv.NEXT_PUBLIC_SITE_INDEXABLE === "true";
