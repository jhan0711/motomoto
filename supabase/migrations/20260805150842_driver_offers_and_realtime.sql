-- =============================================================================
-- Fase 12A: como se entera el conductor de que hay una solicitud
-- =============================================================================
--
-- Dos piezas del mismo problema. La funcion que lee las ofertas, y la
-- publicacion que hace que lleguen solas.
--
-- DECISION D158: el aviso llega empujado por el servidor, no preguntando cada
-- pocos segundos. El motivo es la regla R2: el conductor tiene veinte segundos
-- para responder. Sondeando cada diez, la mitad de su tiempo se va antes de que
-- vea nada. Para que no se notara habria que preguntar cada dos o tres segundos,
-- y eso son mas de mil peticiones por hora y por conductor con datos moviles.
--
-- Esto adelanta trabajo previsto para la Fase 13, y a proposito: es el mecanismo
-- que esa fase necesita de todos modos. Lo que se queda alli es la prevencion de
-- la aceptacion simultanea probada con dos sesiones y el aviso al pasajero.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Funcion: las ofertas vivas de quien llama
-- -----------------------------------------------------------------------------

-- SECURITY INVOKER, igual que list_places y get_active_request. Las politicas
-- ride_offers_select_own y ride_requests_select_offered_driver ya restringen lo
-- que este conductor puede ver, asi que la funcion no necesita saltarselas.
--
-- Aqui NO viaja ningun dato del pasajero. Ni nombre ni telefono. Antes de
-- aceptar, el conductor decide con el viaje: de donde a donde, cuanta gente y a
-- que distancia esta la recogida. Quien es esa persona es asunto suyo hasta que
-- alguien se compromete a llevarla, y esta funcion es el sitio donde esa linea
-- se dibuja o se borra.
create or replace function public.list_driver_offers()
returns table (
  offer_id uuid,
  request_id uuid,
  expires_at timestamptz,
  seconds_remaining integer,
  distance_m integer,
  passenger_count smallint,
  origin_lat double precision,
  origin_lng double precision,
  origin_label text,
  destination_lat double precision,
  destination_lng double precision,
  destination_label text,
  requested_at timestamptz
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    o.id,
    r.id,
    o.expires_at,
    -- Calculados por el servidor y no por el telefono, mismo criterio que D154:
    -- un reloj desajustado ensenaria un temporizador falso, y aqui el
    -- temporizador es lo que decide si el conductor llega a tiempo o no.
    greatest(0, ceil(extract(epoch from (o.expires_at - now()))))::integer,
    o.distance_m,
    r.passenger_count,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(r.origin::extensions.geometry),
    extensions.st_x(r.origin::extensions.geometry),
    r.origin_label,
    extensions.st_y(r.destination::extensions.geometry),
    extensions.st_x(r.destination::extensions.geometry),
    r.destination_label,
    r.requested_at
  from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
  where o.driver_id = (select auth.uid())
    and o.response = 'pending'
    and o.expires_at > now()
    -- Y la solicitud tiene que seguir buscando. Sin esta condicion, una oferta
    -- cuyo servicio ya se llevo otro conductor seguiria apareciendo hasta que
    -- caducara sola, y el conductor gastaria su atencion en algo que ya no
    -- existe. El estado de la solicitud manda sobre el de la oferta.
    and r.status = 'searching'
  order by o.expires_at;
$$;

comment on function public.list_driver_offers is
  'Ofertas vivas del conductor que llama, con las coordenadas ya separadas. Sin datos del pasajero.';

revoke all on function public.list_driver_offers() from public, anon;
grant execute on function public.list_driver_offers() to authenticated;


-- -----------------------------------------------------------------------------
-- Publicacion de tiempo real
-- -----------------------------------------------------------------------------

-- La publicacion `supabase_realtime` ya existia en el proyecto, vacia:
-- comprobado antes de escribir esto. Aqui entra su primera tabla.
--
-- Se publica ride_offers y no ride_requests. La oferta es la fila que pertenece
-- a un conductor concreto, asi que la politica ride_offers_select_own basta para
-- que cada uno reciba solo lo suyo. Publicar las solicitudes obligaria a filtrar
-- con una politica que consulta otra tabla, y eso en tiempo real se evalua en
-- cada evento y para cada suscriptor.
alter publication supabase_realtime add table public.ride_offers;

-- Identidad de replica completa para que los eventos de actualizacion incluyan
-- la fila anterior. Hace falta para distinguir "esta oferta acaba de pasar a
-- rechazada" de "acaba de aparecer", que en la pantalla del conductor son cosas
-- muy distintas.
alter table public.ride_offers replica identity full;
