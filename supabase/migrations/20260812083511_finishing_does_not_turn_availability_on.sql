-- =============================================================================
-- Fase 15, paso 1: terminar un servicio deja de encender la disponibilidad
-- =============================================================================
--
-- EL FALLO. `complete_ride` y `cancel_ride` terminaban las dos con la misma
-- linea:
--
--     update public.drivers set is_available = true where id = v_ride.driver_id;
--
-- Escrita en la Fase 5 con el comentario "el conductor vuelve a estar libre", y
-- entonces era razonable: bajo la regla R7 un conductor con un viaje estaba
-- ocupado por definicion, aceptar lo apagaba, y terminar lo devolvia a como
-- estaba. La linea restauraba un estado que el propio sistema habia cambiado.
--
-- **D161 y D164 dejaron esa linea obsoleta, y nadie volvio a mirarla.** Hoy hace
-- dos cosas mal:
--
-- 1. **Contradice a D164 de frente.** Esa decision dice que aceptar "puede
--    apagar la disponibilidad, nunca encenderla", con el motivo escrito: quien
--    apago el interruptor a mano no debe reaparecer disponible sin pedirlo.
--    `accept_ride_offer` lo cumple desde entonces con
--    `is_available = (is_available and v_free > 0)`. Terminar el viaje se lo
--    saltaba y lo encendia sin preguntar. Un conductor que apago el interruptor
--    porque se iba a comer, y que termina su ultimo servicio, volvia a recibir
--    solicitudes sin tocar nada.
-- 2. **Se lleva mal con D161.** Un conductor puede llevar dos o tres servicios a
--    la vez. Terminar UNO lo marcaba disponible aunque el motorraton siguiera
--    lleno con los otros. El disparador de capacidad rechazaria la aceptacion,
--    asi que no se rompe nada, pero se le ofrecen viajes que no puede tomar.
--
-- LA CORRECCION ES QUITAR LA LINEA, no sustituirla por un calculo. Y conviene
-- explicar por que no se recalcula, que fue lo primero que se penso.
--
-- Para encender la disponibilidad con criterio haria falta saber **quien la
-- apago**: si fue el conductor a mano, encenderla es justo lo que D164 prohibe;
-- si fue el sistema por falta de asientos, encenderla seria un favor. Ese dato no
-- existe hoy y anadirlo es una columna nueva en `drivers`.
--
-- Y no hace falta, porque las consecuencias de equivocarse no son simetricas:
--
--   - Encender al que no queria: recibe solicitudes cuando habia decidido parar,
--     sin enterarse de por que. Invisible y contra una decision aprobada.
--   - Dejar apagado al que si queria: ve "No disponible" en la tarjeta mas grande
--     de su pantalla y lo enciende con un toque.
--
-- El segundo error es barato y visible; el primero no. Asi que terminar y
-- cancelar dejan la disponibilidad como estaba, y encenderla vuelve a ser
-- siempre una decision del conductor.
--
-- `cancel_ride` se corrige aqui aunque las cancelaciones sean de la Fase 18: es
-- la misma linea, el mismo motivo y la misma frase de codigo. Arreglar una y
-- dejar la otra seria dejar el fallo puesto a sabiendas.
--
-- Las dos funciones se reescriben enteras a partir de su ULTIMA version, que es
-- la de la Fase 5 en los dos casos. Comprobado con:
--
--   grep -l "function public.complete_ride" supabase/migrations/*.sql
--   grep -l "function public.cancel_ride" supabase/migrations/*.sql
--
-- que es la leccion que dejo E30.
-- =============================================================================

create or replace function public.complete_ride(p_ride_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ride public.rides;
  v_distance integer;
  v_points integer;
begin
  v_ride := public.assert_ride_driver(p_ride_id, array['in_progress']::public.ride_status[]);

  -- Longitud del recorrido a partir de los puntos registrados. Hacen falta al
  -- menos dos; si el conductor no tuvo cobertura, se deja sin calcular en lugar
  -- de guardar un cero enganoso.
  select count(*) into v_points from public.ride_locations where ride_id = p_ride_id;

  if v_points >= 2 then
    select round(extensions.st_length(
             extensions.st_makeline(array_agg(location::extensions.geometry order by recorded_at))::extensions.geography
           ))::integer
    into v_distance
    from public.ride_locations where ride_id = p_ride_id;
  end if;

  update public.rides
  set status = 'completed',
      completed_at = now(),
      distance_m = v_distance,
      duration_s = extract(epoch from (now() - started_at))::integer
  where id = p_ride_id;

  update public.ride_requests
  set status = 'completed', completed_at = now()
  where id = v_ride.request_id;

  -- Aqui estaba el `set is_available = true`. Ver la cabecera: terminar libera
  -- asientos, pero no decide por el conductor si quiere seguir trabajando.
end;
$$;


create or replace function public.cancel_ride(p_ride_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ride public.rides;
  v_expiry integer;
begin
  v_ride := public.assert_ride_driver(
    p_ride_id,
    array['assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress']::public.ride_status[]
  );

  update public.rides
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = 'driver',
      cancellation_reason = p_reason
  where id = p_ride_id;

  -- Aqui estaba la misma linea, por el mismo motivo y con el mismo problema.

  -- Si el recorrido no habia empezado, el pasajero merece otra oportunidad.
  if v_ride.status in ('assigned', 'driver_on_the_way', 'driver_arrived') then
    v_expiry := (public.get_setting('request_expiry_seconds', '300'))::integer;

    update public.ride_requests
    set status = 'searching',
        assigned_at = null,
        expires_at = now() + make_interval(secs => v_expiry)
    where id = v_ride.request_id;

    perform public.offer_request_to_drivers(v_ride.request_id);
  else
    update public.ride_requests
    set status = 'cancelled',
        cancelled_at = now(),
        cancelled_by = 'driver',
        cancellation_reason = p_reason
    where id = v_ride.request_id;
  end if;
end;
$$;

comment on function public.complete_ride is
  'Cierra el viaje y calcula su distancia. NO toca la disponibilidad del conductor.';
comment on function public.cancel_ride is
  'Cancela el viaje del conductor y reofrece la solicitud si no habia empezado.';
