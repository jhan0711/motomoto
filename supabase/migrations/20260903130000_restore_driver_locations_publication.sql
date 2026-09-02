-- =============================================================================
-- Fase 24, paso 3 (arreglo): devolver `driver_locations` a la publicacion sin
-- lista de columnas
-- =============================================================================
--
-- POR QUE EXISTE ESTA MIGRACION. La primera version de `20260903120000` intento
-- acotar la publicacion `supabase_realtime` a cuatro columnas de `driver_locations`
-- para adelgazar el evento de tiempo real. **No funciono** -Supabase Realtime usa
-- `wal2json`, que ignora las listas de columnas- y ademas dejo la tabla publicada
-- con una lista de columnas que no sirve para nada y confunde a quien la lea. La
-- migracion se reescribio para no hacer eso, pero ya se habia aplicado al entorno
-- enlazado, asi que hace falta un paso que lo deshaga.
--
-- Deja `driver_locations` publicada EXACTAMENTE como la dejo
-- `20260811204827_driver_location_for_passenger.sql`: en `supabase_realtime`, sin
-- lista de columnas. Idempotente: en una base nueva construida desde las
-- migraciones, `driver_locations` ya esta asi y esto solo lo reafirma.
-- =============================================================================

do $publicacion$
begin
  -- Quitarla si esta (con o sin lista de columnas) y volver a anadirla entera.
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'driver_locations'
  ) then
    alter publication supabase_realtime drop table public.driver_locations;
  end if;

  alter publication supabase_realtime add table public.driver_locations;
end
$publicacion$;
