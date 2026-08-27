-- =============================================================================
-- FASE 20, PASO 5: vehiculos y asignacion conductor-vehiculo
-- =============================================================================
--
-- TERCERA VEZ QUE APARECE EL MISMO HUECO, Y ESTA VEZ SE DICE EN VOZ ALTA. El
-- paso 2 lo encontro en `profiles`, el 4a en `drivers`, y aqui esta otra vez en
-- `vehicles` y en `driver_vehicle_assignments`: las politicas `_all_admin` son
-- `for all`, asi que un administrador puede crear, editar, asignar y desasignar
-- **con escritura directa y sin dejar rastro**.
--
-- No es un descuido de la Fase 5: cuando se escribieron esas politicas no habia
-- panel, y la unica forma de tocar esas tablas era a mano, sabiendo lo que se
-- hacia. Lo que cambia con el panel es que esas operaciones pasan a ser de uso
-- diario y con varias personas.
--
-- Se cierran las dos, y **quedan avisadas las que faltan**: `document_types`,
-- `documents` y `places` siguen con su politica `for all` y se cerraran en sus
-- pasos (4c y 6). La lectura no se toca: `vehicles_select_authenticated` sigue
-- abierta, porque el numero y la placa estan pintados en el vehiculo y son
-- visibles en la calle (D86).
--
-- LAS DOS REGLAS QUE PROTEGEN LA OPERACION ya estaban, y son de la Fase 5: dos
-- indices unicos parciales impiden que un conductor figure con dos unidades y
-- que dos conductores figuren con la misma. Este paso no las reemplaza; les
-- pone mensajes que se puedan leer y una auditoria que diga quien lo hizo.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_list_vehicles
-- -----------------------------------------------------------------------------
--
-- `security invoker` (D242). Aqui la lectura de `vehicles` esta abierta a
-- cualquier autenticado a proposito, pero **quien lo conduce no**: eso sale de
-- `driver_vehicle_assignments`, que solo deja ver lo propio y al administrador.
-- Siendo invoker, un pasajero que llamara a esta funcion veria la flota -que ya
-- ve por la calle- pero no quien lleva cada unidad.
create or replace function public.admin_list_vehicles()
returns table (
  vehicle_id uuid,
  unit_number integer,
  plate text,
  model text,
  max_passengers smallint,
  status public.vehicle_status,
  notes text,

  -- El conductor que lo lleva ahora, si lo lleva alguno.
  driver_id uuid,
  driver_name text,
  assigned_at timestamptz,

  -- Si la unidad esta metida en un servicio ahora mismo. Es el dato que decide
  -- si se puede desasignar o retirar sin dejar a un pasajero a medias, mismo
  -- criterio que D244 con los conductores.
  has_active_ride boolean,

  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    v.id,
    v.unit_number,
    v.plate,
    v.model,
    v.max_passengers,
    v.status,
    v.notes,

    dva.driver_id,
    p.full_name,
    dva.assigned_at,

    exists (
      select 1 from public.rides r
      where r.vehicle_id = v.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    v.created_at
  from public.vehicles v
  left join public.driver_vehicle_assignments dva
    on dva.vehicle_id = v.id and dva.unassigned_at is null
  left join public.profiles p on p.id = dva.driver_id

  -- Los activos primero, y dentro de cada grupo por numero de unidad, que es
  -- como la gente los nombra (D55).
  order by
    case v.status when 'active' then 0 when 'maintenance' then 1 else 2 end,
    v.unit_number;
$$;

comment on function public.admin_list_vehicles() is
  'Listado de vehiculos para el panel, con quien los conduce y si estan ocupados.';

revoke all on function public.admin_list_vehicles() from public;
grant execute on function public.admin_list_vehicles() to authenticated;


-- -----------------------------------------------------------------------------
-- admin_create_vehicle
-- -----------------------------------------------------------------------------

create or replace function public.admin_create_vehicle(
  p_unit_number integer,
  p_plate text,
  p_model text default null,
  p_max_passengers smallint default 3
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede crear vehiculos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  -- Las restricciones de la tabla ya rechazan todo esto. Se comprueba antes
  -- igualmente para poder devolver un codigo estable que la pantalla sepa
  -- traducir: un 23505 crudo no le dice al usuario cual de los dos campos
  -- unicos choco.
  if p_unit_number is null or p_unit_number <= 0 then
    raise exception 'El numero de motorraton debe ser mayor que cero'
      using errcode = 'P0001', hint = 'INVALID_UNIT_NUMBER';
  end if;

  if length(trim(coalesce(p_plate, ''))) not between 5 and 10 then
    raise exception 'La placa debe tener entre 5 y 10 caracteres'
      using errcode = 'P0001', hint = 'INVALID_PLATE';
  end if;

  if p_max_passengers is null or p_max_passengers not between 1 and 10 then
    raise exception 'La capacidad debe estar entre 1 y 10 pasajeros'
      using errcode = 'P0001', hint = 'INVALID_CAPACITY';
  end if;

  if exists (select 1 from public.vehicles where unit_number = p_unit_number) then
    raise exception 'Ya existe un motorraton con ese numero'
      using errcode = 'P0001', hint = 'UNIT_NUMBER_TAKEN';
  end if;

  -- La placa se compara en mayusculas porque el disparador
  -- `normalize_vehicle_plate` la guarda asi. Comparar sin normalizar dejaria
  -- pasar 'abc12' contra un 'ABC12' existente y el choque saltaria despues,
  -- como un 23505 sin explicacion.
  if exists (select 1 from public.vehicles where plate = upper(trim(p_plate))) then
    raise exception 'Ya existe un motorraton con esa placa'
      using errcode = 'P0001', hint = 'PLATE_TAKEN';
  end if;

  insert into public.vehicles (unit_number, plate, model, max_passengers)
  values (p_unit_number, trim(p_plate), nullif(trim(coalesce(p_model, '')), ''), p_max_passengers)
  returning id into v_id;

  perform public.log_admin_action(
    'create_vehicle', 'vehicles', v_id::text, null,
    jsonb_build_object('unit_number', p_unit_number, 'plate', upper(trim(p_plate)),
                       'max_passengers', p_max_passengers)
  );

  return v_id;
end;
$$;

comment on function public.admin_create_vehicle(integer, text, text, smallint) is
  'Da de alta un motorraton dejando registro. Unico camino desde el panel.';

revoke all on function public.admin_create_vehicle(integer, text, text, smallint) from public;
grant execute on function public.admin_create_vehicle(integer, text, text, smallint) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_update_vehicle
-- -----------------------------------------------------------------------------

create or replace function public.admin_update_vehicle(
  p_vehicle_id uuid,
  p_unit_number integer,
  p_plate text,
  p_model text,
  p_max_passengers smallint,
  p_status public.vehicle_status,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.vehicles;
  v_active_ride uuid;
  v_seats_in_use smallint;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede editar vehiculos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_before from public.vehicles where id = p_vehicle_id;

  if not found then
    raise exception 'No se encontro ese vehiculo'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  if p_unit_number is null or p_unit_number <= 0 then
    raise exception 'El numero de motorraton debe ser mayor que cero'
      using errcode = 'P0001', hint = 'INVALID_UNIT_NUMBER';
  end if;

  if length(trim(coalesce(p_plate, ''))) not between 5 and 10 then
    raise exception 'La placa debe tener entre 5 y 10 caracteres'
      using errcode = 'P0001', hint = 'INVALID_PLATE';
  end if;

  if p_max_passengers is null or p_max_passengers not between 1 and 10 then
    raise exception 'La capacidad debe estar entre 1 y 10 pasajeros'
      using errcode = 'P0001', hint = 'INVALID_CAPACITY';
  end if;

  if exists (
    select 1 from public.vehicles
    where unit_number = p_unit_number and id <> p_vehicle_id
  ) then
    raise exception 'Ya existe otro motorraton con ese numero'
      using errcode = 'P0001', hint = 'UNIT_NUMBER_TAKEN';
  end if;

  if exists (
    select 1 from public.vehicles
    where plate = upper(trim(p_plate)) and id <> p_vehicle_id
  ) then
    raise exception 'Ya existe otro motorraton con esa placa'
      using errcode = 'P0001', hint = 'PLATE_TAKEN';
  end if;

  select r.id, r.passenger_count into v_active_ride, v_seats_in_use
  from public.rides r
  where r.vehicle_id = p_vehicle_id
    and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  limit 1;

  -- NO SE RETIRA NI SE MANDA A TALLER UNA UNIDAD QUE VA POR LA CALLE CON UN
  -- PASAJERO DENTRO. Mismo criterio que D244 con los conductores: la salida es
  -- resolver el servicio primero, no cambiarle el estado por debajo.
  if p_status <> 'active' and v_active_ride is not null then
    raise exception 'Ese motorraton tiene un servicio en curso. Resuelvelo antes de cambiarle el estado'
      using errcode = 'P0001', hint = 'VEHICLE_HAS_ACTIVE_RIDE';
  end if;

  -- Y NO SE LE BAJA LA CAPACIDAD POR DEBAJO DE LO QUE YA LLEVA ENCIMA. Sin esto
  -- quedaria un viaje con tres pasajeros en una unidad declarada de dos, que es
  -- un dato que se contradice a si mismo y que ninguna restriccion de la Fase 5
  -- atrapa: `enforce_ride_capacity` mira al aceptar, no al editar el vehiculo.
  if v_active_ride is not null and p_max_passengers < v_seats_in_use then
    raise exception 'Ese motorraton lleva % pasajeros ahora mismo. No puedes dejarlo en %',
      v_seats_in_use, p_max_passengers
      using errcode = 'P0001', hint = 'CAPACITY_BELOW_CURRENT_LOAD';
  end if;

  update public.vehicles
  set unit_number = p_unit_number,
      plate = trim(p_plate),
      model = nullif(trim(coalesce(p_model, '')), ''),
      max_passengers = p_max_passengers,
      status = p_status,
      notes = nullif(trim(coalesce(p_notes, '')), '')
  where id = p_vehicle_id;

  perform public.log_admin_action(
    'update_vehicle', 'vehicles', p_vehicle_id::text,
    jsonb_build_object('unit_number', v_before.unit_number, 'plate', v_before.plate,
                       'max_passengers', v_before.max_passengers, 'status', v_before.status),
    jsonb_build_object('unit_number', p_unit_number, 'plate', upper(trim(p_plate)),
                       'max_passengers', p_max_passengers, 'status', p_status)
  );
end;
$$;

comment on function public.admin_update_vehicle(uuid, integer, text, text, smallint, public.vehicle_status, text) is
  'Edita un motorraton dejando registro. Protege los que tienen un servicio en curso.';

revoke all on function public.admin_update_vehicle(uuid, integer, text, text, smallint, public.vehicle_status, text)
  from public;
grant execute on function public.admin_update_vehicle(uuid, integer, text, text, smallint, public.vehicle_status, text)
  to authenticated;


-- -----------------------------------------------------------------------------
-- admin_assign_vehicle
-- -----------------------------------------------------------------------------
--
-- Asignar una unidad a un conductor. Si el conductor ya llevaba otra, o si la
-- unidad ya la llevaba otro, **se cierra la asignacion anterior en la misma
-- transaccion**: los indices unicos parciales de la Fase 5 lo exigen, y hacerlo
-- aqui evita que el panel tenga que acordarse de desasignar primero.
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

  -- Una unidad retirada o en taller no se le entrega a nadie. La aplicacion del
  -- conductor no lo comprueba: comprobarlo aqui es lo que impide que salga a
  -- trabajar con una unidad que la empresa dio de baja.
  if v_vehicle.status <> 'active' then
    raise exception 'Ese motorraton no esta activo'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_ACTIVE';
  end if;

  -- Lo que llevaba cada uno antes, para poder cerrarlo y para poder contarlo en
  -- la auditoria: "se le quito la 99 y se le dio la 98" es lo que hace util el
  -- registro dentro de seis meses.
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

  -- No se le quita la unidad a quien va conduciendo con ella, ni se le cambia
  -- la suya a quien esta a mitad de servicio.
  if exists (
    select 1 from public.rides r
    where (r.vehicle_id = p_vehicle_id or r.driver_id = p_driver_id
           or (v_prev_vehicle is not null and r.vehicle_id = v_prev_vehicle))
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Hay un servicio en curso con ese conductor o ese motorraton. Resuelvelo primero'
      using errcode = 'P0001', hint = 'ASSIGNMENT_HAS_ACTIVE_RIDE';
  end if;

  update public.driver_vehicle_assignments
  set unassigned_at = now()
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

revoke all on function public.admin_assign_vehicle(uuid, uuid) from public;
grant execute on function public.admin_assign_vehicle(uuid, uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_unassign_vehicle
-- -----------------------------------------------------------------------------

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
  set unassigned_at = now()
  where driver_id = p_driver_id and unassigned_at is null;

  perform public.log_admin_action(
    'unassign_vehicle', 'driver_vehicle_assignments', p_driver_id::text,
    jsonb_build_object('vehicle_id', v_vehicle_id), null
  );
end;
$$;

comment on function public.admin_unassign_vehicle(uuid) is
  'Cierra la asignacion vigente de un conductor dejando registro.';

revoke all on function public.admin_unassign_vehicle(uuid) from public;
grant execute on function public.admin_unassign_vehicle(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierra la escritura directa
-- -----------------------------------------------------------------------------
--
-- La lectura se conserva: `vehicles_select_authenticated` para la flota (D86) y
-- `dva_select_own` para que cada conductor vea la suya. Lo que desaparece es la
-- escritura directa, que es la que permitia asignar sin dejar rastro.
--
-- El administrador sigue leyendo `driver_vehicle_assignments` entera, que lo
-- necesita el listado: por eso se sustituye la politica `for all` por una de
-- solo lectura, en vez de borrarla sin mas.
drop policy if exists "vehicles_all_admin" on public.vehicles;
drop policy if exists "dva_all_admin" on public.driver_vehicle_assignments;

create policy "dva_select_admin"
  on public.driver_vehicle_assignments for select to authenticated
  using (public.is_admin());
