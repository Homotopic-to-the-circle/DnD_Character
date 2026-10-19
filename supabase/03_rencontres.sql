-- Rencontres du MJ : un document par campagne (sections, monstres, PV, combat en cours)
alter table public.campagne add column if not exists rencontres jsonb not null default '[]'::jsonb;

create or replace function public.mj_rencontres(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin
  return jsonb_build_object(
    'rencontres', (select rencontres from public.campagne where id = c),
    'joueurs', coalesce((select jsonb_agg(jsonb_build_object(
        'id', j.id, 'nom', j.nom, 'perso', j.etat->>'nom',
        'pv', j.etat->>'pv', 'pvTemp', j.etat->>'pvTemp',
        'pvMax', coalesce(nullif(j.etat->'statOv'->>'pvMax', ''), j.versions->-1->'data'->'combat'->>'pvMax'),
        'init', coalesce(nullif(j.etat->'statOv'->>'init', ''), j.versions->-1->'data'->'combat'->>'init'),
        'conc', j.etat->'conc', 'etats', j.etat->'etats') order by j.cree_le)
      from public.joueur j where j.campagne_id = c and not j.archive), '[]'::jsonb));
end $$;

create or replace function public.mj_rencontres_sauver(p_code text, p_doc jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin
  if jsonb_typeof(p_doc) <> 'array' then raise exception 'doc_invalide'; end if;
  if pg_column_size(p_doc) > 2000000 then raise exception 'doc_trop_gros'; end if;
  update public.campagne set rencontres = p_doc where id = c;
end $$;

revoke all on function public.mj_rencontres(text) from public;
revoke all on function public.mj_rencontres_sauver(text, jsonb) from public;
grant execute on function public.mj_rencontres(text) to anon, authenticated;
grant execute on function public.mj_rencontres_sauver(text, jsonb) to anon, authenticated;

-- l'export complet inclut les rencontres
CREATE OR REPLACE FUNCTION public.mj_export(p_code text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare c uuid := public.mj_camp(p_code);
begin
  return jsonb_build_object('type', 'export-campagne', 'date', now(),
    'campagne', (select jsonb_build_object('nom', nom, 'cree_le', cree_le, 'rencontres', rencontres) from public.campagne where id = c),
    'joueurs', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nom', nom, 'cle', cle, 'archive', archive,
        'perso_id', perso_id, 'etat', etat, 'versions', versions, 'maj', maj)) from public.joueur where campagne_id = c), '[]'::jsonb),
    'objets', coalesce((select jsonb_agg(to_jsonb(o) - 'campagne_id') from public.objet o where campagne_id = c), '[]'::jsonb),
    'envois', coalesce((select jsonb_agg(to_jsonb(e) - 'campagne_id') from public.envoi e where campagne_id = c), '[]'::jsonb));
end $function$;
