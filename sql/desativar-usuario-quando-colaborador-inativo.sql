-- ============================================================
-- Mantém usuarios.ativo em sincronia com colaboradores.status_colaborador:
-- vira 'Inativo' -> ativo=false; volta pra 'Ativo' -> ativo=true. Trigger no
-- banco em vez de mexer em cada tela que altera o status (Informações
-- Contratuais, Admissões, etc.), pra cobrir qualquer jeito que o status
-- mude, inclusive edição direta na tabela. Outros status (Férias, Afastado,
-- Pendente Documentação) não mexem em usuarios.ativo.
-- Execute este script no SQL Editor do Supabase.
-- ============================================================

-- Remove a versão anterior (só desativava, não reativava), caso já tenha sido executada.
drop trigger if exists trg_desativar_usuario_colaborador_inativo on public.colaboradores;
drop function if exists public.desativar_usuario_colaborador_inativo();

create or replace function public.sincronizar_usuario_ativo_status_colaborador()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status_colaborador is distinct from OLD.status_colaborador then
    if NEW.status_colaborador = 'Inativo' then
      update public.usuarios
      set ativo = false
      where colaborador_id = NEW.id_colaborador
        and ativo = true;
    elsif NEW.status_colaborador = 'Ativo' then
      update public.usuarios
      set ativo = true
      where colaborador_id = NEW.id_colaborador
        and ativo = false;
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_sincronizar_usuario_ativo_colaborador on public.colaboradores;

create trigger trg_sincronizar_usuario_ativo_colaborador
after update of status_colaborador on public.colaboradores
for each row
execute function public.sincronizar_usuario_ativo_status_colaborador();
