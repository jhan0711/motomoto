-- =============================================================================
-- Panel: mapa de la flota (pedido de la empresa, 2026-09-16)
-- =============================================================================
--
-- El panel pidio ver en un mapa donde esta cada conductor, no solo el de un
-- servicio en curso -eso ya lo cubre `get_driver_location` para el pasajero,
-- acotado a un conductor a la vez por D131/Fase 14-.
--
-- NO HACE FALTA NINGUNA POLITICA NUEVA. `driver_locations_select_admin` existe
-- desde la Fase 5 y ya deja a un administrador leer la tabla entera
-- (`rls_policies.sql`); esta funcion solo la envuelve para no mandar el binario
-- de PostGIS al navegador, mismo motivo que `get_driver_location`.
--
-- SECURITY INVOKER, por la misma razon que las demas funciones del panel: es
-- lo que hace que `driver_locations_select_admin` y las politicas de
-- `drivers`/`profiles` se apliquen de verdad. Con definer un pasajero que la
-- llamara -si algun dia se le concediera EXECUTE por error- veria la flota
-- entera; con invoker, la propia base de datos lo impide antes de que
-- `revoke`/`grant` de mas abajo tenga que ser la unica barrera.
--
-- SOLO CONDUCTORES CON POSICION CONOCIDA. Un conductor recien aprobado que
-- nunca encendio el interruptor no tiene fila en `driver_locations`
-- -`reportLocation` es lo unico que la crea-, y no hay nada que pintarle en el
-- mapa: se deja fuera con el join, en vez de forzar coordenadas 0,0 que
-- pondrian un marcador falso en el golfo de Guinea.
create or replace function public.admin_list_driver_locations()
returns table (
  driver_id uuid,
  full_name text,
  is_available boolean,
  has_active_ride boolean,
  unit_number integer,
  plate text,
  latitude double precision,
  longitude double precision,
  heading numeric,
  updated_at timestamptz,
  age_seconds integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    d.id,
    p.full_name,
    d.is_available,

    exists (
      select 1 from public.rides r
      where r.driver_id = d.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    v.unit_number,
    v.plate,

    dl.lat,
    dl.lng,
    dl.heading,
    dl.updated_at,
    greatest(0, floor(extract(epoch from (now() - dl.updated_at))))::integer

  from public.driver_locations dl
  join public.drivers d on d.id = dl.driver_id
  join public.profiles p on p.id = d.id

  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id

  order by p.full_name;
$$;

comment on function public.admin_list_driver_locations() is
  'Posicion de cada conductor con fila en driver_locations, para el mapa de la flota del panel.';

revoke all on function public.admin_list_driver_locations() from public, anon;
grant execute on function public.admin_list_driver_locations() to authenticated;
