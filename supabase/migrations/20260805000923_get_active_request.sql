-- =============================================================================
-- Fase 11C: recuperar la solicitud en curso
-- =============================================================================
--
-- DECISION D152. El pasajero pide un servicio, cierra la aplicacion y vuelve a
-- abrirla. Sin esto, el mapa arranca limpio y el pasajero no tiene forma de ver
-- ni de cancelar lo que dejo en marcha; si intenta pedir otro, la regla R6 le
-- responde que ya tiene un servicio en curso, y ese es un callejon sin salida.
--
-- Por que una funcion y no un select desde la aplicacion, otra vez: origin y
-- destination son de tipo geography, y PostgREST las devuelve como EWKB en
-- hexadecimal. Es el mismo motivo que obligo a escribir list_places en la Fase 9
-- (D131), y la misma solucion.
--
-- SECURITY INVOKER, igual que list_places y por la misma razon: se ejecuta con
-- los permisos de quien llama, asi que la politica ride_requests_select_own se
-- sigue aplicando. Aun asi filtra por auth.uid() de forma explicita, porque un
-- administrador puede leer las solicitudes de todos y sin ese filtro esta
-- funcion le devolveria las de medio municipio en lugar de la suya.
--
-- Alcance en esta fase: hoy solo es alcanzable 'searching', porque la asignacion
-- llega en la Fase 13. Se devuelven ya los tres estados vivos para que la Fase
-- 15 amplie la pantalla y no la consulta.
-- =============================================================================

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
  seconds_remaining integer
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
    end
  from public.ride_requests r
  where r.passenger_id = (select auth.uid())
    and r.status in ('searching', 'assigned', 'in_progress')
    -- Una solicitud que ya paso su hora no se devuelve aunque siga marcada como
    -- searching. Puede estarlo durante menos de un minuto, hasta que pase
    -- pg_cron. Devolverla pintaria una cuenta atras parada en cero, y el
    -- pasajero preferiria un mapa limpio desde el que volver a pedir.
    and (r.status <> 'searching' or r.expires_at > now());
$$;

comment on function public.get_active_request is
  'La solicitud viva del pasajero que llama, con las coordenadas ya separadas. Cero o una fila.';

-- Sin sesion no hay solicitud que recuperar.
revoke all on function public.get_active_request() from public, anon;
grant execute on function public.get_active_request() to authenticated;
