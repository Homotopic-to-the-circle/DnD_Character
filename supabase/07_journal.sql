-- Journal de campagne : [{id, date, titre, texte}] sur la campagne ; RPC mj_journal / mj_journal_sauver ; inclus dans mj_export
alter table public.campagne add column if not exists journal jsonb not null default '[]'::jsonb;
-- Présence à la table : joueur.absent (hors des combats) ; RPC mj_joueur_presence(p_code, p_id, p_absent) ; mj_etat renvoie 'absent'
alter table public.joueur add column if not exists absent boolean not null default false;
