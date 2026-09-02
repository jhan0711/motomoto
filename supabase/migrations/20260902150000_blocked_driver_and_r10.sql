-- =============================================================================
-- QUE EL BLOQUEO MUERDA, Y LA ALERTA DE R10 (Fase 20, paso 11; D215, D216)
-- =============================================================================
--
-- **LO QUE SE MIDIO ANTES DE ESCRIBIR NADA, Y ES PEOR DE LO QUE DECIA D216.**
-- Se monto en el servidor un conductor con un pasajero dentro, se le bloqueo, y
-- se le pregunto que podia seguir haciendo:
--
--   aceptar una oferta nueva ................ LO DEJABA
--   ponerse disponible ...................... LO DEJABA
--   terminar el viaje que llevaba ........... lo dejaba (y debe dejarlo, D262)
--   bloquearlo conduciendo pedia motivo ..... NO
--   el tablero decia que estaba bloqueado ... NO
--
-- O sea: **el bloqueo frenaba el inicio de sesion, pero con la sesion ya abierta
-- el conductor seguia trabajando**. Es lo que D216 dejo pendiente para cuando
-- existiera el panel, y resulto ser mas grande que una alerta.
--
-- LO QUE YA ESTABA BIEN Y NO SE TOCA. `find_available_drivers` **ya filtra
-- `p.status = 'active'`** desde la Fase 11: el reparto automatico nunca ha
-- ofrecido nada a un bloqueado. El hueco estaba en las ofertas **que ya tenia
-- recibidas** antes del bloqueo.
--
-- D262: EL VIAJE QUE LLEVA ENCIMA SE TERMINA. Decidido con el usuario el
-- 2026-09-02. Cortarlo dejaria al pasajero tirado a mitad de camino -de noche o
-- lejos del pueblo, y la aplicacion no sabe conseguirle otro motorraton en el
-- sitio-, y **quien va dentro no tiene la culpa de lo que hizo el conductor**.
-- Lo que se corta es todo lo demas: ese es el ultimo viaje.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Un conductor bloqueado no coge trabajo nuevo
-- -----------------------------------------------------------------------------

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

  -- **SE COMPRUEBA AQUI Y NO SOLO EN EL REPARTO.** `find_available_drivers` ya
  -- deja fuera a los bloqueados, pero eso solo cubre las ofertas **nuevas**: una
  -- oferta recibida un minuto antes del bloqueo seguia siendo aceptable, y con
  -- ella el conductor volvia a la operacion. Se mira en el momento de aceptar,
  -- que es cuando se decide de verdad.
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

  update public.ride_offers
  set response = 'accepted', responded_at = now()
  where id = p_offer_id;

  insert into public.rides (request_id, driver_id, vehicle_id, passenger_count)
  values (v_offer.request_id, v_uid, v_vehicle, v_request.passenger_count)
  returning id into v_ride_id;

  update public.ride_requests
  set status = 'assigned', assigned_at = now()
  where id = v_offer.request_id;

  -- La disponibilidad se recalcula por asientos libres, no se apaga sin mas:
  -- es lo que decidio `20260805222621`, y no cambia aqui.
  select v.max_passengers - coalesce((
      select sum(r.passenger_count)
      from public.rides r
      where r.vehicle_id = v_vehicle
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ), 0)
  into v_free
  from public.vehicles v where v.id = v_vehicle;

  update public.drivers set is_available = (v_free > 0) where id = v_uid;

  return v_ride_id;
end;
$$;

comment on function public.accept_ride_offer(uuid) is
  'Acepta una oferta. Rechaza si la cuenta esta bloqueada o sin aprobar.';


-- -----------------------------------------------------------------------------
-- 2. Ni se pone disponible
-- -----------------------------------------------------------------------------

create or replace function public.block_unavailable_driver()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.user_status;
begin
  -- Solo se vigila el encendido. **Apagarse siempre se puede**, y tiene que
  -- poderse: es justo lo que hace `admin_set_account_status` al bloquear.
  if new.is_available and not coalesce(old.is_available, false) then
    select p.status into v_status from public.profiles p where p.id = new.id;

    if v_status is distinct from 'active' then
      raise exception 'Tu cuenta esta bloqueada. Comunicate con la empresa'
        using errcode = 'P0001', hint = 'ACCOUNT_BLOCKED';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.block_unavailable_driver() is
  'Impide que un conductor bloqueado vuelva a ponerse disponible.';

drop trigger if exists drivers_block_availability on public.drivers;
create trigger drivers_block_availability
  before update of is_available on public.drivers
  for each row
  execute function public.block_unavailable_driver();


-- -----------------------------------------------------------------------------
-- 3. Bloquear a un conductor lo saca de la operacion en el acto
-- -----------------------------------------------------------------------------

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
                       -- Queda escrito si se hizo con un servicio vivo: es el
                       -- dato que explicara la decision dentro de seis meses.
                       'had_active_request', v_active_request is not null)
  );
end;
$$;

comment on function public.admin_set_account_status(uuid, public.user_status, text) is
  'Bloquea o desbloquea una cuenta dejando registro. Con servicio en curso, exige motivo.';


-- -----------------------------------------------------------------------------
-- 4. R10: el conductor sin senal durante un viaje
-- -----------------------------------------------------------------------------
--
-- **R10 NO CANCELA NADA, AVISA.** Lo dice la regla desde la Fase 2 y sigue
-- siendo lo correcto: que un telefono se quede sin cobertura tres minutos en la
-- carretera de Amalfi es lo normal, no una emergencia. Quien decide si pasa algo
-- es la empresa, llamando.
--
-- El umbral vive en `app_settings` como todo lo demas, para que la empresa lo
-- ajuste viendo el tablero sin tocar codigo.
insert into public.app_settings (key, value, description)
values ('driver_signal_lost_seconds', '180'::jsonb,
        'Segundos sin recibir posicion de un conductor en viaje antes de avisar en el tablero (R10)')
on conflict (key) do nothing;


drop function if exists public.admin_list_active_services();

create function public.admin_list_active_services()
returns table (
  request_id uuid,
  status public.ride_request_status,
  service_type public.service_type,
  passenger_count smallint,
  origin_label text,
  destination_label text,
  pickup_reference text,
  parcel_description text,
  fare_amount integer,
  fare_reference text,
  passenger_name text,
  passenger_phone text,
  driver_name text,
  unit_number integer,
  driver_location_age_seconds integer,
  driver_blocked boolean,
  signal_lost boolean,
  pending_offers integer,
  waiting_seconds integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    rr.id,
    rr.status,
    rr.service_type,
    rr.passenger_count,
    rr.origin_label,
    rr.destination_label,
    rr.pickup_reference,
    rr.parcel_description,
    rr.fare_amount,
    rr.fare_reference,
    pp.full_name,
    pp.phone,
    dp.full_name,
    v.unit_number,
    case when dl.updated_at is not null
      then greatest(0, extract(epoch from (now() - dl.updated_at)))::integer end,

    -- **QUE EL CONDUCTOR ESTE BLOQUEADO SE VE EN EL TABLERO.** Antes no se veia
    -- por ningun lado: la empresa bloqueaba a alguien y el servicio seguia en la
    -- pantalla igual que los demas, sin nada que dijera que ese motorraton es el
    -- ultimo que va a hacer esa persona.
    case when r.driver_id is not null then dp.status = 'blocked' end,

    -- R10. Solo tiene sentido con un viaje en marcha: en `searching` todavia no
    -- hay conductor de quien esperar senal.
    case when r.driver_id is not null then
      dl.updated_at is null
      or dl.updated_at < now() - make_interval(
           secs => (public.get_setting('driver_signal_lost_seconds', '180'))::integer)
    end,

    (select count(*) from public.ride_offers o
      where o.request_id = rr.id and o.response = 'pending' and o.expires_at > now())::integer,

    greatest(0, extract(epoch from (now() - rr.requested_at)))::integer
  from public.ride_requests rr
  join public.profiles pp on pp.id = rr.passenger_id
  -- El `left join` excluye los cancelados a proposito: un servicio puede tener
  -- un viaje cancelado y haber vuelto a `searching` esperando otro.
  left join public.rides r on r.request_id = rr.id
    and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  left join public.profiles dp on dp.id = r.driver_id
  left join public.vehicles v on v.id = r.vehicle_id
  left join public.driver_locations dl on dl.driver_id = r.driver_id
  where public.is_admin()
    and rr.status in ('searching', 'assigned', 'in_progress')
  -- Lo que lleva mas tiempo esperando, arriba.
  order by rr.requested_at;
$$;

comment on function public.admin_list_active_services() is
  'Los servicios vivos, con la senal del conductor y si esta bloqueado (R10, D216).';

revoke all on function public.admin_list_active_services() from public;
revoke all on function public.admin_list_active_services() from anon, authenticated;
grant execute on function public.admin_list_active_services() to authenticated;
