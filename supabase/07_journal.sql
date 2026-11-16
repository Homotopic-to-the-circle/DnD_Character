-- Journal de campagne : [{id, date, titre, texte}] sur la campagne ; RPC mj_journal / mj_journal_sauver ; inclus dans mj_export
alter table public.campagne add column if not exists journal jsonb not null default '[]'::jsonb;
