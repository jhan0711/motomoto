-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- VERSION ACOTADA de `purge_qa_accounts.sql` (2026-11-11). Borra SOLO cinco
-- cuentas QA sin historial real, no todas las `@motomoto-qa.co`:
--
--   admin.prueba, superadmin.prueba, demo.paradas1, demo.paradas2, juan
--
-- CONSERVA `pasajero.prueba` y `conductor2.prueba` (las cuentas de demostracion
-- de Apple, que vuelve a necesitar en cada version que revise) y
-- `conductor.prueba` (tiene 34 viajes con usuarios reales que probaron en
-- septiembre: borrarla se los llevaria). El script original NO sirve para esto:
-- borraria las tres.
--
-- POR QUE ESTAS CINCO. `admin.prueba` y `superadmin.prueba` son cuentas con
-- permisos de administracion en produccion y contrasena conocida: no deben
-- existir al abrir al publico. Las otras tres no tienen actividad real.
--
-- Antes de borrar se reviso a mano lo que cae: 4 solicitudes y 4 viajes de
-- `demo.paradas*`, sus 4 ofertas (todas al conductor QA 2), 29 filas de
-- auditoria (todas de pruebas del 27-ago al 2-sep, 0 sobre usuarios reales),
-- 1 notificacion, 1 documento de `juan` (PDF de 728 KB, se quita con la CLI de Storage) y 2 asignaciones de vehiculo de `juan`
-- (el vehiculo se queda). No es reversible.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/purge_qa_accounts_partial.sql
-- =============================================================================

do $purga$
declare
  v_qa uuid[];
  v_intrusos int;
begin
  select array_agg(id) into v_qa from auth.users
   where email in ('admin.prueba@motomoto-qa.co', 'superadmin.prueba@motomoto-qa.co',
                   'demo.paradas1@motomoto-qa.co', 'demo.paradas2@motomoto-qa.co',
                   'juan@motomoto-qa.co');

  if v_qa is null then
    raise notice 'No hay cuentas del lote. Nada que purgar.';
    return;
  end if;

  -- Salvaguarda propia de la version acotada: las dos cuentas de demostracion de
  -- Apple y el conductor QA con historial real NO pueden estar en el lote.
  if exists (select 1 from auth.users
              where id = any(v_qa)
                and email in ('pasajero.prueba@motomoto-qa.co',
                              'conductor2.prueba@motomoto-qa.co',
                              'conductor.prueba@motomoto-qa.co')) then
    raise exception 'Salvaguarda: el lote incluye una cuenta que debe conservarse. Purga abortada.';
  end if;

  -- Salvaguarda: ninguna id del lote puede corresponder a una cuenta que no sea
  -- @motomoto-qa.co. Si el `array_agg` de arriba se tocara mal alguna vez, esto
  -- lo corta antes de borrar nada real.
  select count(*) into v_intrusos
    from auth.users
   where id = any(v_qa) and email not like '%@motomoto-qa.co';

  if v_intrusos > 0 then
    raise exception 'Salvaguarda: % cuenta(s) del lote no son @motomoto-qa.co. Purga abortada.', v_intrusos;
  end if;

  -- 1. Viajes de un conductor QA. `rides.driver_id` es ON DELETE RESTRICT, asi
  --    que hay que borrarlos antes que al conductor. Se incluyen tambien los
  --    viajes de solicitudes de un pasajero QA (esos ademas caerian por cascada
  --    en el paso 2, pero borrarlos aqui deja el paso 2 limpio).
  delete from public.rides
   where driver_id = any(v_qa)
      or request_id in (select id from public.ride_requests where passenger_id = any(v_qa));

  -- 2. Solicitudes de un pasajero QA. `ride_requests.passenger_id` es RESTRICT.
  --    Cascada: ride_offers, ride_request_cargo, rides (por request),
  --    ride_locations, ratings (por ride).
  delete from public.ride_requests where passenger_id = any(v_qa);

  -- 3. Ofertas de un conductor QA sobre solicitudes de pasajeros reales que
  --    hayan sobrevivido a los pasos anteriores.
  delete from public.ride_offers where driver_id = any(v_qa);

  -- 4. Auditoria generada por un admin QA. La FK es ON DELETE SET NULL, pero se
  --    borra en vez de dejar 29 filas con actor nulo: el registro de auditoria
  --    de produccion empieza vacio.
  delete from public.admin_audit_logs where actor_id = any(v_qa);

  -- 5. (Quitado) Documentos en el almacenamiento. Supabase ya no permite borrar
  --    `storage.objects` con SQL ("Direct deletion from storage tables is not
  --    allowed"), y el script original fallaba aqui. El unico fichero del lote es
  --    `driver/b19e4e19-8324-4dad-baae-21fcf3ac9e44/257a0c9e-2100-4571-8494-bc04cd4a79b7.pdf`
  --    (un PDF de `juan`) y se quita aparte con la CLI de Storage, antes de esto.

  -- 6. Las cuentas. El resto se va por clave foranea:
  --
  --    CASCADE  auth.users -> profiles -> drivers -> driver_locations,
  --                                                  driver_vehicle_assignments,
  --                                                  documents, ride_offers
  --             profiles -> notifications, ratings, reports
  --    SET NULL app_settings/cargo_types/urban_fares/rural_fares.updated_by,
  --             drivers.approved_by, driver_vehicle_assignments.assigned_by,
  --             reports.resolved_by, admin_audit_logs.actor_id
  --    (auth.identities / auth.sessions / auth.refresh_tokens: CASCADE del esquema auth)
  delete from auth.users where id = any(v_qa);

  raise notice 'Purga completa: % cuenta(s) QA eliminada(s).', array_length(v_qa, 1);
end
$purga$;

-- ---------------------------------------------------------------------------
-- DESPUES: no debe quedar ninguna cuenta QA, y el super admin del dueno sigue.
-- ---------------------------------------------------------------------------
select
  'DESPUES' as momento,
  (select count(*) from auth.users where email like '%@motomoto-qa.co') as cuentas_qa_restantes /* deben quedar 3 */,
  (select count(*) from public.profiles) as perfiles_total,
  (select count(*) from public.profiles where role = 'super_admin' and status = 'active') as super_admins_activos,
  (select string_agg(u.email, ', ')
     from public.profiles p join auth.users u on u.id = p.id
    where p.role in ('admin', 'super_admin')) as admins_restantes;
