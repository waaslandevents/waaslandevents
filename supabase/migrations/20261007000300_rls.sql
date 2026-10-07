-- ============================================================================
-- WaaslandEvents — 0003 Row Level Security
--
-- Uitgangspunten (spec §35, §67)
--  * RLS staat aan op ELKE tabel. Geen policy = geen toegang.
--  * Publiek (anon) leest alleen gepubliceerde catalogus- en contentdata.
--    Er is géén publieke toegang tot leveranciers of hun producten
--    → geen publieke leveranciersdirectory.
--  * Aanvragen, reviews en analytics worden door de server ingevoegd
--    (service role, na validatie + rate limiting + captcha).
--  * Een leverancier ziet enkel rijen van zijn eigen bedrijf en enkel
--    aanvragen/klantgegevens die expliciet aan hem zijn toegewezen.
--  * Leads, opdrachten en commissies wijzigt een leverancier enkel via RPC.
-- ============================================================================

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Basisrechten: RLS doet het eigenlijke filterwerk.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
revoke all on public.audit_logs from authenticated, anon;
grant select on public.audit_logs to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: overal volledige toegang
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('create policy admin_all on public.%I for all to authenticated
                    using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- Instellingen: alleen super admin schrijft. Publieke sleutels leesbaar.
drop policy admin_all on public.platform_settings;
create policy settings_read_admin on public.platform_settings for select to authenticated using (public.is_admin());
create policy settings_read_public on public.platform_settings for select to anon, authenticated using (is_public);
create policy settings_write_admin on public.platform_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Audit log: alleen lezen door admin; schrijven gebeurt via security-definer functies.
drop policy admin_all on public.audit_logs;
create policy audit_read_admin on public.audit_logs for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Publieke catalogus en content
-- ---------------------------------------------------------------------------
create policy public_read on public.locations     for select to anon, authenticated using (is_active);
create policy public_read on public.categories    for select to anon, authenticated using (is_active);
create policy public_read on public.event_types   for select to anon, authenticated using (is_active);
create policy public_read on public.product_types for select to anon, authenticated using (is_active);
create policy public_read on public.faqs          for select to anon, authenticated using (is_active);
create policy public_read on public.cms_blocks    for select to anon, authenticated using (true);
create policy public_read on public.posts         for select to anon, authenticated
  using (status = 'published' and published_at <= now());
create policy public_read on public.seo_landing_pages for select to anon, authenticated using (status = 'published');
create policy public_read on public.legal_documents   for select to anon, authenticated using (published_at is not null);
create policy public_read on public.media for select to anon, authenticated using (is_public and deleted_at is null);
-- Goedgekeurde reviews zijn publiek (zonder leveranciersnaam: de site toont ze per categorie/product).
create policy public_read on public.reviews for select to anon, authenticated using (status = 'approved');

-- ---------------------------------------------------------------------------
-- Eigen profiel
-- ---------------------------------------------------------------------------
create policy own_read   on public.profiles for select to authenticated using (id = auth.uid());
create policy own_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy own_read on public.notifications for select to authenticated using (profile_id = auth.uid());
create policy own_update on public.notifications for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy own_read on public.legal_acceptances for select to authenticated
  using (profile_id = auth.uid() or supplier_id in (select public.my_supplier_ids()));
create policy supplier_insert on public.legal_acceptances for insert to authenticated
  with check (profile_id = auth.uid() and (supplier_id is null or public.owns_supplier(supplier_id)));

-- ---------------------------------------------------------------------------
-- Leverancier: eigen bedrijf en aanbod
-- ---------------------------------------------------------------------------
create policy own_read on public.suppliers for select to authenticated using (owner_profile_id = auth.uid());
create policy own_insert on public.suppliers for insert to authenticated
  with check (owner_profile_id = auth.uid() and public.my_role() = 'supplier');
create policy own_update on public.suppliers for update to authenticated
  using (owner_profile_id = auth.uid()) with check (owner_profile_id = auth.uid());

create policy own_all on public.supplier_categories for all to authenticated
  using (public.owns_supplier(supplier_id)) with check (public.owns_supplier(supplier_id));
create policy own_all on public.supplier_event_types for all to authenticated
  using (public.owns_supplier(supplier_id)) with check (public.owns_supplier(supplier_id));
create policy own_all on public.supplier_locations for all to authenticated
  using (public.owns_supplier(supplier_id)) with check (public.owns_supplier(supplier_id));

create policy own_read on public.supplier_products for select to authenticated using (public.owns_supplier(supplier_id));
create policy own_insert on public.supplier_products for insert to authenticated with check (public.owns_supplier(supplier_id));
create policy own_update on public.supplier_products for update to authenticated
  using (public.owns_supplier(supplier_id)) with check (public.owns_supplier(supplier_id));
-- Geen DELETE: archiveren i.p.v. verwijderen (historiek).

create policy own_all on public.media for all to authenticated
  using (supplier_id is not null and public.owns_supplier(supplier_id))
  with check (supplier_id is not null and public.owns_supplier(supplier_id) and is_public = false);

-- ---------------------------------------------------------------------------
-- Leverancier: enkel toegewezen leads (spec §35, §67, testscenario 10)
-- ---------------------------------------------------------------------------
create policy supplier_read on public.lead_assignments for select to authenticated
  using (supplier_id in (select public.my_supplier_ids()));
-- Geen insert/update/delete voor leveranciers: via RPC's.

create policy supplier_read on public.lead_status_history for select to authenticated
  using (assignment_id in (select id from public.lead_assignments
                           where supplier_id in (select public.my_supplier_ids())));

create policy supplier_read on public.event_requests for select to authenticated
  using (deleted_at is null and id in (select request_id from public.lead_assignments
                                       where supplier_id in (select public.my_supplier_ids())));

-- Enkel de items (categorieën) waarvoor deze leverancier gekozen werd.
create policy supplier_read on public.event_request_items for select to authenticated
  using (id in (select request_item_id from public.lead_assignments
                where supplier_id in (select public.my_supplier_ids())));

create policy supplier_read on public.customer_profiles for select to authenticated
  using (id in (select r.customer_id from public.event_requests r
                join public.lead_assignments la on la.request_id = r.id
                where la.supplier_id in (select public.my_supplier_ids())));

create policy supplier_read on public.bookings for select to authenticated
  using (supplier_id in (select public.my_supplier_ids()));
create policy supplier_read on public.commission_records for select to authenticated
  using (supplier_id in (select public.my_supplier_ids()));
create policy supplier_read on public.commission_adjustments for select to authenticated
  using (commission_id in (select id from public.commission_records
                           where supplier_id in (select public.my_supplier_ids())));
create policy supplier_read on public.reviews for select to authenticated
  using (supplier_id in (select public.my_supplier_ids()));

-- Bewust GEEN leverancierstoegang tot: request_notes, supplier_admin_notes,
-- customer_feedback, feedback_invites, email_logs, analytics_events,
-- audit_logs. Die zijn intern (spec §67–68).

-- ---------------------------------------------------------------------------
-- Functies: execute-rechten expliciet
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.my_role(), public.is_admin(), public.is_super_admin(), public.is_privileged(),
  public.is_staff(), public.is_system_caller(),
  public.my_supplier_ids(), public.owns_supplier(uuid), public.setting_numeric(text),
  public.distance_km(numeric, numeric, numeric, numeric), public.calc_commission(numeric, numeric),
  public.mark_lead_viewed(uuid), public.set_lead_status(uuid, public.lead_status, text),
  public.mark_lead_won(uuid, date, numeric, text), public.cancel_booking(uuid, text),
  public.confirm_revenue(uuid, numeric, numeric, text),
  public.set_commission_status(uuid, public.commission_status, text, text),
  public.request_supplier_stop(uuid),
  public.add_commission_adjustment(uuid, public.adjustment_type, numeric, text),
  public.match_candidates(uuid), public.assign_leads(uuid, uuid[]),
  public.anonymize_customer(uuid)
to authenticated;
-- RLS-helpers worden ook in anon-policies geëvalueerd
grant execute on function public.is_admin(), public.my_supplier_ids(), public.owns_supplier(uuid),
  public.my_role(), public.calc_commission(numeric, numeric) to anon;
grant execute on all functions in schema public to service_role;
-- Interne hulpfuncties niet rechtstreeks aanroepbaar
revoke execute on function public.log_audit(text, text, uuid, jsonb, jsonb) from authenticated;
revoke execute on function public.notify_supplier(uuid, text, text, text, text) from authenticated;
revoke execute on function public.recalc_commission(uuid) from authenticated;
revoke execute on function public.process_due_bookings() from authenticated;
revoke execute on function public.process_supplier_deactivations() from authenticated;

grant select on public.v_supplier_leads, public.v_supplier_dashboard,
  public.v_admin_commissions, public.v_admin_kpis, public.v_admin_monthly,
  public.v_attribution_flags, public.admin_users to authenticated;
revoke select on public.v_supplier_leads, public.v_supplier_dashboard,
  public.v_admin_commissions, public.v_admin_kpis, public.v_admin_monthly,
  public.v_attribution_flags, public.admin_users from anon;

-- ---------------------------------------------------------------------------
-- Storage: publieke beelden (catalogus) en privé leveranciersuploads
--   public-media/…                 → leesbaar voor iedereen, schrijven = admin
--   supplier-uploads/<supplier_id>/… → leverancier schrijft eigen map, admin leest;
--                                     na goedkeuring kopieert admin naar public-media
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values
  ('public-media', 'public-media', true),
  ('supplier-uploads', 'supplier-uploads', false)
on conflict (id) do nothing;

create policy "public-media lezen" on storage.objects for select to anon, authenticated
  using (bucket_id = 'public-media');
create policy "public-media admin" on storage.objects for all to authenticated
  using (bucket_id = 'public-media' and public.is_admin())
  with check (bucket_id = 'public-media' and public.is_admin());
create policy "supplier-uploads eigen map" on storage.objects for all to authenticated
  using (bucket_id = 'supplier-uploads'
         and ((storage.foldername(name))[1] in (select id::text from public.my_supplier_ids() as id) or public.is_admin()))
  with check (bucket_id = 'supplier-uploads'
         and ((storage.foldername(name))[1] in (select id::text from public.my_supplier_ids() as id) or public.is_admin()));
