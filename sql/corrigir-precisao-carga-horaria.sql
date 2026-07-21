-- ============================================================
-- Corrige cursos Internos com muitas horas exibindo "0h 0min" na listagem
-- de Treinamentos > Cursos, mesmo com as aulas certinho cadastradas.
--
-- Causa: a coluna cursos.carga_horaria foi criada (ou alterada depois) com
-- uma precisão numérica curta (ex: numeric(4,2), que só guarda até 99,99).
-- Cursos com 100h+ de aulas estouram esse limite, o UPDATE feito pelo app
-- falha (só loga no console) e carga_horaria fica travado no valor antigo
-- (0, do momento em que o curso foi criado).
--
-- Execute este script no SQL Editor do Supabase.
-- ============================================================

-- 1) Remove qualquer limite de precisão/escala da coluna.
alter table public.cursos
  alter column carga_horaria type numeric using carga_horaria::numeric;

-- 2) Recalcula carga_horaria de todos os cursos Internos a partir da soma
-- real das aulas (mesma conta feita no app: segundos / 3600, 2 casas).
update public.cursos c
set carga_horaria = round(
  coalesce((select sum(a.duracao_segundos) from public.curso_aulas a where a.id_curso = c.id), 0) / 3600.0,
  2
)
where c.tipo = 'Interno';
