-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Borra las cuentas de prueba (`@motomoto-qa.co`) y todo lo que cuelga de ellas.
-- Se creo en la Fase 25 paso 9: el proyecto vinculado (`bosodjcehvqmmegxdmlu`)
-- va a ser el de produccion (mismo proyecto, decision del usuario), y hoy tiene
-- 8 cuentas QA de las 9 que existen.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/purge_qa_accounts.sql
--
-- CUANDO EJECUTARLO: **una sola vez, justo antes de abrir la app al publico**.
-- No antes: mientras se sigue probando en el dispositivo se usan estas cuentas
-- (`pasajero.prueba@…`, `conductor.prueba@…`, `superadmin.prueba@…`, …). No es
-- una migracion a proposito -`db push` y `db reset` no lo miran-, y no hay forma
-- de deshacerlo.
--
-- QUE NO TOCA: la cuenta real del dueno (`jhank.45617@gmail.com`, super_admin) y
-- toda la configuracion -tarifas, ajustes, tipos de carga, lugares, tipos de
-- documento-. Si un `updated_by` apuntaba a un admin QA, la FK es
-- `ON DELETE SET NULL`: la fila de config se queda, sin autor. Comprobado el
-- 2026-09-02: 0 ajustes y 0 tarifas editados por una cuenta QA, asi que ni eso.
--
-- ES IDEMPOTENTE. Si ya no hay cuentas QA, no hace nada.
--
-- COMO FUNCIONA EL BORRADO. Casi todo se va por cascada de clave foranea al
-- borrar `auth.users` (ver el mapa dentro del bloque). Solo hay que adelantarse
-- a mano en las tres FK `ON DELETE RESTRICT` que apuntan a estas cuentas:
-- `rides.driver_id`, `rides.request_id` (via `ride_requests`) y
-- `ride_requests.passenger_id`.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- ANTES: que hay colgando de las cuentas QA.
-- ---------------------------------------------------------------------------
with qa as (select id from auth.users where email like '%@motomoto-qa.co')
select
  'ANTES' as momento,
  (select count(*) from qa) as cuentas_qa,
  (select count(*) from public.ride_requests where passenger_id in (select id from qa)) as solicitudes,
  (select count(*) from public.rides where driver_id in (select id from qa)) as viajes_conductor_qa,
  (select count(*) from public.ride_offers where driver_id in (select id from qa)) as ofertas,
  (select count(*) from public.ratings
     where rater_id in (select id from qa) or rated_id in (select id from qa)) as calificaciones,
  (select count(*) from public.admin_audit_logs where actor_id in (select id from qa)) as auditoria,
  (select count(*) from storage.objects
     where bucket_id = 'documents'
       and (string_to_array(name, '/'))[2] in (select id::text from qa)) as documentos_storage;

-- ---------------------------------------------------------------------------
-- PURGA
-- ---------------------------------------------------------------------------
do $purga$
declare
  v_qa uuid[];
  v_intrusos int;
begin
  select array_agg(id) into v_qa from auth.users where email like '%@motomoto-qa.co';

  if v_qa is null then
    raise notice 'No hay cuentas @motomoto-qa.co. Nada que purgar.';
    return;
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

  -- 5. Documentos (metadatos + fichero) subidos por un conductor QA. La fila de
  --    `public.documents` cae por cascada al borrar al conductor; el objeto de
  --    `storage.objects` no, hay que borrarlo aqui. Ruta: `driver/<id>/<doc>`.
  delete from storage.objects
   where bucket_id = 'documents'
     and (string_to_array(name, '/'))[2] = any(v_qa::text[]);

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
  (select count(*) from auth.users where email like '%@motomoto-qa.co') as cuentas_qa_restantes,
  (select count(*) from public.profiles) as perfiles_total,
  (select count(*) from public.profiles where role = 'super_admin' and status = 'active') as super_admins_activos,
  (select string_agg(u.email, ', ')
     from public.profiles p join auth.users u on u.id = p.id
    where p.role in ('admin', 'super_admin')) as admins_restantes;
