# WaaslandEvents — architectuur (Fase 1)

## 1. Principes

1. **Eén flow staat centraal:** aanvraag → matching → lead → opdracht → event → omzet → commissie. Elke tabel en elk scherm dient die flow.
2. **De database bewaakt de regels.** "Max. 3 per categorie", "commissie pas na het event", "leverancier ziet enkel zijn leads": dit zit in Postgres (triggers, RPC's, RLS). Een fout in de frontend kan die regels niet omzeilen.
3. **Geen publieke leveranciersdirectory.** Anonieme bezoekers kunnen technisch geen enkele leverancier of leveranciersproduct lezen. Ze zien enkel neutrale `product_types`.
4. **Alles beheerbaar.** Gemeenten, categorieën, eventtypes, producttypes, commissietarief en termijnen staan in de database. Niets daarvan is hardcoded in de frontend.

## 2. Informatiearchitectuur

**Publiek:**
- `/` · `/hoe-werkt-het` · `/aanvraag` (wizard) · `/aanvraag/ontvangen`
- `/categorieen` · `/categorie/[slug]` · `/product/[slug]` · `/locatie/[slug]`
- SEO-combinaties zoals `/categorie/[slug]/[gemeente]`. Die bestaan **enkel** als er een gepubliceerde rij in `seo_landing_pages` is, met minstens 200 tekens unieke intro.
- `/inspiratie` + `/inspiratie/[slug]` · `/veelgestelde-vragen`
- `/voor-leveranciers` · `/word-partner` · `/over-ons` · `/contact` · 5 juridische pagina's

**Leveranciersportaal** (`/partner`):
- dashboard · leads · lead-detail · opdrachten (omzet bevestigen) · commissies · profiel · producten · werkgebied

**Admin** (`/admin`):
- KPI's · aanvragen → matching · leveranciers · productreview · commissies · reviews
- catalogus (categorieën, producttypes, gemeenten, eventtypes) · content/SEO · instellingen · audit log

## 3. Datamodel

| Domein | Tabellen | Opmerking |
|---|---|---|
| Identiteit | `auth.users`, `profiles` (rol), `customer_profiles` | `admin_users` = view op profiles. Klanten hebben in de MVP geen account. |
| Catalogus | `categories` (boom), `event_types`, `product_types`, `locations` (regio → gemeente → deelgemeente) | `product_types` = neutrale publieke catalogus, toegevoegd t.o.v. de spec |
| Leveranciers | `suppliers`, `supplier_categories`, `supplier_event_types`, `supplier_locations`, `supplier_products`, `supplier_admin_notes`, `media` | Interne notities in een aparte tabel, zodat RLS ze afschermt |
| Aanvragen | `event_requests`, `event_request_items` (één per gevraagde categorie), `request_notes` | Referentie `WE-2026-00001` |
| Leads | `lead_assignments` (item × leverancier), `lead_status_history` | Max. N per item via trigger; `attribution_until` = leadbescherming |
| Geld | `bookings`, `commission_records`, `commission_adjustments`, `platform_settings` | Tarief wordt bij "gewonnen" vastgelegd (snapshot) |
| Na het event | `feedback_invites`, `customer_feedback`, `reviews` | Feedback dient ook als controle op de gemelde omzet |
| Overig | `notifications`, `email_logs`, `legal_documents`, `legal_acceptances`, `audit_logs`, `cms_blocks`, `faqs`, `posts`, `seo_landing_pages`, `analytics_events` | |

Bedragen zijn altijd `numeric(12,2)`, **exclusief btw**.

## 4. Rollen en toegang

| Rol | Kan |
|---|---|
| anon | Gepubliceerde catalogus en content lezen. Niets schrijven: aanvragen gaan via de server. |
| customer | (V2) eigen aanvragen |
| supplier | Eigen bedrijf, aanbod en werkgebied beheren. Enkel toegewezen leads en de bijhorende klantgegevens lezen. Leadstatus, "gewonnen", omzet en betwisting enkel via RPC. |
| admin | Alles lezen en beheren, matchen, commissies opvolgen |
| super_admin | Bovendien: adminrechten toekennen |

Server-taken (aanvraag opslaan, dagelijkse job, e-mails) gebruiken de service role en draaien enkel server-side.

## 5. Lead-lifecycle

```
Aanvraag:  nieuw → in_behandeling → info_nodig → gematcht → afgesloten
                                                          ↘ geannuleerd / spam

Lead (per leverancier):
  nieuw → contact_opgenomen → offerte_voorbereiding → offerte_verstuurd → onderhandeling
        ↘ verloren (met reden)
        → gewonnen → event_gepland → event_afgerond → omzet_geregistreerd
```

- **Normale statussen** zet de leverancier zelf (`set_lead_status`).
- **Gewonnen** loopt via `mark_lead_won`. Dat maakt een opdracht en een commissierecord aan.
- **Event afgerond** zet de dagelijkse job.
- **Omzet geregistreerd** volgt uit `confirm_revenue`.
- Elke wijziging komt in `lead_status_history` en `audit_logs`.

## 6. Commissie-lifecycle

```
wacht_op_event ─(dag na event, job)→ omzet_opvragen ─(leverancier bevestigt)→ commissie_berekend
   ─(admin, factuurnr)→ factuur_opgesteld ─→ betaald ─(creditnota achteraf)→ gecrediteerd
   betwist ↔ (admin beslist)          vervallen = event niet doorgegaan / omzet 0
```

**Berekening:**

    grondslag = gerealiseerde netto omzet − creditnota bij bevestiging − latere correcties
    commissie = round(grondslag × tarief, 2)

Voorbeeld uit de spec: €2.000 − €250 = €1.750 × 12,5% = **€218,75**.

**Dagelijkse job:**
- vraagt de omzet op de dag na het event;
- stuurt een herinnering na 14 dagen;
- escaleert na 30 dagen naar de admin.

Alle termijnen staan in `platform_settings`.

## 7. Technische architectuur

- **Next.js 16** met Cache Components:
  - Publieke catalogus via `'use cache'` (1 uur, tag `catalog`); de admin revalideert bij wijzigingen.
  - Ingelogde schermen streamen binnen `<Suspense>`.
- **Supabase:**
  - Postgres 17 met RLS op elke tabel.
  - Business-RPC's als `security definer` met eigen toegangscontrole.
  - Storage: `public-media` voor goedgekeurde beelden, `supplier-uploads/<supplier_id>/…` (privé) voor uploads.
- **Vercel** voor hosting en Cron (`/api/cron/daily` → `process_due_bookings()` en `process_supplier_deactivations()`).
- **E-mail:** Resend met React-templates (fase 9). Elke verzonden mail komt in `email_logs`.
- **Spam:** Cloudflare Turnstile + rate limiting op de aanvraag-route (fase 3).
- **Fonts** zijn lokaal gehost: geen verbinding met Google, dus geen cookie- of GDPR-issue.
- **Stripe:** enkel `suppliers.stripe_customer_id` voorbereid. Geen betaalflow in de MVP (spec §37).

## 8. Beveiligingsmodel, kort

- `is_admin()` en `my_supplier_ids()` zijn de bouwstenen van alle policies.
- Leveranciers hebben **geen** UPDATE-policy op leads, opdrachten en commissies. Alles loopt via RPC's die eigenaarschap en toegelaten statusovergangen controleren.
- **Beschermde velden** (status, partnerbadge, slug, deactivatie) bewaken triggers. Een leverancier kan zichzelf niet activeren of goedkeuren.
- **Een goedgekeurd product dat inhoudelijk wijzigt** gaat automatisch terug naar review.
- **De audit log** kan enkel via security-definer-triggers en RPC's beschreven worden.

Getest in `supabase/sqltests/flow_test.sql`, en via HTTP met PostgREST: als anon, als concurrerende leverancier en als service role.

## 9. Beslissingen buiten de letterlijke spec

Deze keuzes moet de eigenaar bevestigen.

1. **Leadbescherming 12 maanden** (`attribution_months`). Een opdracht van dezelfde klant binnen die termijn telt als WaaslandEvents-opdracht. Dit moet in de leveranciersvoorwaarden.
2. **Controle op zelfgerapporteerde omzet.** De feedbackmail na het event vraagt "met welke partner werkte je samen?". Een mismatch verschijnt in `v_attribution_flags`.
3. **Omzet niet gemeld:** herinnering na 14 dagen, escalatie na 30 dagen.
4. **Deactivatie.** Een gedeactiveerde leverancier wordt niet meer gematcht, maar kan nog inloggen om historiek en openstaande commissies af te handelen.
5. **Consenttekst wizard.** Die moet expliciet melden dat gegevens met max. 3 partners per gevraagde categorie gedeeld worden.
6. **Facturatie** van commissies gebeurt in de eigen boekhoudtool (Peppol-verplichting B2B sinds 2026). Het platform levert de gegevens en het factuurnummer wordt teruggezet in de admin.
7. **Onafhankelijkheid.** Elke matchingbeslissing staat in de audit log. Aanbevolen: op de "Over ons"-pagina transparant zijn over wie WaaslandEvents runt.
8. **Navigatie.** "Ontdek" uit spec §61 is weggelaten: "Categorieën" doet hetzelfde met een duidelijker label.

## 10. MVP-scope

**Binnen:**
- de 10 punten uit spec §48;
- leverancier-onboarding met review;
- CMS-light (FAQ, categorie-intro's, SEO-meta, blog, juridische pagina's);
- demo-data en de testscenario's.

**Buiten:**
- alles uit spec §49;
- automatische of AI-matching;
- klantaccounts;
- facturatie in het platform;
- Stripe-betalingen.
