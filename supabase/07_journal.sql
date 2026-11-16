-- Journal de campagne : [{id, date, titre, texte}] sur la campagne ; RPC mj_journal / mj_journal_sauver ; inclus dans mj_export
alter table public.campagne add column if not exists journal jsonb not null default '[]'::jsonb;
-- Présence à la table : joueur.absent (hors des combats) ; RPC mj_joueur_presence(p_code, p_id, p_absent) ; mj_etat renvoie 'absent'
alter table public.joueur add column if not exists absent boolean not null default false;
-- Objet déjà envoyé modifié par le MJ : mj_objet_sauver ajoute pour chaque envoi une action {action:'maj', cible, nom, description, lien[, mystere]}
-- (objet mystérieux non révélé : seul le texte visible part, le vrai texte est mis à jour dans envoi.secret pour la révélation).
-- Joueurs : j_journal(p_cle) renvoie [{id,date,titre,resume}] ; resume = journal_resume(texte), seulement la rubrique « Résumé : » (le reste reste côté MJ)
