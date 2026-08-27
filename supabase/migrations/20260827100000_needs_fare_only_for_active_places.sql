-- =============================================================================
-- CORRECCION: el aviso "le falta tarifa" solo vale para los lugares activos.
-- =============================================================================
--
-- QUE ESTABA MAL. `needs_fare` marcaba cualquier lugar fuera del radio sin
-- tarifa activa, **estuviera encendido o apagado**.
--
-- COMO SE VIO. Al desactivar "Vereda Guayabito" -6,3 km del centro, sin tarifa-
-- el contador de lugares sin tarifa **se quedo en 1**. La desactivacion era
-- correcta y el aviso seguia ahi.
--
-- POR QUE IMPORTA. Un lugar apagado **no sale en la lista del pasajero**, asi
-- que no puede rebotar con DESTINATION_NOT_PRICED: no hay nada que arreglar.
-- Marcarlo en rojo para siempre convierte el aviso en ruido, y un aviso que
-- siempre esta encendido es un aviso que nadie mira. El valor de `needs_fare`
-- es senalar **lo que hoy esta roto de cara al pasajero**, no todo lo que
-- teoricamente le falta un dato.
--
-- Si alguien reactiva ese lugar, el aviso vuelve solo. Esa es la prueba de que
-- la condicion esta en el sitio correcto: no se pierde informacion, se muestra
-- cuando significa algo.
-- =============================================================================

drop function if exists public.admin_list_places();

create or replace function public.admin_list_places()
returns table (
  place_id uuid,
  name text,
  description text,
  lng double precision,
  lat double precision,
  is_active boolean,
  sort_order smallint,
  distance_from_center_m integer,
  rural_amount integer,
  rural_is_active boolean,
  needs_fare boolean,
  usage_count integer
)
language sql
stable
security invoker
set search_path = public
as $$
  with centro as (
    select
      extensions.st_setsrid(
        extensions.st_makepoint(
          (select (value #>> '{}')::double precision from public.app_settings
           where key = 'fare_center_lng'),
          (select (value #>> '{}')::double precision from public.app_settings
           where key = 'fare_center_lat')
        ), 4326)::extensions.geography as punto,
      (select (value #>> '{}')::double precision from public.app_settings
       where key = 'unpriced_destination_max_km') as max_km
  )
  select
    p.id,
    p.name,
    p.description,
    extensions.st_x(p.location::extensions.geometry),
    extensions.st_y(p.location::extensions.geometry),
    p.is_active,
    p.sort_order,
    round(extensions.st_distance(p.location, c.punto))::integer,
    rf.amount,
    rf.is_active,
    -- LAS TRES CONDICIONES. La tercera es la que se anade: si el lugar esta
    -- apagado, el pasajero no lo ve y no hay nada roto.
    p.is_active
      and extensions.st_distance(p.location, c.punto) > c.max_km * 1000
      and coalesce(rf.is_active, false) = false,
    (select count(*)::integer from public.ride_requests rr
     where rr.origin_place_id = p.id or rr.destination_place_id = p.id)
  from public.places p
  cross join centro c
  left join public.rural_fares rf on rf.place_id = p.id
  order by p.sort_order, p.name;
$$;

comment on function public.admin_list_places() is
  'Lugares con su distancia al centro, su tarifa rural y si les falta una estando activos (D229).';

revoke all on function public.admin_list_places() from public;
grant execute on function public.admin_list_places() to authenticated;
