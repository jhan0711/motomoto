-- =============================================================================
-- FASE 22, PASO 8: se le quitan a `anon` los privilegios de tabla y de secuencia
-- que tiene sobre todo `public` y que no usa para nada.
-- =============================================================================
--
-- EL HALLAZGO, del barrido de cierre. `anon` tiene
-- `select/insert/update/delete/truncate/references/trigger` sobre las 22 tablas
-- de `public` -154 permisos-. Es el mismo patron de siempre: Supabase concede
-- todo a `anon`, `authenticated` y `service_role` por defecto, y las RLS de la
-- Fase 5 son lo que de verdad protege las filas.
--
-- NO ES UN AGUJERO ABIERTO. Todas las tablas tienen RLS activada y **ninguna
-- politica nombra a `anon` ni a `public`** -comprobado en el barrido-, asi que
-- una sesion sin login no lee ni escribe una sola fila. Pero es superficie que
-- no tiene por que existir, igual que los grants de funcion que se cerraron en
-- los pasos 1 y 2.
--
-- QUE NO SE TOCA. `authenticated` conserva sus 154 permisos -las RLS y las
-- politicas hacen el trabajo real para quien tiene sesion-, y `service_role`
-- tambien. `anon` no necesita tocar ninguna tabla: el registro pasa por GoTrue,
-- y el disparador `handle_new_user` que crea el perfil corre con la identidad de
-- su dueno (`postgres`), no con la de quien se registra.
--
-- EL `alter default privileges` cubre las tablas que cree en adelante el rol
-- `postgres` -con el que corren las migraciones-. El de `supabase_admin` no se
-- puede tocar (postgres no es superusuario), pero solo afecta a tablas internas
-- y de extensiones, no a las del proyecto.
-- =============================================================================

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
