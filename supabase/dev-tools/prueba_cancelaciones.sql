-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `get_driver_cancelled_notice` (Fase 18, paso 1).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_cancelaciones.sql
--
-- `cancel_request` y `cancel_ride` no se prueban aqui: existen desde la Fase 5
-- y ya se probaron entonces (comentario de driver-service.ts). Lo nuevo es la
-- funcion de lectura, y lo que hay que romper es la frontera de quien ve que:
-- que un pasajero no vea el aviso de otro, que un aviso viejo no aparezca, y
-- que una cancelacion del PASAJERO (cancelled_by = 'passenger') no le salga a
-- el mismo como si el conductor le hubiera cancelado.
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
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
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1'; -- pasajero.prueba
  c_marta constant uuid := '60000000-0000-4000-8000-000000000001'; -- otra pasajera, prueba_calificaciones
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001'; -- conductor.prueba
  c_veh1  constant uuid := 'e0000000-0000-4000-8000-000000000001';

  c_ra1 constant uuid := 'a8000000-0000-4000-8000-000000000001'; -- cancelada por el conductor, a bordo
  c_ra2 constant uuid := 'a8000000-0000-4000-8000-000000000002'; -- cancelada por el conductor, hace rato
  c_ra3 constant uuid := 'a8000000-0000-4000-8000-000000000003'; -- cancelada por LA PASAJERA MISMA

  c_v1 constant uuid := 'b8000000-0000-4000-8000-000000000001';
  c_v2 constant uuid := 'b8000000-0000-4000-8000-000000000002';
  c_v3 constant uuid := 'b8000000-0000-4000-8000-000000000003';

  v_origen      extensions.geography;
  v_origen_lbl  text;
  v_destino     extensions.geography;
  v_destino_lbl text;
begin
  select p.location, p.name into v_origen, v_origen_lbl
  from public.places p where p.name ilike '%parque%' order by p.sort_order limit 1;

  select p.location, p.name into v_destino, v_destino_lbl
  from public.places p where p.name ilike '%hospital%' order by p.sort_order limit 1;

  -- CASO 1: el conductor cancelo hace dos minutos, con Ana a bordo. Dentro de
  -- la ventana de `finished_summary_minutes` (5). Es el que tiene que aparecer.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at, assigned_at, started_at,
    cancelled_at, cancelled_by
  ) values
    (c_ra1, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '20 minutes', now() - interval '15 minutes',
     now() - interval '18 minutes', now() - interval '5 minutes',
     now() - interval '2 minutes', 'driver'),

    -- CASO 2: mismo desenlace, pero hace 20 minutos. Fuera de la ventana.
    (c_ra2, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '40 minutes', now() - interval '35 minutes',
     now() - interval '38 minutes', now() - interval '25 minutes',
     now() - interval '20 minutes', 'driver'),

    -- CASO 3: Ana cancelo esta ella misma. No es un aviso de "el conductor te
    -- canceló": es lo contrario, y no tiene que aparecer como tal.
    (c_ra3, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '10 minutes', now() - interval '5 minutes',
     now() - interval '8 minutes', null,
     now() - interval '3 minutes', 'passenger');

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, cancelled_at, cancelled_by
  ) values
    (c_v1, c_ra1, c_cond1, c_veh1, 'cancelled', 1,
     now() - interval '18 minutes', now() - interval '12 minutes',
     now() - interval '5 minutes', now() - interval '2 minutes', 'driver'),
    (c_v2, c_ra2, c_cond1, c_veh1, 'cancelled', 1,
     now() - interval '38 minutes', now() - interval '32 minutes',
     now() - interval '25 minutes', now() - interval '20 minutes', 'driver'),
    (c_v3, c_ra3, c_cond1, c_veh1, 'cancelled', 1,
     now() - interval '8 minutes', null,
     null, now() - interval '3 minutes', 'passenger');
end
$datos$;


-- -----------------------------------------------------------------------------
-- Las comprobaciones
-- -----------------------------------------------------------------------------

do $checks$
declare
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_marta constant uuid := '60000000-0000-4000-8000-000000000001';
  c_ra1   constant uuid := 'a8000000-0000-4000-8000-000000000001';

  v_admin constant text := current_user;
  v_id     uuid;
  v_nombre text;
  v_n      integer;
  v_ok     boolean;
begin
  -- ---------------------------------------------------------------- pasajera Ana
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_ana, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  select n.id, n.driver_name into v_id, v_nombre
  from public.get_driver_cancelled_notice() n;

  insert into resultados values (1, 'Ve el aviso mas reciente dentro de la ventana',
    c_ra1::text, coalesce(v_id::text, '(sin fila)'), v_id = c_ra1);

  insert into resultados values (2, 'Y trae el nombre del conductor que cancelo',
    'Conductor de prueba', coalesce(v_nombre, '(nulo)'), v_nombre = 'Conductor de prueba');

  -- Solo una fila, la mas reciente. La de hace 20 minutos no debe colarse.
  select count(*) into v_n from public.get_driver_cancelled_notice();
  insert into resultados values (3, 'Solo devuelve una fila, no las dos canceladas por el conductor',
    '1', v_n::text, v_n = 1);

  perform set_config('role', v_admin, true);

  -- ------------------------------------------------------ ATAQUE: otra pasajera
  -- Marta no tiene ninguna cancelacion de conductor en esta prueba. Si viera
  -- algo, seria el aviso de Ana filtrandose por la frontera equivocada.
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_marta, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  select count(*) into v_n from public.get_driver_cancelled_notice();
  insert into resultados values (4, 'ATAQUE: otra pasajera no ve el aviso de Ana',
    '0', v_n::text, v_n = 0);

  perform set_config('role', v_admin, true);

  -- ------------------------------------------------------------------ permisos
  select has_function_privilege('anon', 'public.get_driver_cancelled_notice()', 'execute')
    into v_ok;
  insert into resultados values (5, 'Sin sesion no se puede llamar',
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
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
