-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Segundo conductor de prueba. Hermano de seed_test_driver.sql y con las mismas
-- reglas: vive fuera de supabase/migrations/, asi que db push no lo mira, y no
-- se llama seed.sql, asi que db reset tampoco. Solo se ejecuta a mano.
--
-- NUNCA debe ejecutarse contra produccion: crea una cuenta con contrasena
-- conocida y escrita en claro unas lineas mas abajo.
--
--   correo: conductor2.prueba@motomoto-qa.co
--   clave:  Conductor2.2026
--
-- PARA QUE SIRVE TENER DOS. Con uno solo no se pueden probar las situaciones
-- que mas cuesta acertar, y que son justo las que la Fase 13 tenia que resolver:
--
--   - Dos conductores compitiendo por la misma solicitud, para ver que solo
--     entra uno y que al otro se le retira la oferta de la pantalla
--   - Que una solicitud se ofrezca de verdad a todos los disponibles (D160, R4),
--     que con un unico conductor no se distingue de ofrecersela solo a el
--   - Repartir un grupo entre dos motorratones el dia que eso se implemente
--
-- Se ejecuta asi, y se puede repetir tantas veces como haga falta:
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_second_driver.sql
--
-- LO QUE MAS MOLESTA AL PROBAR, igual que con el primero: find_available_drivers
-- descarta a cualquier conductor cuya ubicacion tenga mas de DOS MINUTOS. Si
-- llevas mas de ese rato sin ejecutar este archivo, vuelve a ejecutarlo antes de
-- probar o la aplicacion dira que no hay motorratones.
-- =============================================================================

do $semilla$
declare
  -- Identificadores fijos, para poder repetir el archivo sin duplicar nada.
  c_driver  constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_vehicle constant uuid := 'e0000000-0000-4000-8000-000000000002';

  c_email    constant text := 'conductor2.prueba@motomoto-qa.co';
  c_password constant text := 'Conductor2.2026';

  -- Al otro lado del parque respecto del primer conductor, a unos 220 metros
  -- (coordenada del parque alineada con `places` en la Fase 25, H17).
  -- Separarlos importa: con los dos en el mismo punto, la distancia de las dos
  -- ofertas sale igual y no se puede comprobar que el orden por cercania
  -- funciona.
  c_lng constant double precision := -75.0762;
  c_lat constant double precision := 6.9089;
begin
  if not exists (select 1 from auth.users where id = c_driver) then
    -- Las cuatro columnas de token van a cadena vacia y NO a nulo. Es la
    -- diferencia entre un conductor que puede iniciar sesion y uno que no:
    -- GoTrue las lee como texto y un nulo hace que el inicio de sesion responda
    -- 500 con "Database error querying schema". Leccion E28 de la Fase 12.
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      c_driver, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      c_email, extensions.crypt(c_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Segundo conductor","phone":"3009997766"}',
      '', '', '', ''
    );

    -- El disparador on_auth_user_created ya creo el perfil, pero con rol
    -- passenger, y profiles_protect_columns revierte cualquier UPDATE del rol
    -- incluso ejecutando como postgres (hallazgo H5). El disparador es BEFORE
    -- UPDATE y no cubre INSERT, asi que la unica via es sustituir la fila.
    delete from public.profiles where id = c_driver;

    insert into public.profiles (id, full_name, phone, role, status)
    values (c_driver, 'Segundo conductor', '3009997766', 'driver', 'active');

    -- approval_status se fija aqui por el mismo motivo: drivers_protect_columns
    -- tampoco deja cambiarlo despues. Y sin approved no se puede estar
    -- disponible, que lo impide drivers_available_only_when_approved.
    insert into public.drivers (id, approval_status, approved_at, is_available)
    values (c_driver, 'approved', now(), true);
  end if;

  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status)
  values (c_vehicle, 98, 'PRB98D', 'Motorraton de prueba 2', 3, 'active')
  on conflict (id) do nothing;

  if not exists (
    select 1 from public.driver_vehicle_assignments
    where driver_id = c_driver and unassigned_at is null
  ) then
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (c_driver, c_vehicle);
  end if;

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
-- tablas por separado. Deben salir LOS DOS conductores de prueba, con distinta
-- distancia al parque; si sale uno solo, al otro se le caduco la ubicacion.
select
  d.full_name,
  d.unit_number,
  d.plate,
  d.max_passengers,
  round(d.distance_m::numeric, 0) as distancia_al_parque_m,
  (select round(extract(epoch from (now() - updated_at))::numeric, 0)
     from public.driver_locations where driver_id = d.driver_id) as antiguedad_ubicacion_s
from public.find_available_drivers(
       extensions.st_setsrid(extensions.st_makepoint(-75.074987, 6.907392), 4326)::extensions.geography,
       1::smallint
     ) d
order by d.distance_m;
