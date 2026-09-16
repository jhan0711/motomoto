-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Este archivo NO se aplica solo. Vive fuera de supabase/migrations/, asi que
-- db push no lo mira, y no se llama seed.sql, asi que db reset tampoco. Solo se
-- ejecuta a mano y contra la base de desarrollo.
--
-- NUNCA debe ejecutarse contra produccion: crea una cuenta con contrasena
-- conocida y escrita en claro unas lineas mas abajo.
--
-- Mismo patron que seed_test_driver.sql / seed_second_driver.sql, pero para
-- pasajero: aqui no hace falta vehiculo ni ubicacion que caduque, un pasajero
-- solo necesita una cuenta de Auth y una fila en profiles con role='passenger'.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_test_passenger.sql
--
-- Correo: pasajero.prueba@motomoto-qa.co / contrasena: Pasajero.2026
-- =============================================================================

do $semilla$
declare
  -- Identificador fijo para que el archivo se pueda repetir sin duplicar nada.
  c_passenger constant uuid := 'b0000000-0000-4000-8000-000000000001';

  -- Dominio entregable a proposito. La API de Auth rechaza los correos
  -- @motomoto.test (hallazgo H6), y esta cuenta tiene que poder iniciar sesion
  -- de verdad.
  c_email    constant text := 'pasajero.prueba@motomoto-qa.co';
  c_password constant text := 'Pasajero.2026';
begin
  if not exists (select 1 from auth.users where id = c_passenger) then
    -- Las cuatro columnas de token van a cadena vacia y NO a nulo. Es la
    -- diferencia entre un pasajero que puede iniciar sesion y uno que no -ver
    -- el comentario largo en seed_test_driver.sql para el porque-.
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      c_passenger, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      c_email, extensions.crypt(c_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Pasajero de prueba","phone":"3009996655"}',
      '', '', '', ''
    );

    -- El disparador on_auth_user_created ya creo el perfil, con rol
    -- passenger por defecto -que es justo lo que hace falta aqui-, asi que no
    -- hay que sustituir la fila como si hiciera falta un rol distinto.
    update public.profiles
    set full_name = 'Pasajero de prueba', phone = '3009996655'
    where id = c_passenger;
  end if;
end;
$semilla$;

select id, full_name, phone, role, status from public.profiles where id = 'b0000000-0000-4000-8000-000000000001';
