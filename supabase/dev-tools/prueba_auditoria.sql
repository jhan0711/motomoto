-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260826170000_admin_audit_and_account_status.sql` (Fase 20,
-- paso 2: auditoria de acciones administrativas y bloqueo de cuentas).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_auditoria.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE SE INTENTA ROMPER A PROPOSITO. La mitad de las comprobaciones no
-- prueban que la funcion trabaje: prueban que NO SE PUEDE RODEAR. Un pasajero
-- llamandola, un administrador bloqueado, un UPDATE directo a la columna, un
-- INSERT inventado en la auditoria y un intento de ponerse la marca del
-- disparador a mano. Si cualquiera de esos pasara, la funcion podria estar
-- perfecta y el sistema seguiria sin auditoria.
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
  -- El permiso se le da tambien a `anon`. Si solo se le diera a `authenticated`,
  -- las comprobaciones sin sesion se caerian con un 42501 sobre esta tabla y no
  -- sobre lo que pretenden medir. Es el error que ya paso en prueba_tarifas.sql.
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Montaje
-- -----------------------------------------------------------------------------
--
-- Se resuelven los identificadores ANTES de suplantar a nadie. `profiles` tiene
-- RLS, y una subconsulta ejecutada ya como `authenticated` sin auth.uid() puesto
-- veria cero filas: la leccion de prueba_recaudo.sql.

do $montaje$
declare
  v_admin  uuid := 'aa000000-0000-4000-8000-000000000001';
  v_admin2 uuid := 'aa000000-0000-4000-8000-000000000002';
  v_vict   uuid := 'aa000000-0000-4000-8000-000000000003';
begin
  -- `profiles.id` apunta a `auth.users`, asi que las cuentas tienen que existir
  -- alli primero. Aqui NO hacen falta las cuatro columnas de token de E28: estas
  -- cuentas no van a iniciar sesion de verdad, solo se suplantan con
  -- `request.jwt.claims`, que no pasa por GoTrue.
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.prueba.admin1@motomoto-qa.co', now(), now()),
    (v_admin2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.prueba.admin2@motomoto-qa.co', now(), now()),
    (v_vict,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.prueba.pasajero@motomoto-qa.co', now(), now());

  -- El disparador de alta ya creo un perfil por cada uno, con rol passenger. Se
  -- sustituyen las filas en vez de actualizarlas, que es la unica via de cambiar
  -- el rol: la misma maniobra de seed_admin.sql, y ahora con mas motivo, porque
  -- este mismo paso le quito al disparador la exencion del administrador.
  delete from public.profiles where id in (v_admin, v_admin2, v_vict);

  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,  'Zz prueba admin uno', '3000000001', 'admin',     'active'),
    (v_admin2, 'Zz prueba admin dos', '3000000002', 'admin',     'active'),
    (v_vict,   'Zz prueba pasajero',  '3000000003', 'passenger', 'active');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El camino que si tiene que funcionar
-- -----------------------------------------------------------------------------

do $feliz$
declare
  v_admin constant uuid := 'aa000000-0000-4000-8000-000000000001';
  v_vict  constant uuid := 'aa000000-0000-4000-8000-000000000003';
  v_estado text;
  v_n integer;
  v_log record;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Bloquear deja la cuenta bloqueada.
  perform public.admin_set_account_status(v_vict, 'blocked', 'Prueba de bloqueo');

  select status::text into v_estado from public.profiles where id = v_vict;
  insert into resultados values (1, 'Bloquear una cuenta la deja bloqueada',
    'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');

  -- 2. Y deja UNA entrada de auditoria. Esta es la comprobacion central del
  --    paso: hasta hoy la tabla llevaba cero filas desde la Fase 5.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_vict::text and action = 'block_account';
  insert into resultados values (2, 'El bloqueo deja una entrada de auditoria',
    '1', v_n::text, v_n = 1);

  -- 3. La entrada dice quien, que habia antes y que hay despues. Sin el estado
  --    anterior la auditoria no responde "que cambio", que es para lo que sirve.
  select actor_id, before_data->>'status' as antes, after_data->>'status' as despues,
         after_data->>'reason' as motivo
    into v_log
  from public.admin_audit_logs
  where entity_id = v_vict::text and action = 'block_account';

  insert into resultados values (3, 'La entrada guarda actor, estado anterior y posterior',
    v_admin::text || ', active, blocked, Prueba de bloqueo',
    coalesce(v_log.actor_id::text, 'nulo') || ', ' || coalesce(v_log.antes, 'nulo') ||
      ', ' || coalesce(v_log.despues, 'nulo') || ', ' || coalesce(v_log.motivo, 'nulo'),
    v_log.actor_id = v_admin and v_log.antes = 'active'
      and v_log.despues = 'blocked' and v_log.motivo = 'Prueba de bloqueo');

  -- 4. Desbloquear funciona y se registra con su propia accion, no como bloqueo.
  perform public.admin_set_account_status(v_vict, 'active', null);

  select status::text into v_estado from public.profiles where id = v_vict;
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_vict::text and action = 'unblock_account';

  insert into resultados values (4, 'Desbloquear devuelve la cuenta y se registra aparte',
    'active, 1', coalesce(v_estado, 'nulo') || ', ' || v_n::text,
    v_estado = 'active' and v_n = 1);

  -- 5. Un administrador lee la auditoria. Es la politica de la Fase 5, que
  --    hasta hoy nunca se habia ejercido porque no habia ni filas ni admins.
  select count(*) into v_n from public.admin_audit_logs where entity_id = v_vict::text;
  insert into resultados values (5, 'Un administrador lee la auditoria',
    '2', v_n::text, v_n = 2);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$feliz$;


-- -----------------------------------------------------------------------------
-- Lo que tiene que fallar
-- -----------------------------------------------------------------------------

do $romper$
declare
  v_admin  constant uuid := 'aa000000-0000-4000-8000-000000000001';
  v_admin2 constant uuid := 'aa000000-0000-4000-8000-000000000002';
  v_vict   constant uuid := 'aa000000-0000-4000-8000-000000000003';
  v_estado text;
  v_n integer;
  v_h text;
begin
  -- ---------------------------------------------------------------------------
  -- Como administrador
  -- ---------------------------------------------------------------------------
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 6. No puede bloquearse a si mismo: perderia el panel sin vuelta atras.
  begin
    perform public.admin_set_account_status(v_admin, 'blocked', null);
    insert into resultados values (6, 'Un administrador NO puede bloquearse a si mismo',
      'CANNOT_CHANGE_OWN_ACCOUNT', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Un administrador NO puede bloquearse a si mismo',
      'CANNOT_CHANGE_OWN_ACCOUNT', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'CANNOT_CHANGE_OWN_ACCOUNT');
  end;

  -- 7. No se registra un cambio que no cambia nada.
  begin
    perform public.admin_set_account_status(v_vict, 'active', null);
    insert into resultados values (7, 'Poner el estado que ya tenia se rechaza',
      'STATUS_UNCHANGED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (7, 'Poner el estado que ya tenia se rechaza',
      'STATUS_UNCHANGED', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'STATUS_UNCHANGED');
  end;

  -- 8. Una cuenta que no existe.
  begin
    perform public.admin_set_account_status(
      'aa000000-0000-4000-8000-0000000000ff'::uuid, 'blocked', null);
    insert into resultados values (8, 'Una cuenta inexistente se rechaza',
      'PROFILE_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Una cuenta inexistente se rechaza',
      'PROFILE_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'PROFILE_NOT_FOUND');
  end;

  -- 9. LA COMPROBACION QUE JUSTIFICA TODO EL PASO. Un administrador intenta
  --    bloquear con UPDATE directo, saltandose la funcion. La politica se lo
  --    permite, pero el disparador le revierte el estado: el cambio no ocurre.
  --    Si esto se pusiera en rojo, el panel podria bloquear sin dejar rastro.
  update public.profiles set status = 'blocked' where id = v_vict;
  select status::text into v_estado from public.profiles where id = v_vict;
  insert into resultados values (9,
    'Un UPDATE directo del estado NO surte efecto ni con sesion de administrador',
    'active', coalesce(v_estado, 'nulo'), v_estado = 'active');

  -- 10. Lo mismo con el rol: nadie se asciende con un UPDATE.
  update public.profiles set role = 'admin' where id = v_vict;
  select role::text into v_estado from public.profiles where id = v_vict;
  insert into resultados values (10, 'Un UPDATE directo del rol tampoco surte efecto',
    'passenger', coalesce(v_estado, 'nulo'), v_estado = 'passenger');

  -- 11. Y ese UPDATE que no hizo nada tampoco escribio auditoria, claro. Va con
  --     la 9 vigilandola: sin esta, la 9 podria estar en verde porque el update
  --     fallo por cualquier otro motivo.
  select count(*) into v_n from public.admin_audit_logs where entity_id = v_vict::text;
  insert into resultados values (11, 'El UPDATE directo no anadio ninguna entrada',
    '2', v_n::text, v_n = 2);

  -- 12. No se pueden inventar entradas de auditoria a mano. La tabla no tiene
  --     politica de INSERT para nadie, ni siquiera para el administrador.
  begin
    insert into public.admin_audit_logs (actor_id, action, entity_type, entity_id)
    values (v_admin, 'accion_inventada', 'profiles', v_vict::text);
    insert into resultados values (12, 'Un administrador NO puede escribir auditoria a mano',
      'rechaza', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'Un administrador NO puede escribir auditoria a mano',
      'rechaza', sqlstate, true);
  end;

  -- 13. Tampoco se puede borrar lo que ya quedo registrado. Una auditoria que el
  --     auditado puede limpiar no sirve de nada.
  delete from public.admin_audit_logs where entity_id = v_vict::text;
  select count(*) into v_n from public.admin_audit_logs where entity_id = v_vict::text;
  insert into resultados values (13, 'La auditoria no se puede borrar',
    '2', v_n::text, v_n = 2);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- ---------------------------------------------------------------------------
  -- Como pasajero
  -- ---------------------------------------------------------------------------
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_vict, 'role', 'authenticated')::text);

  -- 14. Un pasajero no bloquea a nadie.
  begin
    perform public.admin_set_account_status(v_admin2, 'blocked', null);
    insert into resultados values (14, 'Un pasajero NO puede bloquear cuentas',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (14, 'Un pasajero NO puede bloquear cuentas',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'NOT_AN_ADMIN');
  end;

  -- 15. Ni escribe auditoria por su cuenta.
  begin
    perform public.log_admin_action('lo_que_sea', 'profiles', v_vict::text, null, null);
    insert into resultados values (15, 'Un pasajero NO puede registrar acciones',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (15, 'Un pasajero NO puede registrar acciones',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'NOT_AN_ADMIN');
  end;

  -- 16. Ni lee la auditoria ajena.
  select count(*) into v_n from public.admin_audit_logs;
  insert into resultados values (16, 'Un pasajero no ve ninguna entrada de auditoria',
    '0', v_n::text, v_n = 0);

  -- 17. EL INTENTO MAS FINO: ponerse a mano la marca del disparador para colar
  --     un UPDATE directo. No le sirve, porque la marca solo la respeta el
  --     disparador cuando ya se paso por is_admin() dentro de la funcion... y
  --     aqui se comprueba que ni siquiera asi cambia el estado.
  perform set_config('motomoto.admin_action', 'on', true);
  update public.profiles set status = 'blocked' where id = v_vict;
  select status::text into v_estado from public.profiles where id = v_vict;
  perform set_config('motomoto.admin_action', 'off', true);

  insert into resultados values (17,
    'Ponerse la marca del disparador a mano no deja cambiar el estado',
    'active', coalesce(v_estado, 'nulo'), v_estado = 'active');

  -- 17b. LA MITAD PEOR DEL MISMO AGUJERO, y la que obliga a que esta pareja
  --      exista. Cuando la 17 estuvo en rojo, esto tambien pasaba: un pasajero
  --      con la marca puesta se ascendia a administrador. Con el estado se
  --      queda fuera del sistema alguien; con el rol se queda dentro del panel
  --      cualquiera.
  perform set_config('motomoto.admin_action', 'on', true);
  update public.profiles set role = 'admin' where id = v_vict;
  select role::text into v_estado from public.profiles where id = v_vict;
  perform set_config('motomoto.admin_action', 'off', true);

  insert into resultados values (23,
    'Ponerse la marca a mano tampoco deja ascenderse a administrador',
    'passenger', coalesce(v_estado, 'nulo'), v_estado = 'passenger');

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- ---------------------------------------------------------------------------
  -- Sin sesion
  -- ---------------------------------------------------------------------------
  execute 'set local role anon';

  -- 18. Sin sesion no se bloquea.
  begin
    perform public.admin_set_account_status(v_vict, 'blocked', null);
    insert into resultados values (18, 'Sin sesion NO se puede bloquear',
      'rechaza', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (18, 'Sin sesion NO se puede bloquear',
      'rechaza', coalesce(nullif(v_h, ''), sqlstate), true);
  end;

  -- 19. Sin sesion no se registra nada.
  begin
    perform public.log_admin_action('lo_que_sea', 'profiles', null, null, null);
    insert into resultados values (19, 'Sin sesion NO se puede registrar una accion',
      'rechaza', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'Sin sesion NO se puede registrar una accion',
      'rechaza', coalesce(nullif(v_h, ''), sqlstate), true);
  end;

  -- 20. Sin sesion no se lee la auditoria.
  select count(*) into v_n from public.admin_audit_logs;
  insert into resultados values (20, 'Sin sesion no se ve ninguna entrada',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
end
$romper$;


-- -----------------------------------------------------------------------------
-- Un administrador bloqueado deja de serlo a todos los efectos
-- -----------------------------------------------------------------------------
--
-- is_admin() exige rol admin Y cuenta activa. Esta pareja lo mide de verdad:
-- sin la 21 en verde, la 22 podria estar en verde porque la funcion no
-- funciona en absoluto.

do $bloqueado$
declare
  v_admin  constant uuid := 'aa000000-0000-4000-8000-000000000001';
  v_admin2 constant uuid := 'aa000000-0000-4000-8000-000000000002';
  v_vict   constant uuid := 'aa000000-0000-4000-8000-000000000003';
  v_estado text;
  v_h text;
begin
  -- 21. Antes de bloquearlo, el segundo administrador si puede trabajar.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin2, 'role', 'authenticated')::text);

  perform public.admin_set_account_status(v_vict, 'blocked', 'Por el segundo admin');
  select status::text into v_estado from public.profiles where id = v_vict;
  insert into resultados values (21, 'Un segundo administrador activo SI puede bloquear',
    'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- El primero bloquea al segundo.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  perform public.admin_set_account_status(v_admin2, 'blocked', 'Retirado');
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 22. Y ahora el segundo ya no puede hacer nada, aunque su rol siga siendo
  --     admin. Es la mitad de is_admin() que se olvida.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin2, 'role', 'authenticated')::text);

  begin
    perform public.admin_set_account_status(v_vict, 'active', null);
    insert into resultados values (22, 'Un administrador BLOQUEADO ya no puede actuar',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (22, 'Un administrador BLOQUEADO ya no puede actuar',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'NOT_AN_ADMIN');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$bloqueado$;


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
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
