-- =============================================================================
-- Fase 13, paso 1: el pasajero ve a quien le van a recoger
-- =============================================================================
--
-- Hasta ahora `get_active_request` devolvia la solicitud y nada mas. Cuando un
-- conductor la aceptaba, el pasajero pasaba de "buscando motorraton" a
-- "asignado" sin ninguna informacion nueva: ni quien viene, ni en que unidad, ni
-- como llamarlo. La Fase 12 le dio al conductor los datos del pasajero; esto es
-- la otra mitad, que faltaba.
--
-- LA LINEA DE LA PRIVACIDAD ES LA MISMA, EN EL OTRO SENTIDO. El conductor no ve
-- el nombre del pasajero hasta que acepta; el pasajero no ve al conductor hasta
-- que alguien acepta, porque hasta ese momento no hay a quien ver. Los dos datos
-- aparecen en el mismo instante y por el mismo motivo: alguien se comprometio.
--
-- NO HACE FALTA NINGUNA POLITICA NUEVA, y conviene decir por que. Las cuatro
-- tablas que se leen aqui ya dejan pasar a un pasajero con servicio asignado:
--
--   rides    rides_select_participant       via owns_request(request_id)
--   profiles profiles_select_ride_counterpart  via shares_ride_with(id)
--   drivers  drivers_select_ride_counterpart   via has_active_ride_with_driver(id)
--   vehicles vehicles_select_authenticated     abierta a cualquier autenticado
--
-- `drivers_select_ride_counterpart` estaba escrita desde la Fase 5 y hasta hoy
-- no la usaba nadie. Existia para este momento.
--
-- SIGUE SIENDO SECURITY INVOKER. Es lo que hace que las cuatro politicas de
-- arriba se apliquen de verdad. Con SECURITY DEFINER habria que reimplementar a
-- mano cada una de esas comprobaciones dentro de la funcion, y una comprobacion
-- reimplementada es una comprobacion que se puede olvidar.
--
-- Hay que borrarla antes de recrearla: `create or replace` no admite cambiar las
-- columnas que devuelve una funcion.
-- =============================================================================

drop function if exists public.get_active_request();

create or replace function public.get_active_request()
returns table (
  id uuid,
  status public.ride_request_status,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  requested_at timestamptz,
  expires_at timestamptz,
  seconds_remaining integer,

  -- Todo lo que sigue va en nulo mientras la solicitud sigue en 'searching'.
  -- No hay conductor porque todavia no ha aceptado nadie, y esa es justo la
  -- diferencia que la pantalla necesita distinguir.
  ride_id uuid,
  ride_status public.ride_status,
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

    v.ride_id,
    v.ride_status,
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
  'La solicitud viva del pasajero, con el conductor asignado cuando ya lo hay. Cero o una fila.';

-- Sin sesion no hay solicitud que recuperar.
revoke all on function public.get_active_request() from public, anon;
grant execute on function public.get_active_request() to authenticated;
