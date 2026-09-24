-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba del punto 3 del plan del 2026-09-23 (D278): el libro de movimientos del
-- conductor, la comision del 4% en `complete_ride` y el bloqueo por saldo.
-- Wompi no entra: la recarga por pasarela va en otra entrega.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_saldo_conductor.sql
--
-- Todo ocurre dentro de una transaccion que se deshace, INCLUIDO el interruptor
-- `driver_balance_enforced`, que aqui se enciende y en produccion sigue apagado.
-- No deja una fila. El montaje es el de `prueba_solicitud_con_valor.sql`.
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
-- Piezas de apoyo
-- -----------------------------------------------------------------------------

-- Un viaje ya en curso, listo para terminarse, con el valor acordado que se pida.
-- Se monta como postgres y sin pasar por `request_ride`: aqui interesa lo que
-- ocurre AL TERMINAR, no como nacio.
create function pg_temp.viaje_en_curso(p_pas uuid, p_cond uuid, p_veh uuid, p_fare integer)
returns uuid
language plpgsql
as $f$
declare
  v_req uuid := gen_random_uuid();
  v_ride uuid := gen_random_uuid();
  v_geo extensions.geography;
begin
  select location into v_geo from public.places where name = 'El parque';

  update public.ride_requests set status = 'expired'
  where passenger_id = p_pas and status in ('searching', 'assigned', 'in_progress');

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural
  ) values (
    v_req, p_pas, 'assigned', 1, v_geo, 'Zz saldo origen', v_geo, 'Zz saldo destino',
    '3000000201', now() - interval '10 minutes', now() + interval '10 minutes',
    now() - interval '9 minutes', 'passenger', p_fare, 4000, 0, false, false
  );

  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values (v_ride, v_req, p_cond, p_veh, 'assigned', 1, now() - interval '9 minutes');

  update public.rides
  set status = 'in_progress', started_at = now() - interval '5 minutes',
      driver_arrived_at = now() - interval '6 minutes'
  where id = v_ride;

  update public.ride_requests set status = 'in_progress', started_at = now() - interval '5 minutes'
  where id = v_req;

  return v_ride;
end;
$f$;

create function pg_temp.como(p_uid uuid) returns void language plpgsql as $f$
begin
  execute 'reset role';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text);
end;
$f$;

create function pg_temp.como_postgres() returns void language plpgsql as $f$
begin
  execute 'reset role';
  execute 'reset request.jwt.claims';
end;
$f$;

-- -----------------------------------------------------------------------------
-- Las comprobaciones
-- -----------------------------------------------------------------------------

do $saldo$
declare
  a actores;
  v_admin uuid := 'b4000000-0000-4000-8000-0000000000a1';
  v_ride uuid;
  v_h text;
  v_n integer := 1;
  v_bal integer;
  v_row record;
  v_cuenta integer;
  v_ok boolean;
  v_offer uuid;
  v_req uuid;
  v_txt text;
begin
  select * into a from actores;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  values (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'zz.saldo.admin@motomoto-qa.co', now(), now());
  delete from public.profiles where id = v_admin;
  insert into public.profiles (id, full_name, phone, role, status)
  values (v_admin, 'Zz saldo admin', '3000000202', 'admin', 'active');

  -- El montaje dejo al conductor disponible. Se parte de conductor SIN nada en
  -- el libro y con el interruptor en su valor real (apagado).
  -- ------------------------------------------------------------------ apagado
  v_n := v_n + 1;
  select value #>> '{}' into v_txt from public.app_settings where key = 'driver_balance_enforced';
  insert into resultados values (v_n, 'El interruptor nace apagado', '0',
    coalesce(v_txt, 'NO EXISTE'), v_txt = '0');

  v_ride := pg_temp.viaje_en_curso(a.pasajero, a.conductor, a.vehiculo, 5000);
  perform pg_temp.como(a.conductor);
  perform public.complete_ride(v_ride);
  perform pg_temp.como_postgres();
  select count(*) into v_cuenta from public.driver_ledger where ride_id = v_ride;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Apagado: terminar un viaje no cobra comision', '0', v_cuenta::text, v_cuenta = 0);

  -- --------------------------------------------------------------- encendido
  -- Encender apaga a quien no alcanza: el conductor esta disponible (montaje) y
  -- tiene saldo 0.
  update public.app_settings set value = '1'::jsonb where key = 'driver_balance_enforced';
  select is_available into v_ok from public.drivers where id = a.conductor;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Encender el interruptor apaga al conductor sin saldo',
    'false', v_ok::text, v_ok = false);

  perform pg_temp.como(a.conductor);
  select * into v_row from public.get_my_balance();
  perform pg_temp.como_postgres();
  v_n := v_n + 1;
  insert into resultados values (v_n, 'get_my_balance: saldo 0, minimo 160, no puede trabajar',
    '0 / 160 / t / false',
    v_row.balance || ' / ' || v_row.min_required || ' / ' || v_row.enforced || ' / ' || v_row.can_work,
    v_row.balance = 0 and v_row.min_required = 160 and v_row.enforced and not v_row.can_work);

  -- No se puede encender sin saldo.
  perform pg_temp.como(a.conductor);
  begin
    update public.drivers set is_available = true where id = a.conductor;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Encender "disponible" sin saldo', 'INSUFFICIENT_BALANCE', 'LO ENCENDIO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Encender "disponible" sin saldo', 'INSUFFICIENT_BALANCE',
      coalesce(v_h, sqlstate), v_h = 'INSUFFICIENT_BALANCE');
  end;
  perform pg_temp.como_postgres();

  -- ------------------------------------------------------- ajustes de admin
  perform pg_temp.como(a.pasajero);
  begin
    perform public.admin_adjust_driver_balance(a.conductor, 10000, 'intento de un pasajero');
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un no administrador no ajusta saldos', 'NOT_AN_ADMIN', 'LO HIZO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un no administrador no ajusta saldos', 'NOT_AN_ADMIN',
      coalesce(v_h, sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  perform pg_temp.como(v_admin);
  begin
    perform public.admin_adjust_driver_balance(a.conductor, 10000, 'x');
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un ajuste sin motivo se rechaza', 'ADJUSTMENT_REASON_REQUIRED', 'LO HIZO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un ajuste sin motivo se rechaza', 'ADJUSTMENT_REASON_REQUIRED',
      coalesce(v_h, sqlstate), v_h = 'ADJUSTMENT_REASON_REQUIRED');
  end;

  begin
    perform public.admin_adjust_driver_balance(a.conductor, 0, 'un ajuste en cero');
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un ajuste en cero se rechaza', 'INVALID_ADJUSTMENT_AMOUNT', 'LO HIZO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Un ajuste en cero se rechaza', 'INVALID_ADJUSTMENT_AMOUNT',
      coalesce(v_h, sqlstate), v_h = 'INVALID_ADJUSTMENT_AMOUNT');
  end;

  v_bal := public.admin_adjust_driver_balance(a.conductor, 10000, 'Recarga inicial de prueba');
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Un ajuste a favor de 10.000 deja el saldo en 10.000',
    '10000', v_bal::text, v_bal = 10000);

  -- El interruptor solo admite 0 y 1.
  begin
    perform public.admin_set_setting('driver_balance_enforced', '2');
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Interruptor en 2', 'INVALID_SWITCH', 'LO ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Interruptor en 2', 'INVALID_SWITCH',
      coalesce(v_h, sqlstate), v_h = 'INVALID_SWITCH');
  end;
  perform pg_temp.como_postgres();

  -- Con saldo, ahora si se enciende.
  perform pg_temp.como(a.conductor);
  update public.drivers set is_available = true where id = a.conductor;
  perform pg_temp.como_postgres();
  select is_available into v_ok from public.drivers where id = a.conductor;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Con saldo se puede encender "disponible"', 'true', v_ok::text, v_ok);

  -- ---------------------------------------------------------------- comision
  v_ride := pg_temp.viaje_en_curso(a.pasajero, a.conductor, a.vehiculo, 5000);
  perform pg_temp.como(a.conductor);
  perform public.complete_ride(v_ride);
  perform pg_temp.como_postgres();
  select amount, kind into v_row from public.driver_ledger where ride_id = v_ride;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Terminar un viaje de 5.000 descuenta el 4% = 200',
    'commission / -200', coalesce(v_row.kind || ' / ' || v_row.amount, 'SIN FILA'),
    v_row.kind = 'commission' and v_row.amount = -200);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El saldo queda en 9.800', '9800',
    public.driver_balance(a.conductor)::text, public.driver_balance(a.conductor) = 9800);

  -- Redondeo: 4% de 4.130 = 165,2 -> 165.
  v_ride := pg_temp.viaje_en_curso(a.pasajero, a.conductor, a.vehiculo, 4130);
  perform pg_temp.como(a.conductor);
  perform public.complete_ride(v_ride);
  perform pg_temp.como_postgres();
  select amount into v_bal from public.driver_ledger where ride_id = v_ride;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'La comision se redondea al peso: 4% de 4.130 = 165', '-165', v_bal::text, v_bal = -165);

  -- Una comision por viaje.
  begin
    insert into public.driver_ledger (driver_id, kind, amount, ride_id)
    values (a.conductor, 'commission', -1, v_ride);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Dos comisiones para el mismo viaje', '23505', 'LA ACEPTO', false);
  exception when others then
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Dos comisiones para el mismo viaje', '23505', sqlstate, sqlstate = '23505');
  end;

  -- ------------------------------------------------------------ solo se anade
  begin
    update public.driver_ledger set amount = -1 where ride_id = v_ride;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'El libro no admite UPDATE', 'LEDGER_IS_APPEND_ONLY', 'LO ACTUALIZO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'El libro no admite UPDATE', 'LEDGER_IS_APPEND_ONLY',
      coalesce(v_h, sqlstate), v_h = 'LEDGER_IS_APPEND_ONLY');
  end;

  begin
    delete from public.driver_ledger where ride_id = v_ride;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'El libro no admite DELETE', 'LEDGER_IS_APPEND_ONLY', 'LO BORRO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'El libro no admite DELETE', 'LEDGER_IS_APPEND_ONLY',
      coalesce(v_h, sqlstate), v_h = 'LEDGER_IS_APPEND_ONLY');
  end;

  -- ------------------------------------------- el conductor lee lo suyo
  perform pg_temp.como(a.conductor);
  select count(*) into v_cuenta from public.list_my_ledger();
  perform pg_temp.como(a.pasajero);
  select count(*) into v_bal from public.list_my_ledger();
  perform pg_temp.como_postgres();
  v_n := v_n + 1;
  insert into resultados values (v_n, 'El conductor ve sus movimientos y otro usuario ninguno',
    '3 / 0', v_cuenta || ' / ' || v_bal, v_cuenta = 3 and v_bal = 0);

  -- ---------------------------- saldo que se acaba tras un viaje caro (D277)
  -- Se deja al conductor en 300 y se termina un viaje de 20.000 (comision 800):
  -- el saldo queda en -500, y "disponible" se apaga.
  v_bal := public.driver_balance(a.conductor);
  perform pg_temp.como(v_admin);
  perform public.admin_adjust_driver_balance(a.conductor, -(v_bal - 300),
    'Dejar el saldo en 300 para la prueba');
  perform pg_temp.como_postgres();
  v_ride := pg_temp.viaje_en_curso(a.pasajero, a.conductor, a.vehiculo, 20000);
  perform pg_temp.como(a.conductor);
  perform public.complete_ride(v_ride);
  perform pg_temp.como_postgres();
  select is_available into v_ok from public.drivers where id = a.conductor;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Una comision mayor que el saldo lo deja en -500',
    '-500', public.driver_balance(a.conductor)::text, public.driver_balance(a.conductor) = -500);
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Y se apaga "disponible" al quedar sin saldo',
    'false', v_ok::text, v_ok = false);

  -- La recarga paga primero la deuda: -500 + 10.000 = 9.500.
  perform pg_temp.como(v_admin);
  v_bal := public.admin_adjust_driver_balance(a.conductor, 10000, 'Recarga para cubrir la deuda');
  perform pg_temp.como_postgres();
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Recargar 10.000 sobre -500 deja 9.500', '9500', v_bal::text, v_bal = 9500);

  -- ------------------------- el reparto no ofrece a quien no alcanza
  perform pg_temp.como(a.conductor);
  update public.drivers set is_available = true where id = a.conductor;
  perform pg_temp.como_postgres();
  insert into public.driver_locations (driver_id, location, updated_at)
  values (a.conductor, (select location from public.places where name = 'El parque'), now())
  on conflict (driver_id) do update set location = excluded.location, updated_at = now();
  select count(*) into v_cuenta from public.find_available_drivers(
    (select location from public.places where name = 'El parque'), 1::smallint)
  where driver_id = a.conductor;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Con saldo, el reparto lo ve', '1', v_cuenta::text, v_cuenta = 1);

  -- Y ahora un ajuste en contra lo deja sin saldo SIN apagarlo (sigue "disponible"
  -- en la fila): el reparto igual lo ignora.
  v_bal := public.driver_balance(a.conductor);
  perform pg_temp.como(v_admin);
  perform public.admin_adjust_driver_balance(a.conductor, -v_bal,
    'Dejar el saldo en cero para la prueba');
  perform pg_temp.como_postgres();
  select is_available into v_ok from public.drivers where id = a.conductor;
  select count(*) into v_cuenta from public.find_available_drivers(
    (select location from public.places where name = 'El parque'), 1::smallint)
  where driver_id = a.conductor;
  v_n := v_n + 1;
  insert into resultados values (v_n, 'Sin saldo el reparto no lo ve aunque siga encendido',
    'disponible=true / 0', v_ok || ' / ' || v_cuenta, v_ok and v_cuenta = 0);

  -- ------------------------- y si la oferta ya la tenia, no puede aceptarla
  -- Se le da saldo, el pasajero pide, y antes de aceptar se le quita.
  perform pg_temp.como(v_admin);
  perform public.admin_adjust_driver_balance(a.conductor, 10000, 'Saldo para probar el aceptar');
  perform pg_temp.como(a.pasajero);
  v_req := public.request_ride(a.lng, a.lat, 'El parque', a.lng, a.lat, 'El parque', 1::smallint);
  perform pg_temp.como_postgres();
  select id into v_offer from public.ride_offers where request_id = v_req and driver_id = a.conductor;
  perform pg_temp.como(v_admin);
  perform public.admin_adjust_driver_balance(a.conductor, -10000, 'Quitar el saldo antes de aceptar');
  perform pg_temp.como(a.conductor);
  begin
    perform public.accept_ride_offer(v_offer);
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Aceptar una oferta sin saldo', 'INSUFFICIENT_BALANCE', 'LA ACEPTO', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    v_n := v_n + 1;
    insert into resultados values (v_n, 'Aceptar una oferta sin saldo', 'INSUFFICIENT_BALANCE',
      coalesce(v_h, sqlstate), v_h = 'INSUFFICIENT_BALANCE');
  end;
  perform pg_temp.como_postgres();
end
$saldo$;


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
