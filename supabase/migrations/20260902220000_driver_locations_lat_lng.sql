-- =============================================================================
-- FASE 22, PASO 7: `driver_locations` guarda la latitud y la longitud sueltas,
-- para que el pasajero pinte el motorraton con lo que ya viene en el evento de
-- tiempo real y no tenga que volver a preguntar.
-- =============================================================================
--
-- EL PROBLEMA (del diagnostico del puntero, 2026-09-02). El pasajero se suscribe
-- a `driver_locations` por tiempo real, pero del evento **solo usaba el aviso**:
-- la fila llega con la posicion en el binario de PostGIS y descifrarlo en el
-- telefono se descarto en su dia (D131). Asi que al recibir el aviso llamaba a
-- `get_driver_location` para traer lat/lon separadas -otra vuelta de red de 2 a
-- 4 segundos-, y con el envio cada 7 s del conductor el pasajero veia el
-- motorraton moverse con ~12-15 s de retraso, al borde del criterio.
--
-- LA SOLUCION. Dos columnas `lat` y `lng` que un disparador mantiene siempre en
-- sincronia con `location`. El evento de tiempo real las lleva -postgres_changes
-- manda la fila entera-, asi que el pasajero pinta el punto en cuanto llega el
-- aviso, sin la consulta extra.
--
-- `location` SIGUE SIENDO LA FUENTE. Es geography y lo usan `find_available_drivers`,
-- `get_driver_location` y el resto para medir distancias. `lat`/`lng` son una
-- copia de conveniencia para el canal; el disparador garantiza que no se
-- separen. `reportLocation` en el cliente no cambia: sigue escribiendo solo
-- `location`.
-- =============================================================================

alter table public.driver_locations
  add column lat double precision,
  add column lng double precision;

create or replace function public.driver_location_split_coords()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
  -- porque el punto se construye al reves, con la longitud primero.
  new.lat := extensions.st_y(new.location::extensions.geometry);
  new.lng := extensions.st_x(new.location::extensions.geometry);
  return new;
end;
$$;

comment on function public.driver_location_split_coords() is
  'Mantiene driver_locations.lat/lng en sincronia con location. Fase 22, paso 7.';

-- Como se aprendio en el paso 1: `create function` concede EXECUTE a PUBLIC por
-- defecto, y `db push` lo hace tambien pese al `alter default privileges` del
-- paso 2. Una funcion de disparador no la ejecuta nadie a mano; se cierra aqui.
revoke all on function public.driver_location_split_coords() from public, anon, authenticated;

create trigger driver_locations_split_coords
  before insert or update of location on public.driver_locations
  for each row execute function public.driver_location_split_coords();

-- El disparador solo actua en escrituras nuevas: se rellenan las filas que ya
-- existen.
update public.driver_locations
set lat = extensions.st_y(location::extensions.geometry),
    lng = extensions.st_x(location::extensions.geometry);
