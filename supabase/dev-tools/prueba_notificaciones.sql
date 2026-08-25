-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de los disparadores de notificaciones push (Fase 19, paso 1):
-- `notify_driver_arrived` sobre `rides` y `notify_new_offer` sobre
-- `ride_offers`, y la funcion compartida `send_push_notification`.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_notificaciones.sql
--
-- `net.http_post` es asincrono: solo encola la peticion en
-- `net.http_request_queue` y un proceso aparte la envia de verdad DESPUES de
-- que la transaccion confirma. Como todo esto corre dentro de un `begin` que
-- termina en `rollback`, ninguna peticion sale de verdad hacia Expo, ni con el
-- token falso de la comprobacion 3. Lo que se comprueba es que la fila quedo
-- encolada, no la respuesta del servicio.
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
  c_cond2 constant uuid := 'd0000000-0000-4000-8000-000000000002'; -- conductor2.prueba
  c_veh1  constant uuid := 'e0000000-0000-4000-8000-000000000001';

  c_ra1 constant uuid := 'a9000000-0000-4000-8000-000000000001'; -- para driver_arrived
  c_ra2 constant uuid := 'a9000000-0000-4000-8000-000000000002'; -- para new_offer

  c_v1 constant uuid := 'b9000000-0000-4000-8000-000000000001';

  v_origen      extensions.geography;
  v_origen_lbl  text;
  v_destino     extensions.geography;
  v_destino_lbl text;
begin
  select p.location, p.name into v_origen, v_origen_lbl
  from public.places p where p.name ilike '%parque%' order by p.sort_order limit 1;

  select p.location, p.name into v_destino, v_destino_lbl
  from public.places p where p.name ilike '%hospital%' order by p.sort_order limit 1;

  -- CASO 1: en camino, lista para pasar a "llego".
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at, assigned_at
  ) values
    (c_ra1, c_ana, 'assigned', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '5 minutes', now() + interval '25 minutes',
     now() - interval '4 minutes'),

    -- CASO 2: buscando, para colgarle una oferta nueva. Otra pasajera: R6 no
    -- deja tener dos solicitudes activas a la vez con la misma.
    (c_ra2, c_marta, 'searching', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '1 minute', now() + interval '4 minutes', null);

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at
  ) values
    (c_v1, c_ra1, c_cond1, c_veh1, 'driver_on_the_way', 1, now() - interval '4 minutes');

  -- Token falso, solo para que la comprobacion 3 vea la peticion encolada. Se
  -- deshace con el resto al hacer rollback.
  update public.profiles set push_token = 'ExponentPushToken[prueba-falsa]'
  where id = c_ana;
end
$datos$;


-- -----------------------------------------------------------------------------
-- Las comprobaciones
-- -----------------------------------------------------------------------------

do $checks$
declare
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_cond2 constant uuid := 'd0000000-0000-4000-8000-000000000002';

  c_ra1 constant uuid := 'a9000000-0000-4000-8000-000000000001';
  c_ra2 constant uuid := 'a9000000-0000-4000-8000-000000000002';
  c_v1  constant uuid := 'b9000000-0000-4000-8000-000000000001';

  v_admin constant text := current_user;
  v_n     integer;
  v_tipo  text;
  v_ok    boolean;
  v_cola_antes integer;
  v_cola_despues integer;
begin
  -- ---------------------------------------------------- driver_arrived, primera vez
  select count(*) into v_cola_antes from net.http_request_queue;

  update public.rides set status = 'driver_arrived' where id = c_v1;

  select count(*), max(type) into v_n, v_tipo
  from public.notifications where user_id = c_ana and type = 'driver_arrived';
  insert into resultados values (1, 'La llegada crea UNA notificacion para la pasajera',
    '1 / driver_arrived', v_n || ' / ' || coalesce(v_tipo, '(ninguna)'),
    v_n = 1 and v_tipo = 'driver_arrived');

  select count(*) into v_cola_despues from net.http_request_queue;
  insert into resultados values (2, 'Con token, se encola una peticion HTTP de mas',
    'v_cola_despues > v_cola_antes', v_cola_antes || ' -> ' || v_cola_despues,
    v_cola_despues > v_cola_antes);

  -- --------------------------------------------- driver_arrived, no se repite
  -- Un update que no CAMBIA el estado (sigue en driver_arrived) no debe
  -- disparar una segunda notificacion.
  update public.rides set cancellation_reason = null where id = c_v1;

  select count(*) into v_n
  from public.notifications where user_id = c_ana and type = 'driver_arrived';
  insert into resultados values (3, 'Un update que no cambia el estado no duplica el aviso',
    '1', v_n::text, v_n = 1);

  -- ------------------------------------------------------------- nueva oferta
  select count(*) into v_cola_antes from net.http_request_queue;

  insert into public.ride_offers (request_id, driver_id, expires_at)
  values (c_ra2, c_cond2, now() + interval '20 seconds');

  select count(*), max(type) into v_n, v_tipo
  from public.notifications where user_id = c_cond2 and type = 'new_offer';
  insert into resultados values (4, 'La oferta nueva crea UNA notificacion para el conductor',
    '1 / new_offer', v_n || ' / ' || coalesce(v_tipo, '(ninguna)'),
    v_n = 1 and v_tipo = 'new_offer');

  -- El conductor 2 no tiene push_token en los datos de prueba (a diferencia de
  -- Ana): sin token, la fila de notifications se guarda igual pero NO se
  -- encola ninguna peticion.
  select count(*) into v_cola_despues from net.http_request_queue;
  insert into resultados values (5, 'Sin token, se guarda el aviso pero no se encola nada',
    'v_cola_despues = v_cola_antes', v_cola_antes || ' -> ' || v_cola_despues,
    v_cola_despues = v_cola_antes);

  -- ------------------------------------------------------------------ permisos
  select has_function_privilege('authenticated',
    'public.send_push_notification(uuid,text,text,text,jsonb)', 'execute')
    into v_ok;
  insert into resultados values (6, 'ATAQUE: un usuario normal no puede llamar al envio directo',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('anon',
    'public.send_push_notification(uuid,text,text,text,jsonb)', 'execute')
    into v_ok;
  insert into resultados values (7, 'Sin sesion, tampoco',
    'false', v_ok::text, v_ok = false);

  perform set_config('role', v_admin, true);
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
