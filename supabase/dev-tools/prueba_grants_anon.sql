-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260902170000_revoke_anon_execute_all_public_functions.sql`
-- (Fase 22, paso 1: se le quita a `anon` el EXECUTE de las funciones de
-- `public`; cierra H22).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_grants_anon.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE DEMUESTRA:
--   1. Ninguna funcion de `public` la puede ejecutar ya `anon`.
--   2. Las que la aplicacion y el panel necesitan siguen abiertas a
--      `authenticated` y a `service_role`.
--   3. Las cuatro operativas vivas siguen defendiendose solas: un
--      `authenticated` que no es el dueno recibe un rechazo, no una accion.
--   4. El grant por defecto quedo cortado: una funcion nueva creada por
--      `postgres` NO nace ejecutable por `anon`.
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
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- 1. El barrido: cero funciones de `public` ejecutables por `anon`
-- -----------------------------------------------------------------------------

do $barrido$
declare
  v_n integer;
  v_lista text;
begin
  select count(*), string_agg(p.proname, ', ' order by p.proname)
    into v_n, v_lista
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  insert into resultados values (1,
    'Ninguna funcion de public la ejecuta anon',
    '0', v_n::text || coalesce(' (' || v_lista || ')', ''), v_n = 0);
end
$barrido$;


-- -----------------------------------------------------------------------------
-- 2. Lo que la aplicacion y el panel necesitan sigue abierto
-- -----------------------------------------------------------------------------

do $conserva$
declare
  v_rpc text;
  v_admin text;
  v_falta_auth text := '';
  v_falta_srv text := '';
begin
  -- Los 19 RPC que llama el cliente movil.
  foreach v_rpc in array array[
    'accept_ride_offer', 'cancel_request', 'cancel_ride', 'get_active_request',
    'get_driver_cancelled_notice', 'get_driver_job', 'get_driver_location',
    'get_finished_request', 'get_passenger_trip', 'list_driver_active_rides',
    'list_driver_earnings', 'list_driver_history', 'list_driver_offers',
    'list_passenger_history', 'list_places', 'quote_fare', 'rate_ride',
    'reject_ride_offer', 'request_ride'
  ]
  loop
    if not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = v_rpc
        and has_function_privilege('authenticated', p.oid, 'EXECUTE')
    ) then
      v_falta_auth := v_falta_auth || v_rpc || ' ';
    end if;
  end loop;

  insert into resultados values (2,
    'authenticated conserva EXECUTE en los 19 RPC del cliente',
    '(ninguno falta)', coalesce(nullif(v_falta_auth, ''), '(ninguno falta)'),
    v_falta_auth = '');

  -- Una muestra de funciones del panel: service_role no debe perder nada, que
  -- es lo que dejaria al servidor sin poder operar.
  foreach v_admin in array array[
    'admin_list_rides', 'admin_set_setting', 'admin_create_driver',
    'log_admin_action', 'admin_assign_driver'
  ]
  loop
    if not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = v_admin
        and has_function_privilege('service_role', p.oid, 'EXECUTE')
    ) then
      v_falta_srv := v_falta_srv || v_admin || ' ';
    end if;
  end loop;

  insert into resultados values (3,
    'service_role conserva EXECUTE en las funciones del panel',
    '(ninguno falta)', coalesce(nullif(v_falta_srv, ''), '(ninguno falta)'),
    v_falta_srv = '');
end
$conserva$;


-- -----------------------------------------------------------------------------
-- 3. Las operativas vivas siguen defendiendose solas
-- -----------------------------------------------------------------------------

do $defensa$
declare
  v_pas   uuid := 'f2000000-0000-4000-8000-0000000000b1';
  v_otro  uuid := 'f2000000-0000-4000-8000-0000000000b2';
  v_cond  uuid := 'f2000000-0000-4000-8000-0000000000d1';
  v_veh   uuid := 'f2000000-0000-4000-8000-0000000000e1';
  v_req   uuid := 'f2000000-0000-4000-8000-000000000001';
  v_ride  uuid := 'f2000000-0000-4000-8000-00000000c001';
  v_offer uuid := 'f2000000-0000-4000-8000-0000000000f1';
  v_origen  extensions.geography;
  v_destino extensions.geography;
  v_msg text;
begin
  select p.location into v_origen from public.places p
   where p.is_active order by p.sort_order, p.name limit 1;
  select p.location into v_destino from public.places p
   where p.is_active and p.location <> v_origen
   order by p.sort_order, p.name limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  values
    (v_pas,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.gra.pas@motomoto-qa.co',  now(), now()),
    (v_otro, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.gra.otro@motomoto-qa.co', now(), now()),
    (v_cond, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.gra.cond@motomoto-qa.co', now(), now());

  -- El disparador `on_auth_user_created` ya creo un perfil por cada usuario, con
  -- rol `passenger`. Se borran y se ponen los que hacen falta: `INSERT` no lo
  -- toca `profiles_protect_columns`, que es BEFORE UPDATE, y aqui no hay sesion
  -- de administrador.
  delete from public.profiles where id in (v_pas, v_otro, v_cond);

  insert into public.profiles (id, full_name, phone, role, status) values
    (v_pas,  'Zz gra pas',  '3000000501', 'passenger', 'active'),
    (v_otro, 'Zz gra otro', '3000000502', 'passenger', 'active'),
    (v_cond, 'Zz gra cond', '3000000503', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available)
  values (v_cond, 'approved', now(), true);
  insert into public.vehicles (id, unit_number, plate, max_passengers, status)
  values (v_veh, 9951, 'ZG1951', 3, 'active');
  insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
  values (v_cond, v_veh);

  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at, assigned_at
  ) values (
    v_req, v_pas, 'in_progress', 1, v_origen, 'Origen', v_destino, 'Destino',
    '3000000501', now() - interval '20 minutes', now() + interval '10 minutes',
    now() - interval '18 minutes');

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at
  ) values (
    v_ride, v_req, v_cond, v_veh, 'in_progress', 1,
    now() - interval '18 minutes', now() - interval '15 minutes', now() - interval '12 minutes');

  insert into public.ride_offers (id, request_id, driver_id, response, expires_at)
  values (v_offer, v_req, v_cond, 'pending', now() + interval '3 minutes');

  -- 4. `cancel_ride` llamada por alguien que no es el pasajero del viaje: rebota.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_otro, 'role', 'authenticated')::text);
  begin
    perform public.cancel_ride(v_ride, 'no es mio');
    insert into resultados values (4, 'cancel_ride rechaza a quien no es del viaje',
      'excepcion', 'la ejecuto sin quejarse', false);
  exception when others then
    get stacked diagnostics v_msg = MESSAGE_TEXT;
    insert into resultados values (4, 'cancel_ride rechaza a quien no es del viaje',
      'excepcion', 'excepcion: ' || left(v_msg, 40), true);
  end;

  -- 5. `accept_ride_offer` sobre una oferta que no es del que llama: rebota.
  begin
    perform public.accept_ride_offer(v_offer);
    insert into resultados values (5, 'accept_ride_offer rechaza una oferta ajena',
      'excepcion', 'la ejecuto sin quejarse', false);
  exception when others then
    get stacked diagnostics v_msg = MESSAGE_TEXT;
    insert into resultados values (5, 'accept_ride_offer rechaza una oferta ajena',
      'excepcion', 'excepcion: ' || left(v_msg, 40), true);
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$defensa$;


-- -----------------------------------------------------------------------------
-- 4. El grant por defecto quedo cortado
-- -----------------------------------------------------------------------------

do $futuro$
declare
  v_anon    boolean;
  v_public  boolean;
begin
  -- Se mira el artefacto de verdad -el `alter default privileges` del rol
  -- `postgres`, que es el que crea las funciones en las migraciones- en vez de
  -- crear una funcion de mentira: `supabase db query` la crearia con un rol de
  -- login temporal, no con `postgres`, asi que no probaria el camino real.
  select
    coalesce(bool_or(a.grantee = 'anon'::regrole and a.privilege_type = 'EXECUTE'), false),
    coalesce(bool_or(a.grantee = 0 and a.privilege_type = 'EXECUTE'), false)
  into v_anon, v_public
  from pg_default_acl d
  join pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral aclexplode(d.defaclacl) a
  where n.nspname = 'public'
    and d.defaclobjtype = 'f'
    and d.defaclrole = 'postgres'::regrole;

  insert into resultados values (6,
    'El grant por defecto de postgres no da EXECUTE a anon ni a PUBLIC',
    'anon=no, PUBLIC=no',
    'anon=' || v_anon::text || ', PUBLIC=' || v_public::text,
    not v_anon and not v_public);
end
$futuro$;


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
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
