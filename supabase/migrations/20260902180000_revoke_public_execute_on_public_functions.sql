-- =============================================================================
-- FASE 22, PASO 1 (continuacion): se le quita a `PUBLIC` el EXECUTE de las
-- funciones de `public`.
-- =============================================================================
--
-- QUE FALTABA. La migracion `20260902170000` revoco el grant explicito a `anon`,
-- y con eso cayeron las ~35 `admin_*` y varias mas. Pero quedaron 19 funciones
-- que `anon` **todavia** podia ejecutar, y la prueba lo cazo:
--
--   accept_ride_offer, cancel_request, cancel_ride, reject_ride_offer,
--   get_setting, is_admin, is_within_service_area, y 12 de disparador.
--
-- El motivo, medido en `proacl`: tienen la entrada `=X/postgres`, que es el
-- grant a **`PUBLIC`** que PostgreSQL pone solo al hacer `create function` y que
-- estas migraciones antiguas -Fases 5 y 13- nunca revocaron. Las `admin_*` si lo
-- revocaban (`revoke all ... from public`), por eso no lo sufrieron. `anon` es
-- miembro de `PUBLIC`, asi que hereda el permiso por ahi.
--
-- POR QUE NO TOCA A `authenticated` NI A `service_role`. Los dos tienen grant
-- **explicito** (`authenticated=X/postgres`, `service_role=X/postgres`), puesto
-- por el `alter default privileges` de Supabase. Revocar `PUBLIC` no toca un
-- grant explicito. Comprobado: las unicas 8 funciones de `public` sin
-- `authenticated=` en su ACL -`find_available_drivers`, `offer_request_to_drivers`,
-- `expire_stale_requests`, `offer_pending_requests`, `send_push_notification`,
-- `generate_initial_password`, `assert_ride_driver`, `rural_fare_for_point`-
-- tampoco tienen `PUBLIC`: ya estaban cerradas a postgres + service_role, y esta
-- migracion no las cambia.
--
-- QUE HACE.
--   1. Corta el grant por defecto a `PUBLIC` para las funciones futuras que cree
--      `postgres`.
--   2. Revoca EXECUTE a `PUBLIC` (y de paso otra vez a `anon`, por si acaso) en
--      todas las funciones de `public` que `anon` aun puede ejecutar.
--
-- Verificacion: `supabase/dev-tools/prueba_grants_anon.sql`, mas la regresion de
-- las fases 11 a 18 y el ciclo en el emulador.
-- =============================================================================

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

do $revoca$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure::text as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  loop
    execute format('revoke execute on function %s from public, anon', r.sig);
  end loop;
end
$revoca$;
