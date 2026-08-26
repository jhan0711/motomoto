-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Este archivo NO se aplica solo. Vive fuera de supabase/migrations/, asi que
-- db push no lo mira, y no se llama seed.sql, asi que db reset tampoco. Solo se
-- ejecuta a mano y contra la base de desarrollo.
--
-- NUNCA debe ejecutarse contra produccion: crea una cuenta con contrasena
-- conocida y escrita en claro unas lineas mas abajo. El administrador de verdad
-- se crea en la Fase 25, al preparar produccion.
--
-- Para que sirve. El rol admin existe en la base de datos desde la Fase 5, con
-- sus politicas RLS y su funcion is_admin(), pero NO HABIA NI UNA SOLA CUENTA
-- con ese rol: comprobado contra el servidor el 2026-08-26, cuatro pasajeros y
-- dos conductores, cero administradores. Sin esta semilla no hay forma de
-- entrar al panel de la Fase 20 ni de comprobar que la guardia funciona.
--
-- Es idempotente. Se puede ejecutar tantas veces como haga falta:
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_admin.sql
--
-- POR QUE SUSTITUYE LA FILA EN VEZ DE ACTUALIZARLA. El disparador
-- profiles_protect_columns revierte cualquier UPDATE del rol, incluso
-- ejecutando como postgres, porque is_admin() depende de auth.uid() y aqui no
-- hay sesion (hallazgo H5). Es BEFORE UPDATE y no cubre INSERT, asi que la
-- unica via es borrar la fila que creo el disparador de alta y volver a
-- insertarla. Es la misma maniobra que usa seed_test_driver.sql.
-- =============================================================================

do $semilla$
declare
  -- Identificador fijo para que el archivo se pueda repetir sin duplicar nada.
  c_admin constant uuid := 'a0000000-0000-4000-8000-000000000001';

  -- Dominio entregable a proposito. La API de Auth rechaza los correos
  -- @motomoto.test (hallazgo H6), y esta cuenta tiene que poder iniciar sesion
  -- de verdad en el panel.
  c_email    constant text := 'admin.prueba@motomoto-qa.co';
  c_password constant text := 'Admin.2026';
begin
  if not exists (select 1 from auth.users where id = c_admin) then
    -- Las cuatro columnas de token van a cadena vacia y NO a nulo. Es la
    -- diferencia entre una cuenta que puede iniciar sesion y una que no: GoTrue
    -- las lee como texto y un nulo hace que su consulta falle con 500
    -- "Database error querying schema", que no dice nada sobre la causa. Es el
    -- error E28 de la Fase 12, que costo encontrar.
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      c_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      c_email, extensions.crypt(c_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Administrador de prueba","phone":"3001112233"}',
      '', '', '', ''
    );

    -- El disparador on_auth_user_created ya creo el perfil, pero con rol
    -- passenger. Ver la explicacion de la cabecera.
    delete from public.profiles where id = c_admin;

    insert into public.profiles (id, full_name, phone, role, status)
    values (c_admin, 'Administrador de prueba', '3001112233', 'admin', 'active');
  end if;
end;
$semilla$;


-- Comprobacion: se pregunta por lo que de verdad decide el acceso al panel, que
-- es rol admin Y estado activo, las dos condiciones que exige is_admin(). Si
-- esto devuelve una fila, el panel dejara entrar a esta cuenta; si devuelve
-- cero, algo falta por mucho que la tabla parezca bien.
select
  u.email,
  p.full_name,
  p.role::text as rol,
  p.status::text as estado,
  u.email_confirmed_at is not null as correo_confirmado,
  -- Las cuatro columnas de token vacias y no nulas, que es lo que E28 enseño.
  (u.confirmation_token is not null
   and u.recovery_token is not null
   and u.email_change_token_new is not null
   and u.email_change is not null) as tokens_no_nulos
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin' and p.status = 'active';
