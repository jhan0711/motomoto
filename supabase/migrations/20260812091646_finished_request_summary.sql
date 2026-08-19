-- =============================================================================
-- Fase 15, paso 2: el pasajero se entera de que el viaje termino
-- =============================================================================
--
-- EL HUECO QUE CIERRA. `get_active_request` devuelve solo lo que sigue vivo:
-- 'searching', 'assigned' o 'in_progress'. En cuanto el conductor finaliza, la
-- solicitud pasa a 'completed' y **desaparece de golpe**. La pantalla del
-- pasajero se quedaba entonces con lo ultimo que sabia, que era "tu motorraton
-- va en camino", y debajo los botones de "Volver a pedirlo" y "Cambiar el
-- viaje", porque su cuenta atras habia llegado a cero. Es decir: acababa de
-- bajarse del motorraton y la aplicacion le ofrecia volver a pedirlo como si
-- nadie lo hubiera recogido.
--
-- Esta funcion es lo que permite despedirse. Devuelve el ultimo servicio
-- TERMINADO del pasajero, con lo que se puede contar de el.
--
-- SOLO 'completed', Y NO TAMBIEN 'cancelled'. Dos motivos:
--
--   - Cuando cancela el pasajero, ya lo sabe: acaba de tocar el boton. Ensenarle
--     un resumen de lo que el mismo acaba de deshacer seria ruido.
--   - Cuando cancela el conductor antes de empezar, la solicitud vuelve a
--     'searching' y se reofrece, asi que sigue viva y no pasa por aqui.
--
-- Queda el caso de que el conductor cancele con el pasajero ya a bordo. Ahi si
-- haria falta contarselo, y ahi no llega esta funcion. **Es de la Fase 18**, que
-- es la que decide que ve el pasajero ante cada tipo de cancelacion, y meterlo
-- aqui seria adelantar una decision que no toca.
--
-- LA VENTANA DE TIEMPO ES UN PARAMETRO, no una constante. Existe para que el
-- resumen no reaparezca al abrir la aplicacion al dia siguiente. Se lee con
-- `get_setting`, que devuelve el valor por defecto si la fila no existe: asi no
-- hace falta crear la fila hoy y la empresa puede ajustarlo desde el panel el dia
-- que quiera, sin migracion.
--
-- SECURITY INVOKER, como sus hermanas. Es lo que hace que las politicas se
-- apliquen: `ride_requests_select_own` y las de la contraparte del viaje.
-- =============================================================================

create or replace function public.get_finished_request()
returns table (
  id uuid,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  completed_at timestamptz,

  -- Del viaje concreto. Los dos pueden venir nulos y no es un fallo:
  -- `complete_ride` deja la distancia sin calcular cuando el conductor no tuvo
  -- cobertura suficiente para registrar el recorrido, y prefiere no dar un dato
  -- antes que dar uno inventado.
  distance_m integer,
  duration_s integer,

  driver_name text,
  vehicle_unit_number integer
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    r.completed_at,
    v.distance_m,
    v.duration_s,
    p.full_name,
    veh.unit_number
  from public.ride_requests r
    left join lateral (
      select d.distance_m, d.duration_s, d.driver_id, d.vehicle_id
      from public.rides d
      where d.request_id = r.id and d.status = 'completed'
      order by d.completed_at desc
      limit 1
    ) v on true
    left join public.profiles p on p.id = v.driver_id
    left join public.vehicles veh on veh.id = v.vehicle_id
  where r.passenger_id = (select auth.uid())
    and r.status = 'completed'
    and r.completed_at > now() - make_interval(
      mins => (public.get_setting('finished_summary_minutes', '30'))::integer
    )
  order by r.completed_at desc
  limit 1;
$$;

comment on function public.get_finished_request is
  'El ultimo servicio terminado del pasajero, si fue hace poco. Cero o una fila.';

revoke all on function public.get_finished_request() from public, anon;
grant execute on function public.get_finished_request() to authenticated;
