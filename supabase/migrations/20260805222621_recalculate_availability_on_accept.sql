-- =============================================================================
-- D161, paso 3: aceptar deja de apagar la disponibilidad, la recalcula
-- =============================================================================
--
-- ESTE ES EL PASO QUE ENCIENDE LA FUNCION. Los dos anteriores prepararon el
-- terreno sin cambiar nada visible: la regla de capacidad ya deja entrar un
-- segundo viaje y el buscador ya cuenta asientos libres, pero ningun conductor
-- llegaba a recibir una segunda oferta, porque al aceptar la primera se quedaba
-- sin disponibilidad. Aqui se quita ese tope.
--
-- La linea que se va decia:
--
--     -- REGLA R7: mientras atiende un servicio no recibe otros.
--     update public.drivers set is_available = false where id = v_uid;
--
-- y la sustituye una resta: sigue disponible mientras le queden asientos.
--
-- ACEPTAR PUEDE APAGAR, NUNCA ENCENDER. La expresion conserva `is_available` en
-- la propia cuenta. Un conductor que apago su disponibilidad a mano puede seguir
-- teniendo una oferta viva de un minuto antes, y si la acepta no debe reaparecer
-- en la lista de disponibles contra su voluntad. La resta solo puede quitarle la
-- disponibilidad, no devolversela.
--
-- NO SE COMPRUEBA LA CAPACIDAD AQUI. Podria parecer natural mirar antes de
-- insertar si el grupo cabe, pero seria una comprobacion previa que se queda
-- obsoleta entre el SELECT y el INSERT. De eso se encarga el disparador del paso
-- 1, que bloquea el vehiculo y cuenta con la fila delante. Si no cabe, el INSERT
-- de aqui abajo revienta con VEHICLE_CAPACITY_EXCEEDED y toda la transaccion se
-- deshace, incluida la marca de oferta aceptada. Es el mismo criterio que ya se
-- aplicaba a la carrera entre dos conductores.
--
-- LOS OTROS TRES SITIOS QUE TOCAN LA DISPONIBILIDAD NO CAMBIAN. `complete_ride`,
-- `cancel_ride` y `cancel_request` la ponen en true, y sigue siendo correcto:
-- los tres liberan asientos, asi que despues de cualquiera de ellos siempre
-- queda hueco.
-- =============================================================================

create or replace function public.accept_ride_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := (select auth.uid());
  v_offer public.ride_offers;
  v_request public.ride_requests;
  v_vehicle uuid;
  v_ride_id uuid;
  v_free smallint;
begin
  select * into v_offer from public.ride_offers where id = p_offer_id;

  if not found or v_offer.driver_id <> v_uid then
    raise exception 'Esa oferta no es tuya' using errcode = 'P0001', hint = 'OFFER_NOT_FOUND';
  end if;

  if v_offer.response <> 'pending' then
    raise exception 'Ya respondiste a esta solicitud'
      using errcode = 'P0001', hint = 'OFFER_ALREADY_ANSWERED';
  end if;

  if v_offer.expires_at < now() then
    raise exception 'La solicitud expiro' using errcode = 'P0001', hint = 'OFFER_EXPIRED';
  end if;

  select * into v_request from public.ride_requests where id = v_offer.request_id for update;

  if v_request.status <> 'searching' then
    raise exception 'Otro conductor tomo esta solicitud'
      using errcode = 'P0001', hint = 'REQUEST_ALREADY_TAKEN';
  end if;

  select a.vehicle_id into v_vehicle
  from public.driver_vehicle_assignments a
  join public.vehicles v on v.id = a.vehicle_id
  where a.driver_id = v_uid and a.unassigned_at is null and v.status = 'active';

  if v_vehicle is null then
    raise exception 'No tienes un motorraton asignado'
      using errcode = 'P0001', hint = 'NO_VEHICLE_ASSIGNED';
  end if;

  -- Marcar la oferta como aceptada. Si otro conductor gano la carrera, el indice
  -- unico parcial ro_one_accepted_per_request rechaza esta escritura. No es una
  -- comprobacion previa que pueda quedarse obsoleta entre el SELECT y el UPDATE:
  -- es el propio motor de la base de datos garantizando que solo pasa uno.
  begin
    update public.ride_offers
    set response = 'accepted', responded_at = now()
    where id = p_offer_id;
  exception when unique_violation then
    raise exception 'Otro conductor tomo esta solicitud'
      using errcode = 'P0001', hint = 'REQUEST_ALREADY_TAKEN';
  end;

  -- Si el grupo no cabe, el disparador enforce_ride_capacity para aqui.
  insert into public.rides (request_id, driver_id, vehicle_id, passenger_count)
  values (v_request.id, v_uid, v_vehicle, v_request.passenger_count)
  returning id into v_ride_id;

  update public.ride_requests
  set status = 'assigned', assigned_at = now()
  where id = v_request.id;

  -- Las demas ofertas de ESTA solicitud dejan de tener sentido. Las que el
  -- conductor tenga de otras solicitudes siguen vivas a proposito: con D161
  -- puede atender mas de una si le caben y le quedan de camino.
  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = v_request.id and response = 'pending';

  -- DECISION D161: sigue disponible mientras le queden asientos. El vehiculo ya
  -- quedo bloqueado por el disparador durante el INSERT de arriba, asi que esta
  -- cuenta ve el viaje recien creado y no puede cruzarse con otra aceptacion.
  select v.max_passengers - coalesce((
           select sum(r.passenger_count)
           from public.rides r
           where r.vehicle_id = v_vehicle
             and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
         ), 0)
  into v_free
  from public.vehicles v
  where v.id = v_vehicle;

  update public.drivers
  set is_available = (is_available and v_free > 0)
  where id = v_uid;

  return v_ride_id;
end;
$$;

comment on function public.accept_ride_offer is
  'Acepta una oferta y recalcula la disponibilidad segun los asientos que queden (D161).';
