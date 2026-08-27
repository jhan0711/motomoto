-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827160000_admin_create_driver.sql` (Fase 20, paso 4b: dar de
-- alta un conductor desde el panel).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_alta_conductor.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE ESTE ARCHIVO NO PUEDE PROBAR, y se dice para que nadie lo de por
-- cubierto: **que el conductor recien creado inicie sesion de verdad**. Eso pasa
-- por GoTrue, que es un servicio aparte, y desde SQL solo se puede comprobar que
-- la fila tenga la forma que GoTrue espera -que es justo lo que E28 enseno-. La
-- prueba de sesion real la tiene que hacer una persona desde la aplicacion.
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


do $montaje$
declare
  v_admin uuid := 'b4000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'b4000000-0000-4000-8000-0000000000b1';
  v_veh   uuid := 'b4000000-0000-4000-8000-0000000000e1';
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.alta.admin@motomoto-qa.co', now(), now()),
    (v_pas,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.alta.pas@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_pas);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz alta admin',    '3000000081', 'admin',     'active'),
    (v_pas,   'Zz alta pasajero', '3000000082', 'passenger', 'active');

  insert into public.vehicles (id, unit_number, plate, model, max_passengers, status)
  values (v_veh, 9840, 'ZZA840', 'Para el alta', 3, 'active');

  -- Uno retirado, para comprobar que no se entrega en el alta.
  insert into public.vehicles (id, unit_number, plate, max_passengers, status)
  values ('b4000000-0000-4000-8000-0000000000e2', 9841, 'ZZA841', 3, 'retired');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El alta
-- -----------------------------------------------------------------------------

do $alta$
declare
  v_admin constant uuid := 'b4000000-0000-4000-8000-0000000000a1';
  v_veh   constant uuid := 'b4000000-0000-4000-8000-0000000000e1';
  v_id uuid;
  v_password text;
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  select driver_id, initial_password into v_id, v_password
  from public.admin_create_driver('ZZ.Nuevo@Motomoto-QA.co', '  Zz conductor nuevo  ',
                                  '3155551234', v_veh);

  -- SE SUELTA EL ROL SUPLANTADO PARA LEER. `authenticated` no puede consultar
  -- `auth.users` -es la regla 2 de las aprendidas en la Fase 6- y varias de las
  -- comprobaciones de abajo miran justo esa tabla. Se suplanta solo para LLAMAR
  -- a las funciones, que es donde importa la identidad.
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 1. Nace con rol de conductor y cuenta activa. Sin esto, el resto no importa:
  --    seria un pasajero mas.
  select role::text, status::text, full_name, phone into v_row
  from public.profiles where id = v_id;
  insert into resultados values (1, 'El conductor nace con rol driver y cuenta activa',
    'driver, active, Zz conductor nuevo, 3155551234',
    coalesce(v_row.role, 'nulo') || ', ' || coalesce(v_row.status, 'nulo') || ', ' ||
      coalesce(v_row.full_name, 'nulo') || ', ' || coalesce(v_row.phone, 'nulo'),
    v_row.role = 'driver' and v_row.status = 'active'
      and v_row.full_name = 'Zz conductor nuevo' and v_row.phone = '3155551234');

  -- 2. **NACE PENDIENTE DE APROBAR, no aprobado.** Dar de alta y autorizar a
  --    trabajar son dos decisiones distintas (D245 aplicado al alta).
  select approval_status::text, is_available into v_row
  from public.drivers where id = v_id;
  insert into resultados values (2, 'Nace pendiente de aprobar y no disponible',
    'pending, false',
    coalesce(v_row.approval_status, 'nulo') || ', ' || v_row.is_available::text,
    v_row.approval_status = 'pending' and not v_row.is_available);

  -- 3. El correo se guarda en minusculas: si no, "ZZ.Nuevo@..." y "zz.nuevo@..."
  --    serian dos cuentas distintas para GoTrue.
  select email into v_row from auth.users where id = v_id;
  insert into resultados values (3, 'El correo se normaliza a minusculas',
    'zz.nuevo@motomoto-qa.co', coalesce(v_row.email, 'nulo'),
    v_row.email = 'zz.nuevo@motomoto-qa.co');

  -- 4. **LA LECCION DE E28**, que es la que decide si esta cuenta sirve para
  --    algo: las cuatro columnas de token vacias y NO nulas. Con nulos, GoTrue
  --    responde 500 al iniciar sesion y el mensaje no dice nada de la causa.
  select
    (confirmation_token is not null and recovery_token is not null
     and email_change_token_new is not null and email_change is not null) as tokens_ok,
    email_confirmed_at is not null as confirmado
  into v_row
  from auth.users where id = v_id;
  insert into resultados values (4, 'Las cuatro columnas de token no son nulas (E28)',
    'true, true',
    v_row.tokens_ok::text || ', ' || v_row.confirmado::text,
    v_row.tokens_ok and v_row.confirmado);

  -- 5. **LA CONTRASENA DEVUELTA ES LA QUE ABRE LA CUENTA.** Se comprueba contra
  --    el cifrado guardado, que es lo mas cerca que se puede estar de un inicio
  --    de sesion real sin pasar por GoTrue.
  select (encrypted_password = extensions.crypt(v_password, encrypted_password)) as coincide
  into v_row
  from auth.users where id = v_id;
  insert into resultados values (5, 'La contrasena devuelta coincide con la guardada',
    'true', v_row.coincide::text, v_row.coincide);

  -- 6. Y tiene la forma esperada: ocho caracteres largos, dictable, cumpliendo
  --    el minimo de la aplicacion.
  insert into resultados values (6, 'La contrasena tiene el formato dictable',
    'Moto-XXXX-9999, mas de 8 caracteres',
    coalesce(v_password, 'nula') || ' (' || length(coalesce(v_password, '')) || ')',
    v_password ~ '^Moto-[A-Z]{4}-[2-9]{4}$' and length(v_password) >= 8);

  -- 7. Si se le entrego motorraton en el alta, queda asignado.
  select count(*) into v_n from public.driver_vehicle_assignments
  where driver_id = v_id and vehicle_id = v_veh and unassigned_at is null;
  insert into resultados values (7, 'El motorraton del alta queda asignado',
    '1', v_n::text, v_n = 1);

  -- 8. **LA AUDITORIA NO GUARDA LA CONTRASENA.** Es la comprobacion mas
  --    importante de este archivo: un registro que la guardara seria un almacen
  --    de contrasenas en claro que cualquier administrador podria leer.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_id::text
    and (after_data::text like '%' || v_password || '%'
         or before_data::text like '%' || v_password || '%');
  insert into resultados values (8, 'La contrasena NO aparece en la auditoria',
    '0', v_n::text, v_n = 0);

  -- 9. Pero el alta SI queda registrada, con el correo y el nombre. Va con la 8
  --    vigilandola: sin esta, la 8 podria estar en verde porque no se registro
  --    nada en absoluto.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_id::text and action = 'create_driver'
    and after_data->>'email' = 'zz.nuevo@motomoto-qa.co';
  insert into resultados values (9, 'Pero el alta si queda registrada',
    '1', v_n::text, v_n = 1);

  -- A partir de aqui se vuelve a suplantar: lo que se mide son llamadas a las
  -- funciones, no lecturas.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 10. El mismo correo no se puede repetir, ni cambiando mayusculas.
  begin
    perform public.admin_create_driver('zz.NUEVO@motomoto-qa.co', 'Zz otro', '3155551235', null);
    insert into resultados values (10, 'Un correo repetido se rechaza',
      'EMAIL_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (10, 'Un correo repetido se rechaza',
      'EMAIL_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'EMAIL_TAKEN');
  end;

  -- 11. Un correo mal escrito.
  begin
    perform public.admin_create_driver('esto no es un correo', 'Zz otro', '3155551236', null);
    insert into resultados values (11, 'Un correo invalido se rechaza',
      'INVALID_EMAIL', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (11, 'Un correo invalido se rechaza',
      'INVALID_EMAIL', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_EMAIL');
  end;

  -- 12. Un telefono que no es un celular colombiano.
  begin
    perform public.admin_create_driver('zz.otro@motomoto-qa.co', 'Zz otro', '123', null);
    insert into resultados values (12, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'Un telefono invalido se rechaza',
      'INVALID_PHONE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_PHONE');
  end;

  -- 13. No se entrega un motorraton retirado en el alta.
  begin
    perform public.admin_create_driver('zz.otro2@motomoto-qa.co', 'Zz otro dos', '3155551237',
                                       'b4000000-0000-4000-8000-0000000000e2'::uuid);
    insert into resultados values (13, 'Un motorraton retirado NO se entrega en el alta',
      'VEHICLE_NOT_ACTIVE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Un motorraton retirado NO se entrega en el alta',
      'VEHICLE_NOT_ACTIVE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'VEHICLE_NOT_ACTIVE');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 14. **Y CUANDO ALGO FALLA, NO QUEDA MEDIA CUENTA CREADA.** La 13 fallo
  --     despues de validar el correo y el nombre; si la funcion no fuera una
  --     transaccion, ese conductor existiria a medias.
  select count(*) into v_n from auth.users where email = 'zz.otro2@motomoto-qa.co';
  insert into resultados values (14, 'Un alta que falla no deja la cuenta a medias',
    '0', v_n::text, v_n = 0);
end
$alta$;


-- -----------------------------------------------------------------------------
-- Restablecer la contrasena
-- -----------------------------------------------------------------------------

do $reset$
declare
  v_admin constant uuid := 'b4000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'b4000000-0000-4000-8000-0000000000b1';
  v_id uuid;
  v_nueva text;
  v_coincide boolean;
  v_n integer;
  v_h text;
begin
  select id into v_id from public.profiles where full_name = 'Zz conductor nuevo';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 15. Se genera una nueva y abre la cuenta.
  v_nueva := public.admin_reset_driver_password(v_id);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  select (encrypted_password = extensions.crypt(v_nueva, encrypted_password))
  into v_coincide from auth.users where id = v_id;
  insert into resultados values (15, 'La contrasena restablecida abre la cuenta',
    'true', v_coincide::text, v_coincide);

  -- 16. Y queda registrado que se hizo, sin decir a que.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_id::text and action = 'reset_driver_password'
    and coalesce(after_data::text, '') not like '%' || v_nueva || '%';
  insert into resultados values (16, 'Se registra el restablecimiento, sin la contrasena',
    '1', v_n::text, v_n = 1);

  -- 17. **LA PUERTA QUE SE CIERRA, Y ES LA MAS PELIGROSA DE TODO EL PASO.** Sin
  --     la comprobacion de rol, un administrador podria darle contrasena nueva a
  --     OTRO ADMINISTRADOR y entrar con su cuenta. O a un pasajero, y leer sus
  --     viajes.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  begin
    perform public.admin_reset_driver_password(v_admin);
    insert into resultados values (17,
      'NO se puede restablecer la contrasena de otro administrador',
      'NOT_A_DRIVER', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (17,
      'NO se puede restablecer la contrasena de otro administrador',
      'NOT_A_DRIVER', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_A_DRIVER');
  end;

  -- 18. Ni la de un pasajero.
  begin
    perform public.admin_reset_driver_password(v_pas);
    insert into resultados values (18, 'NI la de un pasajero',
      'NOT_A_DRIVER', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (18, 'NI la de un pasajero',
      'NOT_A_DRIVER', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_A_DRIVER');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$reset$;


-- -----------------------------------------------------------------------------
-- Quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_pas constant uuid := 'b4000000-0000-4000-8000-0000000000b1';
  v_id uuid;
  v_h text;
begin
  select id into v_id from public.profiles where full_name = 'Zz conductor nuevo';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  -- 19. Un pasajero no da de alta conductores. Si pudiera, se daria de alta a si
  --     mismo con rol driver.
  begin
    perform public.admin_create_driver('zz.intruso@motomoto-qa.co', 'Zz intruso',
                                       '3155551238', null);
    insert into resultados values (19, 'Un pasajero NO puede dar de alta conductores',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (19, 'Un pasajero NO puede dar de alta conductores',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 20. Ni restablece contrasenas ajenas.
  begin
    perform public.admin_reset_driver_password(v_id);
    insert into resultados values (20, 'Un pasajero NO puede restablecer contrasenas',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Un pasajero NO puede restablecer contrasenas',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 21. Y NO PUEDE GENERAR CONTRASENAS SUELTAS. La funcion generadora no esta
  --     concedida a nadie: solo la usan las dos de arriba, que si comprueban
  --     quien llama. Concederla seria dar un oraculo de contrasenas.
  begin
    perform public.generate_initial_password();
    insert into resultados values (21, 'Nadie puede llamar al generador por su cuenta',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (21, 'Nadie puede llamar al generador por su cuenta',
      'rechaza', sqlstate, sqlstate = '42501');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$privacidad$;


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
