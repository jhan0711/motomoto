-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Convierte la cuenta del dueno del proyecto -jhank.45617@gmail.com, que hasta
-- ahora era el pasajero "Jhan Roldan"- en super administrador.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/promote_jhank_super_admin.sql
--
-- NO ES UNA MIGRACION a proposito: solo existe esta cuenta en desarrollo, y una
-- migracion fallaria o quedaria muerta en cualquier otro entorno. El super
-- administrador de produccion se crea en la Fase 25.
--
-- Es idempotente. Se puede ejecutar las veces que haga falta.
--
-- POR QUE DESACTIVA EL DISPARADOR. `profiles_protect_columns` revierte cualquier
-- UPDATE del rol -incluso ejecutando como postgres-, porque su exencion depende
-- de `is_admin()` y en un script no hay sesion (hallazgo H5). Aqui NO se puede
-- usar la maniobra de borrar y reinsertar la fila como en las semillas: esta
-- cuenta tiene 40 solicitudes y una calificacion de verdad colgando de ella por
-- clave foranea. Se desactiva el disparador, se cambia el rol, se vuelve a
-- activar.
--
-- LA CONTRASENA NO SE TOCA AQUI. La pone o la cambia el dueno desde el panel de
-- Supabase (Authentication -> Users) o por la recuperacion por correo. D264: la
-- cuenta deja de poder pedir servicios como pasajero.
-- =============================================================================

do $promocion$
declare
  c_id constant uuid := 'c52464b0-76e2-49f1-80ab-ee165dd18d0a';
  v_email text;
begin
  select email into v_email from auth.users where id = c_id;

  if v_email is null then
    raise notice 'La cuenta % no existe en este entorno; no se hace nada.', c_id;
    return;
  end if;

  if v_email <> 'jhank.45617@gmail.com' then
    raise exception 'El id % no corresponde a jhank.45617@gmail.com (es %). Se aborta.',
      c_id, v_email;
  end if;

  alter table public.profiles disable trigger profiles_protect_columns;
  update public.profiles set role = 'super_admin' where id = c_id and role <> 'super_admin';
  alter table public.profiles enable trigger profiles_protect_columns;
end
$promocion$;


-- Comprobacion: rol super_admin Y estado activo, mas los tokens no nulos que
-- exige GoTrue para iniciar sesion.
select
  u.email,
  p.full_name,
  p.role::text as rol,
  p.status::text as estado,
  (u.confirmation_token is not null and u.recovery_token is not null
   and u.email_change_token_new is not null and u.email_change is not null) as tokens_no_nulos,
  (select count(*) from public.ride_requests where passenger_id = u.id) as solicitudes_conservadas
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'jhank.45617@gmail.com';
