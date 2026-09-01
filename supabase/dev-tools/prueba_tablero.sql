-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260826200000_admin_active_services.sql` (Fase 20, paso 3: el
-- tablero de servicios en curso).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_tablero.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- SE AISLA POR IDENTIFICADOR PROPIO. Los servicios de esta prueba empiezan por
-- `ac000000`, y toda comprobacion que cuente filas filtra por ahi. La base tiene
-- 57 solicitudes reales acumuladas, y ya van tres veces que una prueba se pone
-- roja por datos que no eran suyos: el `sum` de prueba_recaudo y las dos
-- premisas de prueba_notificaciones.
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
-- Montaje: un servicio en cada estado vivo, mas uno terminado que no debe salir
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'ac000000-0000-4000-8000-0000000000a1';
  -- TRES pasajeros para tres servicios activos, y no uno con tres. La regla R6
  -- (`rr_one_active_per_passenger`) solo admite un servicio vivo por pasajero, y
  -- el primer montaje de esta prueba la incumplia. El terminado si puede
  -- repetir pasajero, porque ya no esta activo: eso lo comprueba la 2.
  v_pas   uuid := 'ac000000-0000-4000-8000-0000000000b1';
  v_pas2  uuid := 'ac000000-0000-4000-8000-0000000000b3';
  v_otro  uuid := 'ac000000-0000-4000-8000-0000000000b2';
  v_cond  uuid;
  v_veh   uuid;
  v_lng   double precision;
  v_lat   double precision;

  v_buscando  uuid := 'ac000000-0000-4000-8000-000000000001';
  v_asignado  uuid := 'ac000000-0000-4000-8000-000000000002';
  v_encurso   uuid := 'ac000000-0000-4000-8000-000000000003';
  v_terminado uuid := 'ac000000-0000-4000-8000-000000000004';
  v_ride_asig uuid := 'ac000000-0000-4000-8000-00000000c002';
begin
  -- Se toma un conductor y un vehiculo que ya existen: la prueba no mide el alta
  -- de conductores, que es del paso 4.
    -- SE ELIGE UN CONDUCTOR APROBADO, no "el primero que haya". Al dar de alta a
  -- alguien desde el panel (paso 4b) nace **pendiente de aprobar**, y si ese cae
  -- el primero en el orden, todo lo que dependa de su disponibilidad se cae con
  -- `drivers_available_only_when_approved`. Paso el 2026-08-27, con un conductor
  -- creado desde el panel minutos antes.
  --
  -- Quinta vez que una prueba se rompe por una premisa heredada del mundo real.
  -- **Una prueba no toma lo que encuentra: toma lo que necesita.**
  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' limit 1;
  select v.id into v_veh from public.vehicles v limit 1;

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.tablero.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.tablero.pas@motomoto-qa.co', now(), now()),
    (v_otro,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.tablero.otro@motomoto-qa.co', now(), now()),
    (v_pas2,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.tablero.pas2@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas, v_pas2, v_otro);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz tablero admin',    '3000000021', 'admin',     'active'),
    (v_pas,   'Zz tablero pasajero', '3000000022', 'passenger', 'active'),
    (v_pas2,  'Zz tablero pasajero2','3000000024', 'passenger', 'active'),
    (v_otro,  'Zz tablero otro',     '3000000023', 'passenger', 'active');

  -- Cuatro solicitudes. Las fechas se ponen a mano y hacia atras para poder
  -- medir `waiting_seconds` y el orden, que con `now()` serian los cuatro cero.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  )
  select
    x.id, x.pas, x.est, 1,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz destino', '3000000022', x.pedido, x.pedido + interval '5 minutes',
    'passenger', 4000, 4000, 0, false, false
  from (values
    (v_buscando,  v_pas,  'searching'::public.ride_request_status,   now() - interval '300 seconds'),
    (v_asignado,  v_pas2, 'assigned'::public.ride_request_status,    now() - interval '200 seconds'),
    (v_encurso,   v_otro, 'in_progress'::public.ride_request_status, now() - interval '100 seconds'),
    (v_terminado, v_pas,  'completed'::public.ride_request_status,   now() - interval '900 seconds')
  ) as x(id, pas, est, pedido);

  -- El asignado tiene viaje vivo; el terminado tambien, para comprobar que lo
  -- que lo deja fuera del tablero es el estado de la SOLICITUD.
  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count, accepted_at)
  values
    (v_ride_asig, v_asignado, v_cond, v_veh, 'assigned', 1, now() - interval '150 seconds'),
    ('ac000000-0000-4000-8000-00000000c004', v_terminado, v_cond, v_veh, 'completed', 1,
     now() - interval '800 seconds');

  -- Dos ofertas sobre el que busca: una viva y una ya caducada. La caducada no
  -- se debe contar, y sin ella la comprobacion de `pending_offers` podria estar
  -- en verde porque el filtro no se evalua nunca.
  -- La caducada lleva `responded_at`: `ro_response_coherence` exige que toda
  -- respuesta distinta de `pending` tenga su fecha. Una oferta caducada sin
  -- fecha de respuesta seria un desenlace sin momento, y la base no lo admite.
  insert into public.ride_offers
    (request_id, driver_id, expires_at, response, offered_at, responded_at)
  values
    (v_buscando, v_cond, now() + interval '20 seconds', 'pending', now(), null),
    (v_buscando, (select d.id from public.drivers d where d.id <> v_cond limit 1),
     now() - interval '10 seconds', 'expired', now() - interval '40 seconds',
     now() - interval '10 seconds');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Lo que el tablero tiene que mostrar
-- -----------------------------------------------------------------------------

do $tablero$
declare
  v_admin constant uuid := 'ac000000-0000-4000-8000-0000000000a1';
  v_buscando  constant uuid := 'ac000000-0000-4000-8000-000000000001';
  v_asignado  constant uuid := 'ac000000-0000-4000-8000-000000000002';
  v_encurso   constant uuid := 'ac000000-0000-4000-8000-000000000003';
  v_terminado constant uuid := 'ac000000-0000-4000-8000-000000000004';
  v_n integer;
  v_row record;
  v_orden text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Salen los tres vivos y solo los tres.
  select count(*) into v_n from public.admin_list_active_services()
  where request_id::text like 'ac000000%';
  insert into resultados values (1, 'El tablero muestra los tres servicios vivos',
    '3', v_n::text, v_n = 3);

  -- 2. Y el terminado NO sale. Va con la 1 vigilandola: sin esta, la 1 podria
  --    estar en verde contando el terminado y perdiendose otro.
  select count(*) into v_n from public.admin_list_active_services()
  where request_id = v_terminado;
  insert into resultados values (2, 'Un servicio terminado NO aparece en el tablero',
    '0', v_n::text, v_n = 0);

  -- 3. El que busca no trae conductor, porque todavia no hay ninguno.
  select ride_id, driver_name, status::text into v_row
  from public.admin_list_active_services() where request_id = v_buscando;
  insert into resultados values (3, 'Un servicio en busqueda no trae conductor',
    'searching, sin viaje, sin conductor',
    coalesce(v_row.status, 'nulo') || ', ' ||
      case when v_row.ride_id is null then 'sin viaje' else 'trae viaje' end || ', ' ||
      case when v_row.driver_name is null then 'sin conductor' else 'trae conductor' end,
    v_row.status = 'searching' and v_row.ride_id is null and v_row.driver_name is null);

  -- 4. El asignado SI trae conductor, motorraton y placa.
  select driver_name, unit_number, plate, ride_status::text into v_row
  from public.admin_list_active_services() where request_id = v_asignado;
  insert into resultados values (4, 'Un servicio asignado trae conductor y motorraton',
    'con nombre, con numero, con placa, assigned',
    case when v_row.driver_name is null then 'sin nombre' else 'con nombre' end || ', ' ||
      case when v_row.unit_number is null then 'sin numero' else 'con numero' end || ', ' ||
      case when v_row.plate is null then 'sin placa' else 'con placa' end || ', ' ||
      coalesce(v_row.ride_status, 'nulo'),
    v_row.driver_name is not null and v_row.unit_number is not null
      and v_row.plate is not null and v_row.ride_status = 'assigned');

  -- 5. `waiting_seconds` mide de verdad, y lo mide el servidor. El que busca
  --    lleva 300 segundos; se admite margen por el tiempo que tarda la prueba.
  select waiting_seconds into v_n
  from public.admin_list_active_services() where request_id = v_buscando;
  insert into resultados values (5, 'La espera se calcula con el reloj del servidor',
    'entre 295 y 320', coalesce(v_n::text, 'nulo'), v_n between 295 and 320);

  -- 6. Solo se cuentan las ofertas vivas. Hay dos sobre el mismo servicio y una
  --    esta caducada.
  select pending_offers into v_n
  from public.admin_list_active_services() where request_id = v_buscando;
  insert into resultados values (6, 'Solo se cuentan las ofertas pendientes sin caducar',
    '1', coalesce(v_n::text, 'nulo'), v_n = 1);

  -- 7. El orden es el que le sirve al despachador: lo que lleva mas esperando,
  --    arriba.
  select string_agg(s.request_id::text, ' > ' order by s.waiting_seconds desc)
    into v_orden
  from public.admin_list_active_services() s
  where s.request_id::text like 'ac000000%';
  insert into resultados values (7, 'Ordena por espera, el mas antiguo primero',
    v_buscando::text || ' > ' || v_asignado::text || ' > ' || v_encurso::text,
    coalesce(v_orden, 'nulo'),
    v_orden = v_buscando::text || ' > ' || v_asignado::text || ' > ' || v_encurso::text);

  -- 8. El valor del servicio viaja, que es lo que D217 anadio y el tablero
  --    tiene que poder mostrar.
  select fare_amount into v_n
  from public.admin_list_active_services() where request_id = v_buscando;
  insert into resultados values (8, 'El tablero trae el valor del servicio',
    '4000', coalesce(v_n::text, 'nulo'), v_n = 4000);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$tablero$;


-- -----------------------------------------------------------------------------
-- Lo que no puede ver quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas  constant uuid := 'ac000000-0000-4000-8000-0000000000b1';
  v_encurso constant uuid := 'ac000000-0000-4000-8000-000000000003';
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 9. LA COMPROBACION QUE JUSTIFICA `security invoker`. Un pasajero puede
  --    llamar a la funcion -esta concedida a `authenticated`- pero las politicas
  --    RLS se aplican con SU identidad, asi que ve lo suyo y nada mas. Con
  --    `security definer` habria visto el tablero entero de la empresa.
  select count(*) into v_n from public.admin_list_active_services()
  where request_id = v_encurso;
  insert into resultados values (9,
    'Un pasajero NO ve en el tablero el servicio de otro pasajero',
    '0', v_n::text, v_n = 0);

  -- 10. Y va con la 9 vigilandola: sus propios servicios si los ve, asi que la
  --     9 no esta en verde porque la funcion devuelva cero a todo el mundo.
  select count(*) into v_n from public.admin_list_active_services()
  where request_id::text like 'ac000000%';
  insert into resultados values (10,
    'Pero SI ve el suyo, asi que la comprobacion anterior mide algo',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 11. Sin sesion no se ve nada.
  execute 'set local role anon';
  begin
    select count(*) into v_n from public.admin_list_active_services();
    insert into resultados values (11, 'Sin sesion no se ve ningun servicio',
      '0', v_n::text, v_n = 0);
  exception when others then
    insert into resultados values (11, 'Sin sesion no se ve ningun servicio',
      '0', 'rechazado: ' || sqlstate, true);
  end;
  execute 'reset role';
end
$privacidad$;


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
