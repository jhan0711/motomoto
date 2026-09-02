-- =============================================================================
-- FASE 20, PASO 9: asignacion manual de conductor a una solicitud (D7)
-- =============================================================================
--
-- **D7 se escribio en la Fase 0 y lleva desde entonces a medias.** Decia
-- "asignacion automatica por cercania, **con anulacion manual del
-- administrador**". Lo automatico existe desde la Fase 13; lo manual no existia
-- porque no habia panel.
--
-- PARA QUE SIRVE DE VERDAD, que es lo que decide como se construye. No es una
-- forma alternativa de repartir servicios: es **la salida cuando el automatico
-- no llega**. Los casos reales:
--
--   - nadie acepto y el pasajero sigue esperando -9 de los 57 servicios de la
--     base acabaron asi-
--   - el conductor esta en la calle pero con la aplicacion cerrada, y la empresa
--     lo tiene al telefono
--   - un servicio que hay que dar a alguien concreto por lo que sea
--
-- POR ESO NO EXIGE QUE EL CONDUCTOR ESTE DISPONIBLE (D256). `is_available` es lo
-- que mira el reparto automatico, y **si el automatico bastara no haria falta
-- esta funcion**. Lo que si exige es todo lo que hace que el servicio pueda
-- ocurrir de verdad: aprobado, cuenta activa, con motorraton activo, con
-- asientos, y sin otro servicio encima.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El disparador de notificacion deja de avisar por las ofertas ya respondidas
-- -----------------------------------------------------------------------------
--
-- `ride_offers_notify_new` es AFTER INSERT **sin condicion**, asi que cualquier
-- fila nueva manda "Tienes un servicio disponible cerca de ti". Para una
-- asignacion manual ese texto miente por partida doble: **ni es una oferta que
-- pueda rechazar, ni tiene veinte segundos para pensarlo**.
--
-- Se le pone la condicion de que la oferta nazca pendiente. **El comportamiento
-- de hoy no cambia**: las ofertas del reparto automatico nacen todas pendientes.
drop trigger if exists ride_offers_notify_new on public.ride_offers;

create trigger ride_offers_notify_new
  after insert on public.ride_offers
  for each row
  when (new.response = 'pending')
  execute function public.notify_new_offer();


-- -----------------------------------------------------------------------------
-- admin_assign_driver
-- -----------------------------------------------------------------------------

create or replace function public.admin_assign_driver(
  p_request_id uuid,
  p_driver_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request public.ride_requests;
  v_driver record;
  v_vehicle record;
  v_ride_id uuid;
  v_offer_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede asignar un conductor'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  -- `for update` como en `accept_ride_offer`: si un conductor esta aceptando en
  -- este mismo instante, uno de los dos espera al otro y el segundo encuentra la
  -- solicitud ya asignada.
  select * into v_request from public.ride_requests where id = p_request_id for update;

  if not found then
    raise exception 'No se encontro esa solicitud'
      using errcode = 'P0001', hint = 'REQUEST_NOT_FOUND';
  end if;

  -- **SOLO SE ASIGNA LO QUE SIGUE BUSCANDO.** Un servicio ya asignado, terminado
  -- o cancelado no se reasigna desde aqui: cambiar el conductor de un viaje en
  -- marcha es otra operacion, con un pasajero esperando a alguien que ya no va.
  if v_request.status <> 'searching' then
    raise exception 'Esa solicitud ya no esta buscando conductor'
      using errcode = 'P0001', hint = 'REQUEST_NOT_SEARCHING';
  end if;

  -- Aunque haya caducado la ventana, la solicitud sigue en `searching` hasta que
  -- alguien la caduca. Asignar una vencida dejaria al pasajero con un conductor
  -- para un viaje que ya dio por perdido.
  if v_request.expires_at < now() then
    raise exception 'Esa solicitud ya vencio. El pasajero tiene que volver a pedirla'
      using errcode = 'P0001', hint = 'REQUEST_EXPIRED';
  end if;

  select p.status, p.full_name, d.approval_status
  into v_driver
  from public.drivers d
  join public.profiles p on p.id = d.id
  where d.id = p_driver_id;

  if not found then
    raise exception 'No se encontro ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  if v_driver.approval_status <> 'approved' then
    raise exception 'Ese conductor no esta aprobado para trabajar'
      using errcode = 'P0001', hint = 'DRIVER_NOT_APPROVED';
  end if;

  if v_driver.status <> 'active' then
    raise exception 'La cuenta de ese conductor esta bloqueada'
      using errcode = 'P0001', hint = 'DRIVER_ACCOUNT_BLOCKED';
  end if;

  -- El motorraton, con las mismas condiciones que exige `accept_ride_offer`.
  select v.id, v.unit_number, v.max_passengers
  into v_vehicle
  from public.driver_vehicle_assignments a
  join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = p_driver_id and a.unassigned_at is null and v.status = 'active';

  if v_vehicle.id is null then
    raise exception 'Ese conductor no tiene un motorraton activo asignado'
      using errcode = 'P0001', hint = 'NO_VEHICLE_ASSIGNED';
  end if;

  -- **EL COMPANERO DE TURNO (D246).** Si comparten unidad y el otro esta
  -- conectado, asignar a este pondria dos personas a trabajar con un solo
  -- motorraton. Se comprueba aqui porque la regla del doble turno vive en
  -- `is_available`, y esta funcion **no la exige** a quien se asigna.
  if exists (
    select 1
    from public.driver_vehicle_assignments companero
    join public.drivers d2 on d2.id = companero.driver_id and d2.is_available
    where companero.vehicle_id = v_vehicle.id
      and companero.unassigned_at is null
      and companero.driver_id <> p_driver_id
  ) then
    raise exception 'Otro conductor esta conectado con ese motorraton. Solo uno puede llevarlo a la vez'
      using errcode = 'P0001', hint = 'COMPANION_ALREADY_AVAILABLE';
  end if;

  -- La capacidad la garantiza `enforce_ride_capacity` al insertar, y ahi tambien
  -- salta `DRIVER_VEHICLE_CONFLICT` si lleva un viaje con otra unidad. Se
  -- comprueba antes solo para dar un mensaje que se entienda.
  if v_request.passenger_count > v_vehicle.max_passengers then
    raise exception 'Ese motorraton tiene % plazas y el servicio pide %',
      v_vehicle.max_passengers, v_request.passenger_count
      using errcode = 'P0001', hint = 'NOT_ENOUGH_SEATS';
  end if;

  -- ---------------------------------------------------------------------------
  -- La asignacion, con los mismos pasos que `accept_ride_offer`
  -- ---------------------------------------------------------------------------

  -- Si ya tenia una oferta viva, se marca aceptada; si no, se crea una. **Tiene
  -- que existir la fila**: el historial del conductor sale de `ride_offers` y no
  -- de `rides` (D196), asi que sin ella el servicio no le apareceria nunca.
  --
  -- Nace ya aceptada, y por eso el disparador de arriba no la notifica como
  -- oferta nueva: no lo es.
  update public.ride_offers
  set response = 'accepted', responded_at = now()
  where request_id = p_request_id and driver_id = p_driver_id and response = 'pending'
  returning id into v_offer_id;

  if v_offer_id is null then
    insert into public.ride_offers (
      request_id, driver_id, offered_at, expires_at, response, responded_at
    ) values (
      p_request_id, p_driver_id, now(), now() + interval '1 minute', 'accepted', now()
    )
    returning id into v_offer_id;
  end if;

  insert into public.rides (request_id, driver_id, vehicle_id, passenger_count)
  values (p_request_id, p_driver_id, v_vehicle.id, v_request.passenger_count)
  returning id into v_ride_id;

  update public.ride_requests
  set status = 'assigned', assigned_at = now()
  where id = p_request_id;

  -- Las demas ofertas dejan de tener sentido, igual que al aceptar.
  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = p_request_id and response = 'pending';

  -- Misma regla que al aceptar: mientras atiende un servicio no recibe otros.
  update public.drivers set is_available = false where id = p_driver_id;

  -- **EL AVISO LO MANDA ESTA FUNCION, con su propio texto.** El del disparador
  -- dice "tienes un servicio disponible cerca de ti", que aqui seria mentira: no
  -- hay nada que aceptar ni tiempo que corra. Este dice lo que pasa de verdad.
  perform public.send_push_notification(
    p_driver_id,
    'admin_assigned',
    'La empresa te asigno un servicio',
    'Tienes un servicio asignado. Abre la aplicacion para verlo.',
    jsonb_build_object('rideId', v_ride_id)
  );

  perform public.log_admin_action(
    'assign_driver', 'ride_requests', p_request_id::text,
    jsonb_build_object('status', 'searching'),
    jsonb_build_object('driver_id', p_driver_id, 'driver_name', v_driver.full_name,
                       'unit_number', v_vehicle.unit_number, 'ride_id', v_ride_id,
                       'reason', p_reason)
  );

  return v_ride_id;
end;
$$;

comment on function public.admin_assign_driver(uuid, uuid, text) is
  'Asigna a mano un conductor a una solicitud que sigue buscando (D7).';

revoke all on function public.admin_assign_driver(uuid, uuid, text) from public;
grant execute on function public.admin_assign_driver(uuid, uuid, text) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_list_assignable_drivers
-- -----------------------------------------------------------------------------
--
-- A quien se le puede dar un servicio concreto, **ordenado por cercania al punto
-- de recogida**, que es el mismo criterio que usa el reparto automatico.
--
-- Devuelve tambien a los que NO se puede asignar, con el motivo: esconderlos
-- haria que el administrador se preguntara donde esta un conductor que sabe que
-- existe. **Verlo apagado con su razon resuelve la duda sin salir de la
-- pantalla.**
create or replace function public.admin_list_assignable_drivers(p_request_id uuid)
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  is_available boolean,
  unit_number integer,
  max_passengers smallint,
  rating_average numeric,

  -- A que distancia esta del punto de recogida, si se sabe. Nulo cuando su
  -- ubicacion nunca llego o es la que hay.
  distance_m integer,
  location_age_seconds integer,

  -- Si se le puede asignar, y por que no cuando no.
  can_assign boolean,
  blocked_reason text
)
language sql
stable
security invoker
set search_path = public
as $$
  with solicitud as (
    select rr.origin, rr.passenger_count
    from public.ride_requests rr
    where rr.id = p_request_id
  )
  select
    d.id,
    p.full_name,
    p.phone,
    d.is_available,
    v.unit_number,
    v.max_passengers,
    d.rating_average,

    case when dl.location is not null
      then round(extensions.st_distance(dl.location, s.origin))::integer end,
    case when dl.updated_at is not null
      then greatest(0, extract(epoch from (now() - dl.updated_at)))::integer end,

    -- El orden de estas condiciones importa: se ensena **el primer motivo que
    -- impide asignar**, y estan puestas de la mas de fondo a la mas pasajera.
    (v.id is not null
     and not exists (
       select 1 from public.rides r
       where r.driver_id = d.id
         and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
     )
     and s.passenger_count <= v.max_passengers),

    case
      when v.id is null then 'Sin motorraton activo asignado'
      when exists (
        select 1 from public.rides r
        where r.driver_id = d.id
          and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      ) then 'Ya tiene un servicio en curso'
      when s.passenger_count > v.max_passengers
        then 'Su motorraton tiene ' || v.max_passengers || ' plazas'
    end
  from public.drivers d
  join public.profiles p on p.id = d.id
  cross join solicitud s
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id and v.status = 'active'
  left join public.driver_locations dl on dl.driver_id = d.id
  where d.approval_status = 'approved'
    and p.status = 'active'
  -- Los asignables primero; entre ellos, los mas cerca del punto de recogida,
  -- que es el criterio del reparto automatico. Sin ubicacion, al final.
  order by
    (v.id is not null
     and not exists (
       select 1 from public.rides r
       where r.driver_id = d.id
         and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
     )) desc,
    extensions.st_distance(dl.location, s.origin) nulls last,
    p.full_name;
$$;

comment on function public.admin_list_assignable_drivers(uuid) is
  'Conductores a los que dar un servicio, por cercania, con el motivo de los que no.';

revoke all on function public.admin_list_assignable_drivers(uuid) from public;
grant execute on function public.admin_list_assignable_drivers(uuid) to authenticated;
