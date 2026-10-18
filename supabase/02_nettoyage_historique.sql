-- Ne garde que les 15 dernières copies par joueur dans l'historique (sinon la base grossit sans fin).
-- À coller dans SQL Editor → Run.
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
    delete from public.joueur_historique h where h.joueur_id = j.id and h.id not in (
      select h2.id from public.joueur_historique h2 where h2.joueur_id = j.id order by h2.archive_le desc limit 15);
  end if;

  update public.joueur set perso_id = p_perso_id, etat = p_etat,
    versions = coalesce(p_versions, versions), versions_sig = coalesce(p_versions_sig, versions_sig),
    maj = t, vu_le = t
  where id = j.id;
  return jsonb_build_object('conflit', false, 'maj', t);
end $$;
