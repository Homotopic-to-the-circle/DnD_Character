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
--        'espece:<nom>', 'trait:<espèce>:<nom>', 'historique:<nom>',
--        'equip:<nom>' (armes, armures, outils, matériel), 'prop:<nom>', 'botte:<nom>', 'objmag:<slug AideDD>',
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
-- espèces (section entière + un texte par trait) et historiques (pg_temp.net et pg_temp.kn ci-dessus)
do $$ declare pg text; typ text; c text; sec text; nom text; morceau text; tn text; begin
  foreach pg in array array['description-des-especes','description-des-historiques'] loop
    typ := case when pg like '%especes' then 'espece' else 'historique' end;
    select content into c from extensions.http_get('https://www.aidedd.org/regles-24/origines-des-personnages/'||pg||'/');
    c := substr(c, strpos(c,'<div class="content v24">'), strpos(c,'<div id="Breadcrumbs">')-strpos(c,'<div class="content v24">'));
    for sec in select x from regexp_split_to_table(c, '(?=<h2[ >])') x where x ~ '^<h2' loop
      nom := pg_temp.net((regexp_match(sec,'^<h2[^>]*>(.*?)</h2>'))[1]);
      if nom is null or nom = '' then continue; end if;
      sec := regexp_replace(sec, '<img[^>]*>', '', 'g');
      insert into public.ref_textes(cle,titre,html,sous,source)
      values(typ||':'||pg_temp.kn(nom), nom, pg_temp.net(substr(sec, strpos(sec,'</h2>')+5)), case when typ='espece' then 'Espèce' else 'Historique' end,
             'https://www.aidedd.org/regles-24/origines-des-personnages/'||pg||'/#'||coalesce((regexp_match(sec,'id="([^"]+)"'))[1],''))
      on conflict (cle) do update set titre=excluded.titre, html=excluded.html, sous=excluded.sous, maj=now();
      if typ='espece' then
        for morceau in select x from regexp_split_to_table(substr(sec, strpos(sec,'</h2>')+5), '(?=<p>\s*<strong>)') x where x ~ '^<p>\s*<strong>' loop
          tn := trim(regexp_replace(pg_temp.net((regexp_match(morceau,'^<p>\s*<strong>([^<]*)'))[1]), '[\s:.]+$', ''));
          if tn ~* '^(Type de créature|Taille|Vitesse)$' or tn ~ '^(nbsp)?$' or tn ~ '^&' then continue; end if;
          insert into public.ref_textes(cle,titre,html,sous,source)
          values('trait:'||pg_temp.kn(nom)||':'||pg_temp.kn(tn), tn, pg_temp.net(morceau), 'Trait · '||nom,
                 'https://www.aidedd.org/regles-24/origines-des-personnages/'||pg||'/#'||coalesce((regexp_match(sec,'id="([^"]+)"'))[1],''))
          on conflict (cle) do update set titre=excluded.titre, html=excluded.html, sous=excluded.sous, maj=now();
        end loop;
      end if;
    end loop;
  end loop; end $$;
-- équipement : armes (ligne + propriétés + botte), armures, outils, matériel d'aventurier
create or replace function pg_temp.ok(cle text, titre text, html text, sous text, src text) returns void language sql as $$
  insert into public.ref_textes(cle,titre,html,sous,source) values(cle,titre,html,sous,src)
  on conflict (cle) do update set titre=excluded.titre, html=excluded.html, sous=excluded.sous, maj=now()
$$;
do $$ declare
  base text := 'https://www.aidedd.org/regles-24/equipement/';
  c text; ch text; sect text; nom text; corps text; tr text; td text[]; cat text; props jsonb := '{}'; bottes jsonb := '{}'; h text; p text; m text[];
begin
  -- ===== armes : propriétés, bottes, puis une fiche par arme (ligne du tableau + ses propriétés + sa botte)
  select content into c from extensions.http_get(base||'armes/');
  c := substr(c, strpos(c,'<div class="content v24">'), strpos(c,'<div id="Breadcrumbs">')-strpos(c,'<div class="content v24">'));
  sect := '';
  for ch in select x from regexp_split_to_table(c, '(?=<h[34][ >])') x loop
    if ch ~ '^<h3' then sect := coalesce((regexp_match(ch,'^<h3[^>]*>\s*<a id="([^"]+)"'))[1],''); continue; end if;
    if ch !~ '^<h4' then continue; end if;
    if strpos(ch,'<table')>0 then ch := substr(ch,1,strpos(ch,'<table')-1); end if;
    nom := pg_temp.net((regexp_match(ch,'^<h4[^>]*>([^<]*)</h4>'))[1]);
    corps := pg_temp.net(substr(ch, strpos(ch,'</h4>')+5));
    if sect='proprietes' then props := props || jsonb_build_object(pg_temp.kn(nom), jsonb_build_array(nom,corps)); perform pg_temp.ok('prop:'||pg_temp.kn(nom), nom, corps, 'Propriété d''arme', base||'armes/#proprietes');
    elsif sect='botte' then bottes := bottes || jsonb_build_object(pg_temp.kn(nom), jsonb_build_array(nom,corps)); perform pg_temp.ok('botte:'||pg_temp.kn(nom), nom, corps, 'Botte d''arme', base||'armes/#botte'); end if;
  end loop;
  cat := '';
  for tr in select x from regexp_split_to_table(substr(c, strpos(c,'<h3>Armes</h3>')), '<tr>') x loop
    select array_agg(pg_temp.net(y[1]) order by o) into td from regexp_matches(tr, '<td[^>]*?>(.*?)</td>', 'g') with ordinality z(y,o);
    if td is null then continue; end if;
    if array_length(td,1)=1 then cat := td[1]; continue; end if;
    if array_length(td,1)<>6 then continue; end if;
    h := '<p><strong>Dégâts</strong> : '||td[2]||'</p><p><strong>Propriétés</strong> : '||td[3]||'</p><p><strong>Botte</strong> : '||td[4]||'</p><p><strong>Poids</strong> : '||td[5]||' · <strong>Prix</strong> : '||td[6]||'</p>';
    foreach p in array regexp_split_to_array(td[3], '\s*,\s*') loop
      p := pg_temp.kn(regexp_replace(p,'\s*\(.*$',''));
      if props ? p then h := h||'<h4>'||(props->p->>0)||'</h4>'||(props->p->>1); end if;
    end loop;
    if bottes ? pg_temp.kn(td[4]) then h := h||'<h4>Botte : '||(bottes->pg_temp.kn(td[4])->>0)||'</h4>'||(bottes->pg_temp.kn(td[4])->>1); end if;
    perform pg_temp.ok('equip:'||pg_temp.kn(td[1]), td[1], h, coalesce(nullif(cat,''),'Arme'), base||'armes/');
  end loop;
  -- ===== armures : une fiche par ligne (+ catégorie)
  select content into c from extensions.http_get(base||'armures/');
  c := substr(c, strpos(c,'<div class="content v24">'), strpos(c,'<div id="Breadcrumbs">')-strpos(c,'<div class="content v24">'));
  cat := '';
  for tr in select x from regexp_split_to_table(substr(c, strpos(c,'<table')), '<tr>') x loop
    select array_agg(pg_temp.net(y[1]) order by o) into td from regexp_matches(tr, '<td[^>]*?>(.*?)</td>', 'g') with ordinality z(y,o);
    if td is null then continue; end if;
    if array_length(td,1)=1 then cat := td[1]; continue; end if;
    if array_length(td,1)<>6 then continue; end if;
    perform pg_temp.ok('equip:'||pg_temp.kn(td[1]), td[1],
      '<p><strong>Classe d’armure</strong> : '||td[2]||'</p><p><strong>Force</strong> : '||td[3]||'</p><p><strong>Discrétion</strong> : '||td[4]||'</p><p><strong>Poids</strong> : '||td[5]||' · <strong>Coût</strong> : '||td[6]||'</p>',
      coalesce(nullif(cat,''),'Armure'), base||'armures/');
  end loop;
  -- ===== outils et matériel d'aventurier : une fiche par <h4> « Nom (prix) »
  foreach p in array array['outils','materiel-daventurier'] loop
    select content into c from extensions.http_get(base||p||'/');
    c := substr(c, strpos(c,'<div class="content v24">'), strpos(c,'<div id="Breadcrumbs">')-strpos(c,'<div class="content v24">'));
    for ch in select x from regexp_split_to_table(c, '(?=<h[234][ >])') x where x ~ '^<h4' loop
      if strpos(ch,'<table')>0 then ch := substr(ch,1,strpos(ch,'<table')-1); end if;
      ch := regexp_replace(ch, '<img[^>]*>', '', 'g');
      nom := pg_temp.net((regexp_match(ch,'^<h4[^>]*>(.*?)</h4>'))[1]);
      m := regexp_match(nom, '^(.*?)\s*\(([^()]*)\)\s*$');
      corps := pg_temp.net(substr(ch, strpos(ch,'</h4>')+5));
      if length(corps)<10 then continue; end if;
      if m is not null then nom := m[1]; corps := '<p><strong>Prix</strong> : '||m[2]||'</p>'||corps; end if;
      perform pg_temp.ok('equip:'||pg_temp.kn(nom), nom, corps, case when p='outils' then 'Outil' else 'Équipement' end, base||p||'/');
    end loop;
  end loop;
end $$;
-- catégories sans balises ; armures : temps pour enfiler/retirer dans le texte
update public.ref_textes set sous = trim(regexp_replace(sous,'<[^>]+>','','g')) where cle like 'equip:%' and sous ~ '<';
update public.ref_textes set html = html || '<p>' || upper(left(m[2],1)) || substr(m[2],2) || '.</p>', sous = m[1]
from (select cle k, regexp_match(sous, '^(.*?)\s*\((.*)\)\s*$') m from public.ref_textes where cle like 'equip:%' and source like '%armures/%') x
where cle = x.k and x.m is not null;
-- noms utilisés par l'export AideDD (créateur 2014) → fiches 2024
insert into public.ref_textes(cle,titre,html,sous,source)
select 'equip:'||a, t, html, sous, source from public.ref_textes, (values ('fleche','Flèches'),('carreau','Carreaux'),('carreaux d arbalete','Carreaux'),('bille de fronde','Billes de fronde'),('aiguille','Aiguilles'),('aiguille de sarbacane','Aiguilles'),('balle de mousquet','Balles')) v(a,t)
where cle='equip:munition' on conflict (cle) do nothing;
insert into public.ref_textes(cle,titre,html,sous,source)
select 'equip:sac '||substr(cle, 17), 'Sac '||substr(titre, 11), html, sous, source from public.ref_textes where cle like 'equip:paquetage %' on conflict (cle) do nothing;
insert into public.ref_textes(cle,titre,html,sous,source)
select 'equip:'||v.a, v.t, r.html, r.sous, r.source from (values ('faucille','Faucille','serpe'),('marmite en fer','Marmite en fer','pot en fer'),('vetement de voyage','Vêtements de voyage','tenue de voyage'),('vetement fin','Vêtements fins','beaux habit')) v(a,t,src)
join public.ref_textes r on r.cle='equip:'||v.src on conflict (cle) do nothing;
-- objets magiques : une page par objet (liste dans ref_aidedd 'objets_magiques')
do $$ declare s jsonb; c text; begin
  for s in select x from public.ref_aidedd, jsonb_array_elements(donnees) x where cle='objets_magiques' order by x->>0 loop
    begin
      select content into c from extensions.http_get('https://www.aidedd.org/magic-item/fr/'||(s->>1));
      if strpos(c, '<div class=''source''>')>0 and strpos(c, 'not available')=0 then
        insert into public.ref_textes(cle,titre,html,sous,source) values('objmag:'||(s->>1), s->>0, pg_temp.fiche(regexp_replace(c,'<img[^>]*>','','g')), 'Objet magique', 'https://www.aidedd.org/magic-item/fr/'||(s->>1))
        on conflict (cle) do update set titre=excluded.titre, html=excluded.html, sous=excluded.sous, maj=now();
      end if;
    exception when others then raise notice 'objet % : %', s->>1, sqlerrm; end;
  end loop; end $$;
*/
