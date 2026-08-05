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
-- Para que sirve. request_ride comprueba la regla R1 antes de crear nada: si no
-- hay ningun conductor disponible con capacidad suficiente, responde
-- NO_DRIVERS_AVAILABLE y no crea la solicitud. Hasta la Fase 12 no existe el
-- modulo del conductor y hasta la Fase 20 no existe el panel, asi que sin esta
-- semilla no hay forma de ver una solicitud creandose de verdad.
--
-- Es idempotente y ADEMAS refresca la ubicacion, que es lo que caduca. Se puede
-- ejecutar tantas veces como haga falta:
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_test_driver.sql
--
-- LO QUE MAS MOLESTA AL PROBAR: find_available_drivers descarta a cualquier
-- conductor cuya ubicacion tenga mas de DOS MINUTOS. Ese valor es un parametro
-- por defecto de la funcion, no se lee de app_settings, asi que no se puede
-- alargar desde la configuracion. En la practica: si llevas mas de dos minutos
-- sin ejecutar este archivo, vuelve a ejecutarlo antes de probar o la aplicacion
-- dira que no hay motorratones.
-- =============================================================================

do $semilla$
declare
  -- Identificadores fijos para que el archivo se pueda repetir sin duplicar nada
  -- ni cambiar de identificador entre ejecuciones.
  c_driver  constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_vehicle constant uuid := 'e0000000-0000-4000-8000-000000000001';

  -- Dominio entregable a proposito. La API de Auth rechaza los correos
  -- @motomoto.test (hallazgo H6), y esta cuenta tiene que poder iniciar sesion
  -- de verdad en la Fase 12.
  c_email    constant text := 'conductor.prueba@motomoto-qa.co';
  c_password constant text := 'Conductor.2026';

  -- A unos 130 metros del parque. No exactamente encima, para que la distancia
  -- que calcula el buscador de conductores sea un numero y no un cero.
  c_lng constant double precision := -75.0760;
  c_lat constant double precision := 6.9040;
begin
  if not exists (select 1 from auth.users where id = c_driver) then
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data
    ) values (
      c_driver, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      c_email, extensions.crypt(c_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Conductor de prueba","phone":"3009998877"}'
    );

    -- El disparador on_auth_user_created ya creo el perfil, pero con rol
    -- passenger. Y profiles_protect_columns revierte cualquier UPDATE del rol
    -- incluso ejecutando como postgres, porque is_admin() depende de auth.uid()
    -- y aqui no hay sesion (hallazgo H5). El disparador es BEFORE UPDATE y no
    -- cubre INSERT, asi que la unica via es sustituir la fila.
    delete from public.profiles where id = c_driver;

    insert into public.profiles (id, full_name, phone, role, status)
    values (c_driver, 'Conductor de prueba', '3009998877', 'driver', 'active');

    -- approval_status se fija aqui por el mismo motivo: drivers_protect_columns
    -- tampoco deja cambiarlo despues. Y sin approved no se puede estar
    -- disponible, que lo impide la restriccion drivers_available_only_when_approved.
    insert into public.drivers (id, approval_status, approved_at, is_available)
    values (c_driver, 'approved', now(), true);
  end if;

  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status)
  values (c_vehicle, 99, 'PRB99D', 'Motorraton de prueba', 3, 'active')
  on conflict (id) do nothing;

  if not exists (
    select 1 from public.driver_vehicle_assignments
    where driver_id = c_driver and unassigned_at is null
  ) then
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (c_driver, c_vehicle);
  end if;

  -- is_available si se puede actualizar: no esta en la lista de columnas que
  -- protege drivers_protect_columns, porque es justo lo que el conductor cambia
  -- desde su aplicacion.
  update public.drivers set is_available = true where id = c_driver;

  -- Lo que caduca. Esta es la razon de que el archivo sea repetible.
  insert into public.driver_locations (driver_id, location, updated_at)
  values (
    c_driver,
    extensions.st_setsrid(extensions.st_makepoint(c_lng, c_lat), 4326)::extensions.geography,
    now()
  )
  on conflict (driver_id) do update
    set location = excluded.location,
        updated_at = now();
end;
$semilla$;


-- Comprobacion: se pregunta al mismo buscador que usa request_ride, no a las
-- tablas por separado. Si esto devuelve una fila, la aplicacion podra crear una
-- solicitud; si devuelve cero, algo falta por mucho que las tablas parezcan bien.
select
  d.full_name,
  d.unit_number,
  d.plate,
  d.max_passengers,
  round(d.distance_m::numeric, 0) as distancia_al_parque_m,
  (select round(extract(epoch from (now() - updated_at))::numeric, 0)
     from public.driver_locations where driver_id = d.driver_id) as antiguedad_ubicacion_s
from public.find_available_drivers(
       extensions.st_setsrid(extensions.st_makepoint(-75.0767, 6.9047), 4326)::extensions.geography,
       1::smallint
     ) d;
