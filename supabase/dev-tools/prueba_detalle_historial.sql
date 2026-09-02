-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `get_passenger_trip` y `get_driver_job` (Fase 16, paso 4).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_detalle_historial.sql
--
-- Mismo metodo que `prueba_historial.sql`: todo dentro de una transaccion que se
-- deshace, cuentas de prueba reales, coordenadas sacadas de `places` y las
-- comprobaciones hechas suplantando a cada usuario.
--
-- LO QUE MAS IMPORTA AQUI son dos cosas. Una, que pedir el identificador de otro
-- devuelva cero filas y no un error: el detalle se abre por identificador, que
-- es la forma mas facil de dejarse una puerta abierta. Y dos, que en una oferta
-- que el conductor rechazo no viajen ni el nombre del pasajero ni la referencia
-- del punto de recogida, que es la columna nueva de este paso.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Los datos de la prueba
-- -----------------------------------------------------------------------------

do $datos$
declare
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_marta constant uuid := '60000000-0000-4000-8000-000000000001';
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_cond2 constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_veh1  constant uuid := 'e0000000-0000-4000-8000-000000000001';

  c_ra1 constant uuid := 'a4000000-0000-4000-8000-000000000001';  -- terminada
  c_ra2 constant uuid := 'a4000000-0000-4000-8000-000000000002';  -- cancelada
  c_ra3 constant uuid := 'a4000000-0000-4000-8000-000000000003';  -- caducada
  c_ra4 constant uuid := 'a4000000-0000-4000-8000-000000000004';  -- viva
  c_rb1 constant uuid := 'a4000000-0000-4000-8000-000000000005';  -- de Marta

  c_via1 constant uuid := 'b4000000-0000-4000-8000-000000000001';

  c_of1 constant uuid := 'c4000000-0000-4000-8000-000000000001';  -- cond1 acepta
  c_of2 constant uuid := 'c4000000-0000-4000-8000-000000000002';  -- cond1 rechaza
  c_of3 constant uuid := 'c4000000-0000-4000-8000-000000000003';  -- cond1 pendiente
  c_of4 constant uuid := 'c4000000-0000-4000-8000-000000000004';  -- del conductor 2

  v_origen      extensions.geography;
  v_origen_lbl  text;
  v_destino     extensions.geography;
  v_destino_lbl text;
begin
  select p.location, p.name into v_origen, v_origen_lbl
  from public.places p where p.name ilike '%parque%' order by p.sort_order limit 1;

  select p.location, p.name into v_destino, v_destino_lbl
  from public.places p where p.name ilike '%hospital%' order by p.sort_order limit 1;

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label, pickup_reference,
    contact_phone, requested_at, expires_at,
    assigned_at, started_at, completed_at, cancelled_at, cancelled_by, cancellation_reason
  ) values
    (c_ra1, c_ana, 'completed', 2,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl, 'Frente a la panaderia',
     '3001234567', now() - interval '3 hours', now() - interval '2 hours 55 minutes',
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 50 minutes',
     now() - interval '2 hours 40 minutes', null, null, null),

    (c_ra2, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl, null,
     '3001234567', now() - interval '2 hours', now() - interval '1 hour 55 minutes',
     null, null, null, now() - interval '1 hour 58 minutes', 'passenger', 'Ya no lo necesito'),

    (c_ra3, c_ana, 'expired', 3,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl, null,
     '3001234567', now() - interval '1 hour', now() - interval '55 minutes',
     null, null, null, null, null, null),

    (c_ra4, c_ana, 'searching', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl, null,
     '3001234567', now(), now() + interval '5 minutes',
     null, null, null, null, null, null),

    (c_rb1, c_marta, 'completed', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl, null,
     '3007654321', now() - interval '4 hours', now() - interval '3 hours 55 minutes',
     now() - interval '3 hours 58 minutes', now() - interval '3 hours 50 minutes',
     now() - interval '3 hours 40 minutes', null, null, null);

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
  ) values
    (c_via1, c_ra1, c_cond1, c_veh1, 'completed', 2,
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 52 minutes',
     now() - interval '2 hours 50 minutes', now() - interval '2 hours 40 minutes', 1200, 600);

  insert into public.ride_offers (
    id, request_id, driver_id, offered_at, expires_at, response, responded_at, distance_m
  ) values
    (c_of1, c_ra1, c_cond1, now() - interval '2 hours 59 minutes',
     now() - interval '2 hours 58 minutes', 'accepted', now() - interval '2 hours 58 minutes', 109),

    (c_of2, c_ra2, c_cond1, now() - interval '1 hour 59 minutes',
     now() - interval '1 hour 58 minutes', 'rejected', now() - interval '1 hour 59 minutes', 259),

    (c_of3, c_ra4, c_cond1, now(), now() + interval '20 seconds', 'pending', null, 109),

    (c_of4, c_ra3, c_cond2, now() - interval '59 minutes',
     now() - interval '58 minutes', 'expired', now() - interval '58 minutes', 259);
end
$datos$;


-- -----------------------------------------------------------------------------
-- Las comprobaciones
-- -----------------------------------------------------------------------------

do $checks$
declare
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001';

  c_ra1 constant uuid := 'a4000000-0000-4000-8000-000000000001';
  c_ra2 constant uuid := 'a4000000-0000-4000-8000-000000000002';
  c_ra3 constant uuid := 'a4000000-0000-4000-8000-000000000003';
  c_ra4 constant uuid := 'a4000000-0000-4000-8000-000000000004';
  c_rb1 constant uuid := 'a4000000-0000-4000-8000-000000000005';

  c_of1 constant uuid := 'c4000000-0000-4000-8000-000000000001';
  c_of2 constant uuid := 'c4000000-0000-4000-8000-000000000002';
  c_of3 constant uuid := 'c4000000-0000-4000-8000-000000000003';
  c_of4 constant uuid := 'c4000000-0000-4000-8000-000000000004';

  v_admin constant text := current_user;

  v_n   integer;
  v_txt text;
  v_ok  boolean;
begin
  -- ---------------------------------------------------------------- pasajera
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_ana, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  select count(*) into v_n from public.get_passenger_trip(c_ra1);
  insert into resultados values (1, 'La terminada abre y devuelve una sola fila', '1', v_n::text, v_n = 1);

  select t.driver_name || ' / ' || t.vehicle_unit_number || ' / ' || t.vehicle_plate into v_txt
  from public.get_passenger_trip(c_ra1) t;
  insert into resultados values (2, 'Trae conductor, unidad y placa',
    'Conductor de prueba / 99 / PRB99D', coalesce(v_txt, '(nulo)'),
    v_txt = 'Conductor de prueba / 99 / PRB99D');

  select (t.accepted_at is not null and t.driver_arrived_at is not null
      and t.started_at is not null and t.completed_at is not null) into v_ok
  from public.get_passenger_trip(c_ra1) t;
  insert into resultados values (3, 'La linea de tiempo trae las cuatro horas',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select t.pickup_reference into v_txt from public.get_passenger_trip(c_ra1) t;
  insert into resultados values (4, 'Trae la referencia del punto de recogida',
    'Frente a la panaderia', coalesce(v_txt, '(nulo)'), v_txt = 'Frente a la panaderia');

  select t.cancelled_by::text || ' / ' || t.cancellation_reason into v_txt
  from public.get_passenger_trip(c_ra2) t;
  insert into resultados values (5, 'La cancelada dice quien y por que',
    'passenger / Ya no lo necesito', coalesce(v_txt, '(nulo)'),
    v_txt = 'passenger / Ya no lo necesito');

  select (t.ride_id is null and t.driver_name is null) into v_ok
  from public.get_passenger_trip(c_ra3) t;
  insert into resultados values (6, 'La caducada abre, y sin viaje ni conductor',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select count(*) into v_n from public.get_passenger_trip(c_rb1);
  insert into resultados values (7, 'ATAQUE: no abre la solicitud de Marta', '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.get_passenger_trip(c_ra4);
  insert into resultados values (8, 'No abre una solicitud viva', '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.get_driver_job(c_of1);
  insert into resultados values (9, 'Una pasajera no abre el detalle del conductor',
    '0', v_n::text, v_n = 0);

  perform set_config('role', v_admin, true);

  -- --------------------------------------------------------------- conductor 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond1, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  select j.outcome into v_txt from public.get_driver_job(c_of1) j;
  insert into resultados values (10, 'La que acepto y termino abre como completed',
    'completed', coalesce(v_txt, '(nulo)'), v_txt = 'completed');

  select j.passenger_name || ' / ' || j.pickup_reference into v_txt
  from public.get_driver_job(c_of1) j;
  insert into resultados values (11, 'En la que llevo ve nombre y referencia',
    'Ana Gomez / Frente a la panaderia', coalesce(v_txt, '(nulo)'),
    v_txt = 'Ana Gomez / Frente a la panaderia');

  select (j.passenger_name is null and j.pickup_reference is null) into v_ok
  from public.get_driver_job(c_of2) j;
  insert into resultados values (12,
    'PRIVACIDAD: en la que rechazo no ve ni nombre ni referencia',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select j.outcome into v_txt from public.get_driver_job(c_of2) j;
  insert into resultados values (13, 'La rechazada abre como rejected',
    'rejected', coalesce(v_txt, '(nulo)'), v_txt = 'rejected');

  select count(*) into v_n from public.get_driver_job(c_of3);
  insert into resultados values (14, 'No abre una oferta que sigue pendiente',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.get_driver_job(c_of4);
  insert into resultados values (15, 'ATAQUE: no abre la oferta del conductor 2',
    '0', v_n::text, v_n = 0);

  -- La lista y el detalle salen ahora de la misma funcion `ride_offer_outcome`.
  -- Esta comprobacion es la que se dara cuenta el dia que dejen de coincidir.
  select count(*) into v_n
  from public.list_driver_history(50, 0) h
    join lateral public.get_driver_job(h.offer_id) j on true
  where j.outcome <> h.outcome;
  insert into resultados values (16, 'El desenlace es el mismo en la lista y en el detalle',
    '0', v_n::text, v_n = 0);

  perform set_config('role', v_admin, true);

  -- ------------------------------------------------------------------ permisos
  select has_function_privilege('anon', 'public.get_passenger_trip(uuid)', 'execute') into v_ok;
  insert into resultados values (17, 'Sin sesion no se abre el detalle del pasajero',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('anon', 'public.get_driver_job(uuid)', 'execute') into v_ok;
  insert into resultados values (18, 'Sin sesion no se abre el del conductor',
    'false', v_ok::text, v_ok = false);
end
$checks$;


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
