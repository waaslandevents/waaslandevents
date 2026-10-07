-- ============================================================================
-- WaaslandEvents — databasetests voor de 10 testscenario's uit spec §55
-- en de acceptatiecriteria uit §80.
-- Draait op een database met migraties + seed. Elke fout stopt het script.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/flow_test.sql
-- ============================================================================
\set ON_ERROR_STOP 1

create schema if not exists tests;
grant usage on schema tests to public;

create or replace function tests.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'FAIL: %', msg; end if;
  raise notice 'ok - %', msg;
end $$;

-- Verwacht dat een statement faalt (geeft de foutmelding terug)
create or replace function tests.throws(sql text, msg text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    raise notice 'ok - % (geweigerd: %)', msg, sqlerrm;
    return;
  end;
  raise exception 'FAIL: % — statement werd NIET geweigerd', msg;
end $$;

-- Gebruiker wisselen zoals Supabase/PostgREST dat doet
create or replace function tests.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), false);
  perform set_config('request.jwt.claim.role', case when p_uid is null then 'anon' else 'authenticated' end, false);
end $$;
grant execute on all functions in schema tests to public;

-- Vaste id's uit seed.sql
\set admin    '''00000000-0000-4000-8000-00000000a001'''
\set u_photo  '''00000000-0000-4000-8000-00000000b001'''
\set u_ent    '''00000000-0000-4000-8000-00000000b002'''
\set u_cat    '''00000000-0000-4000-8000-00000000b003'''
\set u_new    '''00000000-0000-4000-8000-00000000b005'''
\set s_photo  '''00000000-0000-4000-8000-00000000c001'''
\set s_ent    '''00000000-0000-4000-8000-00000000c002'''
\set s_cat    '''00000000-0000-4000-8000-00000000c003'''
\set s_tent   '''00000000-0000-4000-8000-00000000c004'''
\set s_new    '''00000000-0000-4000-8000-00000000c005'''

-- ---------------------------------------------------------------------------
\echo '== Scenario 1: particulier vraagt photobooth aan → aanvraag opgeslagen'
-- (In productie doet de server route dit met de service role na validatie.)
reset role;
create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to public;
with c as (
  insert into public.customer_profiles (full_name, email, phone)
  values ('Test Particulier', 'test1@example.invalid', '+32 470 11 11 11') returning id
), r as (
  insert into public.event_requests (customer_id, event_type_id, event_date, location_id, postal_code, guests_total,
                                     message, consent_at, consent_version)
  select c.id, (select id from public.event_types where slug = 'verjaardag'), current_date + 30,
         (select id from public.locations where slug = 'melsele'), '9120', 60, 'Photobooth graag', now(), 'v1-concept'
  from c returning id, reference
), i as (
  insert into public.event_request_items (request_id, category_id, product_type_id)
  select r.id, (select id from public.categories where slug = 'photobooth'),
         (select id from public.product_types where slug = 'spiegelphotobooth') from r returning id, request_id
)
insert into t_ids select 'req1', request_id from i union all select 'item1', id from i;

select tests.ok((select status = 'nieuw' from public.event_requests where id = (select v from t_ids where k='req1')),
  'aanvraag staat op status nieuw');
select tests.ok((select reference ~ '^WE-\d{4}-\d{5}$' from public.event_requests where id = (select v from t_ids where k='req1')),
  'aanvraag kreeg een referentie');

\echo '== Anon kan aanvragen, leveranciers en klantgegevens NIET lezen'
set role anon; select tests.login(null);
select tests.ok((select count(*) from public.event_requests) = 0, 'anon ziet geen aanvragen');
select tests.ok((select count(*) from public.suppliers) = 0, 'anon ziet geen leveranciers (geen publieke directory)');
select tests.ok((select count(*) from public.supplier_products) = 0, 'anon ziet geen leveranciersproducten');
select tests.ok((select count(*) from public.customer_profiles) = 0, 'anon ziet geen klantgegevens');
select tests.ok((select count(*) from public.product_types) >= 5, 'anon ziet neutrale producttypes');
select tests.ok((select count(*) from public.categories) >= 8, 'anon ziet categorieën');
select tests.throws($$insert into public.event_requests (customer_id, consent_at, consent_version)
  values ('00000000-0000-4000-8000-0000000e0001', now(), 'x')$$, 'anon kan niet rechtstreeks een aanvraag invoegen');

-- ---------------------------------------------------------------------------
\echo '== Scenario 2: bedrijf vraagt volledige eventbegeleiding → meerdere categorieën'
reset role; select tests.login(null);
select tests.ok((select count(*) from public.event_request_items where request_id = '00000000-0000-4000-8000-0000000f0002') = 3,
  'bedrijfsaanvraag heeft 3 categorieën (catering, DJ, photobooth)');

-- ---------------------------------------------------------------------------
\echo '== Scenario 3: admin koppelt leveranciers aan categorie → leveranciers ontvangen lead'
set role authenticated; select tests.login(:admin);
select tests.ok((select count(*) from public.match_candidates((select v from t_ids where k='item1'))) >= 2,
  'shortlist toont kandidaten voor photobooth');
select tests.ok(not exists (select 1 from public.match_candidates((select v from t_ids where k='item1')) where supplier_id = :s_new),
  'niet-goedgekeurde leverancier staat niet op de shortlist');
select tests.ok((select serves_location from public.match_candidates((select v from t_ids where k='item1')) where supplier_id = :s_photo),
  'werkgebied: deelgemeente Melsele valt onder Beveren');

select count(*) from public.assign_leads((select v from t_ids where k='item1'), array[:s_photo::uuid, :s_ent::uuid]);
select tests.ok((select count(*) from public.lead_assignments where request_item_id = (select v from t_ids where k='item1')) = 2,
  '2 leads toegewezen');
select tests.ok((select status = 'gematcht' from public.event_requests where id = (select v from t_ids where k='req1')),
  'aanvraag gaat naar gematcht');
select tests.ok((select count(*) from public.notifications where profile_id = :u_photo and type = 'lead_nieuw') >= 1,
  'leverancier kreeg een melding');
select tests.ok((select attribution_until >= current_date + 360 from public.lead_assignments
                 where request_item_id = (select v from t_ids where k='item1') and supplier_id = :s_photo),
  'leadbescherming 12 maanden gezet');

\echo '== Max 3 per categorie'
reset role; select tests.login(null);
-- tijdelijk een extra actieve photobooth-leverancier om de limiet te testen
update public.suppliers set status = 'actief' where id = :s_new;
set role authenticated; select tests.login(:admin);
select count(*) from public.assign_leads('00000000-0000-4000-8000-0000000f2003',
  array[:s_photo::uuid, :s_ent::uuid, :s_new::uuid]);
select tests.throws($$select public.assign_leads('00000000-0000-4000-8000-0000000f2003',
  array['00000000-0000-4000-8000-00000000c004'::uuid])$$, 'vierde leverancier voor dezelfde categorie wordt geweigerd');
select tests.throws($$select public.assign_leads('00000000-0000-4000-8000-0000000f2001',
  array['00000000-0000-4000-8000-00000000c004'::uuid])$$, 'leverancier buiten de categorie wordt geweigerd');
reset role; select tests.login(null);
update public.suppliers set status = 'aanvraag_ontvangen' where id = :s_new;

\echo '== Leverancier kan zelf geen leads toewijzen'
set role authenticated; select tests.login(:u_cat);
select tests.throws($$select public.assign_leads('00000000-0000-4000-8000-0000000f2001',
  array['00000000-0000-4000-8000-00000000c003'::uuid])$$, 'leverancier kan geen lead aan zichzelf toewijzen');
select tests.throws($$insert into public.lead_assignments (request_item_id, request_id, supplier_id, attribution_until)
  values ('00000000-0000-4000-8000-0000000f2001', '00000000-0000-4000-8000-0000000f0002',
          '00000000-0000-4000-8000-00000000c003', current_date)$$, 'rechtstreekse insert in leads geweigerd');

-- ---------------------------------------------------------------------------
\echo '== Scenario 4: leverancier volgt lead op → status verandert'
set role authenticated; select tests.login(:u_photo);
select tests.ok((select count(*) from public.v_supplier_leads) = 2, 'leverancier ziet zijn 2 leads');
select tests.ok((select customer_email from public.v_supplier_leads where request_id = (select v from t_ids where k='req1'))
                = 'test1@example.invalid', 'leverancier ziet klantgegevens van een toegewezen lead');
select tests.ok((select count(*) from public.event_request_items
                  where request_id = '00000000-0000-4000-8000-0000000f0002') = 1,
  'leverancier ziet enkel het item (photobooth) waarvoor hij gekozen werd, niet catering/DJ');
select public.set_lead_status((select assignment_id from public.v_supplier_leads where request_id = (select v from t_ids where k='req1')),
  'contact_opgenomen', 'Klant gebeld');
select tests.ok((select status = 'contact_opgenomen' from public.v_supplier_leads where request_id = (select v from t_ids where k='req1')),
  'status gewijzigd naar contact opgenomen');
select tests.ok((select count(*) from public.lead_status_history h join public.v_supplier_leads l on l.assignment_id = h.assignment_id
                 where l.request_id = (select v from t_ids where k='req1')) = 2, 'statushistoriek bijgehouden');

\echo '== Rechtstreekse wijziging van een lead door leverancier heeft geen effect'
reset role; select tests.login(null);
create or replace function tests.rows(sql text) returns bigint language plpgsql as $$
declare n bigint;
begin execute sql; get diagnostics n = row_count; return n; end $$;
grant execute on function tests.rows(text) to public;
set role authenticated; select tests.login(:u_photo);
select tests.ok(tests.rows($$update public.lead_assignments set status = 'gewonnen'$$) = 0,
  'UPDATE op leads raakt 0 rijen (enkel via RPC)');
select tests.throws($$select public.set_lead_status((select assignment_id from public.v_supplier_leads limit 1), 'gewonnen')$$,
  '"gewonnen" kan niet via gewone statuswijziging');

-- ---------------------------------------------------------------------------
\echo '== Scenario 10: onbevoegde leverancier probeert andere leadgegevens te bekijken'
set role authenticated; select tests.login(:u_cat);
select tests.ok((select count(*) from public.v_supplier_leads) = 0, 'Demo Catering ziet geen leads van anderen');
select tests.ok((select count(*) from public.event_requests) = 0, 'Demo Catering ziet geen aanvragen van anderen');
select tests.ok((select count(*) from public.customer_profiles) = 0, 'Demo Catering ziet geen klantgegevens');
select tests.ok((select count(*) from public.suppliers) = 1, 'Demo Catering ziet enkel het eigen bedrijf');
select tests.ok((select count(*) from public.request_notes) = 0, 'interne notities onzichtbaar voor leverancier');
select tests.ok((select count(*) from public.commission_records) = 0, 'commissies van anderen onzichtbaar');
select tests.throws($$select public.set_lead_status((select id from public.lead_assignments limit 1), 'verloren')$$,
  'statuswijziging op andermans lead geweigerd');
select tests.throws(format($$select public.set_lead_status(%L, 'verloren')$$,
  (select id from public.lead_assignments where supplier_id = '00000000-0000-4000-8000-00000000c001' limit 1)),
  'RPC op andermans lead-ID geweigerd');
select tests.throws($$select * from public.match_candidates('00000000-0000-4000-8000-0000000f2001')$$,
  'leverancier kan de shortlist niet opvragen');
-- Ook een leverancier die wél een lead kreeg, ziet de interne notitie niet
select tests.login(:u_ent);
select tests.ok((select count(*) from public.request_notes) = 0, 'interne notities onzichtbaar, ook voor toegewezen leverancier');
select tests.ok((select count(*) from public.lead_assignments la where la.supplier_id <> :s_ent) = 0,
  'leverancier ziet geen toewijzingen van concurrenten op dezelfde aanvraag');

-- ---------------------------------------------------------------------------
\echo '== Scenario 5: leverancier wint opdracht → opdracht + commissierecord'
set role authenticated; select tests.login(:u_photo);
select tests.throws($$select public.mark_lead_won((select assignment_id from public.v_supplier_leads
   where reference like 'WE-%' and booking_id is null and event_type = 'Verjaardag' and customer_email = 'test1@example.invalid'), current_date + 30, -5)$$,
  'negatief bedrag geweigerd');
select (public.mark_lead_won((select assignment_id from public.v_supplier_leads where customer_email = 'test1@example.invalid'),
   current_date + 30, 2000, 'Spiegelbooth 5u')).id;
select tests.ok((select status = 'event_gepland' from public.v_supplier_leads where customer_email = 'test1@example.invalid'),
  'lead staat op event gepland');
select tests.ok((select c.status = 'wacht_op_event' and c.rate = 0.125 from public.commission_records c
                 join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 2000),
  'commissierecord: wacht op event, tarief 12,5% vastgelegd');
select tests.throws($$select public.mark_lead_won((select assignment_id from public.v_supplier_leads
   where customer_email = 'test1@example.invalid'), current_date + 30, 2000)$$, 'dubbele registratie geweigerd');
select tests.throws($$select public.confirm_revenue((select id from public.bookings where agreed_net_amount = 2000), 2000, 0)$$,
  'omzet bevestigen vóór het event geweigerd');

-- ---------------------------------------------------------------------------
\echo '== Scenario 6: event is afgelopen → systeem vraagt definitieve omzet'
reset role; select tests.login(null);
update public.bookings set event_date = current_date - 1 where agreed_net_amount = 2000;
select tests.ok((select count(*) from public.process_due_bookings() where action = 'omzet_opvragen') = 1,
  'dagelijkse job zet 1 opdracht op omzet opvragen');
select tests.ok((select c.status = 'omzet_opvragen' and c.revenue_requested_at is not null from public.commission_records c
                 join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 2000), 'commissie: omzet opvragen');
select tests.ok((select la.status = 'event_afgerond' from public.lead_assignments la join public.bookings b on b.assignment_id = la.id
                 where b.agreed_net_amount = 2000), 'lead: event afgerond');
select tests.ok((select count(*) from public.notifications where profile_id = :u_photo and type = 'omzet_opvragen') = 1,
  'leverancier kreeg melding om omzet te bevestigen');
set role authenticated; select tests.login(:u_photo);
select tests.throws($$select public.process_due_bookings()$$, 'leverancier kan de systeemjob niet starten');

-- ---------------------------------------------------------------------------
\echo '== Scenario 7: creditnota → commissie correct verminderd (spec-voorbeeld)'
select tests.throws($$select public.confirm_revenue((select id from public.bookings where agreed_net_amount = 2000), 2000, 2500)$$,
  'creditnota groter dan omzet geweigerd');
select public.confirm_revenue((select id from public.bookings where agreed_net_amount = 2000), 2000, 250, 'Klein deel teruggestort');
select tests.ok((select c.base_amount = 1750 and c.commission_amount = 218.75 and c.status = 'commissie_berekend'
                 from public.commission_records c join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 2000),
  '€2.000 − €250 = €1.750 × 12,5% = €218,75');
select tests.ok((select status = 'omzet_geregistreerd' from public.v_supplier_leads where customer_email = 'test1@example.invalid'),
  'lead: omzet geregistreerd');
select tests.throws($$select public.confirm_revenue((select id from public.bookings where agreed_net_amount = 2000), 100, 0)$$,
  'leverancier kan bevestigde omzet niet nadien verlagen');
select tests.ok(tests.rows($$update public.commission_records set commission_amount = 0$$) = 0,
  'leverancier kan commissiebedrag niet rechtstreeks aanpassen');
select tests.throws($$select public.add_commission_adjustment((select id from public.commission_records limit 1), 'creditnota', 10, 'x')$$,
  'leverancier kan zelf geen correctie boeken');

\echo '== Creditnota achteraf (admin) + factuur + betaald + creditering'
select tests.login(:admin);
select public.set_commission_status((select c.id from public.commission_records c join public.bookings b on b.id = c.booking_id
  where b.agreed_net_amount = 2000), 'factuur_opgesteld', 'WE-2026-0001');
select public.set_commission_status((select c.id from public.commission_records c join public.bookings b on b.id = c.booking_id
  where b.agreed_net_amount = 2000), 'betaald');
select public.add_commission_adjustment((select c.id from public.commission_records c join public.bookings b on b.id = c.booking_id
  where b.agreed_net_amount = 2000), 'creditnota', 150, 'Extra creditnota na klacht');
select tests.ok((select c.base_amount = 1600 and c.commission_amount = 200 and c.status = 'gecrediteerd'
                 from public.commission_records c join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 2000),
  'creditnota na betaling: grondslag €1.600 → €200, status gecrediteerd');

\echo '== Geen event = geen commissie'
select count(*) from public.assign_leads('00000000-0000-4000-8000-0000000f2002', array[:s_ent::uuid]);
select tests.login(:u_ent);
select (public.mark_lead_won((select assignment_id from public.v_supplier_leads where category_name = 'DJ'), null, 900)).id;
select public.cancel_booking((select booking_id from public.v_supplier_leads where category_name = 'DJ'), 'Klant annuleerde het feest');
select tests.ok((select c.status = 'vervallen' and c.commission_amount = 0 from public.commission_records c
                 join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 900),
  'geannuleerde opdracht → commissie vervallen');
select tests.ok((select status = 'verloren' from public.v_supplier_leads where category_name = 'DJ'), 'lead → verloren');

\echo '== Leverancier betwist commissie'
select tests.ok((select c.status = 'commissie_berekend' and c.commission_amount = 93.75 from public.commission_records c
                 join public.bookings b on b.id = c.booking_id where b.agreed_net_amount = 750), 'demo-commissie €750 → €93,75');
select public.set_commission_status((select c.id from public.commission_records c join public.bookings b on b.id = c.booking_id
  where b.agreed_net_amount = 750), 'betwist', null, 'Eén springkasteel werd niet gebruikt');
select tests.throws($$select public.set_commission_status((select c.id from public.commission_records c join public.bookings b
  on b.id = c.booking_id where b.agreed_net_amount = 750), 'betaald')$$, 'leverancier kan commissie niet op betaald zetten');

-- ---------------------------------------------------------------------------
\echo '== Scenario 9: product wordt aangepast → opnieuw naar admin review'
set role authenticated; select tests.login(:u_photo);
update public.supplier_products set price_from = 349 where id = '00000000-0000-4000-8000-0000000d0001';
select tests.ok((select status = 'pending_review' from public.supplier_products where id = '00000000-0000-4000-8000-0000000d0001'),
  'aangepast goedgekeurd product staat terug op pending review');
select tests.throws($$update public.supplier_products set status = 'approved' where id = '00000000-0000-4000-8000-0000000d0001'$$,
  'leverancier kan eigen product niet goedkeuren');
select tests.throws($$insert into public.supplier_products (supplier_id, category_id, name)
  values ('00000000-0000-4000-8000-00000000c002', (select id from public.categories where slug = 'dj'), 'Hack')$$,
  'leverancier kan geen product toevoegen bij een ander bedrijf');
select tests.login(:admin);
update public.supplier_products set status = 'approved' where id = '00000000-0000-4000-8000-0000000d0001';
select tests.ok((select status = 'approved' and reviewed_by = :admin::uuid from public.supplier_products
                 where id = '00000000-0000-4000-8000-0000000d0001'), 'admin keurt opnieuw goed');

\echo '== Onboarding: leverancier kan eigen status niet op actief zetten'
select tests.login(:u_new);
select tests.throws($$update public.suppliers set status = 'actief' where id = '00000000-0000-4000-8000-00000000c005'$$,
  'leverancier kan zichzelf niet activeren');
select tests.throws($$update public.suppliers set verified_at = now() where id = '00000000-0000-4000-8000-00000000c005'$$,
  'leverancier kan zichzelf geen partnerbadge geven');
select tests.throws($$update public.profiles set role = 'admin' where id = auth.uid()$$, 'leverancier kan zichzelf geen admin maken');

-- ---------------------------------------------------------------------------
\echo '== Scenario 8: leverancier wordt gedeactiveerd → verborgen, niet meer gematcht'
set role authenticated; select tests.login(:u_ent);
select public.request_supplier_stop(:s_ent);
reset role; select tests.login(null);
select tests.ok((select count(*) from public.process_supplier_deactivations()) = 0, 'binnen de grace-week nog niet gedeactiveerd');
update public.suppliers set deactivation_requested_at = now() - interval '8 days' where id = :s_ent;
select tests.ok((select count(*) from public.process_supplier_deactivations()) = 1, 'na 7 dagen gedeactiveerd');
select tests.ok((select status = 'gedeactiveerd' and deactivated_at is not null from public.suppliers where id = :s_ent),
  'status gedeactiveerd');
set role authenticated; select tests.login(:admin);
select tests.ok(not exists (select 1 from public.match_candidates('00000000-0000-4000-8000-0000000f2003') where supplier_id = :s_ent),
  'gedeactiveerde leverancier staat niet meer op de shortlist');
select tests.throws($$select public.assign_leads('00000000-0000-4000-8000-0000000f2002', array['00000000-0000-4000-8000-00000000c002'::uuid])$$,
  'gedeactiveerde leverancier kan geen lead meer krijgen');
select tests.ok((select count(*) from public.commission_records where supplier_id = :s_ent) >= 2,
  'commissiehistoriek blijft bewaard');
select tests.login(:u_ent);
select tests.ok((select count(*) from public.v_supplier_leads) >= 1, 'gedeactiveerde leverancier ziet nog zijn historiek');

-- ---------------------------------------------------------------------------
\echo '== Reviews: enkel voor partners die aan de aanvraag gekoppeld waren'
reset role; select tests.login(null);
select tests.throws($$insert into public.reviews (request_id, supplier_id, customer_id, score)
  values ('00000000-0000-4000-8000-0000000f0003', '00000000-0000-4000-8000-00000000c004', '00000000-0000-4000-8000-0000000e0003', 5)$$,
  'review voor niet-gekoppelde leverancier geweigerd');
insert into public.reviews (request_id, supplier_id, customer_id, score, body, status)
values ('00000000-0000-4000-8000-0000000f0003', :s_ent, '00000000-0000-4000-8000-0000000e0003', 5, 'Top!', 'approved');
select tests.ok((select status = 'pending' from public.reviews where request_id = '00000000-0000-4000-8000-0000000f0003'),
  'nieuwe review start altijd als pending (moderatie)');

\echo '== Controle op zelfgerapporteerde omzet'
insert into public.customer_feedback (request_id, booked_supplier_id)
values ((select v from t_ids where k='req1'), :s_ent);
select tests.ok((select count(*) from public.v_attribution_flags where supplier_id = :s_ent) = 1,
  'klant zegt Demo Entertainment geboekt te hebben zonder geregistreerde opdracht → vlag');

-- ---------------------------------------------------------------------------
\echo '== KPI- en dashboardviews'
set role authenticated; select tests.login(:admin);
select tests.ok((select realized_revenue = 1600 + 750 and commission_revenue = 200 + 93.75 from public.v_admin_kpis),
  'admin-KPI: gerealiseerde omzet €2.350, commissie €293,75');
select tests.ok((select count(*) from public.v_admin_monthly) = 12, 'maandoverzicht: 12 maanden');
select tests.login(:u_photo);
select tests.ok((select won_jobs = 1 and commission_paid = 200 and realized_revenue = 1600 from public.v_supplier_dashboard),
  'leveranciersdashboard klopt');
select tests.ok((select count(*) from public.v_admin_commissions) = 1, 'leverancier ziet via adminview enkel zijn eigen commissie');

\echo '== Audit log'
reset role; select tests.login(null);
select tests.ok((select count(*) from public.audit_logs where action in ('lead_toegewezen', 'opdracht_gewonnen', 'omzet_bevestigd',
  'commissie_aangepast', 'leverancier_status:gedeactiveerd', 'product_status:approved', 'review_status:approved')) >= 7,
  'belangrijke acties staan in de audit log');
set role authenticated; select tests.login(:u_photo);
select tests.ok((select count(*) from public.audit_logs) = 0, 'leverancier kan de audit log niet lezen');
select tests.throws($$select public.log_audit('hack', 'x', null)$$, 'leverancier kan niet in de audit log schrijven');

\echo '== GDPR: anonimiseren behoudt commissiehistoriek'
select tests.login(:admin);
select public.anonymize_customer('00000000-0000-4000-8000-0000000e0003');
reset role; select tests.login(null);
select tests.ok((select full_name = 'Geanonimiseerd' and phone is null from public.customer_profiles
                 where id = '00000000-0000-4000-8000-0000000e0003'), 'klant geanonimiseerd');
select tests.ok((select count(*) from public.commission_records c join public.bookings b on b.id = c.booking_id
                 where b.request_id = '00000000-0000-4000-8000-0000000f0003') = 1, 'commissie blijft bewaard');

\echo ''
\echo 'ALLE TESTS GESLAAGD'
