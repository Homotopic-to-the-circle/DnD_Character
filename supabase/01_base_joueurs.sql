-- Feuille de Perso : campagnes, joueurs (fiche sauvegardée), historique.
-- Tables verrouillées : aucun accès direct pour anon/authenticated ; tout passe par des fonctions qui exigent une clé.

create table public.campagne (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  code_mj text,
  cree_le timestamptz not null default now()
);

create table public.joueur (
  id uuid primary key default gen_random_uuid(),
  campagne_id uuid not null references public.campagne(id) on delete cascade,
  nom text not null,
  cle_hash text not null unique,
  perso_id text,
  etat jsonb,
  versions jsonb,
  versions_sig text,
  maj timestamptz,
  vu_le timestamptz,
  cree_le timestamptz not null default now()
);

create table public.joueur_historique (
  id bigint generated always as identity primary key,
  joueur_id uuid not null references public.joueur(id) on delete cascade,
  raison text not null,
  perso_id text,
  etat jsonb,
  versions jsonb,
  maj timestamptz,
  archive_le timestamptz not null default now()
);
create index joueur_historique_joueur on public.joueur_historique(joueur_id, archive_le desc);
create index joueur_campagne on public.joueur(campagne_id);

alter table public.campagne enable row level security;
alter table public.joueur enable row level security;
alter table public.joueur_historique enable row level security;
revoke all on public.campagne, public.joueur, public.joueur_historique from anon, authenticated;

create or replace function public.hache_cle(p_cle text) returns text
language sql immutable set search_path = '' as $$
  select encode(sha256(convert_to(upper(replace(trim(p_cle), '-', '')), 'UTF8')), 'hex')
$$;

create or replace function public.j_charger(p_cle text, p_versions boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare j public.joueur;
begin
  select * into j from public.joueur where cle_hash = public.hache_cle(p_cle);
  if not found then raise exception 'cle_invalide' using errcode = 'P0001'; end if;
  update public.joueur set vu_le = now() where id = j.id;
  return jsonb_build_object(
    'nom', j.nom,
    'campagne', (select c.nom from public.campagne c where c.id = j.campagne_id),
    'perso_id', j.perso_id, 'etat', j.etat,
    'versions', case when p_versions then j.versions else null end,
    'versions_sig', j.versions_sig, 'maj', j.maj);
end $$;

create or replace function public.j_sauver(p_cle text, p_perso_id text, p_etat jsonb, p_versions jsonb,
  p_versions_sig text, p_base timestamptz, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare j public.joueur; t timestamptz := clock_timestamp();
begin
  select * into j from public.joueur where cle_hash = public.hache_cle(p_cle) for update;
  if not found then raise exception 'cle_invalide' using errcode = 'P0001'; end if;
  if p_etat is null then raise exception 'etat_manquant' using errcode = 'P0001'; end if;
  if p_versions is null and j.versions is null then raise exception 'versions_manquantes' using errcode = 'P0001'; end if;

  if j.etat is not null and not p_force and (p_base is null or j.maj > p_base) then
    insert into public.joueur_historique(joueur_id, raison, perso_id, etat, versions, maj)
      values (j.id, 'conflit', p_perso_id, p_etat, p_versions, t);
    return jsonb_build_object('conflit', true, 'maj', j.maj, 'perso_id', j.perso_id);
  end if;

  if j.etat is not null and (p_force or not exists (
       select 1 from public.joueur_historique h
       where h.joueur_id = j.id and h.raison = 'auto' and h.archive_le > t - interval '1 hour')) then
    insert into public.joueur_historique(joueur_id, raison, perso_id, etat, versions, maj)
      values (j.id, 'auto', j.perso_id, j.etat, j.versions, j.maj);
    perform 1;  -- le nettoyage de l'historique est ajouté par 02_nettoyage_historique.sql
  end if;

  update public.joueur set perso_id = p_perso_id, etat = p_etat,
    versions = coalesce(p_versions, versions), versions_sig = coalesce(p_versions_sig, versions_sig),
    maj = t, vu_le = t
  where id = j.id;
  return jsonb_build_object('conflit', false, 'maj', t);
end $$;

revoke all on function public.hache_cle(text) from public, anon, authenticated;
revoke all on function public.j_charger(text, boolean) from public, anon, authenticated;
revoke all on function public.j_sauver(text, text, jsonb, jsonb, text, timestamptz, boolean) from public, anon, authenticated;
grant execute on function public.j_charger(text, boolean) to anon, authenticated;
grant execute on function public.j_sauver(text, text, jsonb, jsonb, text, timestamptz, boolean) to anon, authenticated;
