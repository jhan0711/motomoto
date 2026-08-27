-- =============================================================================
-- FASE 20, PASO 4b: dar de alta un conductor desde el panel
-- =============================================================================
--
-- Lo ultimo que le faltaba al panel para poder incorporar personal sin tocar la
-- base de datos a mano.
--
-- POR QUE NO SE PUEDE HACER DESDE EL NAVEGADOR, y por que este paso se aparto
-- del 4a. Un conductor **no puede auto-registrarse** (seccion 6), asi que la
-- cuenta la tiene que crear el panel, y con la clave publicable eso no sale:
--
--   - `auth.signUp` **inicia sesion como el usuario recien creado**, o sea que
--     echaria al administrador de su propia sesion
--   - el perfil nace con rol `passenger`, y cambiarlo con un UPDATE no funciona:
--     lo revierte `profiles_protect_columns` (regla 1 de las aprendidas)
--
-- LA DECISION (D250, tomada con el usuario el 2026-08-27), entre dos caminos:
--
--   a) meter la clave `service_role` en el servidor de Next y usar
--      `auth.admin.createUser`, que es la via oficial de Supabase
--   b) una funcion `security definer` en la base de datos, como todas las demas
--      del panel
--
-- **Se eligio (b), y el motivo es el alcance del poder.** La `service_role`
-- salta toda la RLS **para cualquier operacion**: quien la tenga puede leer y
-- escribir cualquier cosa de cualquier usuario, y hay que custodiarla. Esta
-- funcion corre con privilegios tambien, pero **acotada a una sola operacion y
-- con `is_admin()` comprobado dentro**. Un agujero aqui da de alta conductores;
-- un agujero con la `service_role` da todo.
--
-- Ademas, el proyecto ya crea cuentas asi: `seed_admin.sql` y
-- `seed_test_driver.sql` llevan meses haciendolo, con las mismas cautelas.
--
-- LA CONTRASENA LA GENERA EL SISTEMA Y SE MUESTRA UNA VEZ (D251). El panel no
-- deja elegirla: cuando las elige una persona para veinte conductores, acaban
-- siendo todas parecidas. Se devuelve **solo como resultado de la llamada**, y
-- **NUNCA se escribe en la auditoria**.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- generate_initial_password
-- -----------------------------------------------------------------------------
--
-- Una contrasena que se pueda DICTAR POR TELEFONO sin equivocarse, que es como
-- va a llegarle al conductor. Por eso el alfabeto excluye los caracteres que se
-- confunden al hablar y al leer: 0 y O, 1 y l y I, 5 y S.
--
-- Formato: `Moto-XXXX-9999`. Cumple los ocho caracteres que exige la aplicacion
-- (`newPassword` en `src/features/auth/schemas.ts`) con holgura.
create or replace function public.generate_initial_password()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  -- Sin O, sin I ni L, sin S: se confunden con 0, 1 y 5 al dictarlas.
  c_letras constant text := 'ABCDEFGHJKMNPQRTUVWXYZ';
  v_letras text := '';
  v_numeros text := '';
  i integer;
begin
  for i in 1..4 loop
    v_letras := v_letras ||
      substr(c_letras, 1 + floor(random() * length(c_letras))::integer, 1);
  end loop;

  for i in 1..4 loop
    -- Del 2 al 9: se saltan el 0 y el 1 por la misma razon que las letras.
    v_numeros := v_numeros || (2 + floor(random() * 8))::text;
  end loop;

  return 'Moto-' || v_letras || '-' || v_numeros;
end;
$$;

comment on function public.generate_initial_password() is
  'Contrasena inicial legible al dictarla: sin caracteres que se confundan.';

revoke all on function public.generate_initial_password() from public;


-- -----------------------------------------------------------------------------
-- admin_create_driver
-- -----------------------------------------------------------------------------

create or replace function public.admin_create_driver(
  p_email text,
  p_full_name text,
  p_phone text,
  -- Opcional: si se le entrega motorraton en el mismo momento del alta.
  p_vehicle_id uuid default null
)
returns table (
  driver_id uuid,
  -- **La unica vez que esta contrasena existe fuera de su cifrado.** No se
  -- guarda en ningun sitio legible ni se escribe en la auditoria.
  initial_password text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid();
  v_password text;
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede dar de alta conductores'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Ese correo no es valido'
      using errcode = 'P0001', hint = 'INVALID_EMAIL';
  end if;

  if length(trim(coalesce(p_full_name, ''))) < 3 then
    raise exception 'El nombre debe tener al menos 3 caracteres'
      using errcode = 'P0001', hint = 'NAME_TOO_SHORT';
  end if;

  -- Las mismas reglas que la aplicacion, repetidas aqui porque esta funcion se
  -- salta el cliente entero.
  if coalesce(p_phone, '') !~ '^3[0-9]{9}$' then
    raise exception 'El telefono debe ser un celular colombiano de 10 digitos'
      using errcode = 'P0001', hint = 'INVALID_PHONE';
  end if;

  if exists (select 1 from auth.users u where lower(u.email) = v_email) then
    raise exception 'Ya existe una cuenta con ese correo'
      using errcode = 'P0001', hint = 'EMAIL_TAKEN';
  end if;

  if p_vehicle_id is not null then
    if not exists (
      select 1 from public.vehicles where id = p_vehicle_id and status = 'active'
    ) then
      raise exception 'Ese motorraton no existe o no esta activo'
        using errcode = 'P0001', hint = 'VEHICLE_NOT_ACTIVE';
    end if;
  end if;

  v_password := public.generate_initial_password();

  -- LAS CUATRO COLUMNAS DE TOKEN VAN A CADENA VACIA Y NO A NULO. Es la
  -- diferencia entre un conductor que puede iniciar sesion y uno que no: GoTrue
  -- las lee como texto y un nulo hace que su consulta falle con un 500
  -- "Database error querying schema", que no dice nada sobre la causa. **Es el
  -- error E28 de la Fase 12**, que costo encontrar, y por eso esta escrito aqui
  -- y no solo en las semillas.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    v_email, extensions.crypt(v_password, extensions.gen_salt('bf')),
    -- Confirmado de entrada: la empresa da de alta a alguien que tiene delante,
    -- no a una direccion que haya que verificar por correo.
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', trim(p_full_name), 'phone', p_phone),
    '', '', '', ''
  );

  -- El disparador de alta ya creo el perfil, con rol `passenger`. Se SUSTITUYE
  -- la fila en vez de actualizarla: `profiles_protect_columns` revierte
  -- cualquier UPDATE del rol, y es BEFORE UPDATE, asi que no cubre INSERT.
  delete from public.profiles where id = v_id;

  insert into public.profiles (id, full_name, phone, role, status)
  values (v_id, trim(p_full_name), p_phone, 'driver', 'active');

  -- NACE PENDIENTE DE APROBAR, no aprobado. Dar de alta y autorizar a trabajar
  -- son dos decisiones distintas -es D245 aplicado al alta-, y la segunda suele
  -- depender de unos papeles que aun no estan.
  insert into public.drivers (id, approval_status) values (v_id, 'pending');

  if p_vehicle_id is not null then
    insert into public.driver_vehicle_assignments (driver_id, vehicle_id, assigned_by)
    values (v_id, p_vehicle_id, (select auth.uid()));
  end if;

  -- **SIN LA CONTRASENA.** La auditoria dice que se dio de alta a alguien, no
  -- con que clave: un registro que la guardara seria un almacen de contrasenas
  -- en claro que cualquier administrador podria leer.
  perform public.log_admin_action(
    'create_driver', 'profiles', v_id::text, null,
    jsonb_build_object('email', v_email, 'full_name', trim(p_full_name),
                       'phone', p_phone, 'vehicle_id', p_vehicle_id)
  );

  return query select v_id, v_password;
end;
$$;

comment on function public.admin_create_driver(text, text, text, uuid) is
  'Da de alta un conductor con contrasena generada. La devuelve una sola vez.';

revoke all on function public.admin_create_driver(text, text, text, uuid) from public;
grant execute on function public.admin_create_driver(text, text, text, uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_reset_driver_password
-- -----------------------------------------------------------------------------
--
-- El complemento inevitable del alta: un conductor olvida su contrasena y la
-- empresa tiene que poder darle otra sin entrar en el panel de Supabase.
--
-- **No se puede usar con una cuenta que no sea de conductor.** Sin esa
-- comprobacion seria una via para que un administrador cambiara la contrasena de
-- otro administrador -o de un pasajero- y entrara con su cuenta.
create or replace function public.admin_reset_driver_password(p_driver_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_password text;
  v_role public.user_role;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede restablecer contrasenas'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select role into v_role from public.profiles where id = p_driver_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  if v_role <> 'driver' then
    raise exception 'Esa cuenta no es de un conductor'
      using errcode = 'P0001', hint = 'NOT_A_DRIVER';
  end if;

  v_password := public.generate_initial_password();

  update auth.users
  set encrypted_password = extensions.crypt(v_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = p_driver_id;

  -- Otra vez: se registra QUE se restablecio, nunca a que.
  perform public.log_admin_action(
    'reset_driver_password', 'profiles', p_driver_id::text, null, null
  );

  return v_password;
end;
$$;

comment on function public.admin_reset_driver_password(uuid) is
  'Genera una contrasena nueva para un conductor. Solo para cuentas de conductor.';

revoke all on function public.admin_reset_driver_password(uuid) from public;
grant execute on function public.admin_reset_driver_password(uuid) to authenticated;
