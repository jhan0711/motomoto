-- =============================================================================
-- Fase 15, paso 3: la distancia del viaje cuenta solo el viaje
-- =============================================================================
--
-- EL RECORRIDO HISTORICO YA TIENE QUIEN LO ESCRIBA. Hasta este paso nadie
-- insertaba en `ride_locations`, asi que `complete_ride` no tenia puntos que
-- medir y `distance_m` se quedaba siempre en nulo. Ahora el conductor lo
-- alimenta durante el recorrido, un punto cada 50 metros (regla R9). Esta
-- migracion no crea eso, que es del cliente; corrige una cuenta que se vuelve
-- importante en cuanto hay puntos de verdad.
--
-- EL FALLO SUTIL. La politica `ride_locations_insert_own_driver`, de la Fase 5,
-- deja al conductor insertar puntos mientras el viaje esta en
-- 'driver_on_the_way', 'driver_arrived' o 'in_progress'. Es decir, tambien
-- MIENTRAS VA HACIA LA RECOGIDA. Y `complete_ride` medi­a la longitud de TODOS
-- los puntos del viaje sin mirar cuando se registraron.
--
-- El cliente que se escribe en este paso solo graba durante 'in_progress', asi
-- que en el uso normal no hay puntos de aproximacion y la cuenta ya sale bien.
-- Pero la politica permite insertarlos por la API, y si alguien lo hiciera la
-- distancia del viaje incluiria el trayecto hasta el pasajero: un numero inflado
-- que no corresponde a lo que el pasajero recorrio. No mueve dinero, porque la
-- plataforma no cobra (D8), pero es un dato que se ensena y que quedaria mal.
--
-- LA CORRECCION: contar solo los puntos registrados desde que arranco el
-- recorrido. `started_at` se fija en `start_ride`, asi que cualquier punto
-- anterior es de la aproximacion y queda fuera. Con esto la distancia es la del
-- viaje aunque existan puntos de antes, venga de donde venga el que los metio.
--
-- Se reescribe entera desde la ULTIMA version, la de
-- 20260812083511 (el arreglo de la disponibilidad). Comprobado con:
--   grep -l "function public.complete_ride" supabase/migrations/*.sql
-- descartando 20260812084420, que solo toca permisos.
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

  -- Solo los puntos del recorrido, no los de la aproximacion. Hacen falta al
  -- menos dos; si el conductor no tuvo cobertura durante el viaje, se deja sin
  -- calcular en lugar de guardar un cero enganoso.
  select count(*) into v_points
  from public.ride_locations
  where ride_id = p_ride_id
    and recorded_at >= v_ride.started_at;

  if v_points >= 2 then
    select round(extensions.st_length(
             extensions.st_makeline(array_agg(location::extensions.geometry order by recorded_at))::extensions.geography
           ))::integer
    into v_distance
    from public.ride_locations
    where ride_id = p_ride_id
      and recorded_at >= v_ride.started_at;
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

  -- Terminar libera asientos pero no decide por el conductor si sigue
  -- trabajando: la disponibilidad no se toca (ver 20260812083511).
end;
$$;

comment on function public.complete_ride is
  'Cierra el viaje y calcula su distancia solo con los puntos del recorrido. NO toca la disponibilidad.';
