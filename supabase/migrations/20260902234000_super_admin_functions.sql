-- =============================================================================
-- BLOQUE SUPER ADMIN, paso 1 (cont.): `is_super_admin()`, `is_admin()` lo
-- incluye, y un administrador ya no puede tocar la cuenta de otro (D265).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- is_super_admin(): la puerta extra del dueno
-- -----------------------------------------------------------------------------
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role = 'super_admin' and status = 'active'
     from public.profiles where id = (select auth.uid())),
    false
  );
$$;

comment on function public.is_super_admin() is
  'Cierto si quien llama es el dueno de la plataforma. Puerta de lo que solo hace el super admin: gestionar administradores (D264).';

revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated;


-- -----------------------------------------------------------------------------
-- is_admin() pasa a incluir al super admin (D264)
-- -----------------------------------------------------------------------------
-- Con esto, las 40+ politicas y funciones que ya comprueban `is_admin()` valen
-- para el super admin sin tocarlas: el super admin ve y hace todo lo del panel.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role in ('admin', 'super_admin') and status = 'active'
     from public.profiles where id = (select auth.uid())),
    false
  );
$$;


-- -----------------------------------------------------------------------------
-- D265: un administrador no puede cambiar el estado de otro administrador
-- -----------------------------------------------------------------------------
-- Hoy `admin_set_account_status` esta abierta a cualquier `is_admin()`. Con un
-- solo administrador daba igual; con varios, el administrador A podria bloquear
-- al administrador B o al super admin. Se recrea copiando la definicion actual
-- (regla 6) y anadiendo una comprobacion: si el objetivo es `admin` o
-- `super_admin`, solo el super admin puede tocarlo.
create or replace function public.admin_set_account_status(
  p_user_id uuid,
  p_status public.user_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.profiles;
  v_active_request uuid;
  v_role public.user_role;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar el estado de una cuenta'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if p_user_id = (select auth.uid()) then
    raise exception 'No puedes cambiar el estado de tu propia cuenta'
      using errcode = 'P0001', hint = 'CANNOT_CHANGE_OWN_ACCOUNT';
  end if;

  select * into v_before from public.profiles where id = p_user_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  if v_before.status = p_status then
    raise exception 'Esa cuenta ya esta en ese estado'
      using errcode = 'P0001', hint = 'STATUS_UNCHANGED';
  end if;

  v_role := v_before.role;

  -- D265. Un administrador normal solo gestiona pasajeros y conductores. Tocar
  -- una cuenta de administrador o del super admin es cosa del super admin.
  if v_role in ('admin', 'super_admin') and not public.is_super_admin() then
    raise exception 'Solo el super administrador puede cambiar el estado de una cuenta de administrador'
      using errcode = 'P0001', hint = 'NEEDS_SUPER_ADMIN';
  end if;

  -- **BLOQUEAR A ALGUIEN CON UN SERVICIO EN CURSO EXIGE MOTIVO ESCRITO.** No se
  -- prohibe -puede haber una urgencia-, pero deja de ser un clic distraido: si
  -- se hace, se explica, y la explicacion queda registrada.
  --
  -- **SE MIRAN LOS DOS LADOS, Y ANTES SOLO SE MIRABA UNO.** La version de
  -- `20260827220000` buscaba por `passenger_id`, asi que bloquear a un conductor
  -- **con un pasajero dentro** no pedia motivo: el caso mas delicado de los dos
  -- era justo el que se colaba.
  if p_status = 'blocked' then
    if v_role = 'driver' then
      select rr.id into v_active_request
      from public.rides r
      join public.ride_requests rr on rr.id = r.request_id
      where r.driver_id = p_user_id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      limit 1;
    else
      select rr.id into v_active_request
      from public.ride_requests rr
      where rr.passenger_id = p_user_id
        and rr.status in ('searching', 'assigned', 'in_progress')
      limit 1;
    end if;

    if v_active_request is not null
       and length(trim(coalesce(p_reason, ''))) < 10 then
      raise exception 'Esa persona tiene un servicio en curso. Escribe el motivo del bloqueo, de al menos 10 caracteres'
        using errcode = 'P0001', hint = 'ACTIVE_RIDE_NEEDS_REASON';
    end if;
  end if;

  perform set_config('motomoto.admin_action', 'on', true);

  update public.profiles set status = p_status where id = p_user_id;

  -- **SE LE APAGA LA DISPONIBILIDAD EN EL ACTO.** Sin esto seguiria figurando
  -- como conectado hasta que el cerrara la aplicacion, y el reparto tendria que
  -- descartarlo una y otra vez. **El viaje que lleva encima no se toca** (D262):
  -- ese lo termina.
  if p_status = 'blocked' and v_role = 'driver' then
    update public.drivers set is_available = false
    where id = p_user_id and is_available;
  end if;

  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    case when p_status = 'blocked' then 'block_account' else 'unblock_account' end,
    'profiles',
    p_user_id::text,
    jsonb_build_object('status', v_before.status),
    jsonb_build_object('status', p_status, 'reason', p_reason,
                       'had_active_request', v_active_request is not null)
  );
end;
$$;

revoke all on function public.admin_set_account_status(uuid, public.user_status, text) from public, anon;
grant execute on function public.admin_set_account_status(uuid, public.user_status, text) to authenticated;
