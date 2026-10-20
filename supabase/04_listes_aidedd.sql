-- Listes AideDD 5.5 (suggestions pendant la frappe dans les deux apps)
-- Table + fonction publique en lecture seule. Les apps téléchargent ref_listes() une fois par semaine au plus.
create table if not exists public.ref_aidedd(cle text primary key, donnees jsonb not null, source text, maj timestamptz not null default now());
alter table public.ref_aidedd enable row level security;
revoke all on public.ref_aidedd from anon, authenticated;
create or replace function public.ref_listes()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(cle, donnees) || jsonb_build_object('maj', max(maj)), '{}'::jsonb) from public.ref_aidedd
$$;
revoke all on function public.ref_listes() from public;
grant execute on function public.ref_listes() to anon, authenticated;

-- ===== Rafraîchir les listes depuis AideDD (rarement : si AideDD ajoute des monstres, sorts ou objets) =====
-- 1. create extension if not exists http with schema extensions;
-- 2. exécuter le bloc ci-dessous ;  3. drop extension if exists http;
/*
create or replace function pg_temp.dec(t text) returns text language sql as $$ select trim(regexp_replace(replace(replace(replace(replace(replace(regexp_replace(t,'<[^>]*>','','g'),'&#039;',''''),'&quot;','"'),'&nbsp;',' '),'&rsquo;','’'),'&amp;','&'),'\s+',' ','g')) $$;
-- monstres [nom, slug, FP]
insert into public.ref_aidedd(cle, donnees, source)
with p as (select content c from extensions.http_get('https://www.aidedd.org/monster/fr/')),
r as (select row_number() over () i, t from p, regexp_split_to_table(c, '<tr>') t where t like '%<td class=''item''>%'),
d as (select i, array_agg(pg_temp.dec(x[1]) order by ord) td from r, regexp_matches(t, '<td[^>]*?>(.*?)</td>', 'g') with ordinality as m(x, ord) group by i),
s as (select d.i, (regexp_match(r.t, $$/monster/fr/([^']+)'$$))[1] slug, td from d join r using(i))
select 'monstres', jsonb_agg(jsonb_build_array(td[2], slug, split_part(td[6],' ',1)) order by td[2]), 'https://www.aidedd.org/monster/fr/' from s
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
-- sorts [nom, slug, niveau, incantation, portée, concentration, rituel, matériel]
insert into public.ref_aidedd(cle, donnees, source)
with p as (select content c from extensions.http_get('https://www.aidedd.org/spell/fr/')),
r as (select row_number() over () i, t from p, regexp_split_to_table(c, '<tr>') t where t like '%<td class=''item''>%'),
d as (select i, array_agg(pg_temp.dec(x[1]) order by ord) td from r, regexp_matches(t, '<td[^>]*?>(.*?)</td>', 'g') with ordinality as m(x, ord) group by i),
s as (select d.i, (regexp_match(r.t, $$/spell/fr/([^']+)'$$))[1] slug, td from d join r using(i))
select 'sorts', jsonb_agg(jsonb_build_array(td[2], slug, td[6]::int, trim(regexp_replace(td[8], '\s*ou Rituel$', '')), td[9], td[12]<>'', td[13]<>'', td[11] like '%M%') order by td[2]), 'https://www.aidedd.org/spell/fr/' from s
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
-- objets magiques [nom, slug, type, rareté]
insert into public.ref_aidedd(cle, donnees, source)
with p as (select content c from extensions.http_get('https://www.aidedd.org/magic-item/fr/')),
r as (select row_number() over () i, t from p, regexp_split_to_table(c, '<tr>') t where t like '%<td class=''item''>%'),
d as (select i, array_agg(pg_temp.dec(x[1]) order by ord) td from r, regexp_matches(t, '<td[^>]*?>(.*?)</td>', 'g') with ordinality as m(x, ord) group by i),
s as (select d.i, (regexp_match(r.t, $$/magic-item/fr/([^']+)'$$))[1] slug, td from d join r using(i))
select 'objets_magiques', jsonb_agg(jsonb_build_array(td[2], slug, td[6], td[7]) order by td[2]), 'https://www.aidedd.org/magic-item/fr/' from s
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
-- armes [nom, dégâts, propriétés, botte] ; armures [nom, CA]
insert into public.ref_aidedd(cle, donnees, source)
with p as (select content c from extensions.http_get('https://www.aidedd.org/regles-24/equipement/armes/')),
r as (select row_number() over () i, t from p, regexp_split_to_table(c, '<tr>') t),
d as (select i, array_agg(pg_temp.dec(x[1]) order by ord) td from r, regexp_matches(t, '<td[^>]*?>(.*?)</td>', 'g') with ordinality as m(x, ord) group by i)
select 'armes', jsonb_agg(jsonb_build_array(td[1], td[2], td[3], td[4]) order by i), 'https://www.aidedd.org/regles-24/equipement/armes/' from d where array_length(td,1)=6
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
insert into public.ref_aidedd(cle, donnees, source)
with p as (select content c from extensions.http_get('https://www.aidedd.org/regles-24/equipement/armures/')),
r as (select row_number() over () i, t from p, regexp_split_to_table(c, '<tr>') t),
d as (select i, array_agg(pg_temp.dec(x[1]) order by ord) td from r, regexp_matches(t, '<td[^>]*?>(.*?)</td>', 'g') with ordinality as m(x, ord) group by i)
select 'armures', jsonb_agg(jsonb_build_array(td[1], td[2]) order by i), 'https://www.aidedd.org/regles-24/equipement/armures/' from d where array_length(td,1)=6
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
-- outils [nom] ; matériel d'aventurier [nom]
insert into public.ref_aidedd(cle, donnees, source)
select 'outils', jsonb_agg(jsonb_build_array(trim(regexp_replace(pg_temp.dec(x[1]), '\s*\([^)]*\)\s*$', ''))) order by o), 'https://www.aidedd.org/regles-24/equipement/outils/'
from extensions.http_get('https://www.aidedd.org/regles-24/equipement/outils/'), regexp_matches(content,'<h4>([^<]*)</h4>','g') with ordinality as m(x,o)
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
insert into public.ref_aidedd(cle, donnees, source)
select 'materiel', jsonb_agg(jsonb_build_array(pg_temp.dec(x[1])) order by o), 'https://www.aidedd.org/regles-24/equipement/materiel-daventurier/'
from extensions.http_get('https://www.aidedd.org/regles-24/equipement/materiel-daventurier/'), regexp_matches(content,'<tr>\s*<td>([^<]*)</td>','g') with ordinality as m(x,o)
on conflict (cle) do update set donnees = excluded.donnees, maj = now();
*/
