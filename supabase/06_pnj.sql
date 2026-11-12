-- PNJ du MJ : régions + fiches, gardés sur la campagne ({regions:[{id,nom}], liste:[{id,nom,titre,num,region,principal,vu,fiche}]})
alter table public.campagne add column if not exists pnj jsonb not null default '{}'::jsonb;
create or replace function public.mj_pnj(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin return (select pnj from public.campagne where id = c); end $$;
create or replace function public.mj_pnj_sauver(p_code text, p_doc jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin
  if jsonb_typeof(p_doc) <> 'object' then raise exception 'doc_invalide'; end if;
  if pg_column_size(p_doc) > 1000000 then raise exception 'doc_trop_gros'; end if;
  update public.campagne set pnj = p_doc where id = c;
end $$;
revoke all on function public.mj_pnj(text) from public;
revoke all on function public.mj_pnj_sauver(text, jsonb) from public;
grant execute on function public.mj_pnj(text) to anon, authenticated;
grant execute on function public.mj_pnj_sauver(text, jsonb) to anon, authenticated;
create or replace function public.mj_export(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin
  return jsonb_build_object('type', 'export-campagne', 'date', now(),
    'campagne', (select jsonb_build_object('nom', nom, 'cree_le', cree_le, 'rencontres', rencontres, 'archives', archives, 'pnj', pnj) from public.campagne where id = c),
    'joueurs', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nom', nom, 'cle', cle, 'archive', archive,
        'perso_id', perso_id, 'etat', etat, 'versions', versions, 'maj', maj)) from public.joueur where campagne_id = c), '[]'::jsonb),
    'objets', coalesce((select jsonb_agg(to_jsonb(o) - 'campagne_id') from public.objet o where campagne_id = c), '[]'::jsonb),
    'envois', coalesce((select jsonb_agg(to_jsonb(e) - 'campagne_id') from public.envoi e where campagne_id = c), '[]'::jsonb));
end $$;
