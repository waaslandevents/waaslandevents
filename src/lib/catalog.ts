import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { publicSupabase } from "@/lib/supabase/public";

/**
 * Publieke catalogus (categorieën, eventtypes, locaties, producttypes).
 * Alles komt uit de database en is in de admin beheerbaar — niets is hier
 * hardcoded. Gecachet per uur; de admin revalideert met tag 'catalog'.
 */

export type Category = {
  id: string;
  parent_id: string | null;
  slug: string;
  name: string;
  short_description: string | null;
  icon: string | null;
  sort_order: number;
};

export type EventType = { id: string; slug: string; name: string; audience: string; sort_order: number };

export type Location = { id: string; parent_id: string | null; slug: string; name: string; type: string };

export type ProductType = {
  id: string;
  category_id: string;
  slug: string;
  name: string;
  short_description: string | null;
  price_type: "vanaf" | "range" | "op_aanvraag";
  price_from: number | null;
  price_to: number | null;
};

async function select<T>(table: string, columns: string): Promise<T[]> {
  const db = publicSupabase();
  if (!db) return [];
  const { data, error } = await db.from(table).select(columns).order("sort_order", { ascending: true });
  if (error) {
    console.error(`[catalog] ${table}:`, error.message);
    return [];
  }
  return (data ?? []) as T[];
}

export async function getCategories() {
  "use cache";
  cacheLife("hours");
  cacheTag("catalog");
  return select<Category>("categories", "id,parent_id,slug,name,short_description,icon,sort_order");
}

export async function getEventTypes() {
  "use cache";
  cacheLife("hours");
  cacheTag("catalog");
  return select<EventType>("event_types", "id,slug,name,audience,sort_order");
}

export async function getLocations() {
  "use cache";
  cacheLife("hours");
  cacheTag("catalog");
  return select<Location>("locations", "id,parent_id,slug,name,type,sort_order");
}

export async function getProductTypes() {
  "use cache";
  cacheLife("hours");
  cacheTag("catalog");
  return select<ProductType>(
    "product_types",
    "id,category_id,slug,name,short_description,price_type,price_from,price_to,sort_order",
  );
}

/** Hoofdcategorieën met hun subcategorieën, in volgorde. */
export async function getCategoryTree() {
  const all = await getCategories();
  return all
    .filter((c) => !c.parent_id)
    .map((parent) => ({ ...parent, children: all.filter((c) => c.parent_id === parent.id) }));
}
