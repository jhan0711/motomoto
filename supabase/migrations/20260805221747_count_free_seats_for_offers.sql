-- =============================================================================
-- D161, paso 2: el buscador de conductores cuenta asientos, no motorratones
-- =============================================================================
--
-- Hasta ahora la pregunta era "¿cabe este grupo en el motorraton?" y se
-- respondia con `v.max_passengers >= p_passenger_count`. Con R7 viva esa
-- pregunta bastaba, porque un conductor disponible era por fuerza un conductor
-- vacio: no podia tener ningun viaje en curso.
--
-- El paso 1 rompio esa equivalencia. Un conductor puede ir por la calle con dos
-- personas dentro, y entonces la capacidad del vehiculo ya no dice nada util. Lo
-- que hay que preguntar es cuantos asientos le quedan LIBRES.
--
-- QUIEN MANDA DE VERDAD. Esta funcion decide a quien se le ofrece; el disparador
-- del paso 1 decide quien entra. No son lo mismo y no tienen por que coincidir:
-- entre que la oferta sale y el conductor la toca pueden pasar veinte segundos,
-- y en ese rato puede haber recogido a alguien. Si eso ocurre, el disparador lo
-- rechaza y hace bien. Una oferta es una invitacion, no una plaza reservada.
--
-- La resta se apoya en `rides_active_by_vehicle_idx`, creado en el paso 1.
--
-- QUE NO CAMBIA TODAVIA. `accept_ride_offer` sigue apagando la disponibilidad al
-- aceptar, y el filtro `d.is_available` de aqui abajo sigue dejando fuera a
-- quien lleva un servicio. Asi que hoy la resta siempre da la capacidad entera y
-- el comportamiento es identico al de ayer. Esta funcion queda lista para el
-- paso 3, que es el que enciende la funcion de verdad.
-- =============================================================================

create or replace function public.find_available_drivers(
  p_origin extensions.geography,
  p_passenger_count smallint,
  p_max_staleness interval default null
)
returns table (
  driver_id uuid,
  full_name text,
  unit_number integer,
  plate text,
  max_passengers smallint,
  rating_average numeric,
  distance_m double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    d.id,
    p.full_name,
    v.unit_number,
    v.plate,
    v.max_passengers,
    d.rating_average,
    extensions.st_distance(dl.location, p_origin) as distance_m
  from public.drivers d
    join public.profiles p on p.id = d.id
    join public.driver_locations dl on dl.driver_id = d.id
    join public.driver_vehicle_assignments a
      on a.driver_id = d.id and a.unassigned_at is null
    join public.vehicles v on v.id = a.vehicle_id
  where d.is_available
    and d.approval_status = 'approved'
    and p.status = 'active'
    and v.status = 'active'
    -- Asientos libres, no capacidad total. Un motorraton de tres que ya lleva
    -- dos personas solo sirve para una solicitud de una.
    and v.max_passengers - coalesce((
          select sum(r.passenger_count)
          from public.rides r
          where r.vehicle_id = v.id
            and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
        ), 0) >= p_passenger_count
    and dl.updated_at > now() - coalesce(
          p_max_staleness,
          make_interval(secs => (public.get_setting('driver_location_stale_seconds', '120'))::integer)
        )
  -- Se conserva el orden por cercania aunque con D160 ya no decida quien gana.
  -- Sigue sirviendo para dos cosas: la distancia que se guarda en cada oferta, y
  -- el dia que la empresa quiera volver a un reparto por tandas.
  order by dl.location <-> p_origin;
$$;

comment on function public.find_available_drivers is
  'Conductores con asientos libres suficientes. La antiguedad maxima de la ubicacion sale de app_settings.';

revoke all on function public.find_available_drivers(extensions.geography, smallint, interval)
  from public, anon, authenticated;
