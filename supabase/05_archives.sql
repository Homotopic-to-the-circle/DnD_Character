-- Archives du MJ : documents (lore, PNJ, langues…), un fichier chacun ; liste gardée sur la campagne
alter table public.campagne add column if not exists archives jsonb not null default '[]'::jsonb;
create or replace function public.mj_archives(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin return (select archives from public.campagne where id = c); end $$;
create or replace function public.mj_archives_sauver(p_code text, p_doc jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare c uuid := public.mj_camp(p_code);
begin
  if jsonb_typeof(p_doc) <> 'array' then raise exception 'doc_invalide'; end if;
  if pg_column_size(p_doc) > 500000 then raise exception 'doc_trop_gros'; end if;
  update public.campagne set archives = p_doc where id = c;
end $$;
revoke all on function public.mj_archives(text) from public;
revoke all on function public.mj_archives_sauver(text, jsonb) from public;
grant execute on function public.mj_archives(text) to anon, authenticated;
grant execute on function public.mj_archives_sauver(text, jsonb) to anon, authenticated;
-- mj_export inclut aussi campagne.archives (voir 03_rencontres.sql pour le reste de la fonction)
-- Fonction « televerser » : en-tête x-remplace (ancienne adresse supprimée après dépôt) et x-action: supprimer.
