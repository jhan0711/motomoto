-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Crea el primer super administrador de PRUEBA. Vive fuera de
-- supabase/migrations/ y no se llama seed.sql, asi que ni `db push` ni
-- `db reset` lo miran. Solo se ejecuta a mano contra la base de desarrollo.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_super_admin.sql
--
-- NUNCA contra produccion: la contrasena esta en claro unas lineas mas abajo. El
-- super administrador de verdad -que es el dueno de la plataforma- se crea al
-- preparar produccion (Fase 25), igual que el `admin` de verdad.
--
-- Es idempotente. Misma maniobra que `seed_admin.sql`: se sustituye la fila del
-- perfil en vez de actualizarla, porque `protect_profile_columns` revierte
-- cualquier UPDATE del rol y aqui no hay sesion (hallazgo H5).
--
-- Cuenta: superadmin.prueba@motomoto-qa.co / SuperAdmin.2026
-- =============================================================================

do $semilla$
declare
  c_id       constant uuid := 'a0000000-0000-4000-8000-000000000002';
  c_email    constant text := 'superadmin.prueba@motomoto-qa.co';
  c_password constant text := 'SuperAdmin.2026';
begin
  if not exists (select 1 from auth.users where id = c_id) then
    -- Las cuatro columnas de token a cadena vacia y NO a nulo, o la cuenta no
    -- puede iniciar sesion (error E28 de la Fase 12).
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      c_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      c_email, extensions.crypt(c_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Super administrador de prueba","phone":"3009990001"}',
      '', '', '', ''
    );

    -- El disparador on_auth_user_created ya creo el perfil, con rol passenger.
    delete from public.profiles where id = c_id;

    insert into public.profiles (id, full_name, phone, role, status)
    values (c_id, 'Super administrador de prueba', '3009990001', 'super_admin', 'active');
  end if;
end;
$semilla$;


-- Comprobacion: rol super_admin Y estado activo, mas los tokens no nulos que
-- exige GoTrue. Si devuelve una fila, la cuenta puede entrar al panel.
select
  u.email,
  p.role::text as rol,
  p.status::text as estado,
  public.is_super_admin() as is_super_admin_desde_sql,
  (u.confirmation_token is not null and u.recovery_token is not null
   and u.email_change_token_new is not null and u.email_change is not null) as tokens_no_nulos
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'super_admin' and p.status = 'active';
