-- ============================================================
-- Continuação de sql/corrigir-rls-permissiva-authenticated.sql: aquele
-- script corrigiu as 8 tabelas que o Security Advisor apontou. Auditando
-- manualmente o resto do schema (fora do advisor, que só sinaliza
-- USING(true)/WITH CHECK(true) — essas tabelas usavam
-- "auth.uid() IS NOT NULL", que passa batido pelo advisor mas tem o MESMO
-- problema: QUALQUER usuário autenticado no sistema, não só
-- Administrador/RH, conseguia inserir/editar/apagar direto via API REST em:
-- colaboradores, colaborador_historico, contratos_alinhamentos,
-- contratos_registros, documentos, internos,
-- "mapeamento_pasta_doc_drive.colaborador", modelos_relatorios,
-- ocorrencias, cargos, vagas e candidaturas.
--
-- Conferido no código (index.html): todas as escritas nessas tabelas hoje
-- só acontecem em telas do painel que, por padrão, só Administrador/RH têm
-- liberadas (ver sql/permissoes-usuarios.sql — Treinamento/Gestor/Estoque
-- começam sem nenhuma página). Nenhuma dessas tabelas tem fluxo de
-- "colaborador comum escrevendo no próprio registro" (diferente de
-- curso_progresso). Então restringir escrita a Administrador/RH não muda
-- nada pra quem já usa o site — só fecha a chamada direta à API REST com o
-- próprio token de sessão.
--
-- candidaturas é tratada à parte: além de escrita, também FECHA a leitura
-- para authenticated (hoje qualquer autenticado baixa nome/CPF/data de
-- nascimento/nome da mãe/telefone de TODOS os candidatos de TODAS as
-- vagas). Não foi encontrado nenhum fluxo no app em que um perfil além de
-- Administrador/RH precise ler candidaturas.
--
-- Também fecha um INSERT que sobrou aberto em testes_avaliacoes: a policy
-- "testes_avaliacoes_insert_anon" tinha WITH CHECK (true) pros papéis
-- "anon, authenticated" — pra anon já não faz efeito (o INSERT foi revogado
-- do papel anon em sql/rpc-finalizar-avaliacao-disc.sql), mas pra
-- authenticated continuava valendo: qualquer usuário logado conseguia criar
-- linhas arbitrárias em testes_avaliacoes. As duas telas que criam essas
-- linhas (Disparo de DISC Interno e aprovar candidato para avaliação) são
-- ambas de Administrador/RH.
--
-- Tabelas conferidas e DEIXADAS DE FORA deste script por não terem nenhuma
-- referência no app (frontend, Edge Functions ou workflows n8n deste
-- repo) — parecem mortas: mapeamento, op, pedidos. Já estão com RLS
-- ligado e zero policies (ou seja, já bloqueadas por padrão pra
-- anon/authenticated). Se alguma delas ainda for usada por algo fora deste
-- repositório, avise antes de mexer.
--
-- Execute este script no SQL Editor do Supabase. Depois, testar como
-- Administrador/RH (tudo deve continuar funcionando normalmente: editar
-- colaborador, lançar ocorrência, contrato, documento, candidatura,
-- disparo de DISC etc.) e, se tiver como, como um perfil sem ser
-- Administrador/RH (não deve mais conseguir escrever nessas tabelas via
-- chamada direta à API).
-- ============================================================

-- 1) colaboradores
drop policy if exists "po.colaboradores" on public.colaboradores;
create policy "colaboradores_select_authenticated" on public.colaboradores
  for select to authenticated using (true);
create policy "colaboradores_insert_admin_rh" on public.colaboradores
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "colaboradores_update_admin_rh" on public.colaboradores
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "colaboradores_delete_admin_rh" on public.colaboradores
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 2) colaborador_historico
drop policy if exists "po.cargos.hist" on public.colaborador_historico;
create policy "colaborador_historico_select_authenticated" on public.colaborador_historico
  for select to authenticated using (true);
create policy "colaborador_historico_insert_admin_rh" on public.colaborador_historico
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "colaborador_historico_update_admin_rh" on public.colaborador_historico
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "colaborador_historico_delete_admin_rh" on public.colaborador_historico
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 3) contratos_alinhamentos
drop policy if exists "po_contratos_alinhamentos" on public.contratos_alinhamentos;
create policy "contratos_alinhamentos_select_authenticated" on public.contratos_alinhamentos
  for select to authenticated using (true);
create policy "contratos_alinhamentos_insert_admin_rh" on public.contratos_alinhamentos
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "contratos_alinhamentos_update_admin_rh" on public.contratos_alinhamentos
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "contratos_alinhamentos_delete_admin_rh" on public.contratos_alinhamentos
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 4) contratos_registros
drop policy if exists "po.expecedesemp" on public.contratos_registros;
create policy "contratos_registros_select_authenticated" on public.contratos_registros
  for select to authenticated using (true);
create policy "contratos_registros_insert_admin_rh" on public.contratos_registros
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "contratos_registros_update_admin_rh" on public.contratos_registros
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "contratos_registros_delete_admin_rh" on public.contratos_registros
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 5) documentos
drop policy if exists "po.doc" on public.documentos;
create policy "documentos_select_authenticated" on public.documentos
  for select to authenticated using (true);
create policy "documentos_insert_admin_rh" on public.documentos
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "documentos_update_admin_rh" on public.documentos
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "documentos_delete_admin_rh" on public.documentos
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 6) internos (só leitura no app hoje — nenhuma escrita encontrada)
drop policy if exists "Policy with security definer functions" on public.internos;
create policy "internos_select_authenticated" on public.internos
  for select to authenticated using (true);
create policy "internos_insert_admin_rh" on public.internos
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "internos_update_admin_rh" on public.internos
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "internos_delete_admin_rh" on public.internos
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 7) "mapeamento_pasta_doc_drive.colaborador" (nome de tabela literal, com
-- ponto no identificador). Só leitura no app; a escrita é feita pelo
-- workflow n8n "Criar pasta colaborador drive" com service_role (que
-- ignora RLS, então não é afetado por esta mudança).
drop policy if exists "po_doc_drive" on public."mapeamento_pasta_doc_drive.colaborador";
create policy "mapeamento_pasta_doc_drive_colaborador_select_authenticated" on public."mapeamento_pasta_doc_drive.colaborador"
  for select to authenticated using (true);
create policy "mapeamento_pasta_doc_drive_colaborador_insert_admin_rh" on public."mapeamento_pasta_doc_drive.colaborador"
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "mapeamento_pasta_doc_drive_colaborador_update_admin_rh" on public."mapeamento_pasta_doc_drive.colaborador"
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "mapeamento_pasta_doc_drive_colaborador_delete_admin_rh" on public."mapeamento_pasta_doc_drive.colaborador"
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 8) modelos_relatorios
drop policy if exists "po.modelrelatorio" on public.modelos_relatorios;
create policy "modelos_relatorios_select_authenticated" on public.modelos_relatorios
  for select to authenticated using (true);
create policy "modelos_relatorios_insert_admin_rh" on public.modelos_relatorios
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "modelos_relatorios_update_admin_rh" on public.modelos_relatorios
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "modelos_relatorios_delete_admin_rh" on public.modelos_relatorios
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 9) ocorrencias
drop policy if exists "po.oco" on public.ocorrencias;
create policy "ocorrencias_select_authenticated" on public.ocorrencias
  for select to authenticated using (true);
create policy "ocorrencias_insert_admin_rh" on public.ocorrencias
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "ocorrencias_update_admin_rh" on public.ocorrencias
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "ocorrencias_delete_admin_rh" on public.ocorrencias
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 10) cargos (mantém a policy "anon_select_cargo_publico" já existente,
-- usada pelo formulário público de candidatura)
drop policy if exists "po.cargos" on public.cargos;
create policy "cargos_select_authenticated" on public.cargos
  for select to authenticated using (true);
create policy "cargos_insert_admin_rh" on public.cargos
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "cargos_update_admin_rh" on public.cargos
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "cargos_delete_admin_rh" on public.cargos
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 11) vagas (mantém as policies de anon já existentes — leitura de vagas
-- abertas e o update de contador, este já sem efeito prático desde que
-- sql/rpc-candidatura-publica.sql revogou o grant de UPDATE de anon)
drop policy if exists "po.vagas" on public.vagas;
create policy "vagas_select_authenticated" on public.vagas
  for select to authenticated using (true);
create policy "vagas_insert_admin_rh" on public.vagas
  for insert to authenticated with check (usuario_e_admin_ou_rh());
create policy "vagas_update_admin_rh" on public.vagas
  for update to authenticated using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());
create policy "vagas_delete_admin_rh" on public.vagas
  for delete to authenticated using (usuario_e_admin_ou_rh());

-- 12) candidaturas — diferente das demais, fecha SELECT também (dados
-- pessoais sensíveis: CPF, data de nascimento, nome da mãe, telefone,
-- currículo de candidatos). Mantém a policy "anon_insert_candidatura" já
-- existente (formulário público de candidatura).
drop policy if exists "po.candidaturas" on public.candidaturas;
create policy "candidaturas_all_admin_rh" on public.candidaturas
  for all to authenticated
  using (usuario_e_admin_ou_rh()) with check (usuario_e_admin_ou_rh());

-- 13) testes_avaliacoes: fecha o INSERT que ainda estava com WITH CHECK
-- (true) pra authenticated (pra anon já não tinha efeito — grant revogado
-- em sql/rpc-finalizar-avaliacao-disc.sql). As duas telas que criam essas
-- linhas (Disparo de DISC Interno, aprovar candidato p/ avaliação) são de
-- Administrador/RH.
drop policy if exists "testes_avaliacoes_insert_anon" on public.testes_avaliacoes;
create policy "testes_avaliacoes_insert_admin_rh" on public.testes_avaliacoes
  for insert to authenticated with check (usuario_e_admin_ou_rh());
