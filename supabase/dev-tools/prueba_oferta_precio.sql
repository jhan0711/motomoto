-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba del punto 4 del plan del 2026-09-23 (D277): el pasajero propone el
-- valor y el conductor lo ve. Cubre `request_ride(p_offered_amount)`,
-- `get_min_offer_amount` y `list_driver_offers`.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_oferta_precio.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila. El
-- montaje es el de `prueba_solicitud_con_valor.sql`: la franja nocturna se aparta
-- para que las cifras de dia no dependan de la hora de ejecucion.
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

    -- SE ELIGE UN CONDUCTOR APROBADO, no "el primero que haya". Al dar de alta a
  -- alguien desde el panel (paso 4b) nace **pendiente de aprobar**, y si ese cae
  -- el primero en el orden, todo lo que dependa de su disponibilidad se cae con
  -- `drivers_available_only_when_approved`. Paso el 2026-08-27, con un conductor
  -- creado desde el panel minutos antes.
  --
  -- Quinta vez que una prueba se rompe por una premisa heredada del mundo real.
  -- **Una prueba no toma lo que encuentra: toma lo que necesita.**
  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' order by d.id limit 1;

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
-- Las comprobaciones
-- -----------------------------------------------------------------------------
--
-- Cada intento que se acepta deja al pasajero con una solicitud viva, y el
-- indice `rr_one_active_per_passenger` no admite dos a la vez: por eso se
-- expira a mano entre un intento y el siguiente.

do $oferta$
declare
  a actores;
  v_h text;
  v_id uuid;
  v_r record;
  v_o record;
  v_carga uuid;
  v_n integer := 1;
begin
  select * into a from actores;
  select id into v_carga from public.cargo_types where is_active order by name limit 1;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  -- El piso sale de la tabla.
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El piso es la tarifa urbana mas baja',
    '4000', public.get_min_offer_amount()::text, public.get_min_offer_amount() = 4000);

  -- Sin oferta rige la tarifa oficial: los clientes viejos no se rompen.
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint);
  select fare_amount, fare_trip_amount, fare_cargo_amount into v_r from public.ride_requests where id = v_id;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Sin oferta: fare_amount es la tarifa oficial',
    '4000', v_r.fare_amount::text, v_r.fare_amount = 4000);
  execute 'reset role';
  update public.ride_requests set status = 'expired' where id = v_id;
  execute 'set local role authenticated';

  -- Con oferta por encima: manda la oferta, el desglose queda como referencia.
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint,
    p_offered_amount => 5000);
  select fare_amount, fare_trip_amount, fare_cargo_amount into v_r from public.ride_requests where id = v_id;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Oferta 5000: fare_amount 5000 y desglose oficial 4000',
    '5000 / 4000', v_r.fare_amount || ' / ' || v_r.fare_trip_amount,
    v_r.fare_amount = 5000 and v_r.fare_trip_amount = 4000);

  -- El conductor la ve con el valor, la tarifa oficial y el tipo de servicio.
  execute 'reset role';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
  select * into v_o from public.list_driver_offers() where request_id = v_id;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El conductor ve la oferta: 5000, oficial 4000, pasajeros',
    '5000 / 4000 / passenger / 1',
    coalesce(v_o.fare_amount || ' / ' || v_o.fare_official_amount || ' / ' || v_o.service_type || ' / ' || v_o.passenger_count, 'NO LA VE'),
    v_o.fare_amount = 5000 and v_o.fare_official_amount = 4000
      and v_o.service_type = 'passenger' and v_o.passenger_count = 1);
  execute 'reset role';
  update public.ride_requests set status = 'expired' where id = v_id;
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', a.pasajero, 'role', 'authenticated')::text);

  -- Por debajo del piso.
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint,
      p_offered_amount => 3999);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta 3999 (bajo el piso)', 'OFFER_BELOW_MINIMUM', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta 3999 (bajo el piso)', 'OFFER_BELOW_MINIMUM',
      coalesce(v_h, sqlstate), v_h = 'OFFER_BELOW_MINIMUM');
  end;

  -- Negativo tambien cae bajo el piso.
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint,
      p_offered_amount => -500);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta negativa', 'OFFER_BELOW_MINIMUM', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta negativa', 'OFFER_BELOW_MINIMUM',
      coalesce(v_h, sqlstate), v_h = 'OFFER_BELOW_MINIMUM');
  end;

  -- El tope: cinco veces la oficial (4000 x 5 = 20000).
  begin
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint,
      p_offered_amount => 20001);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta 20001 (sobre el tope)', 'OFFER_ABOVE_MAXIMUM', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Oferta 20001 (sobre el tope)', 'OFFER_ABOVE_MAXIMUM',
      coalesce(v_h, sqlstate), v_h = 'OFFER_ABOVE_MAXIMUM');
  end;

  -- El tope es inclusivo.
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint,
    p_offered_amount => 20000);
  select fare_amount into v_r from public.ride_requests where id = v_id;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Oferta 20000 (justo en el tope) se acepta',
    '20000', v_r.fare_amount::text, v_r.fare_amount = 20000);
  execute 'reset role';
  update public.ride_requests set status = 'expired' where id = v_id;
  execute 'set local role authenticated';

  -- Debajo de la tarifa oficial pero sobre el piso: permitido (decision de la
  -- empresa). Tres pasajeros cuestan 8500; se ofrece 4000.
  v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 3::smallint,
    p_offered_amount => 4000);
  select fare_amount, fare_trip_amount into v_r from public.ride_requests where id = v_id;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Tres pasajeros ofreciendo 4000: se acepta, oficial queda en 8500',
    '4000 / 8500', v_r.fare_amount || ' / ' || v_r.fare_trip_amount,
    v_r.fare_amount = 4000 and v_r.fare_trip_amount = 8500);
  execute 'reset role';
  update public.ride_requests set status = 'expired' where id = v_id;
  execute 'set local role authenticated';

  -- Encomienda con carga: el conductor ve la descripcion y la carga.
  if v_carga is not null then
    v_id := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 0::smallint,
      null, null, null, 'parcel', 'Caja con documentos', array[v_carga], array[2::smallint],
      p_offered_amount => 9000);
    execute 'reset role';
    execute 'set local role authenticated';
    execute format('set local request.jwt.claims to %L',
      json_build_object('sub', a.conductor, 'role', 'authenticated')::text);
    select * into v_o from public.list_driver_offers() where request_id = v_id;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Encomienda: el conductor ve tipo, descripcion, carga y valor',
      'parcel / Caja con documentos / 2 x ... / 9000',
      coalesce(v_o.service_type || ' / ' || v_o.parcel_description || ' / ' || coalesce(v_o.cargo_summary, 'SIN CARGA') || ' / ' || v_o.fare_amount, 'NO LA VE'),
      v_o.service_type = 'parcel' and v_o.parcel_description = 'Caja con documentos'
        and v_o.cargo_summary like '2 x %' and v_o.fare_amount = 9000);
    execute 'reset role';
    update public.ride_requests set status = 'expired' where id = v_id;
  end if;
end
$oferta$;


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
  -- `coalesce` A PROPOSITO: una comprobacion cuyo `ok` salga NULL -pasa cuando se
  -- compara contra un `select ... into` que no encontro fila- se veia FALLA en su
  -- linea pero **no contaba en el total**, porque `bool_and` ignora los NULL. El
  -- total podia decir "0 fallando" con comprobaciones en rojo. Un NULL es un fallo.
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
