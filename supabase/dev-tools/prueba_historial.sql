-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `list_passenger_history` y `list_driver_history` (Fase 16, paso 1).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_historial.sql
--
-- TODO OCURRE DENTRO DE UNA TRANSACCION QUE SE DESHACE. No deja una fila en el
-- servidor. Usa las cuentas de prueba que ya existen y les cuelga solicitudes,
-- viajes y ofertas inventadas, mira lo que devuelve cada funcion y hace rollback.
--
-- LAS COORDENADAS SALEN DE `places`, NO ESCRITAS A MANO. Tres veces en dos dias
-- un dato de prueba escrito a mano parecio un fallo del producto: el parque, el
-- hospital y el punto de recogida. Aqui el origen y el destino se leen de la
-- tabla, asi que la etiqueta y el punto no pueden discrepar.
--
-- LA PARTE QUE MAS IMPORTA es la que intenta romper: un pasajero pidiendo el
-- historial de otro, un conductor pidiendo el de otro, y el nombre del pasajero
-- en una oferta que se rechazo. Las funciones son SECURITY INVOKER, asi que lo
-- que se prueba de verdad son las politicas de la Fase 5 vistas desde arriba.
--
-- Nota de la Fase 13: `db query -f` solo devuelve el ULTIMO select del archivo.
-- Por eso cada comprobacion se guarda en una tabla temporal y al final se
-- imprime entera.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

-- Lo que devolvio cada funcion, guardado tal cual mientras se suplantaba a su
-- dueno. Se revisa DESPUES, ya con el rol de la CLI, que es el unico que puede
-- mirar las tablas enteras y comprobar de quien era cada fila. Contar filas no
-- valia: estas cuentas ya tienen historial de verdad en el servidor, y una
-- prueba que espera un numero fijo se rompe cada vez que alguien las usa.
create temp table filas (
  quien text,
  pos integer,
  ident uuid
) on commit drop;

-- Las tablas las crea el rol de la CLI, pero las comprobaciones escriben en ella
-- mientras suplantan a un usuario cualquiera. Sin estos dos permisos, la prueba
-- falla por su propio andamiaje y no por lo que quiere medir.
-- El esquema temporal no se puede nombrar como `pg_temp` en un GRANT: hay que
-- preguntarle su nombre real a la sesion.
do $permisos$
begin
  execute format('grant usage on schema %I to authenticated',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados, filas to authenticated';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Los datos de la prueba
-- -----------------------------------------------------------------------------

do $datos$
declare
  -- Cuentas que ya viven en el servidor.
  c_ana      constant uuid := 'ad000000-0000-4000-8000-0000000000f1';  -- pasajera
  c_marta    constant uuid := '60000000-0000-4000-8000-000000000001';  -- la otra
  c_cond1    constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_cond2    constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_veh1     constant uuid := 'e0000000-0000-4000-8000-000000000001';  -- unidad 99

  -- Identificadores fijos para poder senalarlos en las comprobaciones.
  c_ra1 constant uuid := 'a1000000-0000-4000-8000-000000000001';  -- terminada
  c_ra2 constant uuid := 'a1000000-0000-4000-8000-000000000002';  -- cancelada
  c_ra3 constant uuid := 'a1000000-0000-4000-8000-000000000003';  -- caducada
  c_ra4 constant uuid := 'a1000000-0000-4000-8000-000000000004';  -- viva
  c_rb1 constant uuid := 'a1000000-0000-4000-8000-000000000005';  -- de Marta

  c_via1 constant uuid := 'b1000000-0000-4000-8000-000000000001';
  c_via2 constant uuid := 'b1000000-0000-4000-8000-000000000002';

  c_of1 constant uuid := 'c1000000-0000-4000-8000-000000000001';  -- cond1 acepta
  c_of2 constant uuid := 'c1000000-0000-4000-8000-000000000002';  -- cond1 rechaza
  c_of3 constant uuid := 'c1000000-0000-4000-8000-000000000003';  -- cond2 caduca
  c_of4 constant uuid := 'c1000000-0000-4000-8000-000000000004';  -- cond1 pendiente
  c_of5 constant uuid := 'c1000000-0000-4000-8000-000000000005';  -- cond2, otro gano
  c_of6 constant uuid := 'c1000000-0000-4000-8000-000000000006';  -- el otro: cond1 acepta

  v_origen      extensions.geography;
  v_origen_lbl  text;
  v_destino     extensions.geography;
  v_destino_lbl text;
begin
  select p.location, p.name into v_origen, v_origen_lbl
  from public.places p where p.name ilike '%parque%' order by p.sort_order limit 1;

  select p.location, p.name into v_destino, v_destino_lbl
  from public.places p where p.name ilike '%hospital%' order by p.sort_order limit 1;

  if v_origen is null or v_destino is null then
    raise exception 'Faltan lugares en places: origen=% destino=%', v_origen_lbl, v_destino_lbl;
  end if;

  -- Cuatro solicitudes de Ana, una de Marta. Las horas van hacia atras para que
  -- el orden por fecha se pueda comprobar.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at,
    assigned_at, started_at, completed_at, cancelled_at, cancelled_by, cancellation_reason
  ) values
    (c_ra1, c_ana, 'completed', 2,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '3 hours', now() - interval '2 hours 55 minutes',
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 50 minutes',
     now() - interval '2 hours 40 minutes', null, null, null),

    (c_ra2, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '2 hours', now() - interval '1 hour 55 minutes',
     null, null, null, now() - interval '1 hour 58 minutes', 'passenger', 'Ya no lo necesito'),

    (c_ra3, c_ana, 'expired', 3,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '1 hour', now() - interval '55 minutes',
     null, null, null, null, null, null),

    (c_ra4, c_ana, 'searching', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now(), now() + interval '5 minutes',
     null, null, null, null, null, null),

    (c_rb1, c_marta, 'completed', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3007654321', now() - interval '4 hours', now() - interval '3 hours 55 minutes',
     now() - interval '3 hours 58 minutes', now() - interval '3 hours 50 minutes',
     now() - interval '3 hours 40 minutes', null, null, null);

  -- Dos viajes, los dos del conductor 1 y los dos terminados.
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
  ) values
    (c_via1, c_ra1, c_cond1, c_veh1, 'completed', 2,
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 52 minutes',
     now() - interval '2 hours 50 minutes', now() - interval '2 hours 40 minutes', 1200, 600),

    (c_via2, c_rb1, c_cond1, c_veh1, 'completed', 1,
     now() - interval '3 hours 58 minutes', now() - interval '3 hours 52 minutes',
     now() - interval '3 hours 50 minutes', now() - interval '3 hours 40 minutes', 800, 400);

  -- Las cinco ofertas, una por cada desenlace posible.
  insert into public.ride_offers (
    id, request_id, driver_id, offered_at, expires_at, response, responded_at, distance_m
  ) values
    (c_of1, c_ra1, c_cond1, now() - interval '2 hours 59 minutes',
     now() - interval '2 hours 58 minutes', 'accepted', now() - interval '2 hours 58 minutes', 109),

    (c_of2, c_ra2, c_cond1, now() - interval '1 hour 59 minutes',
     now() - interval '1 hour 58 minutes', 'rejected', now() - interval '1 hour 59 minutes', 259),

    (c_of3, c_ra3, c_cond2, now() - interval '59 minutes',
     now() - interval '58 minutes', 'expired', now() - interval '58 minutes', 259),

    (c_of4, c_ra4, c_cond1, now(), now() + interval '20 seconds', 'pending', null, 109),

    (c_of5, c_rb1, c_cond2, now() - interval '3 hours 59 minutes',
     now() - interval '3 hours 58 minutes', 'expired', now() - interval '3 hours 58 minutes', 259),

    -- La cara buena de la anterior: el viaje de Marta lo hizo el conductor 1, y
    -- por eso al 2 le caduco la suya. Sin esta fila el reparto no seria posible,
    -- porque un viaje nace siempre de una oferta aceptada.
    (c_of6, c_rb1, c_cond1, now() - interval '3 hours 59 minutes',
     now() - interval '3 hours 58 minutes', 'accepted', now() - interval '3 hours 58 minutes', 109);
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

  c_ra1 constant uuid := 'a1000000-0000-4000-8000-000000000001';
  c_ra2 constant uuid := 'a1000000-0000-4000-8000-000000000002';
  c_ra3 constant uuid := 'a1000000-0000-4000-8000-000000000003';
  c_ra4 constant uuid := 'a1000000-0000-4000-8000-000000000004';
  c_rb1 constant uuid := 'a1000000-0000-4000-8000-000000000005';

  c_of1 constant uuid := 'c1000000-0000-4000-8000-000000000001';
  c_of2 constant uuid := 'c1000000-0000-4000-8000-000000000002';
  c_of3 constant uuid := 'c1000000-0000-4000-8000-000000000003';
  c_of5 constant uuid := 'c1000000-0000-4000-8000-000000000005';
  c_of6 constant uuid := 'c1000000-0000-4000-8000-000000000006';

  -- A quien hay que volver despues de cada suplantacion. El rol con el que se
  -- conecta la CLI no es siempre el mismo, asi que se guarda en lugar de
  -- suponerlo.
  v_admin constant text := current_user;

  v_n   integer;
  v_txt text;
  v_admin_txt text;
  v_int integer;
  v_ok  boolean;
begin
  -- ---------------------------------------------------------------- pasajera
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_ana, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  insert into filas
  select 'ana', row_number() over (), h.request_id from public.list_passenger_history(50, 0) h;

  select count(*) into v_n from filas f where f.quien = 'ana' and f.ident in (c_ra1, c_ra2, c_ra3);
  insert into resultados values (1, 'Ana ve sus tres solicitudes cerradas', '3', v_n::text, v_n = 3);

  select count(*) into v_n from public.list_passenger_history() h where h.request_id = c_ra4;
  insert into resultados values (2, 'La solicitud viva NO sale en el historial', '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.list_passenger_history() h where h.request_id = c_rb1;
  insert into resultados values (3, 'ATAQUE: Ana no ve la solicitud de Marta', '0', v_n::text, v_n = 0);

  select h.driver_name || ' / ' || h.vehicle_unit_number into v_txt
  from public.list_passenger_history() h where h.request_id = c_ra1;
  insert into resultados values (4, 'La terminada trae conductor y unidad',
    'Conductor de prueba / 99', coalesce(v_txt, '(nulo)'), v_txt = 'Conductor de prueba / 99');

  select h.distance_m || ' m / ' || h.duration_s || ' s' into v_txt
  from public.list_passenger_history() h where h.request_id = c_ra1;
  insert into resultados values (5, 'La terminada trae distancia y duracion',
    '1200 m / 600 s', coalesce(v_txt, '(nulo)'), v_txt = '1200 m / 600 s');

  select h.cancelled_by::text into v_txt
  from public.list_passenger_history() h where h.request_id = c_ra2;
  insert into resultados values (6, 'La cancelada dice quien la cancelo',
    'passenger', coalesce(v_txt, '(nulo)'), v_txt = 'passenger');

  select (h.ride_id is null and h.driver_name is null) into v_ok
  from public.list_passenger_history() h where h.request_id = c_ra3;
  insert into resultados values (7, 'La caducada no tiene viaje ni conductor',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  -- RELATIVO Y NO ABSOLUTO. Antes se pedia que la primera fila de la lista fuera
  -- la de la prueba, y eso se rompio solo en cuanto la cuenta hizo servicios de
  -- verdad mas recientes. Lo que hay que exigir es el ORDEN entre las tres filas
  -- que esta prueba creo.
  select
    (select f.pos from filas f where f.quien = 'ana' and f.ident = c_ra3) <
    (select f.pos from filas f where f.quien = 'ana' and f.ident = c_ra2)
    and
    (select f.pos from filas f where f.quien = 'ana' and f.ident = c_ra2) <
    (select f.pos from filas f where f.quien = 'ana' and f.ident = c_ra1)
  into v_ok;
  insert into resultados values (8, 'Orden: de la mas reciente a la mas antigua',
    'true', coalesce(v_ok::text, '(sin filas)'), coalesce(v_ok, false));

  select count(*) into v_n from public.list_passenger_history(1, 0);
  insert into resultados values (9, 'El limite se respeta', '1', v_n::text, v_n = 1);

  select h.request_id into v_txt from public.list_passenger_history(1, 1) h;
  select f.ident::text into v_admin_txt from filas f where f.quien = 'ana' and f.pos = 2;
  insert into resultados values (10, 'El desplazamiento salta a la segunda de la lista',
    coalesce(v_admin_txt, '(sin segunda)'), coalesce(v_txt, '(nulo)'), v_txt = v_admin_txt);

  select count(*) into v_n from public.list_passenger_history(0, 0);
  insert into resultados values (11, 'Un limite de cero se sube a uno', '1', v_n::text, v_n = 1);

  select count(*) into v_n from public.list_driver_history();
  insert into resultados values (12, 'Una pasajera no tiene historial de conductor',
    '0', v_n::text, v_n = 0);

  perform set_config('role', v_admin, true);

  -- --------------------------------------------------------------- conductor 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond1, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  insert into filas
  select 'cond1', row_number() over (), h.offer_id from public.list_driver_history(50, 0) h;

  select count(*) into v_n from filas f
  where f.quien = 'cond1' and f.ident in (c_of1, c_of2, c_of6);
  insert into resultados values (13, 'El conductor 1 ve sus tres ofertas cerradas',
    '3', v_n::text, v_n = 3);

  select count(*) into v_n from public.list_driver_history() h where h.request_id = c_ra4;
  insert into resultados values (14, 'La oferta pendiente NO sale', '0', v_n::text, v_n = 0);

  select h.outcome into v_txt from public.list_driver_history() h where h.request_id = c_ra1;
  insert into resultados values (15, 'La que acepto y termino: completed',
    'completed', coalesce(v_txt, '(nulo)'), v_txt = 'completed');

  select h.outcome into v_txt from public.list_driver_history() h where h.request_id = c_ra2;
  insert into resultados values (16, 'La que rechazo: rejected',
    'rejected', coalesce(v_txt, '(nulo)'), v_txt = 'rejected');

  select h.passenger_name into v_txt from public.list_driver_history() h where h.request_id = c_ra1;
  insert into resultados values (17, 'En la que llevo si ve el nombre',
    'Ana Gomez', coalesce(v_txt, '(nulo)'), v_txt = 'Ana Gomez');

  select h.passenger_name is null into v_ok
  from public.list_driver_history() h where h.request_id = c_ra2;
  insert into resultados values (18, 'PRIVACIDAD: en la que rechazo no ve el nombre',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select h.distance_m into v_int from public.list_driver_history() h where h.request_id = c_ra1;
  insert into resultados values (19, 'La terminada trae la distancia del viaje',
    '1200', coalesce(v_int::text, '(nulo)'), v_int = 1200);

  select h.pickup_distance_m into v_int from public.list_driver_history() h where h.request_id = c_ra2;
  insert into resultados values (20, 'Se conserva la distancia que habia al ofrecersela',
    '259', coalesce(v_int::text, '(nulo)'), v_int = 259);

  perform set_config('role', v_admin, true);

  -- --------------------------------------------------------------- conductor 2
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond2, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  insert into filas
  select 'cond2', row_number() over (), h.offer_id from public.list_driver_history(50, 0) h;

  select count(*) into v_n from filas f
  where f.quien = 'cond2' and f.ident in (c_of3, c_of5);
  insert into resultados values (21, 'El conductor 2 ve sus dos ofertas', '2', v_n::text, v_n = 2);

  select h.outcome into v_txt from public.list_driver_history() h where h.request_id = c_ra3;
  insert into resultados values (22, 'Nadie la tomo y el no respondio: expired',
    'expired', coalesce(v_txt, '(nulo)'), v_txt = 'expired');

  select h.outcome into v_txt from public.list_driver_history() h where h.request_id = c_rb1;
  insert into resultados values (23, 'Se la llevo otro conductor: taken_by_other',
    'taken_by_other', coalesce(v_txt, '(nulo)'), v_txt = 'taken_by_other');

  select count(*) into v_n from public.list_driver_history() h
  where h.request_id in (c_ra1, c_ra2);
  insert into resultados values (24, 'ATAQUE: no ve ninguna oferta del conductor 1',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n from public.list_passenger_history();
  insert into resultados values (25, 'Un conductor no tiene historial de pasajero',
    '0', v_n::text, v_n = 0);

  perform set_config('role', v_admin, true);

  -- ------------------------------------------------------------------ permisos
  select has_function_privilege('anon', 'public.list_passenger_history(integer,integer)', 'execute')
    into v_ok;
  insert into resultados values (26, 'Sin sesion no se puede pedir el historial del pasajero',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('anon', 'public.list_driver_history(integer,integer)', 'execute')
    into v_ok;
  insert into resultados values (27, 'Sin sesion no se puede pedir el del conductor',
    'false', v_ok::text, v_ok = false);

  -- ------------------------------------------------------- de quien era cada fila
  --
  -- Esto se mira ya con el rol de la CLI, que es el unico que ve las tablas
  -- enteras. Desde dentro de la sesion suplantada no serviria de nada: RLS
  -- esconde lo ajeno, asi que la consulta no encontraria una fuga aunque la
  -- hubiera. Una comprobacion que no puede ver lo que busca siempre sale bien.
  --
  -- Y va sobre TODO lo que devolvieron las funciones, no solo sobre las filas
  -- que invento esta prueba: estas cuentas ya tienen historial de verdad.
  select count(*) into v_n
  from filas f join public.ride_requests r on r.id = f.ident
  where f.quien = 'ana' and r.passenger_id <> c_ana;
  insert into resultados values (28, 'ATAQUE: ninguna fila de Ana es de otro pasajero',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n
  from filas f join public.ride_offers o on o.id = f.ident
  where f.quien = 'cond1' and o.driver_id <> c_cond1;
  insert into resultados values (29, 'ATAQUE: ninguna fila del conductor 1 es de otro',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n
  from filas f join public.ride_offers o on o.id = f.ident
  where f.quien = 'cond2' and o.driver_id <> c_cond2;
  insert into resultados values (30, 'ATAQUE: ninguna fila del conductor 2 es de otro',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n
  from filas f join public.ride_requests r on r.id = f.ident
  where f.quien = 'ana' and r.status not in ('completed', 'cancelled', 'expired');
  insert into resultados values (31, 'Ninguna solicitud viva se colo en el historial',
    '0', v_n::text, v_n = 0);

  select count(*) into v_n
  from filas f join public.ride_offers o on o.id = f.ident
  where f.quien in ('cond1', 'cond2') and o.response = 'pending';
  insert into resultados values (32, 'Ninguna oferta pendiente se colo en el historial',
    '0', v_n::text, v_n = 0);
end
$checks$;


-- -----------------------------------------------------------------------------
-- El resultado. Este es el ultimo select del archivo, y por eso es el que se ve.
-- -----------------------------------------------------------------------------

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
