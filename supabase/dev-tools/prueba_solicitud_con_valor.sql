-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `request_ride` reescrita en `20260826040000_request_ride_with_fare.sql`
-- (bloque especial, paso 4).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_solicitud_con_valor.sql
--
-- LA MITAD DE ESTE ARCHIVO ES REGRESION DE E30, y hay un motivo para insistir.
-- E30 fue reescribir `request_ride` partiendo de una version vieja y borrar sin
-- darse cuenta las dos comprobaciones de zona de servicio y la caducidad
-- dirigida. `PROJECT_STATUS.md` dice que entonces "se anadieron tres pruebas de
-- regresion" en `prueba_referencia.sql`, y **ese archivo no esta en el
-- repositorio**: la red que deberia haber protegido esta reescritura no existia.
-- Asi que se escribe aqui.
--
-- Las once comprobaciones que la funcion ya tenia se prueban una por una. No es
-- desconfianza del codigo recien escrito: es que la forma de romperlo ya se
-- conoce y cuesta poco cerrarla.
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- LA FRANJA NOCTURNA SE APARTA, PARA QUE ESTE ARCHIVO NO DEPENDA DE LA HORA
-- -----------------------------------------------------------------------------
--
-- Este archivo comprueba la tarifa que nace con la solicitud, y `request_ride`
-- calcula el valor con `now()`: no admite que se le pase una hora. Asi que las
-- comprobaciones que esperan 4.000 -la urbana de dia- **fallaban al ejecutarlas
-- de noche**, devolviendo los 7.000 de la franja nocturna. Paso el 2026-08-27 a
-- las 22:20 hora de Amalfi, con tres comprobaciones en rojo y el servidor
-- teniendo razon.
--
-- Es exactamente la leccion que el bloque especial dejo escrita al hacer
-- `prueba_calculo_tarifa.sql` -"todas las comprobaciones pasan la hora a mano,
-- ninguna deja now(); una prueba que no fije la hora pasaria por la tarde y
-- fallaria a medianoche"-, **y a este archivo no se le aplico**.
--
-- Como aqui no se puede fijar la hora, se aparta la franja: se mueve a una que
-- no incluya el momento de la ejecucion, sea cual sea. Como todo lo demas del
-- archivo, se deshace con el `rollback` del final y produccion no se entera.
do $franja$
declare
  v_hora integer;
begin
  select extract(hour from now() at time zone (
    select value #>> '{}' from public.app_settings where key = 'fare_timezone'
  ))::integer into v_hora;

  -- Una ventana de una hora que empieza justo despues de la hora actual: nunca
  -- cae encima de "ahora", corra el archivo a la hora que corra.
  update public.app_settings
  set value = to_jsonb(((v_hora + 2) % 24))
  where key = 'night_fare_start_hour';

  update public.app_settings
  set value = to_jsonb(((v_hora + 3) % 24))
  where key = 'night_fare_end_hour';
end
$franja$;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

create temp table actores (
  pasajero uuid,
  conductor uuid,
  otro_pasajero uuid,
  vehiculo uuid,
  capacidad smallint,
  lng double precision,
  lat double precision
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
  execute 'grant select on actores to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Montaje
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_pas   uuid;
  v_otro  uuid;
  v_cond  uuid;
  v_veh   uuid;
  v_cap   smallint;
  v_lng   double precision;
  v_lat   double precision;
  v_n     integer;
begin
  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places where name = 'El parque';

  -- Se desactivan las tarifas rurales reales, dentro de esta transaccion. Este
  -- archivo pasa "el parque" como coordenada suelta, sin `place_id` -al reves
  -- que la aplicacion real, que si lo manda-, y desde que se cargaron los
  -- primeros destinos rurales de verdad (Alto del Rio queda a 1.432 m del
  -- parque, dentro del radio de D230) esa coordenada suelta empezo a pegarsele
  -- a un rural real. Se apaga para que la prueba no dependa de que ningun
  -- destino rural futuro caiga cerca del parque. Mismo ajuste que en
  -- `prueba_calculo_tarifa.sql`.
  update public.rural_fares set is_active = false;

  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;

  select p.id into v_otro from public.profiles p
  where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
  order by p.created_at limit 1;

  select d.id into v_cond from public.drivers d order by d.id limit 1;

  -- LA PRUEBA CREA SU PROPIA ASIGNACION SI NO LA HAY, en vez de dar por hecho
  -- que el conductor tiene motorraton. Dejo de ser cierto el 2026-08-27, cuando
  -- el usuario probo la pantalla de motorratones del panel y quito y reasigno
  -- unidades: el conductor se quedo sin ninguna vigente y esta prueba se cayo
  -- con un 23502, sin que nada estuviera roto.
  --
  -- Es la cuarta vez que una prueba se pone roja por una premisa heredada del
  -- mundo real -antes: el `sum` de prueba_recaudo, y las dos de
  -- prueba_notificaciones-. La regla ya deberia estar aprendida: **una prueba
  -- monta lo que necesita, no lo encuentra.**
  select a.vehicle_id, v.max_passengers into v_veh, v_cap
  from public.driver_vehicle_assignments a
    join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = v_cond and a.unassigned_at is null;

  if v_veh is null then
    select v.id, v.max_passengers into v_veh, v_cap
    from public.vehicles v where v.status = 'active' limit 1;
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
    values (v_cond, v_veh);
  end if;

  -- El conductor, disponible y con la posicion recien puesta. **La ubicacion de
  -- los conductores de prueba caduca a los dos minutos**, asi que este archivo
  -- no puede depender de que alguien haya ejecutado la semilla hace un rato: se
  -- la pone el mismo, y el rollback la deja como estaba.
  update public.drivers set is_available = true where id = v_cond;

  insert into public.driver_locations (driver_id, location, updated_at)
  values (v_cond,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    now())
  on conflict (driver_id) do update
    set location = excluded.location, updated_at = now();

  -- Los demas conductores fuera, para que las cuentas de ofertas sean exactas.
  update public.drivers set is_available = false where id <> v_cond;

  -- El pasajero, sin nada vivo. Los tres estados del indice
  -- `rr_one_active_per_passenger`, no solo 'searching'.
  update public.ride_requests set status = 'expired'
  where passenger_id in (v_pas, v_otro)
    and status in ('searching', 'assigned', 'in_progress');

  update public.rides
  set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where driver_id = v_cond
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  insert into actores values (v_pas, v_cond, v_otro, v_veh, v_cap, v_lng, v_lat);

  select count(*) into v_n
  from public.find_available_drivers(
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    1::smallint);

  insert into resultados values (1, 'Montaje: hay un conductor disponible en el parque',
    '1', v_n::text, v_n = 1);
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Regresion de E30: las once comprobaciones que la funcion ya tenia
-- -----------------------------------------------------------------------------

do $e30$
declare
  a actores;
  v_h text;
  v_id uuid;
begin
  select * into a from actores;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  -- D150, primera mitad. Medellin esta fuera del poligono de Amalfi.
  begin
    v_id := public.request_ride(-75.5636, 6.2518, 'Medellin',
      a.lng, a.lat, 'El parque', 1::smallint);
    insert into resultados values (2, 'E30: origen fuera de la zona de servicio',
      'ORIGIN_OUT_OF_AREA', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (2, 'E30: origen fuera de la zona de servicio',
      'ORIGIN_OUT_OF_AREA', coalesce(v_h, sqlstate), v_h = 'ORIGIN_OUT_OF_AREA');
  end;

  -- D150, segunda mitad. Es la que E30 borro junto con la anterior.
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      -75.5636, 6.2518, 'Medellin', 1::smallint);
    insert into resultados values (3, 'E30: destino fuera de la zona de servicio',
      'DESTINATION_OUT_OF_AREA', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (3, 'E30: destino fuera de la zona de servicio',
      'DESTINATION_OUT_OF_AREA', coalesce(v_h, sqlstate), v_h = 'DESTINATION_OUT_OF_AREA');
  end;

  -- R11, leida de app_settings.
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 4::smallint);
    insert into resultados values (4, 'R11: cuatro pasajeros',
      'PASSENGER_COUNT_OUT_OF_RANGE', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (4, 'R11: cuatro pasajeros',
      'PASSENGER_COUNT_OUT_OF_RANGE', coalesce(v_h, sqlstate),
      v_h = 'PASSENGER_COUNT_OUT_OF_RANGE');
  end;

  -- D172: se rechaza en lugar de recortar.
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 1::smallint, null, null, repeat('x', 81));
    insert into resultados values (5, 'Referencia de 81 caracteres',
      'PICKUP_REFERENCE_TOO_LONG', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (5, 'Referencia de 81 caracteres',
      'PICKUP_REFERENCE_TOO_LONG', coalesce(v_h, sqlstate),
      v_h = 'PICKUP_REFERENCE_TOO_LONG');
  end;

  execute 'reset role';

  -- El rol se comprueba suplantando a un CONDUCTOR de verdad, no cambiandole el
  -- rol a nadie. `protect_profile_columns` revierte en silencio un cambio de rol
  -- hecho sin ser administrador, y una prueba montada asi saldria mal por el
  -- motivo equivocado: es exactamente E11.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 1::smallint);
    insert into resultados values (6, 'Un conductor no puede pedir un servicio',
      'NOT_A_PASSENGER', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Un conductor no puede pedir un servicio',
      'NOT_A_PASSENGER', coalesce(v_h, sqlstate), v_h = 'NOT_A_PASSENGER');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$e30$;


-- -----------------------------------------------------------------------------
-- El telefono, que la encomienda tambien necesita
-- -----------------------------------------------------------------------------

do $telefono$
declare
  a actores;
  v_tel text;
  v_h   text;
  v_id  uuid;
begin
  select * into a from actores;

  select phone into v_tel from public.profiles where id = a.pasajero;
  update public.profiles set phone = null where id = a.pasajero;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 1::smallint);
    insert into resultados values (7, 'Sin telefono no se puede pedir',
      'PHONE_REQUIRED', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Sin telefono no se puede pedir',
      'PHONE_REQUIRED', coalesce(v_h, sqlstate), v_h = 'PHONE_REQUIRED');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  update public.profiles set phone = v_tel where id = a.pasajero;
end
$telefono$;


-- -----------------------------------------------------------------------------
-- El camino feliz, con el valor dentro
-- -----------------------------------------------------------------------------

do $feliz$
declare
  a actores;
  v_id  uuid;
  v_r   public.ride_requests;
  v_n   integer;
  v_bici uuid;
  v_caja uuid;
  v_q    record;
begin
  select * into a from actores;
  select id into v_bici from public.cargo_types where name = 'Bicicleta';
  select id into v_caja from public.cargo_types where name = 'Caja pequeña';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  -- --------------------------------------------------------- viaje de siempre

  v_id := public.request_ride(a.lng, a.lat, 'El parque',
    a.lng, a.lat, 'El parque', 1::smallint, null, null, '   frente a la tienda   ');

  execute 'reset role';
  execute 'reset request.jwt.claims';

  select * into v_r from public.ride_requests where id = v_id;

  insert into resultados values (8, 'Un viaje de pasajeros normal se sigue creando',
    'una solicitud', case when v_r.id is null then 'ninguna' else 'una solicitud' end,
    v_r.id is not null);

  insert into resultados values (9, 'Nace con su valor: 4.000 urbano de una persona',
    '4000 / 4000 / 0',
    coalesce(v_r.fare_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_trip_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_cargo_amount::text, 'nulo'),
    v_r.fare_amount = 4000 and v_r.fare_trip_amount = 4000 and v_r.fare_cargo_amount = 0);

  insert into resultados values (10, 'Urbano: sin referencia de tarifa y sin marca rural',
    'false / nulo',
    coalesce(v_r.fare_is_rural::text, 'nulo') || ' / ' || coalesce(v_r.fare_reference, 'nulo'),
    v_r.fare_is_rural = false and v_r.fare_reference is null);

  -- La normalizacion, que E30 no toco pero conviene no perder.
  insert into resultados values (11, 'La referencia se guarda sin los espacios de los extremos',
    'frente a la tienda', coalesce(v_r.pickup_reference, 'nulo'),
    v_r.pickup_reference = 'frente a la tienda');

  insert into resultados values (12, 'Y el servicio queda marcado como de pasajeros',
    'passenger', v_r.service_type::text, v_r.service_type = 'passenger');

  -- Se sigue ofreciendo. Es la ultima linea de la funcion y la mas facil de
  -- perder en una reescritura.
  select count(*) into v_n from public.ride_offers where request_id = v_id;
  insert into resultados values (13, 'La solicitud se ofrecio al conductor disponible',
    '1', v_n::text, v_n = 1);

  -- R6 con esa viva.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 1::smallint);
    insert into resultados values (14, 'R6: ya tiene un servicio en curso',
      'ACTIVE_REQUEST_EXISTS', 'LA ACEPTO', false);
  exception when others then
    declare v_h text;
    begin
      get stacked diagnostics v_h = pg_exception_hint;
      insert into resultados values (14, 'R6: ya tiene un servicio en curso',
        'ACTIVE_REQUEST_EXISTS', coalesce(v_h, sqlstate), v_h = 'ACTIVE_REQUEST_EXISTS');
    end;
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- D151, LA CADUCIDAD DIRIGIDA, que es la tercera cosa que E30 borro.
  --
  -- Se deja la solicitud viva pero ya vencida. La funcion tiene que caducarla
  -- ella misma y dejar crear otra. Sin esta linea, quien abandono una solicitud
  -- y vuelve dentro de la ventana de un minuto entre dos pasadas de pg_cron
  -- leeria "ya tienes un servicio en curso" por algo que ya no existe.
  -- SE MUEVEN LAS DOS FECHAS, no solo la de caducidad. `rr_expiry_after_request`
  -- exige que la caducidad sea posterior a la peticion, asi que dejar
  -- `requested_at` en ahora y la caducidad un minuto antes es una fila que la
  -- base rechaza. La primera version de este archivo lo hacia y se cayo entera.
  update public.ride_requests
  set requested_at = now() - interval '10 minutes',
      expires_at = now() - interval '1 minute'
  where id = (select id from public.ride_requests
              where passenger_id = a.pasajero and status = 'searching' limit 1);

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque',
      a.lng, a.lat, 'El parque', 1::smallint,
      null, null, null, 'passenger', null, array[v_bici], array[1::smallint]);
    insert into resultados values (15, 'E30/D151: una vencida no bloquea, la funcion la caduca',
      'crea otra', 'la creo', true);
  exception when others then
    declare v_h text;
    begin
      get stacked diagnostics v_h = pg_exception_hint;
      insert into resultados values (15, 'E30/D151: una vencida no bloquea, la funcion la caduca',
        'crea otra', 'LA RECHAZO ' || coalesce(v_h, sqlstate), false);
    end;
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- --------------------------------------------------------- pasajero + carga

  select * into v_r from public.ride_requests where id = v_id;

  insert into resultados values (16, 'Pasajero con bicicleta: 4.000 + 2.300',
    '6300 / 4000 / 2300',
    coalesce(v_r.fare_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_trip_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_cargo_amount::text, 'nulo'),
    v_r.fare_amount = 6300 and v_r.fare_trip_amount = 4000 and v_r.fare_cargo_amount = 2300);

  select count(*), max(unit_amount), max(quantity)
    into v_n, v_r.fare_trip_amount, v_r.passenger_count
  from public.ride_request_cargo where request_id = v_id;

  insert into resultados values (17, 'La carga quedo guardada con su precio congelado',
    '1 linea de 2300 x1',
    v_n || ' linea(s) de ' || coalesce(v_r.fare_trip_amount::text, 'nulo') ||
      ' x' || coalesce(v_r.passenger_count::text, '?'),
    v_n = 1 and v_r.fare_trip_amount = 2300 and v_r.passenger_count = 1);

  -- D225: el catalogo sube y lo guardado no se mueve.
  update public.cargo_types set amount = 9999 where id = v_bici;
  select unit_amount into v_n from public.ride_request_cargo where request_id = v_id;
  insert into resultados values (18, 'Sube el catalogo y el precio congelado no se mueve',
    '2300', v_n::text, v_n = 2300);
  update public.cargo_types set amount = 2300 where id = v_bici;

  -- Y el valor guardado tiene que ser el mismo que devuelve la funcion de
  -- consulta para los mismos datos. Si alguna vez dejan de coincidir, el
  -- pasajero pagaria algo distinto de lo que vio.
  -- D233: la firma ahora lleva el origen tambien. Aqui el origen y el destino
  -- son el mismo punto, el parque, igual que en la solicitud que se comparo.
  select * into v_q from public.quote_fare('passenger', 1::smallint, a.lng, a.lat,
    a.lng, a.lat, null, null, array[v_bici], array[1::smallint]);
  insert into resultados values (19, 'Lo guardado coincide con lo que ve la pantalla',
    v_q.total_amount::text, v_r.fare_amount::text, v_q.total_amount = v_r.fare_amount);

  update public.ride_requests set status = 'expired' where id = v_id;
end
$feliz$;


-- -----------------------------------------------------------------------------
-- La encomienda, de punta a punta
-- -----------------------------------------------------------------------------

do $encomienda$
declare
  a actores;
  v_id   uuid;
  v_r    public.ride_requests;
  v_cafe uuid;
  v_caja uuid;
  v_h    text;
  v_n    integer;
begin
  select * into a from actores;
  select id into v_cafe from public.cargo_types where name = 'Bulto de café';
  select id into v_caja from public.cargo_types where name = 'Caja pequeña';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  -- 20. La encomienda bien formada. Bulto de cafe: la mayor entre 4.000 y 4.900.
  v_id := public.request_ride(a.lng, a.lat, 'El parque',
    a.lng, a.lat, 'El parque', 0::smallint,
    null, null, null, 'parcel', 'Caja con documentos',
    array[v_cafe], array[1::smallint]);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  select * into v_r from public.ride_requests where id = v_id;

  insert into resultados values (20, 'Una encomienda se crea con cero pasajeros',
    'parcel / 0 pasajeros',
    v_r.service_type::text || ' / ' || v_r.passenger_count || ' pasajeros',
    v_r.service_type = 'parcel' and v_r.passenger_count = 0);

  insert into resultados values (21, 'Con su descripcion guardada',
    'Caja con documentos', coalesce(v_r.parcel_description, 'nulo'),
    v_r.parcel_description = 'Caja con documentos');

  insert into resultados values (22, 'Y su valor: la mayor entre 4.000 y 4.900',
    '4900 / 4000 / 4900',
    coalesce(v_r.fare_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_trip_amount::text, 'nulo') || ' / ' ||
    coalesce(v_r.fare_cargo_amount::text, 'nulo'),
    v_r.fare_amount = 4900 and v_r.fare_trip_amount = 4000 and v_r.fare_cargo_amount = 4900);

  select count(*) into v_n from public.ride_offers where request_id = v_id;
  insert into resultados values (23, 'La encomienda tambien se ofrece a los conductores',
    '1', v_n::text, v_n = 1);

  update public.ride_requests set status = 'expired' where id = v_id;

  -- ------------------------------------------------------- lo que debe rechazar

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      0::smallint, null, null, null, 'parcel', null, array[v_caja], array[1::smallint]);
    insert into resultados values (24, 'Encomienda sin descripcion',
      'PARCEL_DESCRIPTION_REQUIRED', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (24, 'Encomienda sin descripcion',
      'PARCEL_DESCRIPTION_REQUIRED', coalesce(v_h, sqlstate),
      v_h = 'PARCEL_DESCRIPTION_REQUIRED');
  end;

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      0::smallint, null, null, null, 'parcel', 'ab', array[v_caja], array[1::smallint]);
    insert into resultados values (25, 'Encomienda con descripcion de dos letras',
      'PARCEL_DESCRIPTION_LENGTH', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (25, 'Encomienda con descripcion de dos letras',
      'PARCEL_DESCRIPTION_LENGTH', coalesce(v_h, sqlstate),
      v_h = 'PARCEL_DESCRIPTION_LENGTH');
  end;

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      1::smallint, null, null, null, 'parcel', 'Caja con documentos',
      array[v_caja], array[1::smallint]);
    insert into resultados values (26, 'Encomienda con un pasajero a bordo',
      'PARCEL_HAS_NO_PASSENGERS', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (26, 'Encomienda con un pasajero a bordo',
      'PARCEL_HAS_NO_PASSENGERS', coalesce(v_h, sqlstate),
      v_h = 'PARCEL_HAS_NO_PASSENGERS');
  end;

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      0::smallint, null, null, null, 'parcel', 'Caja con documentos', '{}', '{}');
    insert into resultados values (27, 'Encomienda sin ninguna carga declarada',
      'PARCEL_NEEDS_CARGO', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (27, 'Encomienda sin ninguna carga declarada',
      'PARCEL_NEEDS_CARGO', coalesce(v_h, sqlstate), v_h = 'PARCEL_NEEDS_CARGO');
  end;

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      1::smallint, null, null, null, 'passenger', 'Bulto de cafe', '{}', '{}');
    insert into resultados values (28, 'Viaje de pasajeros con descripcion de encomienda',
      'PARCEL_DESCRIPTION_NOT_ALLOWED', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (28, 'Viaje de pasajeros con descripcion de encomienda',
      'PARCEL_DESCRIPTION_NOT_ALLOWED', coalesce(v_h, sqlstate),
      v_h = 'PARCEL_DESCRIPTION_NOT_ALLOWED');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$encomienda$;


-- -----------------------------------------------------------------------------
-- D220 de punta a punta, y el hueco que destapo
-- -----------------------------------------------------------------------------

do $capacidad$
declare
  a actores;
  v_id  uuid;
  v_rq  uuid := 'f9000000-0000-4000-8000-000000000001';
  v_h   text;
  v_n   integer;
begin
  select * into a from actores;

  -- El motorraton, lleno: un viaje que ocupa todos sus asientos.
  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count,
    origin, origin_label, destination, destination_label, contact_phone, expires_at
  )
  select v_rq, a.otro_pasajero, 'passenger', a.capacidad,
    p.location, 'A', p.location, 'B', '3009876543', now() + interval '5 minutes'
  from public.places p where p.name = 'El parque';

  insert into public.rides (request_id, driver_id, vehicle_id, status, passenger_count)
  values (v_rq, a.conductor, a.vehiculo, 'assigned', a.capacidad);

  -- 29. LA COMPROBACION QUE PRUEBA D220 DE VERDAD. Con el motorraton lleno de
  --     pasajeros, la encomienda pide cero asientos, asi que el conductor sigue
  --     siendo candidato y la solicitud se crea.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      0::smallint, null, null, null, 'parcel', 'Caja con documentos',
      array[(select id from public.cargo_types where name = 'Caja pequeña')],
      array[1::smallint]);
    insert into resultados values (29, 'D220: con el motorraton lleno, la encomienda entra igual',
      'la crea', 'la creo', true);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (29, 'D220: con el motorraton lleno, la encomienda entra igual',
      'la crea', 'LA RECHAZO ' || coalesce(v_h, sqlstate), false);
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  update public.ride_requests set status = 'expired'
  where passenger_id = a.pasajero and status = 'searching';

  -- 30. EL HUECO, Y SE ESPERA EN VERDE RECHAZANDO. No es lo que queremos que
  --     pase: es lo que pasa hoy, medido para que quede escrito.
  --
  --     La comprobacion 29 funciona porque este archivo dejo `is_available` en
  --     cierto a mano. En la vida real no seria asi: `accept_ride_offer` hace
  --     `is_available = (is_available and v_free > 0)`, o sea que **un conductor
  --     que se llena queda marcado como no disponible**, y `find_available_drivers`
  --     filtra por esa columna antes de contar asientos. Resultado: a un
  --     motorraton lleno NUNCA se le ofreceria una encomienda, aunque D220 diga
  --     que la carga va en la parrilla y no quita puesto.
  --
  --     Es una decision de la empresa, no del codigo, y por eso no se cambia
  --     aqui: tocar la disponibilidad afecta a los caminos vivos de las fases 13
  --     y 14. Queda como hallazgo abierto.
  update public.drivers set is_available = false where id = a.conductor;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque',
      0::smallint, null, null, null, 'parcel', 'Caja con documentos',
      array[(select id from public.cargo_types where name = 'Caja pequeña')],
      array[1::smallint]);
    insert into resultados values (30, 'Hallazgo abierto: al conductor no disponible no le llega',
      'NO_DRIVERS_AVAILABLE (hallazgo)', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (30, 'Hallazgo abierto: al conductor no disponible no le llega',
      'NO_DRIVERS_AVAILABLE (hallazgo)', coalesce(v_h, sqlstate),
      v_h = 'NO_DRIVERS_AVAILABLE');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$capacidad$;


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------

do $permisos2$
declare
  v_firma constant text :=
    'public.request_ride(double precision,double precision,text,double precision,double precision,text,smallint,uuid,uuid,text,public.service_type,text,uuid[],smallint[])';
  v_ok boolean;
begin
  select has_function_privilege('anon', v_firma, 'execute') into v_ok;
  insert into resultados values (31, 'Sin sesion no se puede crear una solicitud',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('authenticated', v_firma, 'execute') into v_ok;
  insert into resultados values (32, 'El pasajero SI puede crear una solicitud',
    'true', v_ok::text, v_ok = true);
end
$permisos2$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion,
  r.esperado,
  r.obtenido
from resultados r
union all
select
  999,
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
