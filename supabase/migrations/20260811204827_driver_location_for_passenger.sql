-- =============================================================================
-- Fase 14, paso 4: el pasajero ve moverse a su conductor
-- =============================================================================
--
-- Dos piezas: una funcion para leer la posicion y la publicacion de la tabla en
-- tiempo real. Ninguna politica nueva.
--
-- NO HACE FALTA NINGUNA POLITICA, y conviene decir por que.
-- `driver_locations_select_active_passenger` esta escrita desde la Fase 5 y dice
-- exactamente esto: un pasajero puede leer la posicion del conductor con el que
-- comparte un viaje activo, via `has_active_ride_with_driver`. Es la segunda vez
-- que pasa en este proyecto, despues de `drivers_select_ride_counterpart` en la
-- Fase 13: el modelo de seguridad se diseno entero antes que las pantallas, y las
-- pantallas van llegando a politicas que ya estaban esperandolas.
--
-- POR QUE UNA FUNCION Y NO UN SELECT DIRECTO. La columna es `geography`, y la API
-- REST la devuelve como binario en hexadecimal. Descifrar WKB en el telefono es
-- justo lo que D131 descarto para los lugares, y aqui seria peor: esto se lee
-- cada diez segundos mientras dura un servicio.
--
-- SECURITY INVOKER, por lo mismo que `get_active_request`: es lo que hace que la
-- politica de arriba se aplique de verdad. Con definer habria que reimplementar
-- la comprobacion a mano dentro de la funcion, y una comprobacion reimplementada
-- es una que se puede olvidar.
--
-- DEVUELVE TAMBIEN `updated_at`, y no es un extra. Un marcador quieto puede
-- significar dos cosas muy distintas: que el motorraton esta parado en un
-- semaforo o que el conductor se quedo sin cobertura. La pantalla necesita
-- distinguirlas, porque en el segundo caso lo que ve el pasajero es mentira.
-- =============================================================================

create or replace function public.get_driver_location(p_driver_id uuid)
returns table (
  latitude double precision,
  longitude double precision,
  heading numeric,
  updated_at timestamptz,
  age_seconds integer
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(dl.location::extensions.geometry),
    extensions.st_x(dl.location::extensions.geometry),
    dl.heading,
    dl.updated_at,
    -- La antiguedad la calcula el servidor y no el telefono, por lo mismo que
    -- los segundos que quedan de una solicitud (D154): un reloj desajustado
    -- diria que la posicion es del futuro o de hace media hora.
    greatest(0, floor(extract(epoch from (now() - dl.updated_at))))::integer
  from public.driver_locations dl
  where dl.driver_id = p_driver_id;
$$;

comment on function public.get_driver_location is
  'Posicion actual de un conductor, con su antiguedad. Solo la ve quien comparte un viaje activo con el.';

revoke all on function public.get_driver_location(uuid) from public, anon;
grant execute on function public.get_driver_location(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Tiempo real
-- -----------------------------------------------------------------------------
--
-- La tercera tabla publicada, despues de `ride_offers` (D158) y `ride_requests`
-- (D168).
--
-- POR QUE TIEMPO REAL Y NO SONDEO. El criterio de aceptacion 4 pide que el
-- pasajero vea moverse al conductor con menos de quince segundos de retraso. El
-- conductor envia cada diez (R9); si el pasajero preguntara cada diez, el peor
-- caso serian veinte y el criterio no se cumpliria. Bajar el sondeo a cinco
-- segundos serian doce consultas por minuto por pasajero, casi todas para
-- descubrir que no ha cambiado nada.
--
-- SIN `replica identity full`, igual que `ride_requests` y a diferencia de
-- `ride_offers`. Del evento solo se usa el aviso: la fila anterior no aporta
-- nada, y `full` escribiria la fila entera en el registro de transacciones en
-- cada actualizacion, o sea seis veces por minuto y por conductor en viaje.
--
-- LO QUE ESTO CUESTA, DICHO CLARO. Es la tabla que mas se actualiza del sistema,
-- y cada evento se evalua contra la politica de cada suscriptor. Con la flota de
-- un municipio son cifras pequenas, pero es lo primero que hay que mirar si algo
-- va lento (Fase 24).
alter publication supabase_realtime add table public.driver_locations;
