-- =============================================================================
-- FASE 22, PASO 1: se le quita a `anon` el permiso de ejecutar funciones de
-- `public`.
-- =============================================================================
--
-- QUE ESTABA MAL. Supabase deja puesto un
--
--   alter default privileges for role postgres in schema public
--     grant execute on functions to anon, authenticated, service_role;
--
-- (y otro igual para `supabase_admin`). Es un grant explicito por rol, no el de
-- `PUBLIC`, asi que **todos los `revoke ... from public` de las migraciones
-- anteriores nunca lo tocaron**. Solo el de `20260827170000`, que revoco
-- explicitamente a `anon`, funciono.
--
-- Medido antes de tocar nada: `has_function_privilege('anon', ...)` decia `true`
-- para casi todas las funciones del esquema, incluidas las ~35 `admin_*`,
-- `log_admin_action`, `is_admin`, `get_setting`, `is_within_service_area` y las
-- ~18 de disparador, ademas de las cuatro operativas vivas `accept_ride_offer`,
-- `reject_ride_offer`, `cancel_request` y `cancel_ride`. `request_ride` y
-- `rate_ride` ya estaban cerradas desde la Fase 15.
--
-- POR QUE NO ROMPE NADA -comprobado, no supuesto-.
--   - La aplicacion movil no llama ninguna funcion como `anon`: los 19 RPC del
--     cliente salen todos de pantallas con sesion.
--   - Ninguna politica RLS de `public` nombra a `anon` ni a `public`: todas
--     nombran a `authenticated`. Una sesion `anon` no lee una sola fila, asi que
--     las expresiones de politica -y las funciones que llaman- nunca se evaluan
--     para `anon`.
--   - Los disparadores se ejecutan con la identidad de su dueno, no con la de
--     quien provoca el INSERT: quitarle a `anon` el EXECUTE de `handle_new_user`
--     no afecta al alta de usuarios.
--   - `service_role` y `authenticated` conservan sus permisos intactos.
--
-- QUE HACE ESTA MIGRACION.
--   1. Corta el grant por defecto para las funciones que cree a partir de ahora
--      el rol `postgres`, que es con el que corren las migraciones.
--   2. Revoca EXECUTE a `anon` en todas las funciones de `public` que ya existen.
--
-- No se toca el `alter default privileges` de `supabase_admin`: `postgres` no es
-- superusuario y no puede, y las funciones del proyecto las crea `postgres`. Si
-- alguna funcion futura se colara con el grant, la caza el barrido del paso 8.
--
-- Verificacion: `supabase/dev-tools/prueba_grants_anon.sql` mas la regresion
-- completa de las fases 11 a 18 y el ciclo en el emulador.
-- =============================================================================

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

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
    execute format('revoke execute on function %s from anon', r.sig);
  end loop;
end
$revoca$;
