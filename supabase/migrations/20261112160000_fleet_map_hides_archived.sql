-- =============================================================================
-- D308. El mapa de la flota no muestra conductores archivados
-- =============================================================================
--
-- Pedido de Jhan (2026-11-12): cuando se archiva o se elimina un conductor, que
-- tampoco aparezca en el mapa de la flota.
--
-- Eliminar ya lo cumple solo: `driver_locations.driver_id` es ON DELETE CASCADE,
-- asi que al borrar al conductor desaparece su posicion. Archivar NO: la fila de
-- ubicacion se queda, y el mapa seguia pintando al conductor en su ultima
-- posicion conocida. Se filtra aqui, en la unica funcion que alimenta el mapa
-- (`admin_list_driver_locations`; el mapa no usa tiempo real).
--
-- No cambia la forma de lo que devuelve la funcion.
-- =============================================================================

create or replace function public.admin_list_driver_locations()
 returns table(
   driver_id uuid, full_name text, is_available boolean, has_active_ride boolean,
   unit_number integer, plate text, latitude double precision, longitude double precision,
   heading numeric, updated_at timestamptz, age_seconds integer
 )
 language sql
 stable
 set search_path to 'public'
as $function$
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

  -- D308: un conductor archivado no se pinta en el mapa.
  where d.archived_at is null

  order by p.full_name;
$function$;
