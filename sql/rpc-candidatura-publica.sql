-- ============================================================
-- Mesma proteção aplicada em testes_avaliacoes (ver
-- sql/rpc-finalizar-avaliacao-disc.sql), agora para o formulário público de
-- candidatura (link "?candidatura=<token>"), que hoje lê/escreve direto nas
-- tabelas vagas e candidaturas usando a chave anon.
--
-- Problema encontrado: loadVagasForApp()/loadCandidaturasForApp() fazem
-- select('*') SEM NENHUM FILTRO e rodam pra QUALQUER visita ao site,
-- inclusive anônima (antes até de saber se é um link público). Se a policy
-- de SELECT for permissiva pra anon, isso baixa a tabela candidaturas
-- INTEIRA (nome, CPF, data de nascimento, nome da mãe, telefone, link do
-- currículo de TODOS os candidatos de TODAS as vagas) para o navegador de
-- qualquer visitante — um vazamento sério de dado pessoal. Também dava pra
-- outra pessoa (com a chave anon, extraível do código-fonte da página)
-- inserir candidaturas apontando pra qualquer id_vagas — mesmo vagas
-- fechadas — ou alterar o contador de candidatos de qualquer vaga.
--
-- Solução: 2 funções SECURITY DEFINER (bypassam RLS) que só expõem o
-- mínimo necessário pro formulário público funcionar. As tabelas ficam
-- fechadas para anon (revoke no final) — toda a leitura/escrita pública
-- passa a ser só através dessas funções.
--
-- Execute este script no SQL Editor do Supabase.
-- ============================================================

-- 1) Dados públicos mínimos de uma vaga, pelo token do link — usado para
-- exibir o formulário (cargo, status), sem carregar a tabela vagas inteira.
create or replace function public.obter_vaga_por_token(p_token text)
returns table (id_vagas bigint, id_cargos bigint, status text)
language sql
security definer
set search_path = public
as $$
  select id_vagas, id_cargos, status
  from public.vagas
  where "link-token" = p_token;
$$;

grant execute on function public.obter_vaga_por_token(text) to anon;

-- 2) Recebe os dados do formulário + o token da vaga, confere que a vaga
-- existe e está aberta, grava a candidatura já com id_vagas/id_cargos
-- corretos (o cliente nunca escolhe esses ids diretamente) e incrementa o
-- contador de candidatos da vaga — tudo em uma única transação.
create or replace function public.enviar_candidatura(
  p_token text,
  p_nome text,
  p_cpf text,
  p_data_nascimento date,
  p_nome_mae text,
  p_numero text,
  p_instagram text,
  p_url_curriculo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_vagas bigint;
  v_id_cargos bigint;
  v_status text;
begin
  select id_vagas, id_cargos, status
    into v_id_vagas, v_id_cargos, v_status
  from public.vagas
  where "link-token" = p_token
  for update;

  if not found then
    raise exception 'Vaga não encontrada.';
  end if;

  if v_status is distinct from 'aberta' then
    raise exception 'Esta vaga não está mais recebendo candidaturas.';
  end if;

  insert into public.candidaturas (
    id_vagas, id_cargos, nome_candidato, cpf, data_nascimento,
    nome_da_mae, numero, instagram, url_curriculo, data_envio_candidatura
  ) values (
    v_id_vagas, v_id_cargos, p_nome, p_cpf, p_data_nascimento,
    p_nome_mae, nullif(p_numero, ''), nullif(p_instagram, ''), p_url_curriculo, current_date
  );

  update public.vagas
  set candidatos_count = coalesce(candidatos_count, 0) + 1
  where id_vagas = v_id_vagas;
end;
$$;

grant execute on function public.enviar_candidatura(text, text, text, date, text, text, text, text) to anon;

-- 3) Fecha as tabelas para anon: só dá pra interagir com vagas/candidaturas
-- através das funções acima. Usuários logados (authenticated/admin) não são
-- afetados — o revoke é só do papel anon.
revoke select, insert, update, delete on public.vagas from anon;
-- Em candidaturas, mantém o INSERT direto (não mexe nesse grant) e revoga só
-- select, update e delete — que são as operações que vazavam PII de todos os
-- candidatos e permitiam alterar/apagar candidaturas de qualquer um.
revoke select, update, delete on public.candidaturas from anon;
