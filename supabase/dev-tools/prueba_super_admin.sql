-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba del bloque super admin, paso 1: el rol `super_admin`, que `is_admin()`
-- lo incluye, y que un administrador ya no puede tocar la cuenta de otro (D265).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_super_admin.sql
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
  v_super  uuid := 'f5000000-0000-4000-8000-0000000000a0';
  v_admin1 uuid := 'f5000000-0000-4000-8000-0000000000a1';
  v_admin2 uuid := 'f5000000-0000-4000-8000-0000000000a2';
  v_pas    uuid := 'f5000000-0000-4000-8000-0000000000b1';
  v_b boolean;
  v_h text;
  v_estado text;
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_super,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.sa.super@motomoto-qa.co',  now(), now()),
    (v_admin1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.sa.admin1@motomoto-qa.co', now(), now()),
    (v_admin2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.sa.admin2@motomoto-qa.co', now(), now()),
    (v_pas,    '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zz.sa.pas@motomoto-qa.co',    now(), now());

  delete from public.profiles where id in (v_super, v_admin1, v_admin2, v_pas);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_super,  'Zz sa super',  '3000000901', 'super_admin', 'active'),
    (v_admin1, 'Zz sa admin1', '3000000902', 'admin',       'active'),
    (v_admin2, 'Zz sa admin2', '3000000903', 'admin',       'active'),
    (v_pas,    'Zz sa pas',    '3000000904', 'passenger',   'active');

  -- 1-3. is_super_admin() / is_admin() con la identidad de cada uno
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_super, 'role', 'authenticated')::text);
  select public.is_super_admin() into v_b;
  insert into resultados values (1, 'is_super_admin() cierto para el super admin', 'true', v_b::text, v_b);
  select public.is_admin() into v_b;
  insert into resultados values (2, 'is_admin() cierto tambien para el super admin', 'true', v_b::text, v_b);

  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin1, 'role', 'authenticated')::text);
  select public.is_super_admin() into v_b;
  insert into resultados values (3, 'is_super_admin() falso para un administrador normal', 'false', v_b::text, v_b = false);
  select public.is_admin() into v_b;
  insert into resultados values (4, 'is_admin() cierto para un administrador normal', 'true', v_b::text, v_b);

  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  select public.is_admin() into v_b;
  insert into resultados values (5, 'is_admin() falso para un pasajero', 'false', v_b::text, v_b = false);

  -- 6. Un administrador NO bloquea a otro administrador (D265)
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin1, 'role', 'authenticated')::text);
  begin
    perform public.admin_set_account_status(v_admin2, 'blocked', null);
    insert into resultados values (6, 'Un administrador NO bloquea a otro administrador',
      'NEEDS_SUPER_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Un administrador NO bloquea a otro administrador',
      'NEEDS_SUPER_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NEEDS_SUPER_ADMIN');
  end;

  -- 7. Ni al super admin
  begin
    perform public.admin_set_account_status(v_super, 'blocked', null);
    insert into resultados values (7, 'Un administrador NO bloquea al super admin',
      'NEEDS_SUPER_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Un administrador NO bloquea al super admin',
      'NEEDS_SUPER_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NEEDS_SUPER_ADMIN');
  end;

  -- 8. Pero SI bloquea a un pasajero (no se rompio lo que ya andaba)
  begin
    perform public.admin_set_account_status(v_pas, 'blocked', null);
    select status::text into v_estado from public.profiles where id = v_pas;
    insert into resultados values (8, 'Un administrador SI bloquea a un pasajero',
      'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Un administrador SI bloquea a un pasajero',
      'blocked', 'rechazo: ' || coalesce(nullif(v_h, ''), sqlstate), false);
  end;

  -- 9. El super admin SI bloquea a un administrador
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_super, 'role', 'authenticated')::text);
  begin
    perform public.admin_set_account_status(v_admin2, 'blocked', null);
    select status::text into v_estado from public.profiles where id = v_admin2;
    insert into resultados values (9, 'El super admin SI bloquea a un administrador',
      'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (9, 'El super admin SI bloquea a un administrador',
      'blocked', 'rechazo: ' || coalesce(nullif(v_h, ''), sqlstate), false);
  end;

  -- 10. Y lo desbloquea
  begin
    perform public.admin_set_account_status(v_admin2, 'active', null);
    select status::text into v_estado from public.profiles where id = v_admin2;
    insert into resultados values (10, 'El super admin SI desbloquea a un administrador',
      'active', coalesce(v_estado, 'nulo'), v_estado = 'active');
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (10, 'El super admin SI desbloquea a un administrador',
      'active', 'rechazo: ' || coalesce(nullif(v_h, ''), sqlstate), false);
  end;

  -- 11. Ni el super admin puede bloquearse a si mismo
  begin
    perform public.admin_set_account_status(v_super, 'blocked', null);
    insert into resultados values (11, 'Ni el super admin se bloquea a si mismo',
      'CANNOT_CHANGE_OWN_ACCOUNT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (11, 'Ni el super admin se bloquea a si mismo',
      'CANNOT_CHANGE_OWN_ACCOUNT', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'CANNOT_CHANGE_OWN_ACCOUNT');
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
