-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260828010000_admin_rides.sql` (Fase 20, paso 8: listado e
-- inspeccion de servicios).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_servicios.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- **ESTA PRUEBA MIRA UN LISTADO SIN FILTRAR, y eso obliga a un cuidado extra.**
-- La base tiene 57 solicitudes reales; contar el total absoluto haria que se
-- pusiera roja el dia que alguien pida un viaje. Por eso **todas las
-- comprobaciones de conteo filtran por los servicios propios** -los que llevan
-- "Zz servicio" en la etiqueta de origen- y las que miran el total solo
-- comprueban que **crece con los que se anaden**, no un numero fijo.
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
-- Montaje: un servicio terminado completo y uno que nadie tomo
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'b7000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'b7000000-0000-4000-8000-0000000000b1';
  v_pas2  uuid := 'b7000000-0000-4000-8000-0000000000b2';
  v_cond  uuid;
  v_cond2 uuid;
  v_veh   uuid;
  v_lng double precision;
  v_lat double precision;

  v_terminado uuid := 'b7000000-0000-4000-8000-000000000001';
  v_caducado  uuid := 'b7000000-0000-4000-8000-000000000002';
  v_ride      uuid := 'b7000000-0000-4000-8000-00000000c001';
begin
  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' order by d.id limit 1;
  select d.id into v_cond2 from public.drivers d
  where d.id <> v_cond and d.approval_status = 'approved' order by d.id limit 1;
  select v.id into v_veh from public.vehicles v where v.status = 'active' limit 1;

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.serv.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.serv.pas@motomoto-qa.co', now(), now()),
    (v_pas2,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.serv.pas2@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas, v_pas2);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz serv admin',     '3000000111', 'admin',     'active'),
    (v_pas,   'Zz serv pasajero',  '3000000112', 'passenger', 'active'),
    (v_pas2,  'Zz serv pasajero2', '3000000113', 'passenger', 'active');

  -- Uno terminado, con su valor y su referencia de recogida.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    assigned_at, started_at, completed_at, pickup_reference,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    v_terminado, v_pas, 'completed', 2,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz servicio origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz servicio destino', '3000000112',
    now() - interval '3 hours', now() - interval '3 hours' + interval '5 minutes',
    now() - interval '3 hours' + interval '1 minute',
    now() - interval '3 hours' + interval '9 minutes',
    now() - interval '3 hours' + interval '24 minutes',
    'Zz junto al arbol grande',
    'passenger', 6200, 6200, 0, false, false
  );

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
  ) values (
    v_ride, v_terminado, v_cond, v_veh, 'completed', 2,
    now() - interval '3 hours' + interval '1 minute',
    now() - interval '3 hours' + interval '7 minutes',
    now() - interval '3 hours' + interval '9 minutes',
    now() - interval '3 hours' + interval '24 minutes',
    2400, 900
  );

  -- Dos puntos de rastro, para poder medir que el detalle los cuenta.
  insert into public.ride_locations (ride_id, location, recorded_at)
  values
    (v_ride, extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
     now() - interval '3 hours' + interval '10 minutes'),
    (v_ride, extensions.st_setsrid(extensions.st_makepoint(v_lng + 0.001, v_lat), 4326)::extensions.geography,
     now() - interval '3 hours' + interval '20 minutes');

  -- La oferta que acepto, y las dos calificaciones.
  insert into public.ride_offers (request_id, driver_id, expires_at, response, offered_at,
                                  responded_at, distance_m)
  values (v_terminado, v_cond, now() - interval '3 hours' + interval '20 seconds', 'accepted',
          now() - interval '3 hours', now() - interval '3 hours' + interval '8 seconds', 300);

  insert into public.ratings (ride_id, rater_id, rated_id, stars, comment) values
    (v_ride, v_pas, v_cond, 5, 'Zz muy amable'),
    (v_ride, v_cond, v_pas, 4, 'Zz puntual');

  -- Y uno que nadie tomo: dos conductores lo dejaron pasar. Es el caso que la
  -- pantalla tiene que poder explicar.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural
  ) values (
    v_caducado, v_pas2, 'expired', 1,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz servicio origen dos',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz servicio destino dos', '3000000113',
    now() - interval '2 hours', now() - interval '2 hours' + interval '5 minutes',
    'passenger', 4000, 4000, 0, false, false
  );

  insert into public.ride_offers (request_id, driver_id, expires_at, response, offered_at,
                                  responded_at, distance_m)
  values
    (v_caducado, v_cond,  now() - interval '2 hours' + interval '20 seconds', 'rejected',
     now() - interval '2 hours', now() - interval '2 hours' + interval '5 seconds', 400),
    (v_caducado, v_cond2, now() - interval '2 hours' + interval '50 seconds', 'expired',
     now() - interval '2 hours' + interval '30 seconds',
     now() - interval '2 hours' + interval '50 seconds', 900);
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El listado y sus filtros
-- -----------------------------------------------------------------------------

do $listado$
declare
  v_admin constant uuid := 'b7000000-0000-4000-8000-0000000000a1';
  v_terminado constant uuid := 'b7000000-0000-4000-8000-000000000001';
  v_caducado  constant uuid := 'b7000000-0000-4000-8000-000000000002';
  v_n integer;
  v_row record;
  v_total bigint;
  -- **CUARTA VEZ EN ESTE PROYECTO.** Un `select ... into` de un solo valor no se
  -- lee con `v_row.column1`: hace falta una variable escalar. Ya paso en
  -- prueba_conductores, prueba_documentos y prueba_pasajeros.
  v_duracion text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Los dos de la prueba salen, buscando por su etiqueta.
  select count(*) into v_n
  from public.admin_list_rides(null, null, null, 'Zz servicio', 100, 0);
  insert into resultados values (1, 'El buscador encuentra por etiqueta de origen o destino',
    '2', v_n::text, v_n = 2);

  -- 2. **EL BUSCADOR MIRA CUATRO CAMPOS A LA VEZ**, porque quien busca no sabe
  --    de antemano en cual esta lo que recuerda: nombre del pasajero, del
  --    conductor, origen o destino.
  select count(*) into v_n
  from public.admin_list_rides(null, null, null, 'Zz serv pasajero2', 100, 0);
  insert into resultados values (2, 'El buscador tambien encuentra por nombre del pasajero',
    '1', v_n::text, v_n = 1);

  -- 3. El filtro de estado.
  select count(*) into v_n
  from public.admin_list_rides('expired', null, null, 'Zz servicio', 100, 0);
  insert into resultados values (3, 'El filtro por estado deja solo los de ese estado',
    '1', v_n::text, v_n = 1);

  -- 4. El de fechas. Los dos son de hoy, asi que un rango de ayer no trae nada.
  select count(*) into v_n
  from public.admin_list_rides(null, now() - interval '2 days', now() - interval '1 day',
                               'Zz servicio', 100, 0);
  insert into resultados values (4, 'El filtro de fechas excluye lo que cae fuera',
    '0', v_n::text, v_n = 0);

  -- 5. Y los incluye cuando el rango si los cubre. Va con la 4 vigilandola: sin
  --    esta, la 4 podria estar en verde porque el filtro no devuelve nunca nada.
  select count(*) into v_n
  from public.admin_list_rides(null, now() - interval '1 day', now() + interval '1 day',
                               'Zz servicio', 100, 0);
  insert into resultados values (5, 'Y los incluye cuando el rango si los cubre',
    '2', v_n::text, v_n = 2);

  -- 6. **EL TOTAL VIENE EN CADA FILA**, para poder paginar sin pedir el listado
  --    entero. Se comprueba que cuenta lo filtrado y no la tabla completa.
  select max(total_count) into v_total
  from public.admin_list_rides(null, null, null, 'Zz servicio', 100, 0);
  insert into resultados values (6, 'El total cuenta lo filtrado, no la tabla entera',
    '2', coalesce(v_total::text, 'nulo'), v_total = 2);

  -- 7. La paginacion parte el resultado sin perder el total.
  select count(*), max(total_count) into v_n, v_total
  from public.admin_list_rides(null, null, null, 'Zz servicio', 1, 0);
  insert into resultados values (7, 'Pidiendo uno se devuelve uno, con el total completo',
    '1, 2', v_n::text || ', ' || coalesce(v_total::text, 'nulo'), v_n = 1 and v_total = 2);

  -- 8. El tope del servidor manda sobre lo que pida el cliente (D199).
  select count(*) into v_n
  from public.admin_list_rides(null, null, null, 'Zz servicio', 99999, 0);
  insert into resultados values (8, 'El limite pedido no puede pasar del tope del servidor',
    '2', v_n::text, v_n = 2);

  -- 9. El terminado trae su duracion de punta a punta; el caducado no tiene.
  select
    (select duration_minutes from public.admin_list_rides(null,null,null,'Zz servicio',100,0)
     where request_id = v_terminado)::text || ', ' ||
    coalesce((select duration_minutes::text from public.admin_list_rides(null,null,null,'Zz servicio',100,0)
     where request_id = v_caducado), 'nulo')
  into v_duracion;
  insert into resultados values (9, 'La duracion se calcula solo si el servicio termino',
    '24, nulo', coalesce(v_duracion, 'nulo'), v_duracion = '24, nulo');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$listado$;


-- -----------------------------------------------------------------------------
-- El detalle
-- -----------------------------------------------------------------------------

do $detalle$
declare
  v_admin constant uuid := 'b7000000-0000-4000-8000-0000000000a1';
  v_terminado constant uuid := 'b7000000-0000-4000-8000-000000000001';
  v_caducado  constant uuid := 'b7000000-0000-4000-8000-000000000002';
  v_row record;
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 10. **LAS DOS PARTES JUNTAS, con sus telefonos.** Es lo que las funciones de
  --     la Fase 16 esconden a cada lado a proposito (D198), y lo que hace falta
  --     para resolver una queja.
  select passenger_name, passenger_phone, driver_name, driver_phone, unit_number into v_row
  from public.admin_get_ride_detail(v_terminado);
  insert into resultados values (10, 'El detalle trae las dos partes con sus telefonos',
    'Zz serv pasajero, 3000000112, con conductor, con telefono, con unidad',
    coalesce(v_row.passenger_name, 'nulo') || ', ' || coalesce(v_row.passenger_phone, 'nulo') ||
      ', ' || case when v_row.driver_name is not null then 'con conductor' else 'sin conductor' end ||
      ', ' || case when v_row.driver_phone is not null then 'con telefono' else 'sin telefono' end ||
      ', ' || case when v_row.unit_number is not null then 'con unidad' else 'sin unidad' end,
    v_row.passenger_name = 'Zz serv pasajero' and v_row.passenger_phone = '3000000112'
      and v_row.driver_name is not null and v_row.driver_phone is not null
      and v_row.unit_number is not null);

  -- 11. La linea de tiempo entera, en orden.
  select
    (requested_at < accepted_at
     and accepted_at < driver_arrived_at
     and driver_arrived_at < started_at
     and started_at < completed_at) as en_orden
  into v_row
  from public.admin_get_ride_detail(v_terminado);
  insert into resultados values (11, 'La linea de tiempo viene completa y en orden',
    'true', coalesce(v_row.en_orden::text, 'nulo'), v_row.en_orden);

  -- 12. El desglose del valor, no solo el total: con los precios cambiando desde
  --     el panel, un total suelto no se puede volver a explicar.
  select fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night into v_row
  from public.admin_get_ride_detail(v_terminado);
  insert into resultados values (12, 'El detalle trae el desglose del valor',
    '6200, 6200, 0, false',
    coalesce(v_row.fare_amount::text, 'nulo') || ', ' ||
      coalesce(v_row.fare_trip_amount::text, 'nulo') || ', ' ||
      coalesce(v_row.fare_cargo_amount::text, 'nulo') || ', ' ||
      coalesce(v_row.fare_is_night::text, 'nulo'),
    v_row.fare_amount = 6200 and v_row.fare_trip_amount = 6200
      and v_row.fare_cargo_amount = 0 and not v_row.fare_is_night);

  -- 13. El rastro, contado. Hoy la base tiene un punto por viaje, asi que este
  --     numero es la unica forma honesta de ensenar el recorrido.
  select track_points, distance_m into v_row
  from public.admin_get_ride_detail(v_terminado);
  insert into resultados values (13, 'Cuenta los puntos del rastro y trae la distancia',
    '2, 2400',
    coalesce(v_row.track_points::text, 'nulo') || ', ' || coalesce(v_row.distance_m::text, 'nulo'),
    v_row.track_points = 2 and v_row.distance_m = 2400);

  -- 14. **LO QUE CONVIERTE "NADIE LO TOMO" EN ALGO ACCIONABLE.** Al caducado le
  --     llego a dos conductores: uno lo rechazo y otro dejo pasar el tiempo. Sin
  --     esto, la empresa no puede distinguirlo de "no le llego a nadie".
  select offers_total, offers_rejected, offers_expired into v_row
  from public.admin_get_ride_detail(v_caducado);
  insert into resultados values (14, 'Dice a cuantos llego la oferta y que hicieron',
    '2, 1, 1',
    coalesce(v_row.offers_total::text, 'nulo') || ', ' ||
      coalesce(v_row.offers_rejected::text, 'nulo') || ', ' ||
      coalesce(v_row.offers_expired::text, 'nulo'),
    v_row.offers_total = 2 and v_row.offers_rejected = 1 and v_row.offers_expired = 1);

  -- 15. El detalle de las ofertas, con nombre y tiempo de respuesta.
  select count(*) into v_n from public.admin_get_ride_offers(v_caducado);
  insert into resultados values (15, 'Se puede ver cada oferta por separado',
    '2', v_n::text, v_n = 2);

  select response_seconds into v_row
  from public.admin_get_ride_offers(v_caducado) where response = 'rejected';
  insert into resultados values (16, 'Y cuanto tardo cada conductor en responder',
    '5', coalesce(v_row.response_seconds::text, 'nulo'), v_row.response_seconds = 5);

  -- 17. **LAS DOS CALIFICACIONES JUNTAS.** La Fase 17 le ensena a cada parte la
  --     suya; aqui se ven las dos, que es lo que hace falta para entender una
  --     queja.
  select count(*) into v_n from public.admin_get_ride_ratings(v_terminado);
  insert into resultados values (17, 'Trae las calificaciones en los dos sentidos',
    '2', v_n::text, v_n = 2);

  select stars, comment into v_row
  from public.admin_get_ride_ratings(v_terminado) where rater_role = 'driver';
  insert into resultados values (18, 'Y se distingue quien calificó a quien',
    '4, Zz puntual',
    coalesce(v_row.stars::text, 'nulo') || ', ' || coalesce(v_row.comment, 'nulo'),
    v_row.stars = 4 and v_row.comment = 'Zz puntual');

  -- 19. Un servicio sin conductor -nadie lo tomo- no trae basura: trae nulos.
  select driver_name, unit_number, accepted_at into v_row
  from public.admin_get_ride_detail(v_caducado);
  insert into resultados values (19, 'Un servicio que nadie tomo trae los datos del conductor vacios',
    'sin conductor, sin unidad, sin aceptacion',
    case when v_row.driver_name is null then 'sin conductor' else 'trae conductor' end || ', ' ||
      case when v_row.unit_number is null then 'sin unidad' else 'trae unidad' end || ', ' ||
      case when v_row.accepted_at is null then 'sin aceptacion' else 'trae aceptacion' end,
    v_row.driver_name is null and v_row.unit_number is null and v_row.accepted_at is null);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$detalle$;


-- -----------------------------------------------------------------------------
-- Quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas  constant uuid := 'b7000000-0000-4000-8000-0000000000b1';
  v_terminado constant uuid := 'b7000000-0000-4000-8000-000000000001';
  v_caducado  constant uuid := 'b7000000-0000-4000-8000-000000000002';
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 20. **UN PASAJERO NO VE LA OPERACION DE LA EMPRESA.** Es `security invoker`
  --     (D242): las politicas se aplican con su identidad, y solo ve lo suyo.
  select count(*) into v_n
  from public.admin_list_rides(null, null, null, 'Zz servicio', 100, 0);
  insert into resultados values (20, 'Un pasajero solo ve sus propios servicios en el listado',
    '1', v_n::text, v_n = 1);

  -- 21. Y el que ve es el suyo, no otro. Sin esta, la 20 podria estar en verde
  --     ensenandole el ajeno.
  select count(*) into v_n
  from public.admin_list_rides(null, null, null, 'Zz servicio', 100, 0)
  where request_id = v_terminado;
  insert into resultados values (21, 'Y el que ve es el suyo',
    '1', v_n::text, v_n = 1);

  -- 22. El detalle de un servicio ajeno no le devuelve nada.
  select count(*) into v_n from public.admin_get_ride_detail(v_caducado);
  insert into resultados values (22, 'No puede abrir el detalle de un servicio ajeno',
    '0', v_n::text, v_n = 0);

  -- 23. **NI LAS OFERTAS DE SU PROPIO SERVICIO.** Saber a que conductores les
  --     llego y quien lo rechazo es informacion de la empresa, no del pasajero.
  select count(*) into v_n from public.admin_get_ride_offers(v_terminado);
  insert into resultados values (23, 'Un pasajero NO ve las ofertas ni de su propio servicio',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
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
