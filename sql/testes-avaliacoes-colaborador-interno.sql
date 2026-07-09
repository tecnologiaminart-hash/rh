-- ============================================================
-- Avaliações > Perfil DISC Colaborador Interno — reaproveita a tabela
-- `testes_avaliacoes` (já usada para candidatos) também para colaboradores
-- já contratados.
-- Execute no SQL Editor do Supabase.
-- ============================================================

-- 1) Novas colunas para identificar/registrar o colaborador interno que
-- recebeu o disparo (id_candidato continua sendo usado normalmente para o
-- fluxo de candidatos).
alter table public.testes_avaliacoes add column if not exists id_colaborador bigint;
alter table public.testes_avaliacoes add column if not exists nome_colaborador text;

-- 2) id_candidato precisa aceitar nulo: nas linhas disparadas para
-- colaborador interno não existe candidatura associada.
alter table public.testes_avaliacoes alter column id_candidato drop not null;

-- 3) Libera a nova aba "Perfil DISC Colaborador Interno" (dentro de
-- Avaliações) para quem já tinha acesso total (Administrador e RH).
insert into public.permissoes (perfil_id, pagina_id)
select id, 'aval-disc-interno' from public.perfis where nome in ('Administrador', 'RH')
on conflict (perfil_id, pagina_id) do nothing;
