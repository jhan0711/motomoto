-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `rate_ride`, de la regla R8 y del disparador que mantiene el
-- promedio del conductor (Fase 17, paso 1).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_calificaciones.sql
--
-- ESTO NO PRUEBA CODIGO NUEVO. La funcion, la tabla y el disparador se
-- escribieron en la Fase 5 y hasta hoy no los ha usado ninguna pantalla. Antes
-- de construir encima conviene saber si aguantan, y la unica forma de saberlo es
-- intentar romperlos: calificar dos veces, calificar un viaje ajeno, calificar
-- uno sin terminar, poner seis estrellas y escribir directamente en la tabla.
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
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_marta constant uuid := '60000000-0000-4000-8000-000000000001';
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_cond2 constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_veh1  constant uuid := 'e0000000-0000-4000-8000-000000000001';
  c_veh2  constant uuid := 'e0000000-0000-4000-8000-000000000002';

  c_ra1 constant uuid := 'a5000000-0000-4000-8000-000000000001';  -- terminada
  c_ra2 constant uuid := 'a5000000-0000-4000-8000-000000000002';  -- en curso
  c_rb1 constant uuid := 'a5000000-0000-4000-8000-000000000003';  -- de Marta
  c_ra4 constant uuid := 'a5000000-0000-4000-8000-000000000004';  -- caducada
  c_of1 constant uuid := 'c5000000-0000-4000-8000-000000000001';  -- la que acepto

  c_v1 constant uuid := 'b5000000-0000-4000-8000-000000000001';   -- terminado
  c_v2 constant uuid := 'b5000000-0000-4000-8000-000000000002';   -- en curso
  c_v3 constant uuid := 'b5000000-0000-4000-8000-000000000003';   -- de Marta
  c_v4 constant uuid := 'b5000000-0000-4000-8000-000000000004';   -- cancelado tras aceptar
  c_ra5 constant uuid := 'a5000000-0000-4000-8000-000000000005';  -- su solicitud

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
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at, assigned_at, started_at, completed_at
  ) values
    (c_ra1, c_ana, 'completed', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '3 hours', now() - interval '2 hours 55 minutes',
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 50 minutes',
     now() - interval '2 hours 40 minutes'),

    (c_ra2, c_ana, 'in_progress', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '20 minutes', now() - interval '15 minutes',
     now() - interval '18 minutes', now() - interval '10 minutes', null),

    (c_rb1, c_marta, 'completed', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3007654321', now() - interval '5 hours', now() - interval '4 hours 55 minutes',
     now() - interval '4 hours 58 minutes', now() - interval '4 hours 50 minutes',
     now() - interval '4 hours 40 minutes'),

    -- Caducada: nadie la tomo, asi que no hay nada que calificar. Sirve para
    -- distinguir "sin calificar" de "no hay que calificar".
    (c_ra4, c_ana, 'expired', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '6 hours', now() - interval '5 hours 55 minutes',
     null, null, null);

  -- Cancelada DESPUES de que un conductor la aceptara: tiene viaje, y aun asi no
  -- hay nada que calificar. Es el caso que encontro la tablet. Va en su propia
  -- insercion porque la restriccion `rr_cancelled_status_matches` exige que una
  -- cancelada traiga su hora y su autor.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at, assigned_at, cancelled_at, cancelled_by
  ) values
    (c_ra5, c_ana, 'cancelled', 1,
     v_origen, v_origen_lbl, v_destino, v_destino_lbl,
     '3001234567', now() - interval '7 hours', now() - interval '6 hours 55 minutes',
     now() - interval '6 hours 58 minutes', now() - interval '6 hours 50 minutes', 'passenger');

  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
  ) values
    (c_v1, c_ra1, c_cond1, c_veh1, 'completed', 1,
     now() - interval '2 hours 58 minutes', now() - interval '2 hours 52 minutes',
     now() - interval '2 hours 50 minutes', now() - interval '2 hours 40 minutes', 1200, 600),

    -- En curso, para poder intentar calificar algo que no ha terminado.
    (c_v2, c_ra2, c_cond1, c_veh1, 'in_progress', 1,
     now() - interval '18 minutes', now() - interval '12 minutes',
     now() - interval '10 minutes', null, null, null),

    (c_v3, c_rb1, c_cond2, c_veh2, 'completed', 1,
     now() - interval '4 hours 58 minutes', now() - interval '4 hours 52 minutes',
     now() - interval '4 hours 50 minutes', now() - interval '4 hours 40 minutes', 900, 500),

    (c_v4, c_ra5, c_cond2, c_veh2, 'cancelled', 1,
     now() - interval '6 hours 58 minutes', null, null, null, null, null);

  -- La oferta que dio lugar al viaje del conductor 1. El historial del conductor
  -- sale de las ofertas, no de los viajes, asi que sin ella no hay nada que
  -- mirar en su lista.
  insert into public.ride_offers (
    id, request_id, driver_id, offered_at, expires_at, response, responded_at, distance_m
  ) values
    (c_of1, c_ra1, c_cond1, now() - interval '2 hours 59 minutes',
     now() - interval '2 hours 58 minutes', 'accepted', now() - interval '2 hours 58 minutes', 109);
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

  c_v1 constant uuid := 'b5000000-0000-4000-8000-000000000001';
  c_v2 constant uuid := 'b5000000-0000-4000-8000-000000000002';
  c_v3 constant uuid := 'b5000000-0000-4000-8000-000000000003';

  c_ra1 constant uuid := 'a5000000-0000-4000-8000-000000000001';
  c_ra4 constant uuid := 'a5000000-0000-4000-8000-000000000004';
  c_of1 constant uuid := 'c5000000-0000-4000-8000-000000000001';
  c_v4  constant uuid := 'b5000000-0000-4000-8000-000000000004';

  v_admin constant text := current_user;

  v_id    uuid;
  v_hint  text;
  v_n     integer;
  v_txt   text;
  v_antes numeric;
  v_desp  numeric;
  v_ok    boolean;
begin
  select d.rating_average into v_antes from public.drivers d where d.id = c_cond1;

  -- ---------------------------------------------------------------- pasajera
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_ana, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  select public.rate_ride(c_v1, 4::smallint, '  Muy amable  ') into v_id;
  insert into resultados values (1, 'La pasajera califica su viaje terminado',
    'un identificador', coalesce(v_id::text, '(nulo)'), v_id is not null);

  -- R8, segunda vez.
  begin
    perform public.rate_ride(c_v1, 5::smallint, null);
    v_hint := '(no fallo)';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  insert into resultados values (2, 'R8: no puede calificar dos veces el mismo viaje',
    'ALREADY_RATED', v_hint, v_hint = 'ALREADY_RATED');

  -- Viaje de otras personas.
  begin
    perform public.rate_ride(c_v3, 5::smallint, null);
    v_hint := '(no fallo)';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  insert into resultados values (3, 'ATAQUE: no puede calificar un viaje ajeno',
    'NOT_A_PARTICIPANT', v_hint, v_hint = 'NOT_A_PARTICIPANT');

  -- Viaje que sigue en curso.
  begin
    perform public.rate_ride(c_v2, 5::smallint, null);
    v_hint := '(no fallo)';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  insert into resultados values (4, 'No se puede calificar un viaje sin terminar',
    'RIDE_NOT_COMPLETED', v_hint, v_hint = 'RIDE_NOT_COMPLETED');

  -- Un viaje que no existe.
  begin
    perform public.rate_ride('00000000-0000-4000-8000-000000000000'::uuid, 5::smallint, null);
    v_hint := '(no fallo)';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  insert into resultados values (5, 'Un viaje inexistente responde con su codigo',
    'RIDE_NOT_FOUND', v_hint, v_hint = 'RIDE_NOT_FOUND');

  -- Fuera de rango, por arriba y por abajo. Aqui no hay pista: lo para la
  -- restriccion de la tabla, que devuelve 23514.
  begin
    perform public.rate_ride(c_v2, 6::smallint, null);
    v_txt := '(no fallo)';
  exception when others then
    get stacked diagnostics v_txt = returned_sqlstate;
  end;
  insert into resultados values (6, 'Seis estrellas no entran', 'error', v_txt, v_txt <> '(no fallo)');

  begin
    perform public.rate_ride(c_v2, 0::smallint, null);
    v_txt := '(no fallo)';
  exception when others then
    get stacked diagnostics v_txt = returned_sqlstate;
  end;
  insert into resultados values (7, 'Cero estrellas tampoco', 'error', v_txt, v_txt <> '(no fallo)');

  -- Escribir a mano en la tabla, saltandose la funcion. No hay politica de
  -- insercion para `authenticated`, asi que RLS lo tiene que impedir.
  begin
    insert into public.ratings (ride_id, rater_id, rated_id, stars)
    values (c_v3, c_ana, c_cond2, 5);
    v_txt := '(no fallo)';
  exception when others then
    get stacked diagnostics v_txt = returned_sqlstate;
  end;
  insert into resultados values (8, 'ATAQUE: no se puede escribir en `ratings` a mano',
    '42501', v_txt, v_txt = '42501');

  -- Lo que si puede ver.
  select count(*) into v_n from public.ratings r where r.ride_id = c_v1;
  insert into resultados values (9, 'La pasajera ve la calificacion que dio', '1', v_n::text, v_n = 1);

  select count(*) into v_n from public.ratings r where r.ride_id = c_v3;
  insert into resultados values (10, 'ATAQUE: no ve calificaciones de viajes ajenos',
    '0', v_n::text, v_n = 0);

  -- EL CASO QUE ENCONTRO LA TABLET. Un servicio cancelado despues de que alguien
  -- lo aceptara tiene viaje, y aun asi no se puede calificar: `rate_ride` solo
  -- admite terminados. Antes salia como "sin calificar" y ofrecia el boton.
  select h.already_rated is null into v_ok
  from public.list_passenger_history(50, 0) h where h.ride_id = c_v4;
  insert into resultados values (24,
    'Un cancelado CON viaje no aparece como "sin calificar"',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  perform set_config('role', v_admin, true);

  -- --------------------------------------------------------------- conductor 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond1, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- EL CRUCE QUE IMPORTA. La pasajera ya califico este viaje; el conductor no.
  -- Si `already_rated` mirara solo el viaje, aqui diria que si y la aplicacion
  -- dejaria de ofrecerle algo que todavia puede hacer.
  select h.already_rated into v_ok
  from public.list_driver_history(50, 0) h where h.ride_id = c_v1;
  insert into resultados values (20,
    'Que la otra parte haya calificado NO cuenta como calificado por el',
    'false', coalesce(v_ok::text, '(sin fila)'), v_ok = false);

  select j.my_stars is null into v_ok from public.get_driver_job(c_of1) j;
  insert into resultados values (21, 'Y su detalle no trae estrellas suyas todavia',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select public.rate_ride(c_v1, 5::smallint, null) into v_id;
  insert into resultados values (11, 'El conductor califica el MISMO viaje, y entra',
    'un identificador', coalesce(v_id::text, '(nulo)'), v_id is not null);

  begin
    perform public.rate_ride(c_v1, 3::smallint, null);
    v_hint := '(no fallo)';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;
  insert into resultados values (12, 'R8 vale para las dos partes por igual',
    'ALREADY_RATED', v_hint, v_hint = 'ALREADY_RATED');

  select h.already_rated into v_ok
  from public.list_driver_history(50, 0) h where h.ride_id = c_v1;
  insert into resultados values (22, 'Despues de calificar, su historial lo dice',
    'true', coalesce(v_ok::text, '(sin fila)'), v_ok = true);

  select j.my_stars into v_n from public.get_driver_job(c_of1) j;
  insert into resultados values (23, 'Y su detalle trae las estrellas que puso',
    '5', coalesce(v_n::text, '(nulo)'), v_n = 5);

  perform set_config('role', v_admin, true);

  -- ------------------------------------------------------------------ el dato
  select r.rated_id = c_cond1 into v_ok
  from public.ratings r where r.ride_id = c_v1 and r.rater_id = c_ana;
  insert into resultados values (13, 'La calificacion de la pasajera apunta al conductor',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select r.rated_id = c_ana into v_ok
  from public.ratings r where r.ride_id = c_v1 and r.rater_id = c_cond1;
  insert into resultados values (14, 'Y la del conductor apunta a la pasajera',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  select r.comment into v_txt
  from public.ratings r where r.ride_id = c_v1 and r.rater_id = c_ana;
  insert into resultados values (15, 'El comentario se guarda sin espacios sobrantes',
    'Muy amable', coalesce(v_txt, '(nulo)'), v_txt = 'Muy amable');

  select r.comment is null into v_ok
  from public.ratings r where r.ride_id = c_v1 and r.rater_id = c_cond1;
  insert into resultados values (16, 'Sin comentario se guarda nulo, no cadena vacia',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  -- QUE CAMBIE NO ES LA COMPROBACION BUENA, y esta prueba lo aprendio fallando:
  -- este conductor ya tenia una calificacion real de 4, se le puso otra de 4 y el
  -- promedio se quedo igual. Lo que hay que exigir no es que se mueva, sino que
  -- coincida con lo que dicen las calificaciones. Eso vale siempre.
  select d.rating_average into v_desp from public.drivers d where d.id = c_cond1;
  select round(avg(c.stars), 2) into v_antes
  from public.ratings c where c.rated_id = c_cond1;
  insert into resultados values (17, 'El promedio del conductor coincide con sus calificaciones',
    coalesce(v_antes::text, 'nulo'), coalesce(v_desp::text, 'nulo'), v_desp = v_antes);

  -- El promedio del conductor 2 no se toca: nadie lo califico.
  select count(*) into v_n from public.ratings r where r.rated_id = c_cond2;
  insert into resultados values (18, 'Al conductor que no participo no le llega nada',
    '0', v_n::text, v_n = 0);

  -- ------------------------------------------------------------------ permisos
  select has_function_privilege('anon', 'public.rate_ride(uuid,smallint,text)', 'execute')
    into v_ok;
  insert into resultados values (19, 'Sin sesion no se puede calificar',
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
