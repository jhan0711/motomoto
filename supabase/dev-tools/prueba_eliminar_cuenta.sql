-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `delete_my_account`, definida en
-- `20260904000000_delete_my_account.sql` (Fase 26 paso 7b).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_eliminar_cuenta.sql
--
-- Intenta romper cada guarda: que anon no pueda llamarla, que un conductor no
-- pueda borrar su cuenta, que no se pueda con un servicio en curso, y que en el
-- camino feliz la cuenta desaparezca pero el historial terminado quede
-- anonimizado hacia el perfil marcador.
--
-- Todo dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

create temp table resultados (
  n integer, comprobacion text, esperado text, obtenido text, ok boolean
) on commit drop;

-- Actores de prueba. Ids fijos, viven solo dentro de esta transaccion.
do $montaje$
declare
  c_pasajero constant uuid := 'ee1e7e57-0000-4000-8000-000000000001';
  c_marcador constant uuid := 'de1e7ed0-0000-4000-8000-000000000000';
begin
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    c_pasajero, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'prueba.eliminar@amalfigo.invalid',
    extensions.crypt('irrelevante', extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Pasajero de prueba borrado","phone":"3001112233"}',
    '', '', '', ''
  );

  -- El disparador on_auth_user_created ya hizo el perfil. Se deja tal cual
  -- (rol passenger, activo), con telefono.
  update public.profiles set phone = '3001112233' where id = c_pasajero;

  -- Una solicitud TERMINADA (cancelada) con referencia de recogida: es el
  -- historial que debe sobrevivir anonimizado.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, expires_at, pickup_reference,
    cancelled_at, cancelled_by
  ) values (
    'ee1e7e57-0000-4000-8000-0000000000aa', c_pasajero, 'cancelled', 1,
    extensions.st_point(-75.0745, 6.9070)::geography, 'El parque',
    extensions.st_point(-75.0762, 6.9089)::geography, 'La terminal',
    '3001112233', now() + interval '1 hour', 'casa de la abuela, porton verde',
    now(), 'passenger'
  );
end
$montaje$;


-- ---------------------------------------------------------------------------
-- 1-2. Permisos de ejecucion
-- ---------------------------------------------------------------------------
do $permisos$
declare v_ok boolean;
begin
  select has_function_privilege('anon', 'public.delete_my_account()', 'execute') into v_ok;
  insert into resultados values (1, 'anon NO puede ejecutar delete_my_account',
    'false', v_ok::text, v_ok = false);

  select has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') into v_ok;
  insert into resultados values (2, 'authenticated SI puede ejecutar delete_my_account',
    'true', v_ok::text, v_ok = true);
end
$permisos$;


-- ---------------------------------------------------------------------------
-- 3. Un conductor no puede borrar su propia cuenta
-- ---------------------------------------------------------------------------
do $conductor$
declare
  c_pasajero constant uuid := 'ee1e7e57-0000-4000-8000-000000000001';
  v_hint text := '(sin excepcion)';
begin
  -- Se le pone rol conductor solo para esta comprobacion. Hay que desactivar
  -- `profiles_protect_columns`, que revierte cualquier cambio de rol cuando no
  -- hay sesion de administrador (hallazgo H5). Todo dentro de la transaccion
  -- que se deshace.
  alter table public.profiles disable trigger profiles_protect_columns;
  update public.profiles set role = 'driver' where id = c_pasajero;
  alter table public.profiles enable trigger profiles_protect_columns;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', c_pasajero, 'role', 'authenticated')::text);

  begin
    perform public.delete_my_account();
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  alter table public.profiles disable trigger profiles_protect_columns;
  update public.profiles set role = 'passenger' where id = c_pasajero;
  alter table public.profiles enable trigger profiles_protect_columns;

  insert into resultados values (3, 'Un conductor no puede borrar su cuenta',
    'ACCOUNT_DELETE_NOT_PASSENGER', v_hint, v_hint = 'ACCOUNT_DELETE_NOT_PASSENGER');
end
$conductor$;


-- ---------------------------------------------------------------------------
-- 4. No se puede borrar con un servicio en curso
-- ---------------------------------------------------------------------------
do $encurso$
declare
  c_pasajero constant uuid := 'ee1e7e57-0000-4000-8000-000000000001';
  v_hint text := '(sin excepcion)';
begin
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, expires_at
  ) values (
    'ee1e7e57-0000-4000-8000-0000000000bb', c_pasajero, 'searching', 1,
    extensions.st_point(-75.0745, 6.9070)::geography, 'El parque',
    extensions.st_point(-75.0762, 6.9089)::geography, 'La terminal',
    '3001112233', now() + interval '1 hour'
  );

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', c_pasajero, 'role', 'authenticated')::text);

  begin
    perform public.delete_my_account();
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint;
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  delete from public.ride_requests where id = 'ee1e7e57-0000-4000-8000-0000000000bb';

  insert into resultados values (4, 'No se puede borrar con un servicio en curso',
    'ACCOUNT_DELETE_ACTIVE_RIDE', v_hint, v_hint = 'ACCOUNT_DELETE_ACTIVE_RIDE');
end
$encurso$;


-- ---------------------------------------------------------------------------
-- 5-9. Camino feliz
-- ---------------------------------------------------------------------------
do $feliz$
declare
  c_pasajero constant uuid := 'ee1e7e57-0000-4000-8000-000000000001';
  c_marcador constant uuid := 'de1e7ed0-0000-4000-8000-000000000000';
  c_solicitud constant uuid := 'ee1e7e57-0000-4000-8000-0000000000aa';
  v_error text := '(ninguno)';
  v_users int; v_perfil int; v_dueno uuid; v_ref text; v_marcador int; v_marcador_nombre text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', c_pasajero, 'role', 'authenticated')::text);

  begin
    perform public.delete_my_account();
  exception when others then
    v_error := sqlerrm;
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  insert into resultados values (5, 'delete_my_account no lanza excepcion en el camino feliz',
    '(ninguno)', v_error, v_error = '(ninguno)');

  select count(*) into v_users from auth.users where id = c_pasajero;
  insert into resultados values (6, 'La fila de auth.users desaparece',
    '0', v_users::text, v_users = 0);

  select count(*) into v_perfil from public.profiles where id = c_pasajero;
  insert into resultados values (7, 'El perfil desaparece (cascada)',
    '0', v_perfil::text, v_perfil = 0);

  select passenger_id, pickup_reference into v_dueno, v_ref
  from public.ride_requests where id = c_solicitud;
  insert into resultados values (8, 'La solicitud terminada pasa al perfil marcador',
    c_marcador::text, coalesce(v_dueno::text, '(nula)'), v_dueno = c_marcador);
  insert into resultados values (9, 'La referencia de recogida (texto libre) se borra',
    '(nula)', coalesce(v_ref, '(nula)'), v_ref is null);

  select count(*), max(full_name) into v_marcador, v_marcador_nombre
  from public.profiles where id = c_marcador;
  insert into resultados values (10, 'El perfil marcador sigue intacto',
    'Cuenta eliminada', coalesce(v_marcador_nombre, '(no existe)'),
    v_marcador = 1 and v_marcador_nombre = 'Cuenta eliminada');
end
$feliz$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion, r.esperado, r.obtenido
from resultados r
union all
select
  999,
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
