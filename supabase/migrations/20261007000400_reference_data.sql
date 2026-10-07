-- ============================================================================
-- WaaslandEvents — 0004 referentiedata (productie)
-- Alles hieronder is achteraf in de admin aan te passen. Niets is hardcoded
-- in de frontend.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Platforminstellingen
-- ---------------------------------------------------------------------------
insert into public.platform_settings(key, value, description, is_public) values
  ('commission_rate',              '0.125', 'Commissie op gerealiseerde netto omzet excl. btw', true),
  ('max_suppliers_per_category',   '3',     'Max. leveranciers per gevraagde categorie', true),
  ('attribution_months',           '12',    'Leadbescherming: maanden na toewijzing dat een opdracht als WE-lead telt', false),
  ('revenue_reminder_days',        '14',    'Dagen na opvragen omzet → herinnering', false),
  ('revenue_escalation_days',      '30',    'Dagen na opvragen omzet → escalatie naar admin', false),
  ('deactivation_grace_days',      '7',     'Dagen tussen stopzetting en deactivatie (spec §56)', true),
  ('commission_payment_term_days', '30',    'Betalingstermijn commissiefactuur', true),
  ('consent_version',              '"v1-concept"', 'Versie van de consenttekst in de aanvraagwizard', true)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Locaties — grote regio Waasland
-- (Sinds 2025 fusies: Beveren-Kruibeke-Zwijndrecht en Lokeren-Moerbeke.
--  We houden de herkenbare plaatsnamen aan: zo zoeken mensen.)
-- ---------------------------------------------------------------------------
insert into public.locations(slug, name, type, postal_codes, lat, lng, sort_order) values
  ('waasland',          'Waasland',          'regio',    '{}',               51.1650, 4.1437, 0),
  ('beveren',           'Beveren',           'gemeente', '{9120}',           51.2122, 4.2552, 10),
  ('kruibeke',          'Kruibeke',          'gemeente', '{9150}',           51.1706, 4.3100, 20),
  ('zwijndrecht',       'Zwijndrecht',       'gemeente', '{2070}',           51.2147, 4.3297, 25),
  ('sint-niklaas',      'Sint-Niklaas',      'gemeente', '{9100}',           51.1650, 4.1437, 30),
  ('stekene',           'Stekene',           'gemeente', '{9190}',           51.2108, 4.0369, 40),
  ('sint-gillis-waas',  'Sint-Gillis-Waas',  'gemeente', '{9170}',           51.2228, 4.1239, 50),
  ('temse',             'Temse',             'gemeente', '{9140}',           51.1253, 4.2117, 60),
  ('waasmunster',       'Waasmunster',       'gemeente', '{9250}',           51.1053, 4.0853, 70),
  ('lokeren',           'Lokeren',           'gemeente', '{9160}',           51.1036, 3.9933, 80),
  ('hamme',             'Hamme',             'gemeente', '{9220}',           51.0983, 4.1364, 90),
  ('moerbeke',          'Moerbeke',          'gemeente', '{9180}',           51.1739, 3.9311, 100)
on conflict (slug) do nothing;

update public.locations set parent_id = (select id from public.locations where slug = 'waasland')
 where type = 'gemeente' and parent_id is null;

insert into public.locations(slug, name, type, postal_codes, lat, lng, parent_id, sort_order)
select v.slug, v.name, 'deelgemeente', v.pc, v.lat, v.lng, p.id, v.ord
from (values
  ('melsele',       'Melsele',        '{9120}'::text[], 51.2203, 4.2817, 'beveren',          1),
  ('vrasene',       'Vrasene',        '{9120}',         51.2186, 4.1981, 'beveren',          2),
  ('haasdonk',      'Haasdonk',       '{9120}',         51.1867, 4.2392, 'beveren',          3),
  ('kallo',         'Kallo',          '{9120}',         51.2531, 4.2783, 'beveren',          4),
  ('kieldrecht',    'Kieldrecht',     '{9130}',         51.2875, 4.1750, 'beveren',          5),
  ('verrebroek',    'Verrebroek',     '{9130}',         51.2483, 4.1872, 'beveren',          6),
  ('bazel',         'Bazel',          '{9150}',         51.1442, 4.3003, 'kruibeke',         1),
  ('rupelmonde',    'Rupelmonde',     '{9150}',         51.1272, 4.2917, 'kruibeke',         2),
  ('burcht',        'Burcht',         '{2070}',         51.2033, 4.3436, 'zwijndrecht',      1),
  ('belsele',       'Belsele',        '{9111}',         51.1497, 4.0917, 'sint-niklaas',     1),
  ('sinaai',        'Sinaai',         '{9112}',         51.1592, 4.0453, 'sint-niklaas',     2),
  ('nieuwkerken-waas', 'Nieuwkerken-Waas', '{9100}',    51.1856, 4.1786, 'sint-niklaas',     3),
  ('kemzeke',       'Kemzeke',        '{9190}',         51.2072, 4.0656, 'stekene',          1),
  ('sint-pauwels',  'Sint-Pauwels',   '{9170}',         51.1914, 4.1022, 'sint-gillis-waas', 1),
  ('de-klinge',     'De Klinge',      '{9170}',         51.2672, 4.0911, 'sint-gillis-waas', 2),
  ('meerdonk',      'Meerdonk',       '{9170}',         51.2667, 4.1406, 'sint-gillis-waas', 3),
  ('elversele',     'Elversele',      '{9140}',         51.1194, 4.1361, 'temse',            1),
  ('steendorp',     'Steendorp',      '{9140}',         51.1306, 4.2667, 'temse',            2),
  ('tielrode',      'Tielrode',       '{9140}',         51.1117, 4.1667, 'temse',            3),
  ('daknam',        'Daknam',         '{9160}',         51.1300, 3.9889, 'lokeren',          1),
  ('eksaarde',      'Eksaarde',       '{9160}',         51.1500, 3.9694, 'lokeren',          2)
) as v(slug, name, pc, lat, lng, parent_slug, ord)
join public.locations p on p.slug = v.parent_slug
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Categorieën (spec §27): hoofdcategorie → subcategorie
-- ---------------------------------------------------------------------------
insert into public.categories(slug, name, short_description, icon, sort_order) values
  ('locaties',      'Locaties',      'Feestzalen, eventlocaties en vergaderruimtes', 'building', 10),
  ('catering',      'Catering',      'Traiteurs, foodtrucks, BBQ, drank en desserts', 'utensils', 20),
  ('verhuur',       'Verhuur',       'Tenten, meubilair, verlichting en geluid', 'tent', 30),
  ('entertainment', 'Entertainment', 'DJ, live muziek, photobooth, springkastelen en meer', 'music', 40),
  ('decoratie',     'Decoratie',     'Styling, bloemen en ballonnen', 'sparkles', 50),
  ('foto-video',    'Foto & video',  'Fotografen en videografen', 'camera', 60),
  ('huwelijk',      'Huwelijk',      'Alles voor jullie trouwdag', 'heart', 70),
  ('praktisch',     'Praktisch',     'Security, sanitair, personeel en transport', 'clipboard', 80)
on conflict (slug) do nothing;

insert into public.categories(slug, name, parent_id, sort_order)
select v.slug, v.name, p.id, v.ord
from (values
  ('feestzalen', 'Feestzalen', 'locaties', 1), ('eventlocaties', 'Eventlocaties', 'locaties', 2),
  ('vergaderlocaties', 'Vergaderlocaties', 'locaties', 3),
  ('traiteurs', 'Traiteurs', 'catering', 1), ('foodtrucks', 'Foodtrucks', 'catering', 2),
  ('bbq', 'BBQ', 'catering', 3), ('drank', 'Drank & bars', 'catering', 4),
  ('desserts', 'Desserts', 'catering', 5), ('taarten', 'Taarten', 'catering', 6),
  ('tenten', 'Tenten', 'verhuur', 1), ('tafels', 'Tafels', 'verhuur', 2), ('stoelen', 'Stoelen', 'verhuur', 3),
  ('eventmeubilair', 'Eventmeubilair', 'verhuur', 4), ('verlichting', 'Verlichting', 'verhuur', 5),
  ('verwarming', 'Verwarming', 'verhuur', 6), ('geluidsinstallatie', 'Geluidsinstallatie', 'verhuur', 7),
  ('dj', 'DJ', 'entertainment', 1), ('live-bands', 'Live bands', 'entertainment', 2),
  ('artiesten', 'Artiesten', 'entertainment', 3), ('animatie', 'Animatie', 'entertainment', 4),
  ('photobooth', 'Photobooth', 'entertainment', 5), ('springkastelen', 'Springkastelen', 'entertainment', 6),
  ('vr', 'VR-beleving', 'entertainment', 7), ('silent-disco', 'Silent disco', 'entertainment', 8),
  ('eventstyling', 'Eventstyling', 'decoratie', 1), ('bloemen', 'Bloemen', 'decoratie', 2),
  ('ballonnen', 'Ballonnen', 'decoratie', 3), ('decoratie-verhuur', 'Decoratie', 'decoratie', 4),
  ('fotografen', 'Fotografen', 'foto-video', 1), ('videografen', 'Videografen', 'foto-video', 2),
  ('weddingplanners', 'Weddingplanners', 'huwelijk', 1), ('trouwvervoer', 'Trouwvervoer', 'huwelijk', 2),
  ('trouwfotografie', 'Trouwfotografie', 'huwelijk', 3), ('trouwvideo', 'Trouwvideo', 'huwelijk', 4),
  ('bruidstaarten', 'Bruidstaarten', 'huwelijk', 5),
  ('security', 'Security', 'praktisch', 1), ('toiletten', 'Toiletten', 'praktisch', 2),
  ('eventpersoneel', 'Eventpersoneel', 'praktisch', 3), ('transport', 'Transport', 'praktisch', 4)
) as v(slug, name, parent_slug, ord)
join public.categories p on p.slug = v.parent_slug
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Eventtypes (wizard stap 1)
-- ---------------------------------------------------------------------------
insert into public.event_types(slug, name, audience, sort_order) values
  ('verjaardag',       'Verjaardag',          'particulier', 10),
  ('huwelijk',         'Huwelijk',            'particulier', 20),
  ('communie',         'Communie / lentefeest','particulier', 30),
  ('babyborrel',       'Babyborrel / babyshower','particulier', 40),
  ('familiefeest',     'Familie- of tuinfeest','particulier', 50),
  ('jubileum',         'Jubileum',            'particulier', 60),
  ('bedrijfsfeest',    'Bedrijfsfeest',       'bedrijf', 70),
  ('personeelsfeest',  'Personeelsfeest',     'bedrijf', 80),
  ('teambuilding',     'Teambuilding',        'bedrijf', 90),
  ('klantenevent',     'Klantenevent / opendeurdag', 'bedrijf', 100),
  ('seminarie',        'Seminarie / congres', 'bedrijf', 110),
  ('schoolfeest',      'Schoolfeest',         'school', 120),
  ('sportevent',       'Sportevent',          'vereniging', 130),
  ('fuif',             'Fuif',                'vereniging', 140),
  ('eetfestijn',       'Eetfestijn',          'vereniging', 150),
  ('wijkfeest',        'Wijk- of buurtfeest', 'vereniging', 160),
  ('verenigingsevent', 'Verenigingsevent',    'vereniging', 170),
  ('publiek-event',    'Publiek evenement / markt', 'organisatie', 180)
on conflict (slug) do nothing;
