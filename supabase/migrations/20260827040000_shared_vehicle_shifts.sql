-- =============================================================================
-- DOBLE TURNO: un motorraton lo pueden llevar varias personas
-- =============================================================================
--
-- PETICION DEL USUARIO, 2026-08-27, al probar el paso 5 del panel: "en el plan
-- esta previsto que un motorraton lo pueden manejar dos o mas personas? es que
-- algunos tienen doble turno".
--
-- **No estaba previsto, y el sistema lo impedia a proposito.** El indice
-- `dva_one_active_per_vehicle` de la Fase 5 solo admitia una asignacion vigente
-- por unidad, con este motivo escrito: "sin la segunda, dos conductores podrian
-- aparecer al volante del mismo motorraton, y un pasajero recibiria datos de un
-- vehiculo que no es el que viene por el".
--
-- Ese motivo sigue siendo bueno, pero resuelve **"dos a la vez"**, no **"dos por
-- turnos"**, que es un caso real de la empresa. La regla estaba puesta en el
-- sitio equivocado: en QUIEN TIENE ASIGNADA la unidad, cuando lo que de verdad
-- importa es QUIEN ESTA TRABAJANDO CON ELLA AHORA.
--
-- LO QUE CAMBIA (D246, decidido con el usuario):
--
--   antes   una asignacion vigente por unidad
--   ahora   varias asignaciones vigentes por unidad, pero **un solo conductor
--           disponible a la vez entre los que la comparten**
--
-- Lo que NO cambia, y conviene decirlo: `dva_one_active_per_driver` sigue en
-- pie. Un conductor sigue teniendo una sola unidad. El doble turno es que una
-- unidad tenga varios conductores, no al reves.
--
-- POR QUE LA REGLA VA EN `is_available` Y NO EN LA ASIGNACION. Porque es donde
-- de verdad se decide quien puede recibir un servicio: `find_available_drivers`
-- filtra por ahi. Si dos companeros de unidad pudieran estar disponibles a la
-- vez, los dos recibirian ofertas distintas y **los dos podrian aceptar con un
-- solo motorraton fisico**, que es el problema que el indice viejo evitaba de
-- rebote. Aqui se ataca donde nace.
--
-- Y ADEMAS YA ESTABA MEDIO RESUELTO SIN SABERLO: `enforce_ride_capacity` suma
-- los asientos ocupados **por vehiculo y no por conductor** desde la Fase 5, asi
-- que dos companeros nunca podrian sobrecargar la unidad entre los dos. Esa
-- mitad no hay que tocarla.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Se levanta el limite de una asignacion por unidad
-- -----------------------------------------------------------------------------

drop index if exists public.dva_one_active_per_vehicle;

comment on table public.driver_vehicle_assignments is
  'Periodos de asignacion. unassigned_at nulo significa vigente. Una unidad puede tener varias vigentes a la vez (doble turno); un conductor, solo una.';


-- -----------------------------------------------------------------------------
-- Un solo conductor disponible por unidad
-- -----------------------------------------------------------------------------
--
-- Se comprueba al ENCENDER la disponibilidad, no al apagarla: apagarla nunca
-- crea un conflicto. Y solo cuando cambia de apagada a encendida, para que un
-- update que toque otra columna del conductor no vuelva a evaluarla.
create or replace function public.one_available_driver_per_vehicle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_companion text;
  v_unit integer;
begin
  if not new.is_available or coalesce(old.is_available, false) then
    return new;
  end if;

  select p.full_name, v.unit_number into v_companion, v_unit
  from public.driver_vehicle_assignments mia
  join public.driver_vehicle_assignments suya
    on suya.vehicle_id = mia.vehicle_id
   and suya.unassigned_at is null
   and suya.driver_id <> new.id
  join public.drivers d on d.id = suya.driver_id and d.is_available
  join public.profiles p on p.id = suya.driver_id
  join public.vehicles v on v.id = mia.vehicle_id
  where mia.driver_id = new.id
    and mia.unassigned_at is null
  limit 1;

  if v_companion is not null then
    -- El mensaje **dice quien es y con que unidad**, porque el conductor que lo
    -- lee tiene que poder resolverlo por su cuenta: llamar a su companero. Un
    -- "no puedes conectarte" a secas lo mandaria a la oficina.
    raise exception '% ya esta conectado con el motorraton %. Solo uno puede estar disponible a la vez',
      v_companion, v_unit
      using errcode = 'P0001', hint = 'COMPANION_ALREADY_AVAILABLE';
  end if;

  return new;
end;
$$;

comment on function public.one_available_driver_per_vehicle() is
  'Impide que dos conductores que comparten motorraton esten disponibles a la vez.';

create trigger drivers_one_available_per_vehicle
  before update on public.drivers
  for each row execute function public.one_available_driver_per_vehicle();


-- -----------------------------------------------------------------------------
-- admin_assign_vehicle deja de expulsar al companero
-- -----------------------------------------------------------------------------
--
-- Antes cerraba TODA asignacion vigente del conductor **o de la unidad**. Esa
-- segunda mitad era lo que hacia imposible el doble turno: asignar a Pedro la
-- unidad de Juan le quitaba la unidad a Juan.
--
-- Ahora solo se cierra la del conductor que se esta asignando, porque
-- `dva_one_active_per_driver` sigue exigiendo que tenga una sola.
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
  v_companions integer;
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

  if v_prev_vehicle = p_vehicle_id then
    raise exception 'Ese conductor ya lleva ese motorraton'
      using errcode = 'P0001', hint = 'ASSIGNMENT_UNCHANGED';
  end if;

  -- Cuantos lo comparten ya. Solo para dejarlo escrito en la auditoria: saber
  -- que una unidad paso de uno a tres conductores es justo lo que se querra
  -- consultar cuando algo no cuadre.
  select count(*) into v_companions
  from public.driver_vehicle_assignments
  where vehicle_id = p_vehicle_id and unassigned_at is null;

  -- SOLO SE MIRA AL CONDUCTOR QUE SE ASIGNA, no a la unidad de destino. Que un
  -- companero vaya conduciendo la unidad ahora mismo **ya no impide** anadir a
  -- otro al turno: son cosas distintas, y esa es la peticion del doble turno.
  if exists (
    select 1 from public.rides r
    where (r.driver_id = p_driver_id
           or (v_prev_vehicle is not null and r.vehicle_id = v_prev_vehicle))
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  ) then
    raise exception 'Hay un servicio en curso con ese conductor o con su motorraton actual. Resuelvelo primero'
      using errcode = 'P0001', hint = 'ASSIGNMENT_HAS_ACTIVE_RIDE';
  end if;

  update public.driver_vehicle_assignments
  set unassigned_at = greatest(clock_timestamp(), assigned_at + interval '1 microsecond')
  where unassigned_at is null
    and driver_id = p_driver_id;

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id, assigned_by)
  values (p_driver_id, p_vehicle_id, (select auth.uid()));

  perform public.log_admin_action(
    'assign_vehicle', 'driver_vehicle_assignments', p_driver_id::text,
    jsonb_build_object('vehicle_id', v_prev_vehicle),
    jsonb_build_object('vehicle_id', p_vehicle_id, 'unit_number', v_vehicle.unit_number,
                       'drivers_sharing_before', v_companions)
  );
end;
$$;

comment on function public.admin_assign_vehicle(uuid, uuid) is
  'Asigna un motorraton a un conductor. Varios pueden compartir la misma unidad (doble turno).';


-- -----------------------------------------------------------------------------
-- admin_list_vehicles pasa a contar varios conductores
-- -----------------------------------------------------------------------------
--
-- Con el limite levantado, el `left join` de antes devolvia **una fila por
-- conductor**, asi que una unidad compartida habria salido dos veces en el
-- panel. Se agrupa.
--
-- `driver_name` cambia de significado y por eso cambia de nombre: ya no es "el
-- conductor", es `drivers_label`, la lista de los que la comparten. Y se anade
-- `active_driver_name`, **el que esta al volante ahora**, que es el unico dato
-- que responde a "quien viene con esta unidad".
drop function if exists public.admin_list_vehicles();

create or replace function public.admin_list_vehicles()
returns table (
  vehicle_id uuid,
  unit_number integer,
  plate text,
  model text,
  max_passengers smallint,
  status public.vehicle_status,
  notes text,

  -- Cuantos y quienes la comparten.
  driver_count integer,
  drivers_label text,
  -- Los identificadores, para que el panel pueda ofrecer quitar a uno concreto.
  driver_ids uuid[],

  -- Quien esta trabajando con ella ahora mismo: el disponible, o el que tiene un
  -- servicio en marcha. Nulo si ninguno de los que la comparten esta conectado.
  active_driver_id uuid,
  active_driver_name text,

  has_active_ride boolean,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
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
    -- disponible: si alguien esta conduciendo, ese es el que lleva la unidad,
    -- este como este su interruptor.
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
    coalesce(array_agg(a.driver_id order by a.full_name)
             filter (where a.driver_id is not null), '{}'),

    av.driver_id,
    av.full_name,

    exists (
      select 1 from public.rides r
      where r.vehicle_id = v.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    v.created_at
  from public.vehicles v
  left join asignados a on a.vehicle_id = v.id
  left join al_volante av on av.vehicle_id = v.id
  group by v.id, av.driver_id, av.full_name
  order by
    case v.status when 'active' then 0 when 'maintenance' then 1 else 2 end,
    v.unit_number;
$$;

comment on function public.admin_list_vehicles() is
  'Listado de vehiculos con todos sus conductores asignados y quien va al volante ahora.';

revoke all on function public.admin_list_vehicles() from public;
grant execute on function public.admin_list_vehicles() to authenticated;


-- -----------------------------------------------------------------------------
-- Quitar a un conductor concreto de una unidad
-- -----------------------------------------------------------------------------
--
-- `admin_unassign_vehicle(p_driver_id)` ya servia y no cambia: quita a UN
-- conductor, y con varios compartiendo unidad eso es justo lo que hace falta.
-- Queda dicho aqui para que no se busque una funcion nueva que no existe.
