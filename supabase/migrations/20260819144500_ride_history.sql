-- =============================================================================
-- Fase 16, paso 1: el historial de las dos partes
-- =============================================================================
--
-- Dos funciones de solo lectura, una por rol. Ninguna politica nueva: todo lo
-- que devuelven ya lo podia leer quien llama, y por eso las dos son SECURITY
-- INVOKER. Lo que aportan es la forma, no el permiso.
--
-- LAS DOS LISTAS NO SON LA MISMA LISTA, y conviene decirlo antes de leer el
-- codigo. El pasajero tiene solicitudes: una por cada vez que pidio un
-- motorraton. El conductor tiene ofertas: una por cada vez que el sistema le
-- propuso un servicio, lo tomara o no. Un servicio que el rechazo no existe en
-- el historial del pasajero, porque desde su lado no paso nada; su solicitud
-- siguio buscando. Por eso la del pasajero sale de `ride_requests` y la del
-- conductor de `ride_offers`.
--
-- EL RECHAZO NO SE LE ENSENA AL PASAJERO. No es solo que no le sirva: saber
-- quien lo rechazo es informacion sobre terceros, y la politica
-- `ride_offers_select_own` ya la cierra desde la Fase 5.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El historial del pasajero
-- -----------------------------------------------------------------------------

-- Entran los tres finales que puede tener una solicitud: terminada, cancelada y
-- caducada. No entra ninguna viva, que es cosa de `get_active_request`.
create or replace function public.list_passenger_history(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  request_id uuid,
  status public.ride_request_status,
  requested_at timestamptz,
  finished_at timestamptz,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  cancelled_by public.actor_type,
  cancellation_reason text,
  ride_id uuid,
  distance_m integer,
  duration_s integer,
  driver_name text,
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
    r.requested_at,
    -- Cuando termino, sea como fuere. Una solicitud caducada no tiene hora de
    -- cierre propia: la suya es la hora a la que iba a caducar, que es cuando
    -- dejo de buscar.
    coalesce(r.completed_at, r.cancelled_at, r.expires_at),
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    r.cancelled_by,
    r.cancellation_reason,
    v.ride_id,
    v.trip_distance_m,
    v.trip_duration_s,
    v.driver_name,
    v.unit_number,
    v.plate
  from public.ride_requests r
    -- LATERAL con LIMIT 1 por el mismo motivo que en `get_active_request`: hoy
    -- una solicitud produce un solo viaje (D5), pero el modelo admite repartir
    -- un grupo entre varios motorratones y un join a secas duplicaria la fila.
    --
    -- SIN FILTRAR POR ESTADO DEL VIAJE, al reves que alli. Aqui interesa el
    -- viaje que hubo, y si acabo cancelado tambien cuenta: el pasajero quiere
    -- ver que aquel dia alguien acepto y luego se cayo.
    left join lateral (
      select
        d.id as ride_id,
        d.distance_m as trip_distance_m,
        d.duration_s as trip_duration_s,
        p.full_name as driver_name,
        veh.unit_number,
        veh.plate
      from public.rides d
        -- LEFT JOIN a `profiles` y no join a secas. La politica
        -- `profiles_select_ride_counterpart` deja pasar al pasajero, pero si
        -- algun dia se cierra a los viajes vivos, un join normal haria
        -- desaparecer la fila entera del historial en vez de dejar el nombre en
        -- blanco. Una fila sin nombre es un dato incompleto; una fila que falta
        -- es una mentira.
        left join public.profiles p on p.id = d.driver_id
        left join public.vehicles veh on veh.id = d.vehicle_id
      where d.request_id = r.id
      order by d.accepted_at desc
      limit 1
    ) v on true
  where r.passenger_id = (select auth.uid())
    and r.status in ('completed', 'cancelled', 'expired')
  order by r.requested_at desc
  -- El tope de 50 no es desconfianza del cliente: es que una pantalla de movil
  -- no pinta mas y una peticion sin techo la puede pedir cualquiera por la API.
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

comment on function public.list_passenger_history is
  'Solicitudes terminadas, canceladas y caducadas del pasajero que llama, de la mas reciente a la mas antigua.';

revoke all on function public.list_passenger_history(integer, integer) from public, anon;
grant execute on function public.list_passenger_history(integer, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- El historial del conductor
-- -----------------------------------------------------------------------------

-- Ordena por `offered_at`, y el unico indice que hay sobre esa columna es
-- parcial, solo para las ofertas pendientes. El historial pide justo las
-- contrarias.
create index if not exists ro_driver_history_idx
  on public.ride_offers (driver_id, offered_at desc);

-- El desenlace de cada oferta, en una sola columna. Se calcula aqui y no en el
-- telefono porque sale de cruzar tres tablas, y esa cuenta hecha en el cliente
-- es una cuenta que habria que repetir el dia que haya un panel.
--
-- Cinco valores:
--
--   completed       la acepto y el viaje termino
--   cancelled       la acepto y el viaje se cancelo
--   rejected        la rechazo el
--   taken_by_other  no respondio, y otro conductor se la llevo
--   expired         no respondio, y nadie la atendio
--
-- `taken_by_other` NO ESTABA EN LA LISTA DE CUATRO, y esta puesto a proposito.
-- Cuando otro conductor acepta, las ofertas que seguian pendientes se marcan
-- 'expired' (Fase 5). Sin separarlo, la pantalla le diria "caducada" a una
-- oferta que el no dejo pasar: alguien fue mas rapido. Y mezclarlos hincharia
-- justo la cuenta que a la empresa le va a importar mirar.
--
-- LO QUE SIGUE MEZCLADO, y queda dicho: dentro de `expired` caben "se agoto el
-- tiempo sin que nadie la tomara" y "el pasajero cancelo mientras estaba
-- pendiente". Ninguno de los dos es un rechazo, que es lo que importa aqui.
create or replace function public.list_driver_history(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  offer_id uuid,
  request_id uuid,
  ride_id uuid,
  outcome text,
  offered_at timestamptz,
  responded_at timestamptz,
  finished_at timestamptz,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  pickup_distance_m integer,
  distance_m integer,
  duration_s integer,
  cancelled_by public.actor_type,
  passenger_name text
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    o.id,
    r.id,
    d.id,
    case
      when o.response = 'rejected' then 'rejected'
      when o.response = 'accepted' and d.status = 'completed' then 'completed'
      when o.response = 'accepted' and d.status = 'cancelled' then 'cancelled'
      when r.status in ('assigned', 'in_progress', 'completed') then 'taken_by_other'
      else 'expired'
    end,
    o.offered_at,
    o.responded_at,
    coalesce(d.completed_at, d.cancelled_at, o.responded_at, o.expires_at),
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    -- La distancia que habia hasta el punto de recogida cuando se le ofrecio.
    -- Explica por que le llego a el.
    o.distance_m,
    d.distance_m,
    d.duration_s,
    d.cancelled_by,
    -- EL NOMBRE SOLO EN LO QUE ACEPTO, y el filtro esta escrito aqui a
    -- proposito en lugar de dejarselo a la politica.
    --
    -- La primera version confiaba en `shares_ride_with`, dando por hecho que sin
    -- viaje no habria nombre que leer. La prueba lo tumbo: esa politica mira a
    -- LA PERSONA, no al viaje. Un conductor que llevo a alguien alguna vez pasa
    -- su comprobacion para siempre, asi que en una oferta rechazada de esa misma
    -- pasajera el nombre salia igual. Y quien es el pasajero es justo lo que el
    -- conductor no ve hasta aceptar, desde la Fase 12.
    --
    -- Es la mitad del hallazgo H15 vista desde otro sitio. Lo de fondo se decide
    -- al cerrar esta fase; esto cierra la puerta de esta pantalla mientras tanto.
    case when o.response = 'accepted' then p.full_name end
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
    -- LEFT JOIN, no join. Con RLS por medio, un join normal borraria del
    -- historial toda oferta sin viaje propio, que son precisamente las
    -- rechazadas y las caducadas: la mitad de lo que esta lista existe para
    -- ensenar.
    left join public.rides d on d.request_id = o.request_id
      and d.driver_id = o.driver_id
    left join public.profiles p on p.id = r.passenger_id
  where o.driver_id = (select auth.uid())
    -- Fuera lo que sigue vivo. Una oferta pendiente esta en la pantalla
    -- principal con su cuenta atras, y un viaje en curso tambien.
    and o.response <> 'pending'
    and (d.id is null or d.status in ('completed', 'cancelled'))
  order by o.offered_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

comment on function public.list_driver_history is
  'Ofertas cerradas del conductor que llama, con su desenlace, de la mas reciente a la mas antigua.';

revoke all on function public.list_driver_history(integer, integer) from public, anon;
grant execute on function public.list_driver_history(integer, integer) to authenticated;
