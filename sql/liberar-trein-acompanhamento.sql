-- ============================================================
-- Treinamentos > Acompanhamento e Registros — libera a nova página para quem
-- já tinha acesso total (Administrador e RH), mesmo padrão de
-- sql/criar-cursos-treinamento.sql. Página id 'trein-acompanhamento' no NAV.
-- Execute este script no SQL Editor do Supabase.
-- ============================================================

insert into public.permissoes (perfil_id, pagina_id)
select id, 'trein-acompanhamento' from public.perfis where nome in ('Administrador', 'RH')
on conflict (perfil_id, pagina_id) do nothing;
