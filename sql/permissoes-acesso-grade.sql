-- ============================================================
-- Permissões de Acesso (tela de checkboxes perfil × página, só Administrador)
-- Execute no SQL Editor do Supabase.
-- ============================================================

-- 1) Função auxiliar: só verdadeiro para o perfil Administrador (mais
-- restrita que usuario_e_admin_ou_rh(), que também aceita RH). SECURITY
-- DEFINER pelo mesmo motivo de sempre: evita "infinite recursion detected in
-- policy" ao consultar `usuarios` dentro de uma policy de `permissoes`.
create or replace function public.usuario_e_administrador()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.usuarios u
    join public.perfis p on p.id = u.perfil_id
    where u.auth_user_id = auth.uid()
      and p.nome = 'Administrador'
  );
$$;

grant execute on function public.usuario_e_administrador() to authenticated;

-- 2) Só o Administrador pode criar/apagar linhas em `permissoes` — a leitura
-- para qualquer autenticado já existe desde permissoes-usuarios.sql e
-- continua valendo (essa policy só cobre insert/update/delete na prática,
-- já que a de leitura já permite o select pra todo mundo).
create policy "permissoes: gerenciar (admin)" on public.permissoes
  for all
  to authenticated
  using ( public.usuario_e_administrador() )
  with check ( public.usuario_e_administrador() );

-- 3) Libera a nova página "Permissões de Acesso" só para o Administrador —
-- nem RH tem acesso a essa tela, por decisão explícita.
insert into public.permissoes (perfil_id, pagina_id)
select id, 'permissoes-acesso' from public.perfis where nome = 'Administrador'
on conflict (perfil_id, pagina_id) do nothing;
