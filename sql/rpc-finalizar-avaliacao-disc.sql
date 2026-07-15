-- ============================================================
-- Fecha a avaliação de Perfil DISC (candidato ou colaborador interno) para
-- que a escrita em testes_avaliacoes (e a réplica em mapeamento_perfil, no
-- caso de colaborador interno) só possa ser feita por quem tem o token do
-- link — mesmo que alguém extraia a chave anon do Supabase e tente chamar a
-- API diretamente, sem passar pelo site.
--
-- Por quê: uma policy de RLS não enxerga "o token que o app usou no filtro",
-- só os dados da própria linha. Se a policy de UPDATE for permissiva (ex.:
-- "using (true)"), qualquer pessoa com a chave anon consegue alterar
-- QUALQUER linha da tabela via chamada direta à API, filtrando por outra
-- coluna (ex.: id) em vez de token — o token deixa de ser uma trava de
-- verdade. Uma função SECURITY DEFINER resolve isso: ela roda com os
-- privilégios de quem a criou (bypassa RLS) e só existe UMA porta de
-- entrada — passar o token como parâmetro — que só atualiza a linha cujo
-- token bate. As tabelas ficam fechadas para anon (revoke abaixo).
--
-- Execute este script no SQL Editor do Supabase.
-- ============================================================

-- 1) Função que finaliza a avaliação: recebe o token e os dois perfis,
-- confere que o token existe e que a avaliação ainda não foi respondida,
-- grava o resultado em testes_avaliacoes e, se for colaborador interno
-- (id_colaborador preenchido), replica em mapeamento_perfil.perfil_disc_1/2.
create or replace function public.finalizar_avaliacao_disc(
  p_token text,
  p_perfil_1 text,
  p_perfil_2 text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_colaborador bigint;
  v_status text;
begin
  select id_colaborador, status_realizacao
    into v_id_colaborador, v_status
  from public.testes_avaliacoes
  where token::text = p_token
  for update;

  if not found then
    raise exception 'Token de avaliação inválido.';
  end if;

  if v_status = 'concluido' then
    raise exception 'Esta avaliação já foi respondida.';
  end if;

  update public.testes_avaliacoes
  set resultado_perfil_disc_1 = p_perfil_1,
      resultado_perfil_disc_2 = p_perfil_2,
      status_realizacao = 'concluido',
      respondido_em = now()
  where token::text = p_token;

  if v_id_colaborador is not null then
    update public.mapeamento_perfil
    set perfil_disc_1 = p_perfil_1,
        perfil_disc_2 = p_perfil_2
    where id_colaborador = v_id_colaborador;

    if not found then
      insert into public.mapeamento_perfil (id_colaborador, perfil_disc_1, perfil_disc_2)
      values (v_id_colaborador, p_perfil_1, p_perfil_2);
    end if;
  end if;
end;
$$;

-- 2) Libera SOMENTE a execução da função para o público (link sem login).
-- Quem chama precisa saber o token — não dá pra "adivinhar" qual linha
-- alterar, porque a função nem aceita outro parâmetro de filtro.
grant execute on function public.finalizar_avaliacao_disc(text, text, text) to anon;

-- 3) Fecha a porta direta: anon deixa de conseguir dar INSERT/UPDATE/DELETE
-- direto nessas tabelas via API, então a função acima passa a ser o único
-- caminho de escrita anônima. Isso vale independente de qualquer RLS policy
-- que já exista (grant/revoke é checado antes da RLS).
revoke insert, update, delete on public.testes_avaliacoes from anon;
revoke insert, update, delete on public.mapeamento_perfil from anon;

-- Observação: a leitura do teste pelo token (tela inicial da avaliação, que
-- hoje faz um select direto em testes_avaliacoes) continua usando select
-- direto e por isso ainda depende de uma policy de SELECT para anon. Se
-- quiser fechar isso também (hoje, com select liberado, dá pra listar/ler
-- outras avaliações via API direta trocando o filtro), me avise — dá pra
-- mover para outra função RPC do mesmo jeito.
