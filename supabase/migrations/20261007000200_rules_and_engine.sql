-- ============================================================================
-- WaaslandEvents — 0002 bedrijfsregels, lead-engine en commissie-engine
--
-- Principe: wat een leverancier mag veranderen, loopt via security-definer
-- RPC's die zelf de toegang controleren. Rechtstreekse UPDATE op leads,
-- opdrachten en commissies is voor leveranciers niet toegestaan (zie RLS).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.my_role()
returns public.app_role language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and deleted_at is null
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('admin', 'super_admin') from public.profiles
                   where id = auth.uid() and deleted_at is null), false)
$$;

create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'super_admin' from public.profiles
                   where id = auth.uid() and deleted_at is null), false)
$$;

-- Systeemaanroep: server met service-role-sleutel, of een migratie/SQL-editor
-- (sessie als postgres zonder JWT). Werkt ook binnen security-definer functies,
-- want het kijkt naar de JWT/sessie en niet naar current_user.
create or replace function public.is_system_caller()
returns boolean language sql stable as $$
  select coalesce(auth.role(), '') = 'service_role'
      or (session_user in ('postgres', 'supabase_admin')
          and coalesce(current_setting('request.jwt.claim.sub', true), '') = ''
          and coalesce(current_setting('request.jwt.claims', true), '') in ('', '{}'))
$$;

-- Gebruik in security-definer RPC's: admin of systeem.
create or replace function public.is_staff()
returns boolean language sql stable as $$
  select public.is_admin() or public.is_system_caller()
$$;

-- Gebruik ENKEL in (invoker-)triggers. Bewust geen security definer:
-- current_user weerspiegelt de aanroeper. Binnen onze eigen security-definer
-- RPC's is current_user de eigenaar (postgres) — die RPC's doen zelf hun
-- toegangscontrole, dus triggers mogen dan doorlaten.
create or replace function public.is_privileged()
returns boolean language sql stable as $$
  select current_user in ('postgres', 'service_role', 'supabase_admin') or public.is_staff()
$$;

create or replace function public.my_supplier_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.suppliers
  where owner_profile_id = auth.uid() and deleted_at is null
$$;

create or replace function public.owns_supplier(p_supplier_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.suppliers
                 where id = p_supplier_id and owner_profile_id = auth.uid() and deleted_at is null)
$$;

create or replace function public.setting_numeric(p_key text)
returns numeric language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::numeric from public.platform_settings where key = p_key
$$;

create or replace function public.distance_km(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric)
returns numeric language sql immutable as $$
  select case when lat1 is null or lng1 is null or lat2 is null or lng2 is null then null else
    round((6371 * 2 * asin(sqrt(
      power(sin(radians((lat2 - lat1)::float8) / 2), 2) +
      cos(radians(lat1::float8)) * cos(radians(lat2::float8)) *
      power(sin(radians((lng2 - lng1)::float8) / 2), 2)
    )))::numeric, 1) end
$$;

-- Commissieberekening op één plek (spec §18): grondslag × tarief, afgerond op cent.
create or replace function public.calc_commission(p_base numeric, p_rate numeric)
returns numeric language sql immutable as $$
  select round(greatest(coalesce(p_base, 0), 0) * p_rate, 2)
$$;

create or replace function public.log_audit(
  p_action text, p_entity_type text, p_entity_id uuid, p_before jsonb default null, p_after jsonb default null
) returns void language sql security definer set search_path = public as $$
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, before, after)
  values (auth.uid(), p_action, p_entity_type, p_entity_id, p_before, p_after)
$$;

-- Generieke audit-trigger voor statuswijzigingen. Security definer zodat
-- gebruikers zelf geen schrijfrecht op de audit log nodig hebben.
--   TG_ARGV[0] = actieprefix (bv. 'leverancier_status'), TG_ARGV[1] = entiteit
create or replace function public.tg_audit_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    perform public.log_audit(tg_argv[0] || ':' || new.status, tg_argv[1], new.id,
      jsonb_build_object('status', old.status), jsonb_build_object('status', new.status));
  end if;
  return new;
end $$;

create or replace function public.notify_supplier(p_supplier_id uuid, p_type text, p_title text, p_body text, p_link text)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(profile_id, type, title, body, link)
  select owner_profile_id, p_type, p_title, p_body, p_link
  from public.suppliers where id = p_supplier_id
$$;

-- ---------------------------------------------------------------------------
-- Profiel aanmaken bij registratie. Rol NOOIT uit metadata vertrouwen,
-- behalve de onschuldige keuze klant/leverancier.
-- ---------------------------------------------------------------------------
create or replace function public.tg_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, full_name, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    case when new.raw_user_meta_data ->> 'signup_as' = 'supplier' then 'supplier'::public.app_role
         else 'customer'::public.app_role end
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.tg_handle_new_user();

create or replace function public.tg_profiles_guard()
returns trigger language plpgsql as $$
begin
  if new.role is distinct from old.role then
    if not public.is_privileged() then
      raise exception 'Je kan je eigen rol niet wijzigen' using errcode = '42501';
    end if;
    if new.role in ('admin', 'super_admin') or old.role in ('admin', 'super_admin') then
      if not (public.is_super_admin() or current_user in ('postgres', 'service_role', 'supabase_admin')) then
        raise exception 'Alleen een super admin kan adminrechten toekennen of intrekken' using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.tg_profiles_guard();

create or replace function public.tg_audit_role()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    perform public.log_audit('rol_gewijzigd', 'profile', new.id,
      jsonb_build_object('role', old.role), jsonb_build_object('role', new.role));
  end if;
  return new;
end $$;
create trigger profiles_audit after update on public.profiles
  for each row execute function public.tg_audit_role();

-- ---------------------------------------------------------------------------
-- Leveranciers: beschermde velden + statusovergangen (spec §14, §56)
-- ---------------------------------------------------------------------------
create or replace function public.tg_suppliers_guard()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_privileged() then
      if new.owner_profile_id is distinct from auth.uid() then
        raise exception 'Je kan alleen een eigen bedrijfsprofiel aanmaken' using errcode = '42501';
      end if;
      new.status := 'concept';
      new.verified_at := null;
      new.deactivated_at := null;
      new.stripe_customer_id := null;
      new.slug := null;
    end if;
    return new;
  end if;

  -- UPDATE
  if not public.is_privileged() then
    if new.owner_profile_id is distinct from old.owner_profile_id
       or new.verified_at is distinct from old.verified_at
       or new.deactivated_at is distinct from old.deactivated_at
       or new.stripe_customer_id is distinct from old.stripe_customer_id
       or new.slug is distinct from old.slug
       or new.status_reason is distinct from old.status_reason
       or new.deleted_at is distinct from old.deleted_at then
      raise exception 'Dit veld kan alleen door WaaslandEvents aangepast worden' using errcode = '42501';
    end if;

    if new.status is distinct from old.status then
      -- Enige toegelaten overgang voor een leverancier: indienen / opnieuw indienen.
      if not (old.status in ('concept', 'info_nodig') and new.status = 'aanvraag_ontvangen') then
        raise exception 'Statuswijziging % → % niet toegelaten', old.status, new.status using errcode = '42501';
      end if;
      if new.terms_accepted_at is null then
        raise exception 'Accepteer eerst de leveranciersvoorwaarden' using errcode = '23514';
      end if;
    end if;

    if old.deactivated_at is not null then
      raise exception 'Dit profiel is gedeactiveerd' using errcode = '42501';
    end if;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'aanvraag_ontvangen' then new.submitted_at := now(); end if;
    if new.status in ('goedgekeurd', 'actief') and new.verified_at is null then new.verified_at := now(); end if;
    if new.status = 'gedeactiveerd' and new.deactivated_at is null then new.deactivated_at := now(); end if;
    if old.status = 'gedeactiveerd' and new.status <> 'gedeactiveerd' then
      new.deactivated_at := null;
      new.deactivation_requested_at := null;
    end if;
  end if;
  return new;
end $$;

create trigger suppliers_guard before insert or update on public.suppliers
  for each row execute function public.tg_suppliers_guard();
create trigger suppliers_audit after update on public.suppliers
  for each row execute function public.tg_audit_status('leverancier_status', 'supplier');

-- Leverancier meldt stopzetting → na grace-periode (standaard 7 dagen) gedeactiveerd.
create or replace function public.request_supplier_stop(p_supplier_id uuid)
returns public.suppliers language plpgsql security definer set search_path = public as $$
declare s public.suppliers;
begin
  if not (public.owns_supplier(p_supplier_id) or public.is_staff()) then
    raise exception 'Geen toegang' using errcode = '42501';
  end if;
  update public.suppliers set deactivation_requested_at = coalesce(deactivation_requested_at, now())
   where id = p_supplier_id and deactivated_at is null
  returning * into s;
  perform public.log_audit('leverancier_stopzetting_gevraagd', 'supplier', p_supplier_id, null, null);
  return s;
end $$;

-- ---------------------------------------------------------------------------
-- Leveranciersproducten: review-flow (spec §41, testscenario 9)
-- ---------------------------------------------------------------------------
create or replace function public.tg_supplier_products_guard()
returns trigger language plpgsql as $$
declare content_changed boolean;
begin
  if tg_op = 'INSERT' then
    if not public.is_privileged() then
      if not public.owns_supplier(new.supplier_id) then
        raise exception 'Geen toegang tot deze leverancier' using errcode = '42501';
      end if;
      if new.status not in ('draft', 'pending_review') then new.status := 'draft'; end if;
      new.reviewed_at := null; new.reviewed_by := null; new.rejection_reason := null;
    end if;
    if new.status = 'pending_review' then new.submitted_at := now(); end if;
    return new;
  end if;

  content_changed :=
       new.name is distinct from old.name
    or new.description is distinct from old.description
    or new.category_id is distinct from old.category_id
    or new.product_type_id is distinct from old.product_type_id
    or new.price_type is distinct from old.price_type
    or new.price_from is distinct from old.price_from
    or new.price_to is distinct from old.price_to
    or new.price_note is distinct from old.price_note
    or new.capacity_min is distinct from old.capacity_min
    or new.capacity_max is distinct from old.capacity_max
    or new.suitable_event_type_ids is distinct from old.suitable_event_type_ids
    or new.features is distinct from old.features;

  if not public.is_privileged() then
    if new.supplier_id is distinct from old.supplier_id
       or new.reviewed_at is distinct from old.reviewed_at
       or new.reviewed_by is distinct from old.reviewed_by
       or new.rejection_reason is distinct from old.rejection_reason then
      raise exception 'Dit veld kan alleen door WaaslandEvents aangepast worden' using errcode = '42501';
    end if;

    if new.status is distinct from old.status and not (
         (old.status in ('draft', 'rejected') and new.status = 'pending_review')
      or (new.status = 'archived')
      or (old.status = 'archived' and new.status = 'draft')
      or (old.status = 'pending_review' and new.status = 'draft')
    ) then
      raise exception 'Statuswijziging % → % niet toegelaten', old.status, new.status using errcode = '42501';
    end if;

    -- Goedgekeurd product inhoudelijk aangepast → opnieuw naar review.
    if old.status = 'approved' and content_changed and new.status = 'approved' then
      new.status := 'pending_review';
    end if;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'pending_review' then new.submitted_at := now(); end if;
    if new.status in ('approved', 'rejected') then
      new.reviewed_at := now();
      new.reviewed_by := auth.uid();
    end if;
  end if;
  return new;
end $$;

create trigger supplier_products_guard before insert or update on public.supplier_products
  for each row execute function public.tg_supplier_products_guard();
create trigger supplier_products_audit after update on public.supplier_products
  for each row execute function public.tg_audit_status('product_status', 'supplier_product');

-- ---------------------------------------------------------------------------
-- Leads: toewijzing (max N per categorie), historiek en meldingen
-- ---------------------------------------------------------------------------
create or replace function public.tg_lead_assignments_before_insert()
returns trigger language plpgsql as $$
declare
  v_item     public.event_request_items;
  v_supplier public.suppliers;
  v_max      int := coalesce(public.setting_numeric('max_suppliers_per_category'), 3)::int;
  v_months   int := coalesce(public.setting_numeric('attribution_months'), 12)::int;
  v_count    int;
begin
  if not public.is_privileged() then
    raise exception 'Alleen WaaslandEvents kan leads toewijzen' using errcode = '42501';
  end if;

  select * into v_item from public.event_request_items where id = new.request_item_id for update;
  if not found then raise exception 'Onbekend aanvraag-item'; end if;
  new.request_id := v_item.request_id;

  select * into v_supplier from public.suppliers where id = new.supplier_id;
  if not found or v_supplier.status <> 'actief' or v_supplier.deactivated_at is not null
     or v_supplier.deleted_at is not null then
    raise exception 'Leverancier % is niet actief en kan geen leads ontvangen', coalesce(v_supplier.company_name, new.supplier_id::text)
      using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.supplier_categories sc
    join public.categories c on c.id = v_item.category_id
    where sc.supplier_id = new.supplier_id
      and (sc.category_id = c.id or sc.category_id = c.parent_id)
  ) then
    raise exception 'Leverancier is niet actief in deze categorie' using errcode = '23514';
  end if;

  select count(*) into v_count from public.lead_assignments where request_item_id = new.request_item_id;
  if v_count >= v_max then
    raise exception 'Maximaal % leveranciers per categorie', v_max using errcode = '23514';
  end if;

  new.assigned_by := coalesce(new.assigned_by, auth.uid());
  new.attribution_until := (coalesce(new.assigned_at, now()) + make_interval(months => v_months))::date;
  new.status := 'nieuw';
  return new;
end $$;

create trigger lead_assignments_before_insert before insert on public.lead_assignments
  for each row execute function public.tg_lead_assignments_before_insert();

create or replace function public.tg_lead_assignments_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.lead_status_history(assignment_id, from_status, to_status, changed_by, note)
  values (new.id, null, new.status, auth.uid(), 'Lead toegewezen');

  update public.event_request_items set status = 'gematcht' where id = new.request_item_id and status = 'open';
  update public.event_requests
     set status = 'gematcht', matched_at = coalesce(matched_at, now())
   where id = new.request_id and status in ('nieuw', 'in_behandeling', 'info_nodig');

  perform public.log_audit('lead_toegewezen', 'lead_assignment', new.id, null,
    jsonb_build_object('supplier_id', new.supplier_id, 'request_id', new.request_id, 'item_id', new.request_item_id));
  perform public.notify_supplier(new.supplier_id, 'lead_nieuw', 'Nieuwe WaaslandEvents-aanvraag',
    'Er staat een nieuwe aanvraag voor je klaar.', '/partner/leads/' || new.id);
  return new;
end $$;

create trigger lead_assignments_after_insert after insert on public.lead_assignments
  for each row execute function public.tg_lead_assignments_after_insert();

create or replace function public.tg_lead_assignments_status_history()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    insert into public.lead_status_history(assignment_id, from_status, to_status, changed_by, note)
    values (new.id, old.status, new.status, auth.uid(), nullif(current_setting('we.status_note', true), ''));
    perform public.log_audit('leadstatus:' || new.status, 'lead_assignment', new.id,
      jsonb_build_object('status', old.status), jsonb_build_object('status', new.status));
  end if;
  return new;
end $$;

create trigger lead_assignments_status_history after update on public.lead_assignments
  for each row execute function public.tg_lead_assignments_status_history();

-- Leverancier opent de lead voor het eerst
create or replace function public.mark_lead_viewed(p_assignment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.lead_assignments set first_viewed_at = now()
   where id = p_assignment_id and first_viewed_at is null
     and supplier_id in (select public.my_supplier_ids());
end $$;

-- Statusopvolging door leverancier (spec §16). Winnen/omzet lopen via eigen RPC's.
create or replace function public.set_lead_status(p_assignment_id uuid, p_status public.lead_status, p_note text default null)
returns public.lead_assignments language plpgsql security definer set search_path = public as $$
declare
  a public.lead_assignments;
  v_admin boolean := public.is_staff();
begin
  select * into a from public.lead_assignments where id = p_assignment_id for update;
  if not found or not (v_admin or public.owns_supplier(a.supplier_id)) then
    raise exception 'Geen toegang tot deze lead' using errcode = '42501';
  end if;

  if p_status in ('gewonnen', 'event_gepland', 'omzet_geregistreerd') then
    raise exception 'Gebruik "Opdracht gewonnen" of "Omzet bevestigen" voor deze stap' using errcode = '23514';
  end if;

  if not v_admin then
    if a.status in ('gewonnen', 'event_gepland', 'event_afgerond', 'omzet_geregistreerd') then
      raise exception 'Deze lead is al gewonnen. Annuleer de opdracht als het event niet doorgaat.' using errcode = '23514';
    end if;
    if p_status not in ('contact_opgenomen', 'offerte_voorbereiding', 'offerte_verstuurd', 'onderhandeling', 'verloren') then
      raise exception 'Status % niet toegelaten', p_status using errcode = '23514';
    end if;
  end if;

  perform set_config('we.status_note', coalesce(p_note, ''), true);
  update public.lead_assignments
     set status = p_status,
         lost_reason = case when p_status = 'verloren' then coalesce(p_note, lost_reason) else lost_reason end
   where id = p_assignment_id
  returning * into a;
  perform set_config('we.status_note', '', true);
  return a;
end $$;

-- ---------------------------------------------------------------------------
-- Opdracht gewonnen → booking + commissierecord (spec §17)
-- ---------------------------------------------------------------------------
create or replace function public.mark_lead_won(
  p_assignment_id uuid, p_event_date date, p_agreed_net_amount numeric, p_notes text default null
) returns public.bookings language plpgsql security definer set search_path = public as $$
declare
  a public.lead_assignments;
  b public.bookings;
  v_rate numeric := public.setting_numeric('commission_rate');
  v_date date;
begin
  select * into a from public.lead_assignments where id = p_assignment_id for update;
  if not found or not (public.is_staff() or public.owns_supplier(a.supplier_id)) then
    raise exception 'Geen toegang tot deze lead' using errcode = '42501';
  end if;
  if exists (select 1 from public.bookings where assignment_id = p_assignment_id) then
    raise exception 'Deze opdracht is al geregistreerd' using errcode = '23505';
  end if;
  if a.status in ('omzet_geregistreerd') then
    raise exception 'Lead is al afgesloten' using errcode = '23514';
  end if;
  if p_agreed_net_amount is null or p_agreed_net_amount < 0 then
    raise exception 'Geef de afgesproken netto opdrachtwaarde (excl. btw) op' using errcode = '23514';
  end if;
  if v_rate is null then
    raise exception 'Commissietarief ontbreekt in platform_settings' using errcode = 'P0002';
  end if;

  v_date := coalesce(p_event_date, (select event_date from public.event_requests where id = a.request_id));
  if v_date is null then
    raise exception 'Eventdatum is verplicht' using errcode = '23514';
  end if;

  insert into public.bookings(assignment_id, supplier_id, request_id, event_date, agreed_net_amount, notes)
  values (a.id, a.supplier_id, a.request_id, v_date, p_agreed_net_amount, p_notes)
  returning * into b;

  insert into public.commission_records(booking_id, supplier_id, status, rate, revenue_requested_at)
  values (b.id, b.supplier_id,
          case when v_date < current_date then 'omzet_opvragen'::public.commission_status
               else 'wacht_op_event'::public.commission_status end,
          v_rate,
          case when v_date < current_date then now() end);

  perform set_config('we.status_note', 'Opdracht gewonnen', true);
  update public.lead_assignments set status = 'gewonnen' where id = a.id;
  perform set_config('we.status_note', 'Event gepland op ' || to_char(v_date, 'DD/MM/YYYY'), true);
  update public.lead_assignments set status = 'event_gepland' where id = a.id;
  perform set_config('we.status_note', '', true);

  perform public.log_audit('opdracht_gewonnen', 'booking', b.id, null,
    jsonb_build_object('agreed_net_amount', b.agreed_net_amount, 'event_date', b.event_date, 'rate', v_rate));
  return b;
end $$;

-- Event ging niet door → geen commissie (spec §8)
create or replace function public.cancel_booking(p_booking_id uuid, p_reason text)
returns public.bookings language plpgsql security definer set search_path = public as $$
declare
  b public.bookings;
  c public.commission_records;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if not found or not (public.is_staff() or public.owns_supplier(b.supplier_id)) then
    raise exception 'Geen toegang' using errcode = '42501';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Geef een reden op' using errcode = '23514';
  end if;
  select * into c from public.commission_records where booking_id = b.id for update;
  if c.status in ('factuur_opgesteld', 'betaald') then
    raise exception 'Er is al gefactureerd; neem contact op met WaaslandEvents' using errcode = '23514';
  end if;

  update public.bookings set status = 'geannuleerd', cancelled_reason = p_reason where id = b.id returning * into b;
  update public.commission_records
     set status = 'vervallen', base_amount = 0, commission_amount = 0, calculated_at = now()
   where id = c.id;

  perform set_config('we.status_note', 'Opdracht geannuleerd: ' || p_reason, true);
  update public.lead_assignments set status = 'verloren', lost_reason = 'Opdracht geannuleerd: ' || p_reason
   where id = b.assignment_id;
  perform set_config('we.status_note', '', true);

  perform public.log_audit('opdracht_geannuleerd', 'booking', b.id, null, jsonb_build_object('reason', p_reason));
  return b;
end $$;

-- ---------------------------------------------------------------------------
-- Omzet bevestigen na het event → commissie berekenen (spec §17–18)
--   grondslag = gerealiseerde netto omzet − creditnota's − latere correcties
--   commissie = round(grondslag × tarief, 2)
-- ---------------------------------------------------------------------------
create or replace function public.recalc_commission(p_commission_id uuid)
returns public.commission_records language plpgsql security definer set search_path = public as $$
declare c public.commission_records;
begin
  update public.commission_records
     set base_amount = greatest(realized_net_revenue - credited_at_confirmation - adjustments_total, 0),
         commission_amount = public.calc_commission(realized_net_revenue - credited_at_confirmation - adjustments_total, rate),
         calculated_at = now()
   where id = p_commission_id and realized_net_revenue is not null
  returning * into c;
  return c;
end $$;

create or replace function public.confirm_revenue(
  p_booking_id uuid, p_realized_net_revenue numeric, p_credit_amount numeric default 0, p_note text default null
) returns public.commission_records language plpgsql security definer set search_path = public as $$
declare
  b public.bookings;
  c public.commission_records;
  v_admin boolean := public.is_staff();
  v_credit numeric := coalesce(p_credit_amount, 0);
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if not found or not (v_admin or public.owns_supplier(b.supplier_id)) then
    raise exception 'Geen toegang' using errcode = '42501';
  end if;
  if b.status = 'geannuleerd' then
    raise exception 'Deze opdracht werd geannuleerd' using errcode = '23514';
  end if;
  if b.event_date > current_date and not v_admin then
    raise exception 'Omzet kan pas na het event bevestigd worden' using errcode = '23514';
  end if;
  if p_realized_net_revenue is null or p_realized_net_revenue < 0 then
    raise exception 'Geef de gerealiseerde netto omzet (excl. btw) op' using errcode = '23514';
  end if;
  if v_credit < 0 or v_credit > p_realized_net_revenue then
    raise exception 'Het creditbedrag moet tussen 0 en de omzet liggen' using errcode = '23514';
  end if;

  select * into c from public.commission_records where booking_id = b.id for update;
  if c.status not in ('wacht_op_event', 'omzet_opvragen')
     and not (v_admin and c.status in ('commissie_berekend', 'betwist')) then
    raise exception 'De omzet voor deze opdracht is al bevestigd' using errcode = '23514';
  end if;

  update public.commission_records
     set realized_net_revenue = p_realized_net_revenue,
         credited_at_confirmation = v_credit,
         revenue_confirmed_at = now(),
         revenue_confirmed_by = auth.uid()
   where id = c.id;
  c := public.recalc_commission(c.id);

  update public.commission_records
     set status = case when c.base_amount = 0 then 'vervallen'::public.commission_status
                       else 'commissie_berekend'::public.commission_status end
   where id = c.id
  returning * into c;

  update public.bookings set status = 'afgerond' where id = b.id;

  perform set_config('we.status_note', coalesce(p_note, ''), true);
  update public.lead_assignments set status = 'event_afgerond'
   where id = b.assignment_id and status <> 'event_afgerond' and status <> 'omzet_geregistreerd';
  update public.lead_assignments set status = 'omzet_geregistreerd' where id = b.assignment_id;
  perform set_config('we.status_note', '', true);

  perform public.log_audit('omzet_bevestigd', 'commission_record', c.id, null,
    jsonb_build_object('revenue', p_realized_net_revenue, 'credit', v_credit,
                       'base', c.base_amount, 'rate', c.rate, 'commission', c.commission_amount));
  if c.commission_amount > 0 then
    perform public.notify_supplier(c.supplier_id, 'commissie_nieuw', 'Nieuwe commissie beschikbaar',
      'Commissie berekend: € ' || to_char(c.commission_amount, 'FM999G999G990D00'), '/partner/commissies');
  end if;
  return c;
end $$;

-- Creditnota / terugbetaling / correctie achteraf (admin)
create or replace function public.add_commission_adjustment(
  p_commission_id uuid, p_type public.adjustment_type, p_amount numeric, p_reason text
) returns public.commission_records language plpgsql security definer set search_path = public as $$
declare
  c public.commission_records;
  v_before numeric;
begin
  if not public.is_staff() then
    raise exception 'Alleen WaaslandEvents kan commissies corrigeren' using errcode = '42501';
  end if;
  select * into c from public.commission_records where id = p_commission_id for update;
  if not found then raise exception 'Onbekend commissierecord'; end if;
  if c.realized_net_revenue is null then
    raise exception 'Omzet is nog niet bevestigd' using errcode = '23514';
  end if;
  v_before := c.commission_amount;

  insert into public.commission_adjustments(commission_id, type, amount, reason, created_by)
  values (c.id, p_type, p_amount, p_reason, auth.uid());

  update public.commission_records set adjustments_total = adjustments_total + p_amount where id = c.id;
  c := public.recalc_commission(c.id);

  update public.commission_records
     set status = case
           when status = 'betaald' then 'gecrediteerd'::public.commission_status
           when base_amount = 0 and status in ('commissie_berekend', 'betwist') then 'vervallen'::public.commission_status
           else status end
   where id = c.id
  returning * into c;

  perform public.log_audit('commissie_aangepast', 'commission_record', c.id,
    jsonb_build_object('commission', v_before),
    jsonb_build_object('commission', c.commission_amount, 'type', p_type, 'amount', p_amount, 'reason', p_reason));
  return c;
end $$;

-- Factuur / betaald / betwist
create or replace function public.set_commission_status(
  p_commission_id uuid, p_status public.commission_status,
  p_invoice_number text default null, p_reason text default null
) returns public.commission_records language plpgsql security definer set search_path = public as $$
declare
  c public.commission_records;
  v_admin boolean := public.is_staff();
  v_term int := coalesce(public.setting_numeric('commission_payment_term_days'), 30)::int;
  ok boolean;
begin
  select * into c from public.commission_records where id = p_commission_id for update;
  if not found or not (v_admin or public.owns_supplier(c.supplier_id)) then
    raise exception 'Geen toegang' using errcode = '42501';
  end if;

  if not v_admin then
    -- Een leverancier kan enkel een commissie betwisten.
    ok := p_status = 'betwist' and c.status in ('commissie_berekend', 'factuur_opgesteld');
  else
    ok := (c.status = 'commissie_berekend' and p_status in ('factuur_opgesteld', 'betwist'))
       or (c.status = 'factuur_opgesteld' and p_status in ('betaald', 'betwist'))
       or (c.status = 'betwist' and p_status in ('commissie_berekend', 'factuur_opgesteld', 'vervallen'))
       or (c.status = 'betaald' and p_status = 'gecrediteerd');
  end if;
  if not ok then
    raise exception 'Commissiestatus % → % niet toegelaten', c.status, p_status using errcode = '23514';
  end if;
  if p_status = 'factuur_opgesteld' and coalesce(trim(p_invoice_number), '') = '' then
    raise exception 'Factuurnummer is verplicht' using errcode = '23514';
  end if;
  if p_status = 'betwist' and coalesce(trim(p_reason), '') = '' then
    raise exception 'Geef aan waarom je de commissie betwist' using errcode = '23514';
  end if;

  update public.commission_records
     set status = p_status,
         invoice_number = case when p_status = 'factuur_opgesteld' then p_invoice_number else invoice_number end,
         invoiced_at    = case when p_status = 'factuur_opgesteld' then now() else invoiced_at end,
         due_date       = case when p_status = 'factuur_opgesteld' then current_date + v_term else due_date end,
         paid_at        = case when p_status = 'betaald' then now() else paid_at end,
         dispute_reason = case when p_status = 'betwist' then p_reason else dispute_reason end
   where id = c.id
  returning * into c;

  perform public.log_audit('commissie_status:' || p_status, 'commission_record', c.id,
    null, jsonb_build_object('invoice_number', p_invoice_number, 'reason', p_reason));
  return c;
end $$;

-- ---------------------------------------------------------------------------
-- Dagelijkse job (Vercel Cron → /api/cron/daily → deze functies via service role)
-- ---------------------------------------------------------------------------
create or replace function public.process_due_bookings()
returns table(action text, commission_id uuid, booking_id uuid, supplier_id uuid)
language plpgsql security definer set search_path = public as $$
declare
  v_remind int := coalesce(public.setting_numeric('revenue_reminder_days'), 14)::int;
  v_escal  int := coalesce(public.setting_numeric('revenue_escalation_days'), 30)::int;
  r record;
begin
  if not public.is_staff() then
    raise exception 'Alleen voor systeemtaken' using errcode = '42501';
  end if;

  -- 1. Event voorbij → omzet opvragen
  for r in
    select c.id cid, b.id bid, b.supplier_id sid, b.assignment_id aid
      from public.commission_records c join public.bookings b on b.id = c.booking_id
     where c.status = 'wacht_op_event' and b.status = 'gepland' and b.event_date < current_date
     for update of c
  loop
    update public.commission_records set status = 'omzet_opvragen', revenue_requested_at = now() where id = r.cid;
    perform set_config('we.status_note', 'Event voorbij — omzet opgevraagd', true);
    update public.lead_assignments set status = 'event_afgerond' where id = r.aid and status = 'event_gepland';
    perform public.notify_supplier(r.sid, 'omzet_opvragen', 'Bevestig de gerealiseerde omzet',
      'Je event is voorbij. Bevestig de definitieve netto omzet.', '/partner/opdrachten/' || r.bid);
    action := 'omzet_opvragen'; commission_id := r.cid; booking_id := r.bid; supplier_id := r.sid;
    return next;
  end loop;
  perform set_config('we.status_note', '', true);

  -- 2. Herinnering
  for r in
    update public.commission_records c set revenue_reminded_at = now()
     where c.status = 'omzet_opvragen' and c.revenue_reminded_at is null
       and c.revenue_requested_at < now() - make_interval(days => v_remind)
    returning c.id cid, c.booking_id bid, c.supplier_id sid
  loop
    action := 'herinnering'; commission_id := r.cid; booking_id := r.bid; supplier_id := r.sid;
    return next;
  end loop;

  -- 3. Escalatie naar admin
  for r in
    update public.commission_records c set escalated_at = now()
     where c.status = 'omzet_opvragen' and c.escalated_at is null
       and c.revenue_requested_at < now() - make_interval(days => v_escal)
    returning c.id cid, c.booking_id bid, c.supplier_id sid
  loop
    perform public.log_audit('omzet_niet_gemeld_escalatie', 'commission_record', r.cid, null, null);
    action := 'escalatie'; commission_id := r.cid; booking_id := r.bid; supplier_id := r.sid;
    return next;
  end loop;
end $$;

create or replace function public.process_supplier_deactivations()
returns setof uuid language plpgsql security definer set search_path = public as $$
declare v_grace int := coalesce(public.setting_numeric('deactivation_grace_days'), 7)::int;
begin
  if not public.is_staff() then
    raise exception 'Alleen voor systeemtaken' using errcode = '42501';
  end if;
  return query
    update public.suppliers
       set status = 'gedeactiveerd', status_reason = 'Stopzetting op vraag van leverancier'
     where deactivation_requested_at is not null and deactivated_at is null
       and deactivation_requested_at <= now() - make_interval(days => v_grace)
    returning id;
end $$;

-- ---------------------------------------------------------------------------
-- Matching (spec §39, §65) — shortlist voor de admin, geen automatische toewijzing
-- ---------------------------------------------------------------------------
create or replace function public.match_candidates(p_item_id uuid)
returns table(
  supplier_id uuid, company_name text, serves_location boolean, distance_km numeric,
  matching_products int, capacity_ok boolean, avg_score numeric, review_count int,
  open_leads int, won_leads int, already_assigned boolean, stop_requested boolean
) language plpgsql stable security definer set search_path = public as $$
declare
  i public.event_request_items;
  r public.event_requests;
  loc public.locations;
  ploc public.locations;
  cat public.categories;
begin
  if not public.is_staff() then
    raise exception 'Alleen voor WaaslandEvents' using errcode = '42501';
  end if;
  select * into i from public.event_request_items where id = p_item_id;
  select * into r from public.event_requests where id = i.request_id;
  select * into cat from public.categories where id = i.category_id;
  select * into loc from public.locations where id = r.location_id;
  select * into ploc from public.locations where id = loc.parent_id;

  return query
  with base as (
    select s.*,
      public.distance_km(coalesce(pl.lat, ppl.lat), coalesce(pl.lng, ppl.lng),
                         coalesce(loc.lat, ploc.lat), coalesce(loc.lng, ploc.lng)) as dist
    from public.suppliers s
    left join public.locations pl on pl.id = s.primary_location_id
    left join public.locations ppl on ppl.id = pl.parent_id
    where s.status = 'actief' and s.deactivated_at is null and s.deleted_at is null
      and exists (select 1 from public.supplier_categories sc
                  where sc.supplier_id = s.id and (sc.category_id = cat.id or sc.category_id = cat.parent_id))
  )
  select
    b.id,
    b.company_name,
    (r.location_id is null
      or exists (select 1 from public.supplier_locations sl
                 where sl.supplier_id = b.id and sl.location_id in (loc.id, loc.parent_id))
      or b.primary_location_id in (loc.id, loc.parent_id)
      or (b.service_radius_km is not null and b.dist is not null and b.dist <= b.service_radius_km)) as serves_location,
    b.dist,
    (select count(*)::int from public.supplier_products sp
      where sp.supplier_id = b.id and sp.status = 'approved' and sp.deleted_at is null
        and (sp.category_id = i.category_id or sp.product_type_id = i.product_type_id)),
    (r.guests_total is null or b.max_capacity is null or b.max_capacity >= r.guests_total),
    (select round(avg(rv.score), 2) from public.reviews rv where rv.supplier_id = b.id and rv.status = 'approved'),
    (select count(*)::int from public.reviews rv where rv.supplier_id = b.id and rv.status = 'approved'),
    (select count(*)::int from public.lead_assignments la where la.supplier_id = b.id
      and la.status in ('nieuw', 'contact_opgenomen', 'offerte_voorbereiding', 'offerte_verstuurd', 'onderhandeling')),
    (select count(*)::int from public.bookings bk where bk.supplier_id = b.id and bk.status <> 'geannuleerd'),
    exists (select 1 from public.lead_assignments la where la.request_item_id = i.id and la.supplier_id = b.id),
    b.deactivation_requested_at is not null
  from base b
  order by 3 desc, 5 desc, 7 desc nulls last, 9 asc, 4 asc nulls last;
end $$;

create or replace function public.assign_leads(p_item_id uuid, p_supplier_ids uuid[])
returns setof public.lead_assignments language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if not public.is_staff() then
    raise exception 'Alleen WaaslandEvents kan leads toewijzen' using errcode = '42501';
  end if;
  foreach sid in array p_supplier_ids loop
    return query
      insert into public.lead_assignments(request_item_id, request_id, supplier_id, assigned_by, sent_at, attribution_until)
      select p_item_id, i.request_id, sid, auth.uid(), now(), current_date
        from public.event_request_items i where i.id = p_item_id
      returning *;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Reviews & feedback: enkel voor leveranciers die effectief aan de aanvraag
-- gekoppeld waren (spec §23)
-- ---------------------------------------------------------------------------
create or replace function public.tg_reviews_guard()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    if not exists (select 1 from public.lead_assignments la
                   where la.request_id = new.request_id and la.supplier_id = new.supplier_id) then
      raise exception 'Review kan enkel voor een partner die aan deze aanvraag gekoppeld was' using errcode = '23514';
    end if;
    if new.customer_id is distinct from (select customer_id from public.event_requests where id = new.request_id) then
      raise exception 'Review hoort niet bij deze klant' using errcode = '23514';
    end if;
    new.status := 'pending';
  elsif new.status is distinct from old.status then
    new.moderated_at := now();
    new.moderated_by := auth.uid();
  end if;
  return new;
end $$;

create trigger reviews_guard before insert or update on public.reviews
  for each row execute function public.tg_reviews_guard();
create trigger reviews_audit after update on public.reviews
  for each row execute function public.tg_audit_status('review_status', 'review');

create or replace function public.tg_customer_feedback_guard()
returns trigger language plpgsql as $$
begin
  if new.booked_supplier_id is not null and not exists (
    select 1 from public.lead_assignments la
     where la.request_id = new.request_id and la.supplier_id = new.booked_supplier_id) then
    raise exception 'Onbekende partner voor deze aanvraag' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger customer_feedback_guard before insert on public.customer_feedback
  for each row execute function public.tg_customer_feedback_guard();

-- ---------------------------------------------------------------------------
-- Audit op wijzigingen die rechtstreeks door admin gebeuren
-- ---------------------------------------------------------------------------
create or replace function public.tg_audit_settings()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.log_audit('instelling_gewijzigd', 'platform_setting', null,
    jsonb_build_object(old.key, old.value), jsonb_build_object(new.key, new.value));
  return new;
end $$;

create trigger platform_settings_audit after update on public.platform_settings
  for each row execute function public.tg_audit_settings();

create or replace function public.tg_audit_booking_amount()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.agreed_net_amount is distinct from old.agreed_net_amount or new.event_date is distinct from old.event_date then
    perform public.log_audit('opdracht_aangepast', 'booking', new.id,
      jsonb_build_object('agreed_net_amount', old.agreed_net_amount, 'event_date', old.event_date),
      jsonb_build_object('agreed_net_amount', new.agreed_net_amount, 'event_date', new.event_date));
  end if;
  return new;
end $$;

create trigger bookings_audit after update on public.bookings
  for each row execute function public.tg_audit_booking_amount();

-- ---------------------------------------------------------------------------
-- GDPR: klant anonimiseren — commissiehistoriek blijft intact (spec §36, §56)
-- ---------------------------------------------------------------------------
create or replace function public.anonymize_customer(p_customer_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_staff() then
    raise exception 'Geen toegang' using errcode = '42501';
  end if;
  update public.customer_profiles
     set full_name = 'Geanonimiseerd', email = 'anon+' || id || '@invalid.local', phone = null,
         organisation_name = null, anonymized_at = now()
   where id = p_customer_id;
  update public.event_requests
     set address = null, venue_name = null, message = null, budget_note = null, anonymized_at = now()
   where customer_id = p_customer_id;
  update public.reviews set display_name = null where customer_id = p_customer_id;
  perform public.log_audit('klant_geanonimiseerd', 'customer', p_customer_id, null, null);
end $$;

-- ---------------------------------------------------------------------------
-- Views (security_invoker → RLS van de onderliggende tabellen blijft gelden)
-- ---------------------------------------------------------------------------
create view public.v_supplier_leads with (security_invoker = true) as
select
  la.id                as assignment_id,
  la.supplier_id,
  la.status,
  la.assigned_at,
  la.first_viewed_at,
  la.attribution_until,
  r.id                 as request_id,
  r.reference,
  r.event_date,
  r.start_time,
  r.end_time,
  r.date_flexible,
  coalesce(et.name, r.event_type_other) as event_type,
  l.name               as location_name,
  r.postal_code,
  r.venue_name,
  r.address,
  r.indoor_outdoor,
  r.venue_kind,
  r.adults, r.children, r.guests_total,
  r.budget_min, r.budget_max, r.budget_note,
  r.message,
  c.name               as category_name,
  pt.name              as product_type_name,
  i.notes              as item_notes,
  cp.full_name         as customer_name,
  cp.email             as customer_email,
  cp.phone             as customer_phone,
  cp.customer_type,
  cp.organisation_name,
  b.id                 as booking_id
from public.lead_assignments la
join public.event_requests r       on r.id = la.request_id
join public.event_request_items i  on i.id = la.request_item_id
join public.categories c           on c.id = i.category_id
left join public.product_types pt  on pt.id = i.product_type_id
left join public.event_types et    on et.id = r.event_type_id
left join public.locations l       on l.id = r.location_id
left join public.customer_profiles cp on cp.id = r.customer_id
left join public.bookings b        on b.assignment_id = la.id;

create view public.v_supplier_dashboard with (security_invoker = true) as
select
  s.id as supplier_id,
  s.company_name,
  s.status,
  s.verified_at,
  (select count(*) from public.lead_assignments la where la.supplier_id = s.id and la.status = 'nieuw')::int as new_leads,
  (select count(*) from public.lead_assignments la where la.supplier_id = s.id
     and la.status in ('contact_opgenomen', 'offerte_voorbereiding', 'offerte_verstuurd', 'onderhandeling'))::int as open_leads,
  (select count(*) from public.bookings b where b.supplier_id = s.id and b.status <> 'geannuleerd')::int as won_jobs,
  (select count(*) from public.lead_assignments la where la.supplier_id = s.id and la.status = 'verloren')::int as lost_leads,
  (select count(*) from public.bookings b where b.supplier_id = s.id and b.status = 'gepland' and b.event_date >= current_date)::int as upcoming_events,
  (select count(*) from public.bookings b where b.supplier_id = s.id and b.status = 'afgerond')::int as completed_events,
  coalesce((select sum(c.base_amount) from public.commission_records c where c.supplier_id = s.id
     and c.status not in ('vervallen', 'wacht_op_event', 'omzet_opvragen', 'nog_niet_verschuldigd')), 0) as realized_revenue,
  coalesce((select sum(c.commission_amount) from public.commission_records c where c.supplier_id = s.id
     and c.status in ('commissie_berekend', 'factuur_opgesteld', 'betwist')), 0) as commission_due,
  coalesce((select sum(c.commission_amount) from public.commission_records c where c.supplier_id = s.id
     and c.status in ('betaald', 'gecrediteerd')), 0) as commission_paid,
  (select count(*) from public.commission_records c where c.supplier_id = s.id and c.status = 'omzet_opvragen')::int as revenue_to_confirm,
  (select round(avg(rv.score), 1) from public.reviews rv where rv.supplier_id = s.id and rv.status = 'approved') as avg_score,
  (select count(*) from public.reviews rv where rv.supplier_id = s.id and rv.status = 'approved')::int as review_count
from public.suppliers s
where s.deleted_at is null;

create view public.v_admin_commissions with (security_invoker = true) as
select
  c.id as commission_id,
  c.status,
  c.rate,
  c.realized_net_revenue,
  c.credited_at_confirmation,
  c.adjustments_total,
  c.base_amount,
  c.commission_amount,
  c.invoice_number,
  c.due_date,
  c.paid_at,
  c.revenue_requested_at,
  c.escalated_at,
  b.id as booking_id,
  b.event_date,
  b.agreed_net_amount,
  s.id as supplier_id,
  s.company_name as supplier_name,
  r.reference,
  coalesce(et.name, r.event_type_other) as event_type,
  cat.name as category_name,
  l.name as location_name
from public.commission_records c
join public.bookings b on b.id = c.booking_id
join public.suppliers s on s.id = c.supplier_id
join public.event_requests r on r.id = b.request_id
join public.lead_assignments la on la.id = b.assignment_id
join public.event_request_items i on i.id = la.request_item_id
join public.categories cat on cat.id = i.category_id
left join public.event_types et on et.id = r.event_type_id
left join public.locations l on l.id = r.location_id;

create view public.v_admin_kpis with (security_invoker = true) as
select
  (select count(*) from public.event_requests where deleted_at is null and status <> 'spam')::int as total_requests,
  (select count(*) from public.event_requests where status = 'nieuw' and deleted_at is null)::int as new_requests,
  (select count(*) from public.event_requests where status in ('gematcht', 'afgesloten'))::int as qualified_requests,
  (select count(*) from public.suppliers where status = 'actief' and deactivated_at is null)::int as active_suppliers,
  (select count(*) from public.suppliers where status in ('aanvraag_ontvangen', 'in_controle'))::int as suppliers_to_review,
  (select count(*) from public.supplier_products where status = 'approved' and deleted_at is null)::int as active_products,
  (select count(*) from public.supplier_products where status = 'pending_review' and deleted_at is null)::int as products_to_review,
  (select count(*) from public.lead_assignments)::int as total_leads,
  (select count(*) from public.bookings where status <> 'geannuleerd')::int as won_jobs,
  coalesce((select sum(base_amount) from public.commission_records
            where status not in ('vervallen', 'wacht_op_event', 'omzet_opvragen', 'nog_niet_verschuldigd')), 0) as realized_revenue,
  coalesce((select sum(commission_amount) from public.commission_records
            where status in ('commissie_berekend', 'factuur_opgesteld', 'betaald', 'betwist', 'gecrediteerd')), 0) as commission_revenue,
  coalesce((select sum(commission_amount) from public.commission_records where status in ('betaald', 'gecrediteerd')), 0) as commission_paid,
  (select round(avg(base_amount), 2) from public.commission_records
     where status not in ('vervallen', 'wacht_op_event', 'omzet_opvragen', 'nog_niet_verschuldigd')) as avg_order_value,
  (select round(avg(commission_amount), 2) from public.commission_records
     where status in ('commissie_berekend', 'factuur_opgesteld', 'betaald', 'betwist', 'gecrediteerd')) as avg_commission_per_event,
  case when (select count(*) from public.lead_assignments) = 0 then 0
       else round((select count(*) from public.bookings where status <> 'geannuleerd')::numeric
                  / (select count(*) from public.lead_assignments) * 100, 1) end as lead_win_rate_pct,
  (select count(*) from public.commission_records where status = 'omzet_opvragen' and escalated_at is not null)::int as escalations;

create view public.v_admin_monthly with (security_invoker = true) as
with months as (
  select generate_series(date_trunc('month', current_date) - interval '11 months',
                         date_trunc('month', current_date), interval '1 month')::date as month
)
select
  m.month,
  (select count(*) from public.event_requests r
    where date_trunc('month', r.created_at)::date = m.month and r.status <> 'spam')::int as requests,
  (select count(*) from public.bookings b
    where date_trunc('month', b.won_at)::date = m.month and b.status <> 'geannuleerd')::int as won_jobs,
  coalesce((select sum(c.base_amount) from public.commission_records c join public.bookings b on b.id = c.booking_id
    where date_trunc('month', b.event_date)::date = m.month
      and c.status not in ('vervallen', 'wacht_op_event', 'omzet_opvragen', 'nog_niet_verschuldigd')), 0) as revenue,
  coalesce((select sum(c.commission_amount) from public.commission_records c join public.bookings b on b.id = c.booking_id
    where date_trunc('month', b.event_date)::date = m.month
      and c.status in ('commissie_berekend', 'factuur_opgesteld', 'betaald', 'betwist', 'gecrediteerd')), 0) as commission
from months m
order by m.month;

-- Controle: klant zegt partner X geboekt te hebben, maar er is geen (actieve) opdracht.
create view public.v_attribution_flags with (security_invoker = true) as
select
  f.id as feedback_id,
  f.created_at,
  r.reference,
  s.id as supplier_id,
  s.company_name,
  b.status as booking_status
from public.customer_feedback f
join public.event_requests r on r.id = f.request_id
join public.suppliers s on s.id = f.booked_supplier_id
left join public.lead_assignments la on la.request_id = f.request_id and la.supplier_id = f.booked_supplier_id
left join public.bookings b on b.assignment_id = la.id
where f.booked_supplier_id is not null
  and (b.id is null or b.status = 'geannuleerd');
