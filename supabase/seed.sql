-- ============================================================================
-- WaaslandEvents — DEMO-DATA (alleen voor development / staging!)
-- Alle leveranciers zijn fictief en dragen "Demo" in hun naam (spec §53).
-- Wachtwoord van alle demo-accounts (alleen lokaal): Demo-WE-2026!
-- Draaien: `supabase db reset` (lokaal) — NOOIT op productie.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Accounts (profiles worden via trigger aangemaakt)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000a001', 'admin@demo.waaslandevents.be',        '{"full_name":"Demo Admin"}'),
  ('00000000-0000-4000-8000-00000000b001', 'photobooth@demo.waaslandevents.be',   '{"full_name":"Demo Photobooth","signup_as":"supplier"}'),
  ('00000000-0000-4000-8000-00000000b002', 'entertainment@demo.waaslandevents.be','{"full_name":"Demo Entertainment","signup_as":"supplier"}'),
  ('00000000-0000-4000-8000-00000000b003', 'catering@demo.waaslandevents.be',     '{"full_name":"Demo Catering","signup_as":"supplier"}'),
  ('00000000-0000-4000-8000-00000000b004', 'tenten@demo.waaslandevents.be',       '{"full_name":"Demo Tentenverhuur","signup_as":"supplier"}'),
  ('00000000-0000-4000-8000-00000000b005', 'nieuw@demo.waaslandevents.be',        '{"full_name":"Demo Nieuwkomer","signup_as":"supplier"}')
on conflict (id) do nothing;

update public.profiles set role = 'super_admin' where id = '00000000-0000-4000-8000-00000000a001';

-- ---------------------------------------------------------------------------
-- Neutrale producttypes met indicatieve vanaf-prijzen (demo)
-- ---------------------------------------------------------------------------
insert into public.product_types (slug, name, category_id, short_description, price_type, price_from, price_to, price_note, benefits, use_cases, is_active, sort_order, faq)
select v.slug, v.name, c.id, v.descr, v.ptype::public.price_type, v.pfrom, v.pto, v.pnote, v.benefits, v.cases, true, v.ord, v.faq::jsonb
from (values
  ('spiegelphotobooth', 'Spiegelphotobooth huren', 'photobooth',
   'Een grote spiegel die tegelijk camera en scherm is. Gasten zien zichzelf, tikken op het glas en krijgen meteen hun foto.',
   'vanaf', 299::numeric, null::numeric, 'Incl. levering en opbouw in het Waasland, afhankelijk van duur en opties.',
   array['Onbeperkt foto''s', 'Direct afdrukken of digitaal delen', 'Eigen ontwerp op de foto'],
   array['Huwelijk', 'Bedrijfsfeest', 'Verjaardag'], 10,
   '[{"q":"Hoeveel ruimte heb ik nodig?","a":"Reken op ongeveer 3 bij 3 meter en een stopcontact in de buurt."},{"q":"Kunnen de foto''s een eigen ontwerp krijgen?","a":"Ja, de meeste partners zetten jullie namen, logo of datum op elke afdruk."}]'),
  ('360-photobooth', '360° photobooth huren', 'photobooth',
   'Een draaiende camera rond een platform die korte slow-motion video''s maakt om meteen te delen.',
   'vanaf', 399, null, null,
   array['Video''s om te delen op sociale media', 'Groot wow-effect'],
   array['Bedrijfsfeest', 'Fuif', 'Verjaardag'], 20, '[]'),
  ('springkasteel', 'Springkasteel huren', 'springkastelen',
   'Springkastelen in alle maten, van klein en veilig voor peuters tot grote combi''s voor schoolfeesten.',
   'vanaf', 125, null, 'Prijs per dag, levering apart.',
   array['Gecontroleerd materiaal', 'Geleverd en opgesteld'],
   array['Verjaardag', 'Communie', 'Schoolfeest', 'Wijkfeest'], 30, '[]'),
  ('dj', 'DJ boeken', 'dj',
   'Een DJ die de sfeer aanvoelt, met eigen geluid en licht naar keuze.',
   'vanaf', 450, null, 'Afhankelijk van duur, geluid en licht.',
   array['Muziek op maat van je publiek', 'Geluid en licht inbegrepen mogelijk'],
   array['Huwelijk', 'Personeelsfeest', 'Fuif'], 40, '[]'),
  ('partytent', 'Partytent huren', 'tenten',
   'Van een kleine 3x3 tot een grote feesttent voor honderden gasten, met vloer en verwarming als optie.',
   'range', 90, 2500, 'Sterk afhankelijk van afmeting, vloer en opbouw.',
   array['Opbouw door professionals', 'Vloer, verlichting en verwarming als optie'],
   array['Tuinfeest', 'Communie', 'Bedrijfsfeest'], 50, '[]'),
  ('walking-dinner', 'Walking dinner', 'traiteurs',
   'Kleine warme en koude gerechtjes die doorlopend rondgaan, ideaal om te mingelen.',
   'vanaf', 32, null, 'Prijs per persoon, excl. drank en personeel.',
   array['Geen vaste tafelschikking nodig', 'Vlot voor grote groepen'],
   array['Bedrijfsfeest', 'Huwelijk', 'Jubileum'], 60, '[]'),
  ('foodtruck', 'Foodtruck huren', 'foodtrucks',
   'Burgers, pizza, frietjes of iets anders: een foodtruck rijdt tot bij jou.',
   'op_aanvraag', null, null, null,
   array['Weinig opbouw', 'Snel voor grote groepen'],
   array['Personeelsfeest', 'Fuif', 'Wijkfeest'], 70, '[]')
) as v(slug, name, cat, descr, ptype, pfrom, pto, pnote, benefits, cases, ord, faq)
join public.categories c on c.slug = v.cat
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Demo-leveranciers. Status zetten we als postgres (admin-context).
-- ---------------------------------------------------------------------------
insert into public.suppliers (id, owner_profile_id, company_name, slug, description, contact_name, email, phone,
  enterprise_number, vat_number, primary_location_id, service_radius_km, max_capacity, status, terms_accepted_at)
select v.id::uuid, v.owner::uuid, v.name, v.slug, v.descr, v.contact, v.email, v.phone, v.kbo, v.vat,
       (select id from public.locations where slug = v.loc), v.radius, v.cap, v.status::public.supplier_status, now()
from (values
  ('00000000-0000-4000-8000-00000000c001', '00000000-0000-4000-8000-00000000b001', 'Demo Photobooth Waas', 'demo-photobooth-waas',
   'DEMO — fictieve photoboothverhuurder.', 'Demo Contact 1', 'photobooth@demo.waaslandevents.be', '+32 3 000 00 01',
   '0000.000.001', 'BE0000000001', 'beveren', 30, 400, 'actief'),
  ('00000000-0000-4000-8000-00000000c002', '00000000-0000-4000-8000-00000000b002', 'Demo Entertainment', 'demo-entertainment',
   'DEMO — fictief bureau voor DJ''s, springkastelen en photobooths.', 'Demo Contact 2', 'entertainment@demo.waaslandevents.be', '+32 3 000 00 02',
   '0000.000.002', 'BE0000000002', 'sint-niklaas', 25, 800, 'actief'),
  ('00000000-0000-4000-8000-00000000c003', '00000000-0000-4000-8000-00000000b003', 'Demo Catering', 'demo-catering',
   'DEMO — fictieve traiteur.', 'Demo Contact 3', 'catering@demo.waaslandevents.be', '+32 3 000 00 03',
   '0000.000.003', 'BE0000000003', 'temse', 35, 600, 'actief'),
  ('00000000-0000-4000-8000-00000000c004', '00000000-0000-4000-8000-00000000b004', 'Demo Tentenverhuur', 'demo-tentenverhuur',
   'DEMO — fictieve tentenverhuurder.', 'Demo Contact 4', 'tenten@demo.waaslandevents.be', '+32 3 000 00 04',
   '0000.000.004', 'BE0000000004', 'stekene', 40, 1000, 'actief'),
  ('00000000-0000-4000-8000-00000000c005', '00000000-0000-4000-8000-00000000b005', 'Demo Nieuwkomer', null,
   'DEMO — leverancier die nog gecontroleerd moet worden.', 'Demo Contact 5', 'nieuw@demo.waaslandevents.be', '+32 3 000 00 05',
   '0000.000.005', 'BE0000000005', 'lokeren', 20, 150, 'aanvraag_ontvangen')
) as v(id, owner, name, slug, descr, contact, email, phone, kbo, vat, loc, radius, cap, status)
on conflict (id) do nothing;

insert into public.supplier_categories (supplier_id, category_id)
select v.sid::uuid, c.id from (values
  ('00000000-0000-4000-8000-00000000c001', 'photobooth'),
  ('00000000-0000-4000-8000-00000000c002', 'entertainment'),   -- hoofdcategorie: dekt alle subcategorieën
  ('00000000-0000-4000-8000-00000000c003', 'traiteurs'),
  ('00000000-0000-4000-8000-00000000c003', 'foodtrucks'),
  ('00000000-0000-4000-8000-00000000c004', 'tenten'),
  ('00000000-0000-4000-8000-00000000c004', 'tafels'),
  ('00000000-0000-4000-8000-00000000c004', 'stoelen'),
  ('00000000-0000-4000-8000-00000000c005', 'photobooth')
) as v(sid, cat) join public.categories c on c.slug = v.cat
on conflict do nothing;

insert into public.supplier_locations (supplier_id, location_id)
select v.sid::uuid, l.id from (values
  ('00000000-0000-4000-8000-00000000c001', 'beveren'), ('00000000-0000-4000-8000-00000000c001', 'sint-niklaas'),
  ('00000000-0000-4000-8000-00000000c001', 'kruibeke'),
  ('00000000-0000-4000-8000-00000000c002', 'sint-niklaas'), ('00000000-0000-4000-8000-00000000c002', 'beveren'),
  ('00000000-0000-4000-8000-00000000c002', 'temse'), ('00000000-0000-4000-8000-00000000c002', 'stekene'),
  ('00000000-0000-4000-8000-00000000c003', 'temse'), ('00000000-0000-4000-8000-00000000c003', 'sint-niklaas'),
  ('00000000-0000-4000-8000-00000000c004', 'stekene'), ('00000000-0000-4000-8000-00000000c004', 'sint-gillis-waas')
) as v(sid, loc) join public.locations l on l.slug = v.loc
on conflict do nothing;

insert into public.supplier_products (id, supplier_id, category_id, product_type_id, name, description, price_type, price_from, capacity_max, status)
select v.id::uuid, v.sid::uuid, c.id, pt.id, v.name, v.descr, 'vanaf', v.price, v.cap, v.status::public.product_status
from (values
  ('00000000-0000-4000-8000-0000000d0001', '00000000-0000-4000-8000-00000000c001', 'photobooth', 'spiegelphotobooth', 'Spiegelbooth Deluxe (demo)', 'Demo-product', 329::numeric, 300, 'approved'),
  ('00000000-0000-4000-8000-0000000d0002', '00000000-0000-4000-8000-00000000c002', 'photobooth', 'spiegelphotobooth', 'Magic Mirror (demo)', 'Demo-product', 299, 400, 'approved'),
  ('00000000-0000-4000-8000-0000000d0003', '00000000-0000-4000-8000-00000000c002', 'dj', 'dj', 'DJ-set met licht (demo)', 'Demo-product', 450, 500, 'approved'),
  ('00000000-0000-4000-8000-0000000d0004', '00000000-0000-4000-8000-00000000c002', 'springkastelen', 'springkasteel', 'Springkasteel Kasteel (demo)', 'Demo-product', 125, 30, 'approved'),
  ('00000000-0000-4000-8000-0000000d0005', '00000000-0000-4000-8000-00000000c003', 'traiteurs', 'walking-dinner', 'Walking dinner (demo)', 'Demo-product', 34, 400, 'approved'),
  ('00000000-0000-4000-8000-0000000d0006', '00000000-0000-4000-8000-00000000c004', 'tenten', 'partytent', 'Feesttent 10x20 (demo)', 'Demo-product', 1450, 200, 'approved'),
  ('00000000-0000-4000-8000-0000000d0007', '00000000-0000-4000-8000-00000000c005', 'photobooth', 'spiegelphotobooth', 'Photobooth (demo, nog te keuren)', 'Demo-product', 249, 150, 'pending_review')
) as v(id, sid, cat, ptype, name, descr, price, cap, status)
join public.categories c on c.slug = v.cat
join public.product_types pt on pt.slug = v.ptype
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Demo-klanten en -aanvragen
-- ---------------------------------------------------------------------------
insert into public.customer_profiles (id, customer_type, organisation_name, full_name, email, phone) values
  ('00000000-0000-4000-8000-0000000e0001', 'particulier', null,               'Demo Klant Sarah', 'sarah@demo.invalid', '+32 470 00 00 01'),
  ('00000000-0000-4000-8000-0000000e0002', 'bedrijf',     'Demo Logistiek NV','Demo Klant Tom',   'tom@demo.invalid',   '+32 470 00 00 02'),
  ('00000000-0000-4000-8000-0000000e0003', 'school',      'Demo Basisschool', 'Demo Klant An',    'an@demo.invalid',    '+32 470 00 00 03')
on conflict do nothing;

insert into public.event_requests (id, customer_id, event_type_id, event_date, location_id, postal_code, indoor_outdoor, venue_kind,
  adults, children, guests_total, budget_min, budget_max, message, status, consent_at, consent_version, created_at)
select v.id::uuid, v.cid::uuid, et.id, v.d::date, l.id, v.pc, v.io::public.indoor_outdoor, v.vk::public.venue_kind,
       v.adults, v.kids, v.total, v.bmin, v.bmax, v.msg, v.status::public.request_status, now(), 'v1-concept', v.created::timestamptz
from (values
  ('00000000-0000-4000-8000-0000000f0001', '00000000-0000-4000-8000-0000000e0001', 'verjaardag', (current_date + 45)::text, 'beveren', '9120',
   'binnen', 'eigen_locatie', 40, 15, 55, 250::numeric, 400::numeric, 'Graag een photobooth voor de 40ste verjaardag van mijn man.', 'nieuw', (now() - interval '1 day')::text),
  ('00000000-0000-4000-8000-0000000f0002', '00000000-0000-4000-8000-0000000e0002', 'personeelsfeest', (current_date + 90)::text, 'sint-niklaas', '9100',
   'beide', 'externe_locatie', 120, 0, 120, 6000, 9000, 'Personeelsfeest met diner, DJ en photobooth. Locatie nog te bepalen.', 'in_behandeling', (now() - interval '3 days')::text),
  ('00000000-0000-4000-8000-0000000f0003', '00000000-0000-4000-8000-0000000e0003', 'schoolfeest', (current_date - 10)::text, 'temse', '9140',
   'buiten', 'eigen_locatie', 200, 300, 500, null, null, 'Schoolfeest met springkastelen.', 'gematcht', (now() - interval '60 days')::text)
) as v(id, cid, et, d, loc, pc, io, vk, adults, kids, total, bmin, bmax, msg, status, created)
join public.event_types et on et.slug = v.et
join public.locations l on l.slug = v.loc
on conflict (id) do nothing;

insert into public.event_request_items (id, request_id, category_id, product_type_id, notes)
select v.id::uuid, v.rid::uuid, c.id, pt.id, v.notes
from (values
  ('00000000-0000-4000-8000-0000000f1001', '00000000-0000-4000-8000-0000000f0001', 'photobooth', 'spiegelphotobooth', 'Avond van 20u tot 1u'),
  ('00000000-0000-4000-8000-0000000f2001', '00000000-0000-4000-8000-0000000f0002', 'traiteurs', 'walking-dinner', null),
  ('00000000-0000-4000-8000-0000000f2002', '00000000-0000-4000-8000-0000000f0002', 'dj', 'dj', null),
  ('00000000-0000-4000-8000-0000000f2003', '00000000-0000-4000-8000-0000000f0002', 'photobooth', null, null),
  ('00000000-0000-4000-8000-0000000f3001', '00000000-0000-4000-8000-0000000f0003', 'springkastelen', 'springkasteel', '3 à 4 springkastelen')
) as v(id, rid, cat, ptype, notes)
join public.categories c on c.slug = v.cat
left join public.product_types pt on pt.slug = v.ptype
on conflict (id) do nothing;

insert into public.request_notes (request_id, author_id, body) values
  ('00000000-0000-4000-8000-0000000f0002', '00000000-0000-4000-8000-00000000a001', 'Klant lijkt prijsgevoelig voor catering. Bij voorkeur leverancier met eigen personeel.');

-- Lead + gewonnen opdracht + commissie voor het (voorbije) schoolfeest.
select public.assign_leads('00000000-0000-4000-8000-0000000f3001', array['00000000-0000-4000-8000-00000000c002'::uuid]);
select public.mark_lead_won(
  (select id from public.lead_assignments where request_item_id = '00000000-0000-4000-8000-0000000f3001'),
  current_date - 10, 750, 'Demo: 4 springkastelen');
select public.confirm_revenue(
  (select b.id from public.bookings b join public.lead_assignments la on la.id = b.assignment_id
    where la.request_item_id = '00000000-0000-4000-8000-0000000f3001'),
  750, 0, 'Demo-omzet');
