-- =============================================================================
-- BLOQUE SUPER ADMIN, paso 2: el super admin da de alta y gestiona
-- administradores.
-- =============================================================================
--
-- Tres funciones, todas `security definer` y con `is_super_admin()` dentro como
-- su propia puerta (D264, D266). El bloqueo/desbloqueo de un administrador ya
-- quedo restringido al super admin en el paso 1 (D265, en
-- `admin_set_account_status`).
--
--   admin_create_admin        alta de un administrador, con contrasena inicial
--   admin_reset_admin_password restablece la contrasena de un administrador
--   admin_list_admins         el listado, para la pantalla del panel
--
-- MISMO CRITERIO QUE D250 PARA LOS CONDUCTORES: se usa una funcion con
-- privilegios acotada, no la clave `service_role`. La contrasena inicial la
-- genera el sistema en el formato dictable de D251 y **nunca se escribe en la
-- auditoria**: un registro que la guardara seria un almacen de contrasenas en
-- claro.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_create_admin
-- -----------------------------------------------------------------------------
create or replace function public.admin_create_admin(
  p_email text,
  p_full_name text,
  p_phone text
)
returns table (admin_id uuid, initial_password text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid();
  v_password text;
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.is_super_admin() then
    raise exception 'Solo el super administrador puede dar de alta administradores'
      using errcode = 'P0001', hint = 'NEEDS_SUPER_ADMIN';
  end if;

  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Ese correo no es valido'
      using errcode = 'P0001', hint = 'INVALID_EMAIL';
  end if;

  if length(trim(coalesce(p_full_name, ''))) < 3 then
    raise exception 'El nombre debe tener al menos 3 caracteres'
      using errcode = 'P0001', hint = 'NAME_TOO_SHORT';
  end if;

  if coalesce(p_phone, '') !~ '^3[0-9]{9}$' then
    raise exception 'El telefono debe ser un celular colombiano de 10 digitos'
      using errcode = 'P0001', hint = 'INVALID_PHONE';
  end if;

  if exists (select 1 from auth.users u where lower(u.email) = v_email) then
    raise exception 'Ya existe una cuenta con ese correo'
      using errcode = 'P0001', hint = 'EMAIL_TAKEN';
  end if;

  v_password := public.generate_initial_password();

  -- Las cuatro columnas de token a cadena vacia y NO a nulo, o la cuenta no
  -- puede iniciar sesion (error E28 de la Fase 12). Confirmado de entrada: la
  -- empresa da de alta a alguien que tiene delante.
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    v_email, extensions.crypt(v_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', trim(p_full_name), 'phone', p_phone),
    '', '', '', ''
  );

  -- El disparador de alta ya creo el perfil con rol `passenger`. Se sustituye la
  -- fila en vez de actualizarla: `profiles_protect_columns` revierte cualquier
  -- UPDATE del rol y es BEFORE UPDATE, asi que no cubre INSERT.
  delete from public.profiles where id = v_id;

  insert into public.profiles (id, full_name, phone, role, status)
  values (v_id, trim(p_full_name), p_phone, 'admin', 'active');

  -- SIN LA CONTRASENA en la auditoria.
  perform public.log_admin_action(
    'create_admin', 'profiles', v_id::text, null,
    jsonb_build_object('email', v_email, 'full_name', trim(p_full_name), 'phone', p_phone)
  );

  return query select v_id, v_password;
end;
$$;

comment on function public.admin_create_admin(text, text, text) is
  'Da de alta un administrador con contrasena inicial. Solo el super admin (D266).';

revoke all on function public.admin_create_admin(text, text, text) from public, anon;
grant execute on function public.admin_create_admin(text, text, text) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_reset_admin_password
-- -----------------------------------------------------------------------------
create or replace function public.admin_reset_admin_password(p_admin_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_password text;
  v_role public.user_role;
begin
  if not public.is_super_admin() then
    raise exception 'Solo el super administrador puede restablecer la contrasena de un administrador'
      using errcode = 'P0001', hint = 'NEEDS_SUPER_ADMIN';
  end if;

  select role into v_role from public.profiles where id = p_admin_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  -- Solo administradores. Para su propia contrasena el super admin usa la
  -- recuperacion por correo como todo el mundo, no esta funcion.
  if v_role <> 'admin' then
    raise exception 'Esa cuenta no es de un administrador'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN_ACCOUNT';
  end if;

  v_password := public.generate_initial_password();

  update auth.users
  set encrypted_password = extensions.crypt(v_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = p_admin_id;

  perform public.log_admin_action(
    'reset_admin_password', 'profiles', p_admin_id::text, null, null
  );

  return v_password;
end;
$$;

comment on function public.admin_reset_admin_password(uuid) is
  'Restablece la contrasena de un administrador. Solo el super admin.';

revoke all on function public.admin_reset_admin_password(uuid) from public, anon;
grant execute on function public.admin_reset_admin_password(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_list_admins
-- -----------------------------------------------------------------------------
-- `security definer` con `is_super_admin()`: aunque `profiles_select_admin` deja
-- a cualquier administrador ver los perfiles, la lista de administradores -con
-- su correo- es una pantalla del dueno, y el camino de datos va con la pantalla.
create or replace function public.admin_list_admins()
returns table (
  admin_id uuid,
  full_name text,
  phone text,
  email text,
  account_status user_status,
  is_super_admin boolean,
  created_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Solo el super administrador puede ver la lista de administradores'
      using errcode = 'P0001', hint = 'NEEDS_SUPER_ADMIN';
  end if;

  return query
    select
      p.id,
      p.full_name,
      p.phone,
      u.email::text,
      p.status,
      p.role = 'super_admin',
      p.created_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.role in ('admin', 'super_admin')
    -- El super admin arriba, luego por nombre.
    order by (p.role = 'super_admin') desc, p.full_name;
end;
$$;

comment on function public.admin_list_admins() is
  'Lista de administradores y del super admin, con su correo. Solo el super admin.';

revoke all on function public.admin_list_admins() from public, anon;
grant execute on function public.admin_list_admins() to authenticated;
