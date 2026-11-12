-- =============================================================================
-- D307. Liberar el correo de un conductor archivado
-- =============================================================================
--
-- PREGUNTA DE JHAN (2026-11-12): si un conductor se retira de la empresa, como
-- vuelve a usar la app como pasajero si su correo quedo inscrito como conductor.
--
-- Hoy un correo es UNA cuenta con UN rol, y los cambios de rol estan bloqueados a
-- proposito (`protect_profile_columns`). Un conductor con historial no se puede
-- borrar (D306), asi que su cuenta archivada seguia ocupando el correo.
--
-- OPCION A, la elegida por Jhan: al archivarlo (o despues, desde "Ver archivados")
-- se RENOMBRA el correo de la cuenta archivada a un marcador interno
-- (`liberado-<id>@amalfigo.invalid`, mismo dominio `.invalid` que
-- `cuenta-eliminada@amalfigo.invalid`). El correo original queda libre y la
-- persona se registra como pasajero con una cuenta NUEVA (contrasena nueva); su
-- historial de conductor se queda en la cuenta archivada, sin conexion con la
-- nueva.
--
-- Al liberar: se cierran sus sesiones, se limpia su token de notificaciones y
-- la auditoria guarda el correo ANTERIOR (es lo unico que permitiria rehacerlo a
-- mano). Una ficha con el correo liberado NO se puede restaurar: nadie sabe su
-- correo nuevo y no podria entrar.
--
-- Los conductores creados desde el panel no tienen fila en `auth.identities`;
-- las que si la tienen (registro propio) se actualizan tambien.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ¿Esta liberado? (la lista no puede leer `auth.users`: hace falta un ayudante)
-- ---------------------------------------------------------------------------

create function public.driver_email_released(p_driver uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select exists (
    select 1 from auth.users u
    where u.id = p_driver and u.email like 'liberado-%@amalfigo.invalid'
  );
$function$;

revoke all on function public.driver_email_released(uuid) from public, anon;
grant execute on function public.driver_email_released(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. La lista de conductores, con `email_released`
-- ---------------------------------------------------------------------------

drop function public.admin_list_drivers(boolean);

create function public.admin_list_drivers(p_archived boolean default false)
 returns table(
   driver_id uuid, full_name text, phone text, account_status user_status,
   approval_status driver_approval_status, approved_at timestamptz,
   is_available boolean, rating_average numeric, rating_count integer,
   vehicle_id uuid, unit_number integer, plate text, has_active_ride boolean,
   created_at timestamptz, has_history boolean, archived_at timestamptz,
   email_released boolean
 )
 language sql
 stable
 set search_path to 'public'
as $function$
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

    d.created_at,
    public.driver_has_history(d.id),
    d.archived_at,
    public.driver_email_released(d.id)
  from public.drivers d
  join public.profiles p on p.id = d.id
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id
  where (d.archived_at is not null) = p_archived
  order by
    case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
    p.full_name;
$function$;

revoke all on function public.admin_list_drivers(boolean) from public, anon;
grant execute on function public.admin_list_drivers(boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Liberar el correo de un conductor YA archivado
-- ---------------------------------------------------------------------------

create function public.admin_release_driver_email(p_driver_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_driver public.drivers;
  v_profile public.profiles;
  v_old text;
  v_new text;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede liberar un correo'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_driver from public.drivers where id = p_driver_id;
  if not found then
    raise exception 'No se encontro a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  select * into v_profile from public.profiles where id = p_driver_id;
  if v_profile.role <> 'driver' then
    raise exception 'Esa cuenta no es de un conductor'
      using errcode = 'P0001', hint = 'NOT_A_DRIVER';
  end if;

  if v_driver.archived_at is null then
    raise exception 'Primero hay que archivar al conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_ARCHIVED';
  end if;

  select email into v_old from auth.users where id = p_driver_id;

  if v_old like 'liberado-%@amalfigo.invalid' then
    raise exception 'El correo de ese conductor ya esta liberado'
      using errcode = 'P0001', hint = 'EMAIL_ALREADY_RELEASED';
  end if;

  v_new := 'liberado-' || p_driver_id::text || '@amalfigo.invalid';

  update auth.users
  set email = v_new,
      raw_user_meta_data = case
        when raw_user_meta_data ? 'email'
          then jsonb_set(raw_user_meta_data, '{email}', to_jsonb(v_new))
        else raw_user_meta_data
      end,
      updated_at = now()
  where id = p_driver_id;

  update auth.identities
  set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_new)),
      provider_id = case when provider_id = v_old then v_new else provider_id end,
      updated_at = now()
  where user_id = p_driver_id and provider = 'email';

  -- Sin sesiones abiertas (borra tambien sus refresh tokens, por cascada) y sin
  -- token de notificaciones: ese telefono sera de la cuenta nueva.
  delete from auth.sessions where user_id = p_driver_id;
  update public.profiles set push_token = null where id = p_driver_id;

  perform public.log_admin_action(
    'release_driver_email', 'drivers', p_driver_id::text,
    jsonb_build_object('email_was', v_old, 'name', v_profile.full_name),
    jsonb_build_object('email_now', v_new)
  );
end;
$function$;

revoke all on function public.admin_release_driver_email(uuid) from public, anon;
grant execute on function public.admin_release_driver_email(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Archivar, ahora con la opcion de liberar el correo en el mismo paso
-- ---------------------------------------------------------------------------
-- Se borra la version de un solo argumento: con la nueva (valor por defecto)
-- conviviendo, la llamada con un argumento quedaria ambigua.

drop function public.admin_archive_driver(uuid);

create function public.admin_archive_driver(p_driver_id uuid, p_release_email boolean default false)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_driver public.drivers;
  v_profile public.profiles;
  v_vehicle uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede archivar conductores'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_driver from public.drivers where id = p_driver_id;
  if not found then
    raise exception 'No se encontro a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  select * into v_profile from public.profiles where id = p_driver_id;

  if v_driver.archived_at is not null then
    raise exception 'Ese conductor ya esta archivado'
      using errcode = 'P0001', hint = 'ALREADY_ARCHIVED';
  end if;

  if exists (
    select 1 from public.rides r
    where r.driver_id = p_driver_id
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Ese conductor tiene un servicio en curso. Resuelvelo antes de archivarlo'
      using errcode = 'P0001', hint = 'DRIVER_HAS_ACTIVE_RIDE';
  end if;

  perform set_config('motomoto.admin_action', 'on', true);

  update public.profiles set status = 'blocked' where id = p_driver_id;

  update public.drivers
  set is_available = false, archived_at = now()
  where id = p_driver_id;

  update public.driver_vehicle_assignments
  set unassigned_at = greatest(clock_timestamp(), assigned_at + interval '1 microsecond')
  where driver_id = p_driver_id and unassigned_at is null
  returning vehicle_id into v_vehicle;

  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    'archive_driver', 'drivers', p_driver_id::text,
    jsonb_build_object('name', v_profile.full_name, 'account_status', v_profile.status,
                       'approval_status', v_driver.approval_status,
                       'was_available', v_driver.is_available, 'vehicle_id', v_vehicle),
    jsonb_build_object('archived', true, 'release_email', p_release_email)
  );

  if p_release_email then
    perform public.admin_release_driver_email(p_driver_id);
  end if;
end;
$function$;

revoke all on function public.admin_archive_driver(uuid, boolean) from public, anon;
grant execute on function public.admin_archive_driver(uuid, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Restaurar: no si el correo ya esta liberado
-- ---------------------------------------------------------------------------

create or replace function public.admin_restore_driver(p_driver_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_driver public.drivers;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede restaurar conductores'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_driver from public.drivers where id = p_driver_id;
  if not found then
    raise exception 'No se encontro a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  if v_driver.archived_at is null then
    raise exception 'Ese conductor no esta archivado'
      using errcode = 'P0001', hint = 'NOT_ARCHIVED';
  end if;

  -- Con el correo liberado la cuenta ya no tiene un correo que alguien conozca:
  -- restaurarla dejaria una ficha a la que nadie puede entrar.
  if public.driver_email_released(p_driver_id) then
    raise exception 'El correo de ese conductor ya esta liberado: no se puede restaurar'
      using errcode = 'P0001', hint = 'EMAIL_RELEASED';
  end if;

  perform set_config('motomoto.admin_action', 'on', true);
  update public.drivers set archived_at = null where id = p_driver_id;
  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    'restore_driver', 'drivers', p_driver_id::text,
    jsonb_build_object('archived', true), jsonb_build_object('archived', false)
  );
end;
$function$;
