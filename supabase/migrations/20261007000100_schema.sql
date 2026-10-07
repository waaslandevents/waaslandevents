-- ============================================================================
-- WaaslandEvents — 0001 schema
-- Kernflow: AANVRAAG → MATCHING → LEAD → OPDRACHT → EVENT → OMZET → COMMISSIE
--
-- Conventies
--  * Alle tabellen: id uuid, created_at, updated_at; soft delete via deleted_at
--    waar historiek moet blijven (leveranciers, producten, aanvragen).
--  * Statussen zijn Postgres-enums (Nederlandse waarden = wat de UI toont).
--  * Bedragen: numeric(12,2), altijd EXCLUSIEF btw.
--  * "users" uit de spec = auth.users (Supabase). Rol en naam staan in profiles.
--    "admin_users" uit de spec = profiles met rol admin/super_admin
--    (view public.admin_users hieronder).
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.app_role as enum ('customer', 'supplier', 'admin', 'super_admin');

create type public.supplier_status as enum (
  'concept', 'aanvraag_ontvangen', 'in_controle', 'info_nodig',
  'goedgekeurd', 'actief', 'tijdelijk_verborgen', 'afgewezen', 'gedeactiveerd'
);

create type public.product_status as enum ('draft', 'pending_review', 'approved', 'rejected', 'archived');

create type public.price_type as enum ('vanaf', 'range', 'op_aanvraag');

create type public.customer_type as enum ('particulier', 'bedrijf', 'school', 'vereniging', 'organisatie');

create type public.request_status as enum (
  'nieuw', 'in_behandeling', 'info_nodig', 'gematcht', 'afgesloten', 'geannuleerd', 'spam'
);

create type public.request_item_status as enum ('open', 'gematcht', 'geen_match');

create type public.lead_status as enum (
  'nieuw', 'contact_opgenomen', 'offerte_voorbereiding', 'offerte_verstuurd',
  'onderhandeling', 'gewonnen', 'verloren', 'event_gepland', 'event_afgerond',
  'omzet_geregistreerd'
);

create type public.booking_status as enum ('gepland', 'afgerond', 'geannuleerd');

-- 'vervallen' = event ging niet door of omzet = 0 → geen commissie (spec §8)
create type public.commission_status as enum (
  'nog_niet_verschuldigd', 'wacht_op_event', 'omzet_opvragen', 'omzet_bevestigd',
  'commissie_berekend', 'factuur_opgesteld', 'betaald', 'betwist', 'gecrediteerd', 'vervallen'
);

create type public.adjustment_type as enum ('creditnota', 'terugbetaling', 'annulering', 'correctie');

create type public.review_status as enum ('pending', 'approved', 'hidden', 'removed');

create type public.location_type as enum ('regio', 'gemeente', 'deelgemeente');

create type public.indoor_outdoor as enum ('binnen', 'buiten', 'beide', 'onbekend');

create type public.venue_kind as enum ('eigen_locatie', 'externe_locatie', 'nog_te_bepalen');

create type public.content_status as enum ('draft', 'published');

create type public.legal_doc_type as enum (
  'algemene_voorwaarden', 'leveranciersvoorwaarden', 'privacybeleid', 'cookiebeleid', 'disclaimer'
);

-- ---------------------------------------------------------------------------
-- Generieke trigger: updated_at
-- ---------------------------------------------------------------------------
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Platforminstellingen (commissie configureerbaar, spec §57)
-- ---------------------------------------------------------------------------
create table public.platform_settings (
  key         text primary key,
  value       jsonb not null,
  description text,
  is_public   boolean not null default false,   -- mag de publieke site dit lezen?
  updated_by  uuid,
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Identiteit
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        public.app_role not null default 'customer',
  full_name   text,
  email       text,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index profiles_role_idx on public.profiles(role);

create view public.admin_users with (security_invoker = true) as
  select id, full_name, email, role, created_at
  from public.profiles
  where role in ('admin', 'super_admin') and deleted_at is null;

-- Klanten hebben in de MVP geen account: één rij per e-mailadres.
create table public.customer_profiles (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid references public.profiles(id) on delete set null, -- V2: klantaccount
  customer_type     public.customer_type not null default 'particulier',
  organisation_name text,
  full_name         text not null,
  email             text not null,
  phone             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  anonymized_at     timestamptz,                       -- GDPR: gegevens gewist, historiek behouden
  deleted_at        timestamptz
);
create unique index customer_profiles_email_uidx
  on public.customer_profiles (lower(email)) where anonymized_at is null;

-- ---------------------------------------------------------------------------
-- Referentiedata (volledig beheerbaar in admin — niets hardcoded in frontend)
-- ---------------------------------------------------------------------------
create table public.locations (
  id              uuid primary key default gen_random_uuid(),
  parent_id       uuid references public.locations(id) on delete set null,
  type            public.location_type not null default 'gemeente',
  slug            text not null unique,
  name            text not null,
  postal_codes    text[] not null default '{}',
  lat             numeric(9,6),
  lng             numeric(9,6),
  intro_md        text,           -- unieke content voor /locatie/[slug]
  seo_title       text,
  seo_description text,
  is_active       boolean not null default true,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index locations_parent_idx on public.locations(parent_id);
create index locations_postal_idx on public.locations using gin(postal_codes);

create table public.categories (
  id                uuid primary key default gen_random_uuid(),
  parent_id         uuid references public.categories(id) on delete set null,
  slug              text not null unique,
  name              text not null,
  short_description text,
  intro_md          text,
  icon              text,
  image_path        text,
  show_in_wizard    boolean not null default true,
  is_active         boolean not null default true,
  sort_order        int not null default 0,
  seo_title         text,
  seo_description   text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index categories_parent_idx on public.categories(parent_id);

create table public.event_types (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  audience    public.customer_type not null default 'particulier',
  icon        text,
  is_active   boolean not null default true,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Neutrale publieke catalogus ("Spiegelphotobooth huren"). Spec §42.
-- Leveranciersproducten verwijzen hiernaar; de publiek ziet ENKEL dit.
create table public.product_types (
  id                uuid primary key default gen_random_uuid(),
  category_id       uuid not null references public.categories(id),
  slug              text not null unique,
  name              text not null,
  short_description text,
  body_md           text,
  benefits          text[] not null default '{}',
  use_cases         text[] not null default '{}',
  price_type        public.price_type not null default 'vanaf',
  price_from        numeric(12,2),
  price_to          numeric(12,2),
  price_note        text,
  faq               jsonb not null default '[]'::jsonb,   -- [{q, a}]
  image_path        text,
  is_active         boolean not null default false,       -- pas live na redactie
  sort_order        int not null default 0,
  seo_title         text,
  seo_description   text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint product_types_price_ck check (
    (price_type = 'op_aanvraag')
    or (price_type = 'vanaf' and price_from is not null)
    or (price_type = 'range' and price_from is not null and price_to is not null and price_to >= price_from)
  )
);
create index product_types_category_idx on public.product_types(category_id);

-- ---------------------------------------------------------------------------
-- Leveranciers
-- ---------------------------------------------------------------------------
create table public.suppliers (
  id                         uuid primary key default gen_random_uuid(),
  owner_profile_id           uuid not null references public.profiles(id),
  company_name               text not null,
  slug                       text unique,
  description                text,
  contact_name               text,
  email                      text,
  phone                      text,
  enterprise_number          text,           -- KBO
  vat_number                 text,
  website                    text,           -- intern, nooit publiek als verkooproute
  socials                    jsonb not null default '{}'::jsonb,
  logo_path                  text,
  primary_location_id        uuid references public.locations(id),
  service_radius_km          int check (service_radius_km is null or service_radius_km between 0 and 250),
  min_capacity               int,
  max_capacity               int,
  specialisations            text[] not null default '{}',
  price_level                smallint check (price_level between 1 and 4),
  status                     public.supplier_status not null default 'concept',
  status_reason              text,           -- bv. reden afwijzing / gevraagde info
  submitted_at               timestamptz,
  verified_at                timestamptz,    -- ✓ WaaslandEvents Partner
  terms_accepted_at          timestamptz,
  deactivation_requested_at  timestamptz,    -- leverancier stopt → na grace-periode inactief (§56)
  deactivated_at             timestamptz,
  stripe_customer_id         text,           -- voorbereid voor V2
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),
  deleted_at                 timestamptz,
  constraint suppliers_capacity_ck check (min_capacity is null or max_capacity is null or max_capacity >= min_capacity)
);
create index suppliers_owner_idx on public.suppliers(owner_profile_id);
create index suppliers_status_idx on public.suppliers(status);

-- Interne notities over een leverancier: aparte tabel zodat RLS ze afschermt.
create table public.supplier_admin_notes (
  id          uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  author_id   uuid references public.profiles(id),
  body        text not null,
  created_at  timestamptz not null default now()
);

create table public.supplier_categories (
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (supplier_id, category_id)
);

create table public.supplier_event_types (
  supplier_id   uuid not null references public.suppliers(id) on delete cascade,
  event_type_id uuid not null references public.event_types(id) on delete cascade,
  primary key (supplier_id, event_type_id)
);

create table public.supplier_locations (
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (supplier_id, location_id)
);

create table public.supplier_products (
  id                      uuid primary key default gen_random_uuid(),
  supplier_id             uuid not null references public.suppliers(id) on delete cascade,
  product_type_id         uuid references public.product_types(id),   -- koppeling door admin
  category_id             uuid not null references public.categories(id),
  name                    text not null,
  description             text,
  price_type              public.price_type not null default 'vanaf',
  price_from              numeric(12,2),
  price_to                numeric(12,2),
  price_note              text,
  capacity_min            int,
  capacity_max            int,
  suitable_event_type_ids uuid[] not null default '{}',
  features                text[] not null default '{}',
  status                  public.product_status not null default 'draft',
  rejection_reason        text,
  submitted_at            timestamptz,
  reviewed_at             timestamptz,
  reviewed_by             uuid references public.profiles(id),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  deleted_at              timestamptz
);
create index supplier_products_supplier_idx on public.supplier_products(supplier_id);
create index supplier_products_type_idx on public.supplier_products(product_type_id) where status = 'approved';

create table public.media (
  id           uuid primary key default gen_random_uuid(),
  owner_type   text not null check (owner_type in ('supplier', 'supplier_product', 'product_type', 'category', 'post', 'location')),
  owner_id     uuid not null,
  supplier_id  uuid references public.suppliers(id) on delete cascade,  -- gezet bij leveranciersmedia (RLS)
  storage_path text not null,
  alt          text,
  width        int,
  height       int,
  is_public    boolean not null default false,  -- pas true na goedkeuring
  sort_order   int not null default 0,
  created_by   uuid references public.profiles(id),
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index media_owner_idx on public.media(owner_type, owner_id);

-- ---------------------------------------------------------------------------
-- Aanvragen
-- ---------------------------------------------------------------------------
create sequence public.event_request_ref_seq;

create table public.event_requests (
  id                    uuid primary key default gen_random_uuid(),
  reference             text not null unique
                          default ('WE-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.event_request_ref_seq')::text, 5, '0')),
  customer_id           uuid not null references public.customer_profiles(id),
  event_type_id         uuid references public.event_types(id),
  event_type_other      text,
  event_date            date,
  date_flexible         boolean not null default false,
  start_time            time,
  end_time              time,
  location_id           uuid references public.locations(id),
  postal_code           text,
  venue_name            text,
  address               text,
  indoor_outdoor        public.indoor_outdoor not null default 'onbekend',
  venue_kind            public.venue_kind not null default 'nog_te_bepalen',
  adults                int check (adults is null or adults >= 0),
  children              int check (children is null or children >= 0),
  guests_total          int check (guests_total is null or guests_total >= 0),
  budget_min            numeric(12,2),
  budget_max            numeric(12,2),
  budget_note           text,
  message               text,
  status                public.request_status not null default 'nieuw',
  source                text not null default 'wizard',     -- wizard | product | categorie | contact
  source_path           text,
  utm                   jsonb not null default '{}'::jsonb,
  consent_at            timestamptz not null,
  consent_version       text not null,
  assigned_admin_id     uuid references public.profiles(id),
  qualified_at          timestamptz,
  matched_at            timestamptz,
  closed_at             timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  anonymized_at         timestamptz,
  deleted_at            timestamptz,
  constraint event_requests_budget_ck check (budget_min is null or budget_max is null or budget_max >= budget_min)
);
create index event_requests_status_idx on public.event_requests(status) where deleted_at is null;
create index event_requests_date_idx on public.event_requests(event_date);
create index event_requests_customer_idx on public.event_requests(customer_id);

create table public.event_request_items (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references public.event_requests(id) on delete cascade,
  category_id     uuid not null references public.categories(id),
  product_type_id uuid references public.product_types(id),
  notes           text,
  status          public.request_item_status not null default 'open',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index event_request_items_request_idx on public.event_request_items(request_id);

-- Interne notities (spec §68) — nooit zichtbaar voor leverancier of klant.
create table public.request_notes (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.event_requests(id) on delete cascade,
  author_id   uuid references public.profiles(id),
  body        text not null,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Leads = toewijzing van één aanvraag-item aan één leverancier (spec §40)
-- ---------------------------------------------------------------------------
create table public.lead_assignments (
  id                   uuid primary key default gen_random_uuid(),
  request_id           uuid not null references public.event_requests(id),
  request_item_id      uuid not null references public.event_request_items(id),
  supplier_id          uuid not null references public.suppliers(id),
  status               public.lead_status not null default 'nieuw',
  assigned_by          uuid references public.profiles(id),
  assigned_at          timestamptz not null default now(),
  sent_at              timestamptz,
  first_viewed_at      timestamptz,
  lost_reason          text,
  attribution_until    date not null,     -- leadbescherming: tot wanneer telt een opdracht als WE-lead
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (request_item_id, supplier_id)
);
create index lead_assignments_supplier_idx on public.lead_assignments(supplier_id, status);
create index lead_assignments_request_idx on public.lead_assignments(request_id);

create table public.lead_status_history (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.lead_assignments(id) on delete cascade,
  from_status    public.lead_status,
  to_status      public.lead_status not null,
  changed_by     uuid,
  note           text,
  created_at     timestamptz not null default now()
);
create index lead_status_history_assignment_idx on public.lead_status_history(assignment_id);

-- ---------------------------------------------------------------------------
-- Opdrachten en commissie
-- ---------------------------------------------------------------------------
create table public.bookings (
  id                    uuid primary key default gen_random_uuid(),
  assignment_id         uuid not null unique references public.lead_assignments(id),
  supplier_id           uuid not null references public.suppliers(id),
  request_id            uuid not null references public.event_requests(id),
  event_date            date not null,
  agreed_net_amount     numeric(12,2) not null check (agreed_net_amount >= 0),
  notes                 text,
  status                public.booking_status not null default 'gepland',
  won_at                timestamptz not null default now(),
  cancelled_reason      text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index bookings_supplier_idx on public.bookings(supplier_id);
create index bookings_event_date_idx on public.bookings(event_date) where status = 'gepland';

create table public.commission_records (
  id                     uuid primary key default gen_random_uuid(),
  booking_id             uuid not null unique references public.bookings(id),
  supplier_id            uuid not null references public.suppliers(id),
  status                 public.commission_status not null default 'wacht_op_event',
  rate                   numeric(6,5) not null check (rate >= 0 and rate <= 1),  -- snapshot bij gewonnen opdracht
  realized_net_revenue   numeric(12,2) check (realized_net_revenue >= 0),       -- excl. btw, door leverancier bevestigd
  credited_at_confirmation numeric(12,2) not null default 0 check (credited_at_confirmation >= 0),
  adjustments_total      numeric(12,2) not null default 0,                     -- som van commission_adjustments
  base_amount            numeric(12,2),                                        -- commissiegrondslag
  commission_amount      numeric(12,2),
  revenue_requested_at   timestamptz,
  revenue_reminded_at    timestamptz,
  escalated_at           timestamptz,
  revenue_confirmed_at   timestamptz,
  revenue_confirmed_by   uuid references public.profiles(id),
  calculated_at          timestamptz,
  invoice_number         text,
  invoiced_at            timestamptz,
  due_date               date,
  paid_at                timestamptz,
  dispute_reason         text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index commission_records_supplier_idx on public.commission_records(supplier_id, status);
create index commission_records_status_idx on public.commission_records(status);

create table public.commission_adjustments (
  id             uuid primary key default gen_random_uuid(),
  commission_id  uuid not null references public.commission_records(id),
  type           public.adjustment_type not null,
  amount         numeric(12,2) not null check (amount > 0),  -- vermindert de grondslag
  reason         text not null,
  created_by     uuid references public.profiles(id),
  created_at     timestamptz not null default now()
);
create index commission_adjustments_commission_idx on public.commission_adjustments(commission_id);

-- ---------------------------------------------------------------------------
-- Na het event: feedback + reviews (alleen klanten met een echte aanvraag)
-- ---------------------------------------------------------------------------
create table public.feedback_invites (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references public.event_requests(id) on delete cascade,
  token_hash   text not null unique,          -- sha256 van het token in de mail
  sent_at      timestamptz,
  expires_at   timestamptz not null,
  used_at      timestamptz,
  created_at   timestamptz not null default now()
);

-- "Met welke partner werkte je samen?" — controle op zelfgerapporteerde omzet.
create table public.customer_feedback (
  id                 uuid primary key default gen_random_uuid(),
  request_id         uuid not null references public.event_requests(id) on delete cascade,
  booked_supplier_id uuid references public.suppliers(id),   -- null = geen partner via WE geboekt
  category_id        uuid references public.categories(id),
  comment            text,
  created_at         timestamptz not null default now()
);

create table public.reviews (
  id                uuid primary key default gen_random_uuid(),
  request_id        uuid not null references public.event_requests(id),
  supplier_id       uuid not null references public.suppliers(id),
  customer_id       uuid not null references public.customer_profiles(id),
  score             smallint not null check (score between 1 and 5),
  score_communication smallint check (score_communication between 1 and 5),
  score_quality       smallint check (score_quality between 1 and 5),
  score_value         smallint check (score_value between 1 and 5),
  score_execution     smallint check (score_execution between 1 and 5),
  body              text,
  display_name      text,       -- bv. "Sarah uit Beveren"
  status            public.review_status not null default 'pending',
  moderated_by      uuid references public.profiles(id),
  moderated_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (request_id, supplier_id)
);
create index reviews_supplier_idx on public.reviews(supplier_id) where status = 'approved';

-- ---------------------------------------------------------------------------
-- Communicatie
-- ---------------------------------------------------------------------------
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  type        text not null,
  title       text not null,
  body        text,
  link        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_profile_idx on public.notifications(profile_id, read_at);

create table public.email_logs (
  id            uuid primary key default gen_random_uuid(),
  to_email      text not null,
  template      text not null,
  subject       text,
  related_type  text,
  related_id    uuid,
  provider_id   text,
  status        text not null default 'queued' check (status in ('queued', 'sent', 'failed', 'bounced')),
  error         text,
  created_at    timestamptz not null default now()
);
create index email_logs_related_idx on public.email_logs(related_type, related_id);

-- ---------------------------------------------------------------------------
-- Juridisch
-- ---------------------------------------------------------------------------
create table public.legal_documents (
  id                 uuid primary key default gen_random_uuid(),
  type               public.legal_doc_type not null,
  version            text not null,
  title              text not null,
  body_md            text not null,
  needs_legal_review boolean not null default true,   -- banner tot een jurist het nakeek
  published_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (type, version)
);

create table public.legal_acceptances (
  id             uuid primary key default gen_random_uuid(),
  document_type  public.legal_doc_type not null,
  version        text not null,
  profile_id     uuid references public.profiles(id),
  supplier_id    uuid references public.suppliers(id),
  customer_id    uuid references public.customer_profiles(id),
  request_id     uuid references public.event_requests(id),
  accepted_at    timestamptz not null default now(),
  ip_hash        text,          -- gehasht, niet het IP zelf (dataminimalisatie)
  user_agent     text,
  constraint legal_acceptances_subject_ck check (num_nonnulls(profile_id, supplier_id, customer_id) >= 1)
);

-- ---------------------------------------------------------------------------
-- Audit log (spec §69) — alleen via triggers/functies gevuld
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id           bigint generated always as identity primary key,
  actor_id     uuid,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  before       jsonb,
  after        jsonb,
  created_at   timestamptz not null default now()
);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);
create index audit_logs_created_idx on public.audit_logs(created_at desc);

-- ---------------------------------------------------------------------------
-- Content / CMS / SEO
-- ---------------------------------------------------------------------------
create table public.cms_blocks (
  key         text primary key,        -- bv. 'home.hero', 'leveranciers.hero'
  value       jsonb not null,
  updated_by  uuid references public.profiles(id),
  updated_at  timestamptz not null default now()
);

create table public.faqs (
  id           uuid primary key default gen_random_uuid(),
  scope        text not null default 'algemeen' check (scope in ('algemeen', 'klanten', 'leveranciers', 'categorie', 'product')),
  category_id  uuid references public.categories(id) on delete cascade,
  question     text not null,
  answer_md    text not null,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.posts (
  id                  uuid primary key default gen_random_uuid(),
  slug                text not null unique,
  title               text not null,
  excerpt             text,
  body_md             text not null default '',
  topic               text not null default 'inspiratie'
                        check (topic in ('inspiratie','planning','checklist','trends','ideeen','leveranciersgids','eventtypes','locaties','praktische-tips')),
  cover_path          text,
  related_category_id uuid references public.categories(id),   -- stuurt de CTA
  status              public.content_status not null default 'draft',
  published_at        timestamptz,
  author_id           uuid references public.profiles(id),
  seo_title           text,
  seo_description     text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- SEO-landingspagina's per combinatie. Een combinatie bestaat pas
-- (route + sitemap) als er een gepubliceerde rij met unieke content is.
-- → geen duizenden automatisch gegenereerde dunne pagina's (spec §63).
create table public.seo_landing_pages (
  id               uuid primary key default gen_random_uuid(),
  category_id      uuid references public.categories(id) on delete cascade,
  product_type_id  uuid references public.product_types(id) on delete cascade,
  event_type_id    uuid references public.event_types(id) on delete cascade,
  location_id      uuid references public.locations(id) on delete cascade,
  path             text not null unique,     -- bv. '/categorie/photobooth/beveren'
  h1               text not null,
  intro_md         text not null,
  body_md          text,
  faq              jsonb not null default '[]'::jsonb,
  status           public.content_status not null default 'draft',
  seo_title        text,
  seo_description  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint seo_landing_pages_dims_ck check (num_nonnulls(category_id, product_type_id, event_type_id, location_id) >= 1),
  constraint seo_landing_pages_content_ck check (length(intro_md) >= 200)
);

-- ---------------------------------------------------------------------------
-- Analytics (lichtgewicht funnel; ingevoegd via server route)
-- ---------------------------------------------------------------------------
create table public.analytics_events (
  id          bigint generated always as identity primary key,
  session_id  text,
  name        text not null,          -- page_view, wizard_start, wizard_step, wizard_submit, wizard_abandon, cta_click
  path        text,
  props       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index analytics_events_name_idx on public.analytics_events(name, created_at);

-- ---------------------------------------------------------------------------
-- updated_at-triggers
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','customer_profiles','locations','categories','event_types','product_types',
    'suppliers','supplier_products','event_requests','event_request_items','lead_assignments',
    'bookings','commission_records','reviews','legal_documents','faqs','posts','seo_landing_pages'
  ] loop
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function public.tg_set_updated_at()', t);
  end loop;
end $$;
