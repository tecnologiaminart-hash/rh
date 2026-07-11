-- ============================================================
-- Migração pontual: unifica contratos_expectativa + contratos_desempenho em
-- uma única tabela, contratos_registros (coluna "tipo" diferencia as duas).
-- Execute este script UMA VEZ no SQL Editor do Supabase, depois de já ter
-- rodado o sql/contratos-alinhamentos.sql atualizado (que cria a tabela
-- contratos_registros). Pode ser executado mais de uma vez sem duplicar
-- dados (o "where not exists" abaixo evita reinserir o que já foi migrado).
-- ============================================================

insert into public.contratos_registros (id_colaborador, tipo, status_resultado, data_realizacao, observacoes, link, created_at)
select ce.id_colaborador, 'expectativa', ce.status_resultado, ce.data_realizacao, ce.observacoes, ce.url_arquivo, ce.created_at
from public.contratos_expectativa ce
where not exists (
  select 1 from public.contratos_registros r
  where r.id_colaborador = ce.id_colaborador
    and r.tipo = 'expectativa'
    and r.created_at = ce.created_at
);

insert into public.contratos_registros (id_colaborador, tipo, status_resultado, data_realizacao, observacoes, link, created_at)
select cd.id_colaborador, 'desempenho', cd.status_resultado, cd.data_realizacao, cd.observacoes, cd.aval_link, cd.created_at
from public.contratos_desempenho cd
where not exists (
  select 1 from public.contratos_registros r
  where r.id_colaborador = cd.id_colaborador
    and r.tipo = 'desempenho'
    and r.created_at = cd.created_at
);

-- Confira o resultado antes de seguir:
-- select tipo, count(*) from public.contratos_registros group by tipo;

-- Só depois de confirmar que os dados migraram corretamente e que o site já
-- está usando contratos_registros, remova as tabelas antigas (deixado
-- comentado de propósito — descomente e rode manualmente quando tiver certeza):
-- drop table if exists public.contratos_expectativa;
-- drop table if exists public.contratos_desempenho;
