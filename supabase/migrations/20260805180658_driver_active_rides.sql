-- =============================================================================
-- Fase 12C: los viajes que el conductor lleva en curso
-- =============================================================================
--
-- Aqui si viajan el nombre y el telefono del pasajero, y es el primer sitio del
-- proyecto donde ocurre. La linea esta puesta a proposito: en la oferta el
-- conductor decide con el viaje, y quien es esa persona aparece cuando alguien
-- se compromete a llevarla.
--
-- La politica `profiles_select_ride_counterpart` ya lo permite a partir de ese
-- momento, porque `shares_ride_with` exige una fila en `rides`, y esa fila nace
-- al aceptar. Esta funcion no abre nada nuevo: pone en una sola llamada lo que
-- el conductor ya tenia derecho a leer.
--
-- DEVUELVE UNA LISTA Y NO UNA FILA, aunque hoy la regla R7 solo admita un viaje
-- activo por conductor. La decision D161 aprueba recoger pasajeros en ruta
-- cuando quede capacidad, asi que en cuanto se sustituyan los indices
-- `rides_one_active_per_driver` y `rides_one_active_per_vehicle` esta misma
-- funcion devolvera dos o tres filas sin tocar una linea.
-- =============================================================================

create or replace function public.list_driver_active_rides()
returns table (
  ride_id uuid,
  request_id uuid,
  status public.ride_status,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  passenger_name text,
  passenger_phone text,
  accepted_at timestamptz
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    v.id,
    r.id,
    v.status,
    v.passenger_count,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    p.full_name,
    -- El telefono sale de la solicitud y no del perfil a proposito: se congelo
    -- al pedir el servicio. Si el pasajero cambia de numero manana, el conductor
    -- que lo esta recogiendo hoy tiene que seguir viendo el que servia entonces.
    r.contact_phone,
    v.accepted_at
  from public.rides v
    join public.ride_requests r on r.id = v.request_id
    join public.profiles p on p.id = r.passenger_id
  where v.driver_id = (select auth.uid())
    and v.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  order by v.accepted_at;
$$;

comment on function public.list_driver_active_rides is
  'Viajes en curso del conductor que llama, con los datos del pasajero. Lista, no fila.';

revoke all on function public.list_driver_active_rides() from public, anon;
grant execute on function public.list_driver_active_rides() to authenticated;
