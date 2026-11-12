-- =============================================================================
-- D306. Archivar y eliminar conductores y motocarros desde el panel
-- =============================================================================
--
-- POR QUE. Las listas del panel se llenan de fichas que ya no se usan (conductores
-- duplicados, motocarros de prueba) y no hay forma de quitarlas. Pero NO todo se
-- puede borrar: la base de datos lo impide a proposito (FK RESTRICT) cuando hay
-- historial -`rides.driver_id`, `rides.vehicle_id`, `driver_vehicle_assignments.
-- vehicle_id`-, y ademas el libro de saldos (`driver_ledger`) no tiene FK y
-- quedaria huerfano.
--
-- REGLA (aprobada por Jhan el 2026-11-12):
--   * SIN historial  -> ELIMINAR de verdad, definitivo.
--   * CON historial  -> ARCHIVAR: se oculta de la lista (con "Ver archivados" y
--                       "Restaurar"), nada se pierde.
--
-- Historial de un CONDUCTOR: algun viaje, algun movimiento de saldo, alguna
-- recarga o alguna calificacion recibida.
-- Historial de un MOTOCARRO: algun viaje o alguna asignacion (aunque ya se
-- haya quitado).
--
-- ARCHIVAR un conductor bloquea su cuenta, apaga su disponibilidad y le libera
-- el motocarro. RESTAURARLO solo lo devuelve a la lista: la cuenta sigue
-- bloqueada hasta que alguien la desbloquee (decision deliberada: restaurar una
-- ficha no debe devolverle el trabajo a nadie sin que se note).
-- ARCHIVAR un motocarro lo deja "Retirado" y le quita los conductores.
-- RESTAURARLO lo deja "Activo".
--
-- Los archivos de documentos (storage) NO se pueden borrar con SQL en Supabase:
-- las funciones de eliminar devuelven las rutas y el panel las quita despues
-- (mismo patron que `admin_delete_document`).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Columnas
-- ---------------------------------------------------------------------------

alter table public.drivers  add column archived_at timestamptz;
alter table public.vehicles add column archived_at timestamptz;

comment on column public.drivers.archived_at is
  'D306. Ficha archivada desde el panel: oculta de la lista, cuenta bloqueada.';
comment on column public.vehicles.archived_at is
  'D306. Motocarro archivado desde el panel: oculto de la lista, estado retirado.';

-- ---------------------------------------------------------------------------
-- 2. `protect_driver_columns`: el conductor no puede desarchivarse solo
-- ---------------------------------------------------------------------------
-- `drivers_update_own` le deja escribir su fila. `archived_at` solo lo toca una
-- funcion de administrador, que levanta `motomoto.admin_action`.

create or replace function public.protect_driver_columns()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_admin_action boolean :=
    coalesce(current_setting('motomoto.admin_action', true), '') = 'on'
    and public.is_admin();
begin
  if coalesce(current_setting('app.driver_session_write', true), 'off') <> 'on' then
    new.availability_session_id := old.availability_session_id;
    new.availability_started_at := old.availability_started_at;
    new.last_seen_at            := old.last_seen_at;
    new.unanswered_offers       := old.unanswered_offers;
    new.disconnect_reason       := old.disconnect_reason;
    new.location_permission     := old.location_permission;
    new.device_platform         := old.device_platform;
  end if;

  if v_admin_action then
    return new;
  end if;

  new.archived_at := old.archived_at;

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
$function$;

-- ---------------------------------------------------------------------------
-- 3. Que cuenta como "historial"
-- ---------------------------------------------------------------------------
-- Una sola definicion, usada por las listas (para decidir entre "Eliminar" y
-- "Archivar") y por las funciones de eliminar (que la vuelven a comprobar: la
-- pantalla puede tener diez segundos de antiguedad).

create function public.driver_has_history(p_driver uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select exists (select 1 from public.rides r where r.driver_id = p_driver)
      or exists (select 1 from public.driver_ledger l where l.driver_id = p_driver)
      or exists (select 1 from public.topup_intents t where t.driver_id = p_driver)
      or exists (select 1 from public.ratings x where x.rated_id = p_driver);
$function$;

create function public.vehicle_has_history(p_vehicle uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select exists (select 1 from public.rides r where r.vehicle_id = p_vehicle)
      or exists (select 1 from public.driver_vehicle_assignments a where a.vehicle_id = p_vehicle);
$function$;

revoke all on function public.driver_has_history(uuid) from public, anon;
revoke all on function public.vehicle_has_history(uuid) from public, anon;
grant execute on function public.driver_has_history(uuid) to authenticated, service_role;
grant execute on function public.vehicle_has_history(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Las listas: solo lo archivado o solo lo no archivado, y si tiene historial
-- ---------------------------------------------------------------------------
-- Cambia la forma de lo que devuelven, asi que hay que borrar la funcion y
-- crearla de nuevo (un `create or replace` con otro tipo de retorno falla, y con
-- otros argumentos crearia una segunda funcion y la llamada sin argumentos
-- quedaria ambigua).

drop function public.admin_list_drivers();

create function public.admin_list_drivers(p_archived boolean default false)
 returns table(
   driver_id uuid, full_name text, phone text, account_status user_status,
   approval_status driver_approval_status, approved_at timestamptz,
   is_available boolean, rating_average numeric, rating_count integer,
   vehicle_id uuid, unit_number integer, plate text, has_active_ride boolean,
   created_at timestamptz, has_history boolean, archived_at timestamptz
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
    d.archived_at
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

drop function public.admin_list_vehicles();

create function public.admin_list_vehicles(p_archived boolean default false)
 returns table(
   vehicle_id uuid, unit_number integer, plate text, model text,
   max_passengers smallint, status vehicle_status, notes text,
   driver_count integer, drivers_label text, drivers jsonb,
   active_driver_id uuid, active_driver_name text, has_active_ride boolean,
   created_at timestamptz, has_history boolean, archived_at timestamptz
 )
 language sql
 stable
 set search_path to 'public'
as $function$
  with asignados as (
    select
      dva.vehicle_id,
      dva.driver_id,
      p.full_name,
      d.is_available
    from public.driver_vehicle_assignments dva
    join public.profiles p on p.id = dva.driver_id
    join public.drivers d on d.id = dva.driver_id
    where dva.unassigned_at is null
  ),
  al_volante as (
    -- El que tiene un servicio en marcha manda sobre el que solo esta
    -- disponible: si alguien esta conduciendo, ese es el que lleva la unidad.
    select distinct on (a.vehicle_id)
      a.vehicle_id, a.driver_id, a.full_name
    from asignados a
    left join public.rides r
      on r.driver_id = a.driver_id
     and r.vehicle_id = a.vehicle_id
     and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    where r.id is not null or a.is_available
    order by a.vehicle_id, (r.id is not null) desc, a.full_name
  )
  select
    v.id,
    v.unit_number,
    v.plate,
    v.model,
    v.max_passengers,
    v.status,
    v.notes,

    coalesce(count(a.driver_id), 0)::integer,
    nullif(string_agg(a.full_name, ', ' order by a.full_name), ''),
    coalesce(
      jsonb_agg(
        jsonb_build_object('id', a.driver_id, 'name', a.full_name,
                           'is_available', a.is_available)
        order by a.full_name
      ) filter (where a.driver_id is not null),
      '[]'::jsonb
    ),

    av.driver_id,
    av.full_name,

    exists (
      select 1 from public.rides r
      where r.vehicle_id = v.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    v.created_at,
    public.vehicle_has_history(v.id),
    v.archived_at
  from public.vehicles v
  left join asignados a on a.vehicle_id = v.id
  left join al_volante av on av.vehicle_id = v.id
  where (v.archived_at is not null) = p_archived
  group by v.id, av.driver_id, av.full_name
  order by
    case v.status when 'active' then 0 when 'maintenance' then 1 else 2 end,
    v.unit_number;
$function$;

revoke all on function public.admin_list_vehicles(boolean) from public, anon;
grant execute on function public.admin_list_vehicles(boolean) to authenticated, service_role;

-- Los saldos no incluyen a los archivados.
create or replace function public.admin_list_driver_balances()
 returns table(driver_id uuid, balance integer, can_work boolean)
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select d.id, public.driver_balance(d.id), public.driver_can_work(d.id)
  from public.drivers d
  where public.is_admin()
    and d.archived_at is null;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Conductores: archivar, restaurar, eliminar
-- ---------------------------------------------------------------------------

create function public.admin_archive_driver(p_driver_id uuid)
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
    jsonb_build_object('archived', true)
  );
end;
$function$;

create function public.admin_restore_driver(p_driver_id uuid)
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

  perform set_config('motomoto.admin_action', 'on', true);
  update public.drivers set archived_at = null where id = p_driver_id;
  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    'restore_driver', 'drivers', p_driver_id::text,
    jsonb_build_object('archived', true), jsonb_build_object('archived', false)
  );
end;
$function$;

-- Devuelve las rutas de los documentos para que el panel los quite del
-- almacenamiento (Supabase no deja borrar `storage.objects` con SQL).
create function public.admin_delete_driver(p_driver_id uuid)
 returns text[]
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_profile public.profiles;
  v_driver public.drivers;
  v_paths text[];
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede eliminar conductores'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_driver from public.drivers where id = p_driver_id;
  if not found then
    raise exception 'No se encontro a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  select * into v_profile from public.profiles where id = p_driver_id;

  -- Nunca una cuenta de administrador, aunque por alguna razon tuviera fila de
  -- conductor.
  if v_profile.role <> 'driver' then
    raise exception 'Esa cuenta no es de un conductor'
      using errcode = 'P0001', hint = 'NOT_A_DRIVER';
  end if;

  if exists (
    select 1 from public.rides r
    where r.driver_id = p_driver_id
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Ese conductor tiene un servicio en curso'
      using errcode = 'P0001', hint = 'DRIVER_HAS_ACTIVE_RIDE';
  end if;

  if public.driver_has_history(p_driver_id) then
    raise exception 'Ese conductor tiene historial: no se puede eliminar, solo archivar'
      using errcode = 'P0001', hint = 'DRIVER_HAS_HISTORY';
  end if;

  select coalesce(array_agg(file_path), '{}') into v_paths
  from public.documents where driver_id = p_driver_id and file_path is not null;

  -- La auditoria se escribe ANTES: despues de borrar ya no habria de donde
  -- sacar el nombre.
  perform public.log_admin_action(
    'delete_driver', 'drivers', p_driver_id::text,
    jsonb_build_object('name', v_profile.full_name, 'phone', v_profile.phone,
                       'approval_status', v_driver.approval_status,
                       'documents', coalesce(array_length(v_paths, 1), 0)),
    null
  );

  -- Cascada: profiles -> drivers -> documents, ofertas, ubicacion, diario,
  -- asignaciones. Ver la lista de FK en la migracion D306.
  delete from auth.users where id = p_driver_id;

  return v_paths;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Motocarros: archivar, restaurar, eliminar
-- ---------------------------------------------------------------------------

create function public.admin_archive_vehicle(p_vehicle_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_vehicle public.vehicles;
  v_drivers uuid[];
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede archivar motocarros'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if not found then
    raise exception 'No se encontro ese motocarro'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  if v_vehicle.archived_at is not null then
    raise exception 'Ese motocarro ya esta archivado'
      using errcode = 'P0001', hint = 'ALREADY_ARCHIVED';
  end if;

  if exists (
    select 1 from public.rides r
    where r.vehicle_id = p_vehicle_id
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Ese motocarro tiene un servicio en curso. Resuelvelo antes de archivarlo'
      using errcode = 'P0001', hint = 'VEHICLE_HAS_ACTIVE_RIDE';
  end if;

  select coalesce(array_agg(driver_id), '{}') into v_drivers
  from public.driver_vehicle_assignments
  where vehicle_id = p_vehicle_id and unassigned_at is null;

  update public.driver_vehicle_assignments
  set unassigned_at = greatest(clock_timestamp(), assigned_at + interval '1 microsecond')
  where vehicle_id = p_vehicle_id and unassigned_at is null;

  -- Sin motocarro nadie puede estar disponible con el.
  update public.drivers set is_available = false
  where id = any(v_drivers) and is_available;

  update public.vehicles
  set status = 'retired', archived_at = now()
  where id = p_vehicle_id;

  perform public.log_admin_action(
    'archive_vehicle', 'vehicles', p_vehicle_id::text,
    jsonb_build_object('unit_number', v_vehicle.unit_number, 'plate', v_vehicle.plate,
                       'status', v_vehicle.status, 'drivers_removed', v_drivers),
    jsonb_build_object('archived', true, 'status', 'retired')
  );
end;
$function$;

create function public.admin_restore_vehicle(p_vehicle_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_vehicle public.vehicles;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede restaurar motocarros'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if not found then
    raise exception 'No se encontro ese motocarro'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  if v_vehicle.archived_at is null then
    raise exception 'Ese motocarro no esta archivado'
      using errcode = 'P0001', hint = 'NOT_ARCHIVED';
  end if;

  update public.vehicles
  set archived_at = null, status = 'active'
  where id = p_vehicle_id;

  perform public.log_admin_action(
    'restore_vehicle', 'vehicles', p_vehicle_id::text,
    jsonb_build_object('archived', true), jsonb_build_object('archived', false, 'status', 'active')
  );
end;
$function$;

create function public.admin_delete_vehicle(p_vehicle_id uuid)
 returns text[]
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_vehicle public.vehicles;
  v_paths text[];
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede eliminar motocarros'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if not found then
    raise exception 'No se encontro ese motocarro'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  if public.vehicle_has_history(p_vehicle_id) then
    raise exception 'Ese motocarro tiene historial: no se puede eliminar, solo archivar'
      using errcode = 'P0001', hint = 'VEHICLE_HAS_HISTORY';
  end if;

  select coalesce(array_agg(file_path), '{}') into v_paths
  from public.documents where vehicle_id = p_vehicle_id and file_path is not null;

  perform public.log_admin_action(
    'delete_vehicle', 'vehicles', p_vehicle_id::text,
    jsonb_build_object('unit_number', v_vehicle.unit_number, 'plate', v_vehicle.plate,
                       'model', v_vehicle.model,
                       'documents', coalesce(array_length(v_paths, 1), 0)),
    null
  );

  delete from public.vehicles where id = p_vehicle_id;

  return v_paths;
end;
$function$;

-- Permisos: solo usuarios con sesion (y el servicio); `is_admin()` dentro de
-- cada funcion decide el resto.
revoke all on function public.admin_archive_driver(uuid) from public, anon;
revoke all on function public.admin_restore_driver(uuid) from public, anon;
revoke all on function public.admin_delete_driver(uuid) from public, anon;
revoke all on function public.admin_archive_vehicle(uuid) from public, anon;
revoke all on function public.admin_restore_vehicle(uuid) from public, anon;
revoke all on function public.admin_delete_vehicle(uuid) from public, anon;
grant execute on function public.admin_archive_driver(uuid) to authenticated, service_role;
grant execute on function public.admin_restore_driver(uuid) to authenticated, service_role;
grant execute on function public.admin_delete_driver(uuid) to authenticated, service_role;
grant execute on function public.admin_archive_vehicle(uuid) to authenticated, service_role;
grant execute on function public.admin_restore_vehicle(uuid) to authenticated, service_role;
grant execute on function public.admin_delete_vehicle(uuid) to authenticated, service_role;
