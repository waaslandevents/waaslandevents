import "server-only";
import { createClient } from "@supabase/supabase-js";

/**
 * Service-role client: omzeilt RLS. ENKEL server-side gebruiken voor
 * systeemtaken (aanvraag opslaan na validatie, dagelijkse job, e-mails).
 * De sleutel staat nooit in een NEXT_PUBLIC_-variabele.
 */
export function adminSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_SERVICE_ROLE_KEY of NEXT_PUBLIC_SUPABASE_URL ontbreekt");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
