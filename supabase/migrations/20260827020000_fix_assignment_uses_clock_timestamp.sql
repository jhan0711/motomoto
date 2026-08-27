-- =============================================================================
-- CORRECCION DE UN ERROR DEL ASISTENTE, introducido minutos antes en
-- 20260827010000_admin_vehicle_management.sql (Fase 20, paso 5).
-- =============================================================================
--
-- QUE ESTABA MAL. `admin_assign_vehicle` cierra la asignacion anterior con
-- `unassigned_at = now()`, y **`now()` en PostgreSQL no es el reloj: es el
-- instante en que empezo la transaccion**, y vale lo mismo todas las veces que
-- se llame dentro de ella. Si en una misma transaccion se crea una asignacion y
-- despues se cierra, las dos fechas salen identicas y salta
-- `dva_period_valid`, que exige `unassigned_at > assigned_at`.
--
-- COMO SE ENCONTRO. Lo cazo la comprobacion 11 de
-- `supabase/dev-tools/prueba_vehiculos.sql` -"cambiar de unidad deja una sola
-- asignacion vigente"-, que asigna y reasigna seguido. **La prueba corre entera
-- dentro de una transaccion**, que es justo la condicion que destapa el fallo.
--
-- POR QUE IMPORTA AUNQUE EL PANEL NO LO SUFRIRIA. Cada accion del panel es su
-- propia transaccion, asi que ahi `now()` habria dado valores distintos y el
-- error no habria aparecido nunca... hasta el dia que alguien llame a esta
-- funcion dos veces desde otra funcion, o desde un script de migracion de
-- datos. **Un fallo que solo aparece segun quien llame a la funcion es peor que
-- uno que aparece siempre**, porque se descubre tarde y en el sitio equivocado.
--
-- LA CORRECCION. `clock_timestamp()`, que si lee el reloj en el momento de
-- ejecutarse. Semanticamente ademas es lo que se queria decir: el momento en
-- que se cierra la asignacion, no el momento en que empezo lo que la cerro.
--
-- El `greatest(...)` protege el caso limite: si el reloj no ha avanzado un
-- microsegundo entre la insercion y el cierre -o si alguien creo la fila con una
-- fecha futura-, se fuerza a que el periodo tenga duracion positiva en vez de
-- dejar que la restriccion tumbe la operacion. La restriccion sigue siendo la
-- que manda; esto solo evita pelearse con ella.
-- =============================================================================

create or replace function public.admin_assign_vehicle(
  p_driver_id uuid,
  p_vehicle_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle public.vehicles;
  v_prev_vehicle uuid;
  v_prev_driver uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede asignar vehiculos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if not exists (select 1 from public.drivers where id = p_driver_id) then
    raise exception 'No se encontro ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;

  if not found then
    raise exception 'No se encontro ese vehiculo'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  if v_vehicle.status <> 'active' then
    raise exception 'Ese motorraton no esta activo'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_ACTIVE';
  end if;

  select vehicle_id into v_prev_vehicle
  from public.driver_vehicle_assignments
  where driver_id = p_driver_id and unassigned_at is null;

  select driver_id into v_prev_driver
  from public.driver_vehicle_assignments
  where vehicle_id = p_vehicle_id and unassigned_at is null;

  if v_prev_vehicle = p_vehicle_id then
    raise exception 'Ese conductor ya lleva ese motorraton'
      using errcode = 'P0001', hint = 'ASSIGNMENT_UNCHANGED';
  end if;

  if exists (
    select 1 from public.rides r
    where (r.vehicle_id = p_vehicle_id or r.driver_id = p_driver_id
           or (v_prev_vehicle is not null and r.vehicle_id = v_prev_vehicle))
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Hay un servicio en curso con ese conductor o ese motorraton. Resuelvelo primero'
      using errcode = 'P0001', hint = 'ASSIGNMENT_HAS_ACTIVE_RIDE';
  end if;

  -- AQUI ESTABA EL FALLO. Ver la cabecera.
  update public.driver_vehicle_assignments
  set unassigned_at = greatest(clock_timestamp(), assigned_at + interval '1 microsecond')
  where unassigned_at is null
    and (driver_id = p_driver_id or vehicle_id = p_vehicle_id);

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id, assigned_by)
  values (p_driver_id, p_vehicle_id, (select auth.uid()));

  perform public.log_admin_action(
    'assign_vehicle', 'driver_vehicle_assignments', p_driver_id::text,
    jsonb_build_object('vehicle_id', v_prev_vehicle, 'previous_driver_of_target', v_prev_driver),
    jsonb_build_object('vehicle_id', p_vehicle_id, 'unit_number', v_vehicle.unit_number)
  );
end;
$$;

comment on function public.admin_assign_vehicle(uuid, uuid) is
  'Asigna un motorraton a un conductor, cerrando las asignaciones anteriores.';


-- Misma correccion en la funcion de quitar, por el mismo motivo: si en una
-- transaccion se asigna y se quita, `now()` daria el mismo instante para las
-- dos fechas. No lo destapo ninguna comprobacion, y se corrige igual **porque el
-- fallo es el mismo aunque nadie lo haya pisado todavia**.
create or replace function public.admin_unassign_vehicle(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede quitar vehiculos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select vehicle_id into v_vehicle_id
  from public.driver_vehicle_assignments
  where driver_id = p_driver_id and unassigned_at is null;

  if v_vehicle_id is null then
    raise exception 'Ese conductor no tiene ningun motorraton asignado'
      using errcode = 'P0001', hint = 'NO_ASSIGNMENT';
  end if;

  if exists (
    select 1 from public.rides r
    where r.driver_id = p_driver_id
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Ese conductor tiene un servicio en curso. Resuelvelo antes de quitarle el motorraton'
      using errcode = 'P0001', hint = 'ASSIGNMENT_HAS_ACTIVE_RIDE';
  end if;

  update public.driver_vehicle_assignments
  set unassigned_at = greatest(clock_timestamp(), assigned_at + interval '1 microsecond')
  where driver_id = p_driver_id and unassigned_at is null;

  perform public.log_admin_action(
    'unassign_vehicle', 'driver_vehicle_assignments', p_driver_id::text,
    jsonb_build_object('vehicle_id', v_vehicle_id), null
  );
end;
$$;

comment on function public.admin_unassign_vehicle(uuid) is
  'Cierra la asignacion vigente de un conductor dejando registro.';
