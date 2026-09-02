-- =============================================================================
-- accept_ride_offer: devolverle las tres cosas que la Fase 20 paso 11 le quito
-- =============================================================================
--
-- LO QUE PASO. `20260902150000_blocked_driver_and_r10.sql` reescribio
-- `accept_ride_offer` para meter el corte al conductor bloqueado, y lo hizo
-- **partiendo de una version anterior a `20260805222621`**. Perdio, sin que
-- nadie lo notara, las tres cosas que aquella migracion habia anadido. Es el
-- patron E30, y la cabecera de `20260902150000` hasta afirma "la disponibilidad
-- no cambia aqui" cuando si cambio.
--
-- Lo destapo `prueba_transiciones.sql` (Fase 23, paso 2), comprobacion 18.
--
-- LO QUE SE DEVUELVE, sobre la version de `20260902150000` que es la que manda:
--
--   1. EL `and is_available` EN EL RECALCULO. Quedo `is_available = (v_free > 0)`,
--      que reenciende al conductor que apago el interruptor a mano en cuanto
--      acepta una oferta que ya tenia recibida. D164 dice lo contrario, con el
--      motivo escrito: aceptar puede apagar la disponibilidad, nunca encenderla.
--
--   2. EL `exception when unique_violation` al marcar la oferta aceptada. Es la
--      barrera de la carrera entre dos conductores: sin ella, al que pierde le
--      sale el error crudo del indice `ro_one_accepted_per_request` en lugar de
--      "otro conductor tomo esta solicitud".
--
--   3. EL CIERRE DE LAS DEMAS OFERTAS DE LA MISMA SOLICITUD. Se quedaban en
--      'pending' para siempre. No se ven en la pantalla del conductor porque
--      `list_driver_offers` filtra por solicitud en 'searching', pero dejar la
--      tabla inconsistente no es gratis: cualquier consulta que cuente ofertas
--      pendientes por conductor las sigue contando.
--
-- NO SE TOCA NADA MAS. El corte al bloqueado, el corte al no aprobado, el
-- `for update` de la solicitud y el resto quedan igual que en `20260902150000`.
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
  v_status public.user_status;
  v_approval public.driver_approval_status;
begin
  select * into v_offer from public.ride_offers where id = p_offer_id;

  if not found or v_offer.driver_id <> v_uid then
    raise exception 'Esa oferta no es tuya' using errcode = 'P0001', hint = 'OFFER_NOT_FOUND';
  end if;

  -- El corte al conductor bloqueado o sin aprobar (20260902150000). Se mira al
  -- aceptar y no solo en el reparto: una oferta recibida antes del bloqueo
  -- seguia siendo aceptable.
  select p.status, d.approval_status into v_status, v_approval
  from public.profiles p
  join public.drivers d on d.id = p.id
  where p.id = v_uid;

  if v_status is distinct from 'active' then
    raise exception 'Tu cuenta esta bloqueada. Comunicate con la empresa'
      using errcode = 'P0001', hint = 'ACCOUNT_BLOCKED';
  end if;

  if v_approval is distinct from 'approved' then
    raise exception 'Tu cuenta todavia no esta aprobada por la empresa'
      using errcode = 'P0001', hint = 'DRIVER_NOT_APPROVED';
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
  where a.driver_id = v_uid and a.unassigned_at is null
  limit 1;

  if v_vehicle is null then
    raise exception 'No tienes un motorraton asignado'
      using errcode = 'P0001', hint = 'NO_VEHICLE_ASSIGNED';
  end if;

  -- (2) La carrera entre dos conductores la corta el indice unico parcial
  -- ro_one_accepted_per_request, no una comprobacion previa. Se traduce su
  -- error al mensaje que ya conoce la aplicacion.
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
  values (v_offer.request_id, v_uid, v_vehicle, v_request.passenger_count)
  returning id into v_ride_id;

  update public.ride_requests
  set status = 'assigned', assigned_at = now()
  where id = v_offer.request_id;

  -- (3) Las demas ofertas de ESTA solicitud dejan de tener sentido. Las que el
  -- conductor tenga de otras solicitudes siguen vivas a proposito (D161).
  update public.ride_offers
  set response = 'expired', responded_at = now()
  where request_id = v_offer.request_id and response = 'pending';

  -- DECISION D161: sigue disponible mientras le queden asientos. El vehiculo ya
  -- quedo bloqueado por el disparador durante el INSERT, asi que esta cuenta ve
  -- el viaje recien creado.
  select v.max_passengers - coalesce((
      select sum(r.passenger_count)
      from public.rides r
      where r.vehicle_id = v_vehicle
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ), 0)
  into v_free
  from public.vehicles v where v.id = v_vehicle;

  -- (1) DECISION D164: `and is_available`. Recalcular por asientos puede APAGAR
  -- la disponibilidad, nunca encenderla. Quien la apago a mano no reaparece
  -- disponible por aceptar una oferta que ya tenia.
  update public.drivers
  set is_available = (is_available and v_free > 0)
  where id = v_uid;

  return v_ride_id;
end;
$$;

comment on function public.accept_ride_offer(uuid) is
  'Acepta una oferta. Rechaza si la cuenta esta bloqueada o sin aprobar; recalcula la disponibilidad por asientos sin reencenderla (D161, D164).';

-- El `create or replace` conserva los permisos, pero `db push` a veces vuelve a
-- conceder EXECUTE a PUBLIC. Se deja explicito.
revoke all on function public.accept_ride_offer(uuid) from public, anon;
grant execute on function public.accept_ride_offer(uuid) to authenticated;
