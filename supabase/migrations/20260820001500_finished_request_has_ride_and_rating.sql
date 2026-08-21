-- =============================================================================
-- Fase 17, paso 2: la despedida ya sabe que viaje fue y si esta calificado
-- =============================================================================
--
-- `get_finished_request` devolvia el resumen del ultimo servicio terminado pero
-- no el identificador del VIAJE, solo el de la solicitud. Para calificar hace
-- falta el del viaje: `rate_ride` recibe `p_ride_id`, y con razon, porque quien
-- se califica es la persona con la que se compartio el vehiculo.
--
-- Y ADEMAS SI YA ESTA CALIFICADO. Sin ese dato la pantalla tendria dos malas
-- opciones: ofrecer calificar otra vez —y que el servidor conteste "ya
-- calificaste este servicio", que es un error donde no hubo ningun error— o
-- preguntarlo en una segunda consulta, que es un viaje de ida y vuelta mas para
-- pintar una tarjeta que ya estaba lista.
--
-- SE MIRA SOLO LA CALIFICACION DE QUIEN LLAMA. Que el conductor haya calificado
-- al pasajero no cambia nada de lo que el pasajero ve, y al reves tampoco: son
-- dos filas independientes (R8 permite una por parte).
--
-- Hay que borrarla antes de recrearla: `create or replace` no admite cambiar las
-- columnas que devuelve una funcion.
-- =============================================================================

drop function if exists public.get_finished_request();

create or replace function public.get_finished_request()
returns table (
  id uuid,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  completed_at timestamptz,
  distance_m integer,
  duration_s integer,
  driver_name text,
  vehicle_unit_number integer,

  -- Lo nuevo de la Fase 17.
  ride_id uuid,
  already_rated boolean
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
    veh.unit_number,
    v.ride_id,
    -- `exists` y no un join: aqui solo interesa si hay o no hay, y un join
    -- obligaria a pensar en duplicados que no pueden existir.
    exists (
      select 1 from public.ratings c
      where c.ride_id = v.ride_id and c.rater_id = (select auth.uid())
    )
  from public.ride_requests r
    left join lateral (
      select d.id as ride_id, d.distance_m, d.duration_s, d.driver_id, d.vehicle_id
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
  'El ultimo servicio terminado del pasajero, si fue hace poco, con su viaje y si ya lo califico. Cero o una fila.';

revoke all on function public.get_finished_request() from public, anon;
grant execute on function public.get_finished_request() to authenticated;
