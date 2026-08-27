-- =============================================================================
-- FASE 20, PASO 4a: gestion de los conductores que ya existen
-- =============================================================================
--
-- El paso 4 del panel eran tres bloques distintos y se partio a proposito, con
-- el usuario, el 2026-08-26:
--
--   4a  gestionar los conductores que ya existen   <- esto
--   4b  dar de alta uno nuevo                      -> necesita la clave
--                                                     `service_role`, porque
--                                                     crear una cuenta de Auth
--                                                     no lo permite la clave
--                                                     publicable
--   4c  documentos                                 -> no existe el bucket. Solo
--                                                     hay `avatars`, y
--                                                     `documents` lleva cero
--                                                     filas desde la Fase 5
--
-- Mezclar en un mismo paso una decision de seguridad -meter una clave que salta
-- toda la RLS- con pantallas normales era la forma de que la decision pasara sin
-- discutirse.
--
-- EL MISMO HUECO DEL PASO 2, OTRA VEZ, Y EN OTRA TABLA. `protect_driver_columns`
-- empieza por "si es administrador, puede cambiar cualquier cosa", asi que hoy
-- **se puede aprobar o bloquear a un conductor con un UPDATE directo y sin dejar
-- rastro**, igual que pasaba con el estado de las cuentas. Se aplica aqui la
-- misma correccion que ya paso por `protect_profile_columns`: la marca de
-- transaccion **mas** `is_admin()`, nunca una sola de las dos. La leccion de
-- D241 escrita en la segunda tabla que la necesitaba.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_list_drivers
-- -----------------------------------------------------------------------------
--
-- `security invoker` por D242: si fuera definer, un pasajero que la llamara
-- veria la flota entera con telefonos incluidos.
create or replace function public.admin_list_drivers()
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  account_status public.user_status,
  approval_status public.driver_approval_status,
  approved_at timestamptz,
  is_available boolean,
  rating_average numeric,
  rating_count integer,

  -- El vehiculo que lleva ahora mismo, si lleva alguno. Nulo no es un error: un
  -- conductor aprobado sin vehiculo asignado es un caso real, y es justo uno de
  -- los que el panel tiene que dejar ver para poder arreglarlo.
  vehicle_id uuid,
  unit_number integer,
  plate text,

  -- Si tiene un servicio en marcha. El panel lo necesita para avisar antes de
  -- bloquear a alguien que va conduciendo, que es el caso que la Fase 18 dejo
  -- pendiente para este paso (D216).
  has_active_ride boolean,

  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    d.id,
    p.full_name,
    p.phone,
    p.status,
    d.approval_status,
    d.approved_at,
    d.is_available,
    d.rating_average,
    d.rating_count,

    v.id,
    v.unit_number,
    v.plate,

    exists (
      select 1 from public.rides r
      where r.driver_id = d.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    d.created_at
  from public.drivers d
  join public.profiles p on p.id = d.id

  -- Solo la asignacion viva. `unassigned_at is null` es lo que distingue el
  -- vehiculo que lleva hoy de todos los que llevo antes.
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id

  -- Los pendientes de aprobar primero: son los que esperan una decision de la
  -- empresa. Despues, por nombre.
  order by
    case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
    p.full_name;
$$;

comment on function public.admin_list_drivers() is
  'Listado de conductores para el panel, con su vehiculo asignado y si esta ocupado.';

revoke all on function public.admin_list_drivers() from public;
grant execute on function public.admin_list_drivers() to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierra el camino directo a la aprobacion
-- -----------------------------------------------------------------------------

create or replace function public.protect_driver_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- LAS DOS CONDICIONES, igual que en `protect_profile_columns`. Antes bastaba
  -- con ser administrador, y eso permitia aprobar sin auditoria.
  if coalesce(current_setting('motomoto.admin_action', true), '') = 'on'
     and public.is_admin() then
    return new;
  end if;

  -- El recalculo del sistema puede tocar las columnas de calificacion, y solo
  -- esas. El estado de aprobacion sigue protegido incluso durante el recalculo:
  -- ninguna via legitima necesita cambiarlo desde ahi.
  if coalesce(current_setting('app.system_rating_update', true), 'off') = 'on' then
    new.approval_status := old.approval_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    return new;
  end if;

  new.approval_status := old.approval_status;
  new.approved_at := old.approved_at;
  new.approved_by := old.approved_by;
  new.rating_average := old.rating_average;
  new.rating_count := old.rating_count;
  return new;
end;
$$;

comment on function public.protect_driver_columns() is
  'Revierte las columnas privilegiadas del conductor salvo dentro de una accion administrativa auditada.';


-- -----------------------------------------------------------------------------
-- admin_set_driver_approval
-- -----------------------------------------------------------------------------
--
-- Aprobar a un conductor, dejarlo pendiente o retirarle la aprobacion.
--
-- No es lo mismo que bloquear la CUENTA, que es `admin_set_account_status` del
-- paso 2, y por eso son dos funciones y no una con un parametro. Bloquear la
-- cuenta deja a la persona sin poder entrar en la aplicacion; retirar la
-- aprobacion la deja entrar pero no trabajar. La empresa usa las dos cosas en
-- momentos distintos.
create or replace function public.admin_set_driver_approval(
  p_driver_id uuid,
  p_status public.driver_approval_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.drivers;
  v_active_ride uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar la aprobacion de un conductor'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_before from public.drivers where id = p_driver_id;

  if not found then
    raise exception 'No se encontro ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  if v_before.approval_status = p_status then
    raise exception 'Ese conductor ya esta en ese estado'
      using errcode = 'P0001', hint = 'APPROVAL_UNCHANGED';
  end if;

  -- NO SE RETIRA LA APROBACION A QUIEN VA CONDUCIENDO. Es lo que la Fase 18
  -- dejo pendiente en D216 -"que el administrador bloquee a un conductor a
  -- mitad de operacion"- y la respuesta es que no se hace a ciegas: primero se
  -- resuelve el servicio, porque dejar a un pasajero dentro de un motorraton
  -- cuyo conductor acaba de perder el permiso no arregla nada. El panel
  -- ofrecera cancelar el servicio primero, y eso es del paso 11.
  if p_status <> 'approved' then
    select r.id into v_active_ride
    from public.rides r
    where r.driver_id = p_driver_id
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    limit 1;

    if v_active_ride is not null then
      raise exception 'Ese conductor tiene un servicio en curso. Resuelvelo antes de retirarle la aprobacion'
        using errcode = 'P0001', hint = 'DRIVER_HAS_ACTIVE_RIDE';
    end if;
  end if;

  perform set_config('motomoto.admin_action', 'on', true);

  update public.drivers
  set approval_status = p_status,
      -- La fecha de aprobacion se pone al aprobar y NO se borra al retirar: la
      -- restriccion `drivers_approved_has_date` la exige en un solo sentido, a
      -- proposito, para conservar cuando se aprobo por primera vez.
      approved_at = case when p_status = 'approved' then coalesce(v_before.approved_at, now())
                         else v_before.approved_at end,
      approved_by = case when p_status = 'approved' then (select auth.uid())
                         else v_before.approved_by end,
      -- Quien deja de estar aprobado no puede seguir disponible. La restriccion
      -- `drivers_available_only_when_approved` lo rechazaria de todos modos, asi
      -- que se apaga aqui en vez de dejar que la operacion falle.
      is_available = case when p_status = 'approved' then v_before.is_available else false end
  where id = p_driver_id;

  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    case p_status
      when 'approved' then 'approve_driver'
      when 'blocked' then 'block_driver'
      else 'set_driver_pending'
    end,
    'drivers',
    p_driver_id::text,
    jsonb_build_object('approval_status', v_before.approval_status,
                       'is_available', v_before.is_available),
    jsonb_build_object('approval_status', p_status, 'reason', p_reason)
  );
end;
$$;

comment on function public.admin_set_driver_approval(uuid, public.driver_approval_status, text) is
  'Aprueba o retira la aprobacion de un conductor dejando registro. Unico camino desde el panel.';

revoke all on function public.admin_set_driver_approval(uuid, public.driver_approval_status, text)
  from public;
grant execute on function public.admin_set_driver_approval(uuid, public.driver_approval_status, text)
  to authenticated;


-- -----------------------------------------------------------------------------
-- admin_update_driver_contact
-- -----------------------------------------------------------------------------
--
-- Corregir el nombre o el telefono de un conductor.
--
-- Va por funcion aunque `profiles_update_admin` ya permitiria el UPDATE directo,
-- por D240: **el telefono del conductor es el que la aplicacion le ensena al
-- pasajero**, asi que cambiarlo no es un detalle administrativo cualquiera, y un
-- cambio que nadie sabe quien hizo es exactamente lo que la auditoria existe
-- para evitar.
create or replace function public.admin_update_driver_contact(
  p_driver_id uuid,
  p_full_name text,
  p_phone text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.profiles;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede editar los datos de un conductor'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_before from public.profiles where id = p_driver_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  -- Esta funcion es la de los conductores. Si dejara editar cualquier perfil
  -- seria una puerta lateral para tocar los datos de un pasajero, o los de otro
  -- administrador, sin que el nombre de la accion lo dijera.
  if v_before.role <> 'driver' then
    raise exception 'Esa cuenta no es de un conductor'
      using errcode = 'P0001', hint = 'NOT_A_DRIVER';
  end if;

  -- Las mismas reglas que ya valida el perfil del pasajero desde la Fase 7. Se
  -- repiten aqui porque esta funcion es `security definer` y se salta la
  -- validacion del cliente por completo.
  if length(trim(coalesce(p_full_name, ''))) < 3 then
    raise exception 'El nombre debe tener al menos 3 caracteres'
      using errcode = 'P0001', hint = 'NAME_TOO_SHORT';
  end if;

  if coalesce(p_phone, '') !~ '^3[0-9]{9}$' then
    raise exception 'El telefono debe ser un celular colombiano de 10 digitos'
      using errcode = 'P0001', hint = 'INVALID_PHONE';
  end if;

  if v_before.full_name = trim(p_full_name) and v_before.phone = p_phone then
    raise exception 'No hay ningun cambio que guardar'
      using errcode = 'P0001', hint = 'CONTACT_UNCHANGED';
  end if;

  update public.profiles
  set full_name = trim(p_full_name), phone = p_phone
  where id = p_driver_id;

  perform public.log_admin_action(
    'update_driver_contact',
    'profiles',
    p_driver_id::text,
    jsonb_build_object('full_name', v_before.full_name, 'phone', v_before.phone),
    jsonb_build_object('full_name', trim(p_full_name), 'phone', p_phone)
  );
end;
$$;

comment on function public.admin_update_driver_contact(uuid, text, text) is
  'Corrige nombre y telefono de un conductor dejando registro.';

revoke all on function public.admin_update_driver_contact(uuid, text, text) from public;
grant execute on function public.admin_update_driver_contact(uuid, text, text) to authenticated;
