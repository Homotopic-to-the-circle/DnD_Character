-- Textes complets AideDD 5.5 (sorts, dons, états) : affichés dans la fenêtre intégrée des deux apps, hors ligne.
-- Table + fonction publique en lecture seule. Les apps téléchargent ref_textes() une fois par semaine au plus.
create table if not exists public.ref_textes(cle text primary key, titre text, html text not null, source text, maj timestamptz not null default now());
alter table public.ref_textes add column if not exists sous text;   -- sous-titre (« Guerrier · niveau 1 »)
alter table public.ref_textes enable row level security;
revoke all on public.ref_textes from anon, authenticated;
create or replace function public.ref_textes()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(cle, case when sous is null then jsonb_build_array(titre, html) else jsonb_build_array(titre, html, sous) end) || jsonb_build_object('maj', max(maj)), '{}'::jsonb) from public.ref_textes
$$;
revoke all on function public.ref_textes() from public;
grant execute on function public.ref_textes() to anon, authenticated;

-- ===== Rafraîchir les textes depuis AideDD (rarement) =====
-- 1. create extension if not exists http with schema extensions;
-- 2. exécuter le bloc ci-dessous (les sorts en plusieurs fois si le délai est dépassé : changer offset) ;
-- 3. drop extension if exists http;
-- Clés : 'sort:<slug AideDD>', 'don:<slug AideDD>', 'etat:<ancre AideDD>',
--        'capa:<classe>:<sous-classe>:<nom>' (sous-classe vide = capacité de base ; mots normalisés par kn(), comme capaN() dans les apps).
-- Les capacités « Voir le Manuel des Joueurs » ne sont pas copiées : l'app garde le lien AideDD (ou REGLES écrit à la main).
/*
-- nettoyage : <div> → <p>, on garde strong/em/b/i/br/p/table/tr/td/th/ul/li sans attributs, le reste est retiré (texte gardé)
create or replace function pg_temp.net(h text) returns text language sql as $$
  select trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
    regexp_replace(regexp_replace(h, '<div[^>]*>', '<p>', 'g'), '</div>', '</p>', 'g'),
    '<(/?)(strong|em|b|i|br|p|table|tr|td|th|ul|li|h4)(\s[^>]*)?>', '[[\1\2]]', 'g'),
    '<[^>]*>', '', 'g'),
    '\[\[(/?)(\w+)\]\]', '<\1\2>', 'g'),
    '<p>\s*</p>', '', 'g'),
    '\s+', ' ', 'g'))
$$;
-- corps d'une fiche (sort ou don) : entre </h1> et la source
create or replace function pg_temp.fiche(c text) returns text language sql as $$
  select pg_temp.net(substr(c, strpos(c,'</h1>')+5, strpos(c, '<div class=''source''>') - strpos(c,'</h1>') - 5))
$$;
-- sorts (391 pages : par lots de 100, offset 0, 100, 200, 300)
do $$ declare s jsonb; c text; begin
  for s in select x from public.ref_aidedd, jsonb_array_elements(donnees) x where cle='sorts' order by x->>0 offset 0 limit 100 loop
    begin
      select content into c from extensions.http_get('https://www.aidedd.org/spell/fr/'||(s->>1));
      if strpos(c, '<div class=''source''>')>0 and strpos(c, 'not available')=0 then
        insert into public.ref_textes(cle,titre,html,source) values('sort:'||(s->>1), s->>0, pg_temp.fiche(c), 'https://www.aidedd.org/spell/fr/'||(s->>1))
        on conflict (cle) do update set titre=excluded.titre, html=excluded.html, maj=now();
      end if;
    exception when others then raise notice 'sort % : %', s->>1, sqlerrm; end;
  end loop; end $$;
-- dons (Player's Handbook 2024)
do $$ declare r record; c text; begin
  for r in select (regexp_match(t, $r$/feat/fr/([^']+)'$r$))[1] slug from extensions.http_get('https://www.aidedd.org/feat/fr/') p, regexp_split_to_table(p.content,'<tr>') t where t like '%class=''item''%' loop
    begin
      select content into c from extensions.http_get('https://www.aidedd.org/feat/fr/'||r.slug);
      if strpos(c, '<div class=''source''>')>0 and strpos(c, 'not available')=0 then
        insert into public.ref_textes(cle,titre,html,source) values('don:'||r.slug, pg_temp.net((regexp_match(c,'<h1>(.*?)</h1>'))[1]), pg_temp.fiche(c), 'https://www.aidedd.org/feat/fr/'||r.slug)
        on conflict (cle) do update set titre=excluded.titre, html=excluded.html, maj=now();
      end if;
    exception when others then raise notice 'don % : %', r.slug, sqlerrm; end;
  end loop; end $$;
-- états : une section par <h4 id=…> de la page du glossaire
insert into public.ref_textes(cle,titre,html,source)
select 'etat:'||(regexp_match(b, 'id="([^"]+)"'))[1],
       trim(regexp_replace(pg_temp.net((regexp_match(b, '^(.*?)</h4>'))[1]), '\s*\[.*\]\s*$', '')),
       pg_temp.net(substr(b, strpos(b,'</h4>')+5)),
       'https://www.aidedd.org/regles-24/glossaire/etats/#'||(regexp_match(b, 'id="([^"]+)"'))[1]
from (select split_part(split_part(regexp_split_to_table(substr(content, strpos(content,'<h4>')), '<h4>'), '<h2', 1), '</div>', 1) b
      from extensions.http_get('https://www.aidedd.org/regles-24/glossaire/etats/')) x
where b like '%id="%'
on conflict (cle) do update set titre=excluded.titre, html=excluded.html, maj=now();
-- capacités de classe : les 12 classes, base + sous-classes détaillées sur AideDD
create or replace function pg_temp.kn(s text) returns text language sql as $$
  select regexp_replace(trim(regexp_replace(translate(lower(replace(replace(coalesce(s,''),'œ','oe'),'Œ','oe')),'àâäáãéèêëíìîïóòôöõúùûüçñÿæ','aaaaaeeeeiiiiooooouuuucnya'),'[^a-z0-9]+',' ','g')),'\y(\w{3,})s\y','\1','g')
$$;
do $$ declare cl text; c text; ch text; nomc text; sub text; dans boolean; t text; m text[]; nom text; niv text; corps text; begin
  foreach cl in array array['barbare','barde','clerc','druide','ensorceleur','guerrier','magicien','moine','occultiste','paladin','rodeur','roublard'] loop
    begin
    select content into c from extensions.http_get('https://www.aidedd.org/regles-24/classes/'||cl||'/');
    nomc := trim(regexp_replace(pg_temp.net((regexp_match(c,'<h1>(.*?)</h1>'))[1]),'\s*2024\s*$',''));
    c := substr(c, strpos(c,'<div class="content v24">'));
    if strpos(c,'<div id="Breadcrumbs">')>0 then c := substr(c,1,strpos(c,'<div id="Breadcrumbs">')-1); end if;
    sub := ''; dans := false;
    for ch in select x from regexp_split_to_table(c, '(?=<h[234][ >])') x loop
      if strpos(ch,'<div')>0 then ch := substr(ch,1,strpos(ch,'<div')-1); end if;
      if ch ~ '^<h2' then continue; end if;
      if ch ~ '^<h3' then
        t := pg_temp.net((regexp_match(ch,'^<h3[^>]*>(.*?)</h3>'))[1]);
        if ch ~ '^<h3[^>]*>\s*<a id=' then sub := t; dans := true;
        elsif t ~* '^Capacités de classe' then dans := true; sub := '';
        else dans := false; end if;
        continue;
      end if;
      if not dans then continue; end if;
      t := pg_temp.net((regexp_match(ch,'^<h4[^>]*>(.*?)</h4>'))[1]);
      m := regexp_match(t, '^Niveau\s+(\d+)\s*:\s*(.+)$');
      if m is null then niv := null; nom := t; else niv := m[1]; nom := trim(m[2]); end if;
      corps := pg_temp.net(substr(ch, strpos(ch,'</h4>')+5));
      if corps ~* '^\s*(<p>)?\s*Voir le (<em>)?\s*Manuel des Joueurs' or length(corps)<20 then continue; end if;
      insert into public.ref_textes(cle,titre,html,sous,source)
      values('capa:'||cl||':'||pg_temp.kn(sub)||':'||pg_temp.kn(nom), nom, corps,
             case when sub='' then nomc else sub end || coalesce(' · niveau '||niv,''),
             'https://www.aidedd.org/regles-24/classes/'||cl||'/')
      on conflict (cle) do update set titre=excluded.titre, html=excluded.html, sous=excluded.sous, maj=now();
    end loop;
    exception when others then raise notice 'classe % : %', cl, sqlerrm; end;
  end loop; end $$;
-- Maître de guerre : la liste des manœuvres sous Supériorité martiale
update public.ref_textes s set html = s.html || '<h4>Options de manœuvre</h4>' || o.html
from public.ref_textes o
where s.cle = 'capa:guerrier:maitre de guerre:superiorite martiale' and o.cle = 'capa:guerrier:maitre de guerre:option de manoeuvre'
  and strpos(s.html, '<h4>Options de manœuvre') = 0;
*/
