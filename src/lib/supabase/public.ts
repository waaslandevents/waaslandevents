import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { hasSupabase, publicEnv } from "@/lib/env";

/**
 * Client zonder cookies, voor publieke catalogusdata die we cachen
 * ('use cache'). Leest enkel wat RLS aan "anon" toestaat.
 */
let client: SupabaseClient | null = null;

export function publicSupabase(): SupabaseClient | null {
  if (!hasSupabase) return null;
  client ??= createClient(publicEnv.NEXT_PUBLIC_SUPABASE_URL!, publicEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}
