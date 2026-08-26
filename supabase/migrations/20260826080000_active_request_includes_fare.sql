-- =============================================================================
-- Bloque especial, paso 6: la solicitud viva dice tambien que es y cuanto vale
-- =============================================================================
--
-- Cierra el hueco que dejaba D152 con este bloque: un pasajero que cierra la
-- aplicacion a medio servicio y la reabre reconstruye la pantalla desde
-- `get_active_request`, no desde el borrador (D137, el borrador vive solo en
-- memoria). Sin este paso, alguien que pidio una encomienda y volvio a abrir la
-- aplicacion veria "buscando motorratón" sin saber que penso que era una
-- encomienda, cual era la descripcion, ni cuanto iba a pagar.
--
-- Se vuelve a escribir entera porque `create or replace` no admite cambiar las
-- columnas que devuelve una funcion. Esta version parte de
-- `20260811210019_active_request_includes_driver_id.sql`, que es la ULTIMA
-- aplicada: comprobado con
--
--   grep -l "function public.get_active_request" supabase/migrations/*.sql
--
-- que es la leccion que dejo el error E30.
--
-- LO QUE NO TRAE, A PROPOSITO. El desglose de la carga linea por linea
-- (`ride_request_cargo`) no viaja aqui: esta funcion devuelve como mucho una
-- fila, y una solicitud puede llevar varias cargas. La pantalla que necesite el
-- detalle completo puede leer `ride_request_cargo` directamente, que ya tiene su
-- politica `ride_request_cargo_select_participants` desde el paso 2 y no hace
-- falta ninguna funcion nueva para eso.
-- =============================================================================

drop function if exists public.get_active_request();

create function public.get_active_request()
returns table (
  id uuid,
  status public.ride_request_status,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  pickup_reference text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  requested_at timestamptz,
  expires_at timestamptz,
  seconds_remaining integer,

  -- Nuevas. Nulas en las solicitudes anteriores a D217, igual que en la tabla.
  service_type public.service_type,
  parcel_description text,
  fare_amount integer,
  fare_trip_amount integer,
  fare_cargo_amount integer,
  fare_is_night boolean,
  fare_is_rural boolean,
  fare_reference text,

  -- Todo lo que sigue va en nulo mientras la solicitud sigue en 'searching'.
  -- No hay conductor porque todavia no ha aceptado nadie, y esa es justo la
  -- diferencia que la pantalla necesita distinguir.
  ride_id uuid,
  ride_status public.ride_status,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  vehicle_unit_number integer,
  vehicle_plate text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.status,
    r.passenger_count,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    r.pickup_reference,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    r.requested_at,
    r.expires_at,
    -- Los segundos que quedan se calculan aqui y no en el telefono a proposito.
    -- El cliente restaria expires_at menos su propio reloj, y el reloj de un
    -- telefono puede ir desviado minutos. La cuenta atras arranca de este numero
    -- y a partir de ahi corre sola en la pantalla, que para eso si sirve.
    case
      when r.status = 'searching'
      then greatest(0, ceil(extract(epoch from (r.expires_at - now()))))::integer
    end,

    r.service_type,
    r.parcel_description,
    r.fare_amount,
    r.fare_trip_amount,
    r.fare_cargo_amount,
    r.fare_is_night,
    r.fare_is_rural,
    r.fare_reference,

    v.ride_id,
    v.ride_status,
    v.driver_id,
    v.driver_name,
    v.driver_phone,
    v.driver_rating,
    v.unit_number,
    v.plate
  from public.ride_requests r
    -- LATERAL con LIMIT 1 y no un join a secas. Hoy una solicitud produce un
    -- solo viaje (D5), pero el modelo admite repartir un grupo entre varios
    -- motorratones, y el dia que eso llegue un join normal duplicaria la
    -- solicitud en lugar de fallar. Asi el contrato de "cero o una fila" se
    -- sostiene solo.
    left join lateral (
      select
        d.id as ride_id,
        d.status as ride_status,
        d.driver_id,
        p.full_name as driver_name,
        p.phone as driver_phone,
        dr.rating_average as driver_rating,
        veh.unit_number,
        veh.plate
      from public.rides d
        join public.drivers dr on dr.id = d.driver_id
        join public.profiles p on p.id = d.driver_id
        join public.vehicles veh on veh.id = d.vehicle_id
      where d.request_id = r.id
        and d.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      order by d.accepted_at desc
      limit 1
    ) v on true
  where r.passenger_id = (select auth.uid())
    and r.status in ('searching', 'assigned', 'in_progress')
    -- Una solicitud que ya paso su hora no se devuelve aunque siga marcada como
    -- searching. Puede estarlo durante menos de un minuto, hasta que pase
    -- pg_cron. Devolverla pintaria una cuenta atras parada en cero, y el
    -- pasajero preferiria un mapa limpio desde el que volver a pedir.
    and (r.status <> 'searching' or r.expires_at > now());
$$;

comment on function public.get_active_request is
  'La solicitud viva del pasajero, con su valor y el conductor asignado cuando ya lo hay. Cero o una fila.';

-- Se borro, asi que sus permisos se fueron con ella. Y nace con permiso para
-- PUBLIC, que incluye a `anon`: por eso primero se revoca.
revoke all on function public.get_active_request() from public, anon;
grant execute on function public.get_active_request() to authenticated;
