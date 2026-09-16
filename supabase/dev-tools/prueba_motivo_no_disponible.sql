-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de D270 (motivo al desconectarse): `set_driver_unavailable`,
-- `clear_unavailable_reason_on_available` y las restricciones del catalogo.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_motivo_no_disponible.sql
--
-- TODO OCURRE DENTRO DE UNA TRANSACCION QUE SE DESHACE (mismo criterio que
-- `prueba_historial.sql`). Usa las cuentas de prueba que ya existen.
--
-- LO MAS IMPORTANTE QUE CUBRE, y la razon por la que este archivo existe: que
-- `accept_ride_offer` **sigue apagando la disponibilidad sin pedir motivo**
-- cuando llena el motorraton (D161). Es justo el caso que un disparador
-- generico habria roto -ver la cabecera de la migracion `20260916004026`- y
-- que la funcion nueva evita a proposito: `set_driver_unavailable` es la unica
-- que exige el motivo, y un UPDATE directo a la tabla -como el que hace
-- `accept_ride_offer`- no pasa por ella. La prueba 6 lo demuestra con un viaje
-- de verdad, no con una suposicion.
--
-- Lo mismo vale para `admin_assign_driver` y las dos funciones de bloqueo de
-- cuenta: las tres apagan `is_available` con un UPDATE directo, igual que
-- `accept_ride_offer`, y por eso no hace falta repetir la prueba con cada una
-- por separado -el mecanismo que la 6 comprueba es el mismo para las cuatro.
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


do $pruebas$
declare
  -- Andres Zapata, con el motorraton 98 (capacidad 3) vigente de verdad hoy.
  -- Luis Fernando (d0...0001) no sirve para la prueba 6: se le desasigno el
  -- motorraton el 2026-09-11 y accept_ride_offer exige uno para aceptar.
  c_cond   constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_veh    constant uuid := 'e0000000-0000-4000-8000-000000000002';
  c_ana    constant uuid := 'ad000000-0000-4000-8000-0000000000f1';

  v_origen      extensions.geography;
  v_origen_lbl  text;
  v_destino     extensions.geography;
  v_destino_lbl text;

  v_req   uuid;
  v_offer uuid;
  v_admin constant text := current_user;

  v_txt text;
  v_ok  boolean;
begin
  select p.location, p.name into v_origen, v_origen_lbl
  from public.places p where p.name ilike '%parque%' order by p.sort_order limit 1;
  select p.location, p.name into v_destino, v_destino_lbl
  from public.places p where p.name ilike '%hospital%' order by p.sort_order limit 1;

  -- Estado limpio de partida, por si una corrida anterior dejo algo (no
  -- deberia, todo esta en una transaccion que se deshace, pero cuesta poco).
  update public.drivers set is_available = true where id = c_cond;

  -- --------------------------------------------------------- como el conductor
  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- 1. Sin motivo, se rechaza.
  begin
    perform public.set_driver_unavailable(null);
    insert into resultados values (1, 'Sin motivo se rechaza', 'excepcion', 'no hubo excepcion', false);
  exception when others then
    get stacked diagnostics v_txt = pg_exception_hint;
    insert into resultados values (1, 'Sin motivo se rechaza',
      'UNAVAILABLE_REASON_REQUIRED',
      coalesce(nullif(trim(v_txt), ''), '(sin hint)'),
      trim(v_txt) = 'UNAVAILABLE_REASON_REQUIRED');
  end;

  -- 2. Con motivo del catalogo, se apaga y queda escrito.
  perform public.set_driver_unavailable('almuerzo');

  select not d.is_available and d.unavailable_reason_code = 'almuerzo' and d.unavailable_reason is null
  into v_ok from public.drivers d where d.id = c_cond;
  insert into resultados values (2, 'Con motivo valido se apaga y queda registrado',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  -- 3. Reactivarse limpia el motivo, sea quien sea quien lo active. Aqui lo
  -- activa el propio conductor con un UPDATE directo, como ya hace D83.
  update public.drivers set is_available = true where id = c_cond;

  select is_available and unavailable_reason_code is null and unavailable_reason is null
  into v_ok from public.drivers where id = c_cond;
  insert into resultados values (3, 'Reactivarse limpia el motivo',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  -- 4. "Otro" admite detalle.
  perform public.set_driver_unavailable('otro', 'Se pinchó la llanta');

  select unavailable_reason_code = 'otro' and unavailable_reason = 'Se pinchó la llanta'
  into v_ok from public.drivers where id = c_cond;
  insert into resultados values (4, '"Otro" guarda el detalle',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  update public.drivers set is_available = true where id = c_cond;

  perform set_config('role', v_admin, true);

  -- 5. ATAQUE: un detalle junto a un motivo que no es "otro" viola la
  -- restriccion, aunque se escriba con un UPDATE directo (no por la funcion).
  begin
    update public.drivers
    set is_available = false, unavailable_reason_code = 'almuerzo', unavailable_reason = 'texto'
    where id = c_cond;
    insert into resultados values (5, 'Detalle sin "otro" lo rechaza la restriccion',
      'excepcion', 'no hubo excepcion', false);
  exception when check_violation then
    insert into resultados values (5, 'Detalle sin "otro" lo rechaza la restriccion',
      'true', 'true', true);
  end;
  update public.drivers set is_available = true, unavailable_reason_code = null where id = c_cond;

  -- ------------------------------------------------------------ el caso real
  -- 6. accept_ride_offer sigue apagando SIN motivo cuando llena el motorraton
  -- (D161), aunque exista set_driver_unavailable. Si esto fallara, aceptar
  -- viajes se habria roto para cualquier conductor cuyo ultimo asiento cierre
  -- el cupo -exactamente el escenario que la cabecera de la migracion explica.
  if v_origen is null or v_destino is null then
    raise exception 'Faltan lugares en places para la prueba 6';
  end if;

  v_req := gen_random_uuid();
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at
  ) values (
    v_req, c_ana, 'searching', 3,
    v_origen, v_origen_lbl, v_destino, v_destino_lbl,
    '3001234567', now(), now() + interval '5 minutes'
  );

  v_offer := gen_random_uuid();
  insert into public.ride_offers (id, request_id, driver_id, offered_at, expires_at, response, distance_m)
  values (v_offer, v_req, c_cond, now(), now() + interval '1 minute', 'pending', 100);

  perform set_config('request.jwt.claims',
    json_build_object('sub', c_cond, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  perform public.accept_ride_offer(v_offer);

  perform set_config('role', v_admin, true);

  select not is_available and unavailable_reason_code is null
  into v_ok from public.drivers where id = c_cond;
  insert into resultados values (6, 'accept_ride_offer apaga sin exigir motivo (D161)',
    'true', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));

  -- 7. El panel ve el motivo. La fila de la prueba 6 quedo apagada pero sin
  -- motivo (la apago accept_ride_offer, no el conductor); se le pone uno a
  -- mano para comprobar que admin_list_drivers lo trae de vuelta.
  update public.drivers set unavailable_reason_code = 'descanso' where id = c_cond;

  select (unavailable_reason_code::text = 'descanso') into v_ok
  from public.admin_list_drivers() where driver_id = c_cond;
  insert into resultados values (7, 'admin_list_drivers trae el motivo',
    'descanso', coalesce(v_ok::text, '(sin fila)'), coalesce(v_ok, false));
end
$pruebas$;


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
