-- =============================================================================
-- Correccion: cancel_request no podia ejecutarse
-- =============================================================================
--
-- Error encontrado en la Fase 11 y nacido en la Fase 5. La primera llamada real
-- a cancel_request fallaba siempre con:
--
--   42804: column "cancelled_by" is of type actor_type but expression is of
--          type text
--
-- Causa. Un literal suelto como cancelled_by = 'driver' se resuelve al tipo de
-- la columna sin problema, y por eso cancel_ride, que lo hace asi, siempre
-- funciono. Pero dentro de un CASE la cosa cambia: PostgreSQL resuelve primero
-- el tipo del CASE, y con dos literales sin tipo el resultado es text. De text a
-- un tipo enumerado no hay conversion implicita, asi que la asignacion se
-- rechaza. Ocurria en las dos ramas, la de rides y la de ride_requests.
--
-- Esto no dependia de que hubiera filas que actualizar: PL/pgSQL prepara la
-- sentencia al ejecutarla por primera vez, y ahi ya salta. Es decir, cancelar
-- una solicitud NUNCA funciono desde que se escribio la funcion.
--
-- Por que no se detecto en la Fase 5. Aquellas 57 comprobaciones se centraron en
-- restricciones y politicas, es decir, en lo que la base de datos debe RECHAZAR.
-- El camino feliz de cada funcion no se recorrio, entre otras cosas porque sin
-- conductores sembrados no habia forma de llegar a tener una solicitud viva que
-- cancelar. Lo destapo la primera prueba de extremo a extremo, ya con el
-- conductor de prueba en su sitio.
--
-- La correccion es una conversion explicita y nada mas. El resto de la funcion
-- se reproduce igual que en la migracion 20260729013123.
-- =============================================================================

create or replace function public.cancel_request(p_request_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_request public.ride_requests;
  -- Se resuelve una sola vez y con su tipo puesto. Ademas de arreglar el error,
  -- evita llamar a is_admin() dos veces para responder lo mismo.
  v_actor public.actor_type;
begin
  select * into v_request from public.ride_requests where id = p_request_id for update;

  if not found or (v_request.passenger_id <> v_uid and not public.is_admin()) then
    raise exception 'Esa solicitud no es tuya' using errcode = 'P0001', hint = 'REQUEST_NOT_FOUND';
  end if;

  if v_request.status not in ('searching', 'assigned') then
    raise exception 'Un servicio en curso no se puede cancelar desde aqui'
      using errcode = 'P0001', hint = 'INVALID_STATE_TRANSITION';
  end if;

  v_actor := (case when public.is_admin() then 'admin' else 'passenger' end)::public.actor_type;

  update public.rides
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = v_actor,
      cancellation_reason = p_reason
  where request_id = p_request_id
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived');

  update public.drivers
  set is_available = true
  where id in (select driver_id from public.rides where request_id = p_request_id);

  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = p_request_id and response = 'pending';

  update public.ride_requests
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = v_actor,
      cancellation_reason = p_reason
  where id = p_request_id;
end;
$$;

comment on function public.cancel_request is
  'Cancelacion por parte del pasajero o del administrador. Unica via.';
