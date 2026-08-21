-- =============================================================================
-- Fase 18, paso 1: que ve el pasajero cuando el conductor cancela a bordo
-- =============================================================================
--
-- D187 (Fase 15) dejo esto fuera a proposito: "el resumen solo cubre servicios
-- TERMINADOS... queda fuera el caso de que el conductor cancele con el pasajero
-- a bordo, que es de la Fase 18". Ese caso es el unico camino de `cancel_ride`
-- que deja `ride_requests.status = 'cancelled'` con `cancelled_by = 'driver'`:
-- ocurre solo cuando el viaje ya estaba en 'in_progress' al cancelar. Si el
-- conductor cancela ANTES de eso, la solicitud vuelve a 'searching' y se
-- reofrece (mismo `cancel_ride`, rama contraria), y ese caso no necesita una
-- pantalla nueva: el pasajero ya ve "buscando conductor" como lo veria si
-- nadie hubiera aceptado todavia.
--
-- MISMO PATRON QUE `get_finished_request` (Fase 15/17). Se pregunta solo cuando
-- no hay servicio activo, y solo importa si fue hace poco: reusa el parametro
-- `finished_summary_minutes` porque es la misma pregunta ("cuanto es hace
-- poco") aplicada a un desenlace distinto, y tener dos parametros para lo mismo
-- invitaria a que se desincronizaran.
--
-- NO SE OFRECE CALIFICAR AQUI. Calificar es del viaje que se completo (R8 exige
-- un viaje, y `rate_ride` comprueba `status = 'completed'`); un viaje cancelado
-- no admite calificacion y no tiene sentido ofrecerla.
-- =============================================================================

create function public.get_driver_cancelled_notice()
returns table (
  id uuid,
  origin_label text,
  destination_label text,
  cancelled_at timestamptz,
  driver_name text
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
    r.cancelled_at,
    p.full_name
  from public.ride_requests r
    -- LATERAL con LIMIT 1, mismo criterio que get_active_request: el modelo
    -- admite varios viajes por solicitud a futuro, y un join a secas
    -- duplicaria la fila en lugar de fallar.
    left join lateral (
      select d.driver_id
      from public.rides d
      where d.request_id = r.id
      order by d.accepted_at desc
      limit 1
    ) v on true
    left join public.profiles p on p.id = v.driver_id
  where r.passenger_id = (select auth.uid())
    and r.status = 'cancelled'
    and r.cancelled_by = 'driver'
    and r.cancelled_at > now() - make_interval(
      mins => (public.get_setting('finished_summary_minutes', '5'))::integer
    )
  order by r.cancelled_at desc
  limit 1;
$$;

comment on function public.get_driver_cancelled_notice is
  'La ultima solicitud que el conductor cancelo con el pasajero a bordo, si fue hace poco. Cero o una fila.';

revoke all on function public.get_driver_cancelled_notice() from public, anon;
grant execute on function public.get_driver_cancelled_notice() to authenticated;
