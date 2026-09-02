-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba del bloque super admin, paso 2: `admin_create_admin`,
-- `admin_reset_admin_password` y `admin_list_admins`.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_gestion_admins.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


do $prueba$
declare
  v_super uuid := 'f6000000-0000-4000-8000-0000000000a0';
  v_admin uuid := 'f6000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'f6000000-0000-4000-8000-0000000000b1';
  v_nuevo uuid;
  v_pass  text;
  v_pass2 text;
  v_h text;
  v_n integer;
  v_role text;
  v_status text;
  v_ok boolean;
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_super, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.ga.super@motomoto-qa.co', now(), now()),
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.ga.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.ga.pas@motomoto-qa.co',   now(), now());

  delete from public.profiles where id in (v_super, v_admin, v_pas);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_super, 'Zz ga super', '3000001001', 'super_admin', 'active'),
    (v_admin, 'Zz ga admin', '3000001002', 'admin',       'active'),
    (v_pas,   'Zz ga pas',   '3000001003', 'passenger',   'active');

  -- 1. Un administrador normal NO puede dar de alta administradores
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  begin
    perform public.admin_create_admin('nuevo1@motomoto-qa.co', 'Nuevo Uno', '3000009001');
    insert into resultados values (1, 'Un administrador normal NO da de alta administradores',
      'NEEDS_SUPER_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (1, 'Un administrador normal NO da de alta administradores',
      'NEEDS_SUPER_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NEEDS_SUPER_ADMIN');
  end;

  -- 2. Un pasajero tampoco
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  begin
    perform public.admin_create_admin('nuevo2@motomoto-qa.co', 'Nuevo Dos', '3000009002');
    insert into resultados values (2, 'Un pasajero NO da de alta administradores',
      'NEEDS_SUPER_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (2, 'Un pasajero NO da de alta administradores',
      'NEEDS_SUPER_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NEEDS_SUPER_ADMIN');
  end;

  -- 3. El super admin SI crea un administrador
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_super, 'role', 'authenticated')::text);
  select admin_id, initial_password into v_nuevo, v_pass
  from public.admin_create_admin('nuevo@motomoto-qa.co', 'Administrador Nuevo', '3000009000');
  insert into resultados values (3, 'El super admin crea un administrador y recibe la contrasena',
    'id y contrasena', coalesce(v_nuevo::text, 'nulo') || ' / ' || coalesce(length(v_pass)::text, 'nulo'),
    v_nuevo is not null and length(coalesce(v_pass, '')) >= 8);

  -- 4. Nace con rol admin y activo
  select role::text, status::text into v_role, v_status from public.profiles where id = v_nuevo;
  insert into resultados values (4, 'El administrador nuevo nace con rol admin y activo',
    'admin / active', coalesce(v_role, 'nulo') || ' / ' || coalesce(v_status, 'nulo'),
    v_role = 'admin' and v_status = 'active');

  -- 5. La contrasena sirve para iniciar sesion (crypt, como en la semilla).
  --    `auth.users` no la lee `authenticated`, asi que se baja el rol un momento.
  execute 'reset role';
  select (u.encrypted_password = extensions.crypt(v_pass, u.encrypted_password))
    into v_ok
  from auth.users u where u.id = v_nuevo;
  insert into resultados values (5, 'La contrasena inicial abre la cuenta',
    'true', coalesce(v_ok::text, 'nulo'), v_ok);
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_super, 'role', 'authenticated')::text);

  -- 6. Correo repetido se rechaza
  begin
    perform public.admin_create_admin('nuevo@motomoto-qa.co', 'Otro Mas', '3000009010');
    insert into resultados values (6, 'Un correo ya usado se rechaza',
      'EMAIL_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Un correo ya usado se rechaza',
      'EMAIL_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'EMAIL_TAKEN');
  end;

  -- 7. Telefono invalido se rechaza
  begin
    perform public.admin_create_admin('otro@motomoto-qa.co', 'Telefono Malo', '12345');
    insert into resultados values (7, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_PHONE');
  end;

  -- 8. La auditoria registra el alta SIN la contrasena
  select after_data::text into v_h from public.admin_audit_logs
  where action = 'create_admin' and entity_id = v_nuevo::text;
  insert into resultados values (8, 'La auditoria registra el alta sin la contrasena',
    'con correo, sin password',
    case when v_h ilike '%nuevo@motomoto-qa.co%' and v_h not ilike '%' || v_pass || '%'
         then 'ok' else 'mal: ' || left(coalesce(v_h, 'nulo'), 60) end,
    v_h ilike '%nuevo@motomoto-qa.co%' and v_h not ilike '%' || v_pass || '%');

  -- 9. Restablecer la contrasena del administrador nuevo
  select public.admin_reset_admin_password(v_nuevo) into v_pass2;
  execute 'reset role';
  select (u.encrypted_password = extensions.crypt(v_pass2, u.encrypted_password)
          and u.encrypted_password <> extensions.crypt(v_pass, u.encrypted_password))
    into v_ok
  from auth.users u where u.id = v_nuevo;
  insert into resultados values (9, 'Restablecer la contrasena entrega una nueva que sirve',
    'true', coalesce(v_ok::text, 'nulo'), v_ok);
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_super, 'role', 'authenticated')::text);

  -- 10. No se restablece la contrasena de un pasajero
  begin
    perform public.admin_reset_admin_password(v_pas);
    insert into resultados values (10, 'No se restablece la contrasena de una cuenta que no es admin',
      'NOT_AN_ADMIN_ACCOUNT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (10, 'No se restablece la contrasena de una cuenta que no es admin',
      'NOT_AN_ADMIN_ACCOUNT', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN_ACCOUNT');
  end;

  -- 11. admin_list_admins: el super admin ve el super + los admins con su correo.
  --     Se filtra por los tres de esta prueba: la base tiene mas (las semillas).
  select count(*) into v_n from public.admin_list_admins()
  where admin_id in (v_super, v_admin, v_nuevo);
  insert into resultados values (11, 'admin_list_admins devuelve el super y los administradores de la prueba',
    '3', v_n::text, v_n = 3);

  select bool_and(email is not null and (is_super_admin = (admin_id = v_super)))
    into v_ok from public.admin_list_admins()
  where admin_id in (v_super, v_admin, v_nuevo);
  insert into resultados values (12, 'La lista trae el correo y marca quien es el super admin',
    'true', coalesce(v_ok::text, 'nulo'), v_ok);

  -- 13. Un administrador normal NO ve la lista
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  begin
    perform public.admin_list_admins();
    insert into resultados values (13, 'Un administrador normal NO ve la lista de administradores',
      'NEEDS_SUPER_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Un administrador normal NO ve la lista de administradores',
      'NEEDS_SUPER_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NEEDS_SUPER_ADMIN');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$prueba$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion,
  r.esperado,
  r.obtenido
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
