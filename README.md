# WaaslandEvents

Het lokale eventplatform van het Waasland. Eén aanvraag → maximaal 3 passende leveranciers per categorie → 12,5% commissie op de gerealiseerde netto omzet.

**Kernflow:** aanvraag → matching → lead → opdracht → event → omzet → commissie

Stack: Next.js 16 (App Router, Cache Components) · TypeScript · Tailwind CSS 4 · Supabase (Postgres, Auth, RLS, Storage) · Vercel.

Architectuur, datamodel en beslissingen: zie [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Status

| Fase | Inhoud | Status |
|---|---|---|
| 1 | Architectuur, database, RLS, lead- en commissie-engine, design system | ✅ |
| 2 | Homepage, categorie- en productpagina's | 🟡 homepage staat, rest volgt |
| 3 | Aanvraagwizard | ⏳ |
| 4–5 | Leverancier-onboarding en -dashboard | ⏳ (database klaar) |
| 6–8 | Admin, matching, commissies | ⏳ (database klaar) |
| 9–14 | E-mails, SEO/CMS, GDPR, tests, performance, deployment | ⏳ |

## Opstarten

### 1. Database naar Supabase

```bash
npx supabase login
npx supabase link --project-ref xjfmwykwbezzaaxsjrtp
npx supabase db push          # voert supabase/migrations/* uit
```

Dit zet het schema, de RLS-policies, de bedrijfsregels en de referentiedata (gemeenten, categorieën, eventtypes, instellingen) klaar. **`seed.sql` (demo-data) wordt hiermee niet uitgevoerd** — die is enkel voor lokaal gebruik.

Daarna één keer: maak je eigen account aan (Supabase → Authentication → Add user) en geef het super-adminrechten in de SQL-editor:

```sql
update public.profiles set role = 'super_admin' where email = 'jouw@email.be';
```

### 2. Omgevingsvariabelen

Kopieer `.env.example` naar `.env.local` (lokaal) en zet dezelfde variabelen in Vercel. De `SUPABASE_SERVICE_ROLE_KEY` is geheim: enkel in Vercel, nooit in de code.

### 3. Lokaal draaien

```bash
npm install
npm run dev
```

Zonder Supabase-variabelen draait de site ook, maar zonder catalogusdata.

## Tests

De databasetests (86 controles over de 10 testscenario's uit de spec) draaien tegen een lokale Postgres:

```bash
PGHOST=... PGPORT=... PGUSER=postgres npm run test:db
```

`supabase/sqltests/_supabase_stub.sql` bootst de Supabase-specifieke onderdelen (rollen, `auth.uid()`, storage) na. Die stub wordt **nooit** naar Supabase gepusht.

`scripts/local-api/` start optioneel PostgREST + een mini-gateway, zodat de Next.js-app lokaal tegen de testdatabase kan draaien (handig om RLS via HTTP te controleren).

## Mappen

```
src/app/                Routes (App Router)
src/components/ui/      Design system: Button, Field, ChoiceChip, Stepper, StatusPill, Kpi, …
src/components/layout/  Header, footer, mobiele sticky CTA
src/lib/                Supabase-clients, catalogus (gecachet), formattering, statuslabels
src/content/            Teksten (later uit het CMS)
supabase/migrations/    Schema, bedrijfsregels/RPC's, RLS, referentiedata
supabase/seed.sql       Demo-data (fictieve "Demo …"-leveranciers)
supabase/sqltests/      Databasetests
docs/                   Architectuur en beslissingen
```

Het design system is te bekijken op `/ontwerp` (staat op noindex).
