-- Punto 3 del plan del 2026-09-23 (D278), primera entrega: el libro de
-- movimientos del conductor, la comision del 4% y el bloqueo por saldo.
-- Wompi NO entra aqui: la recarga por pasarela va en una entrega aparte.
--
-- ESTA ES LA PRIMERA VEZ QUE LA APLICACION MANEJA DINERO. Hasta hoy la frontera
-- documentada era "la plataforma no procesa pagos"; un saldo prepagado es plata
-- del conductor que la empresa tiene en custodia. Por eso:
--
--  * El saldo NO es un numero que se pisa. Es la suma de un libro que solo se
--    anade (`driver_ledger`): cada recarga, cada comision y cada ajuste es una
--    fila con su viaje o su referencia, y una disputa se revisa leyendo filas.
--    Nada actualiza ni borra (un disparador lo impide hasta para las funciones
--    `security definer`); una correccion es OTRA fila, un ajuste con motivo.
--
--  * Todo queda APAGADO por defecto (`driver_balance_enforced` = 0). Al
--    desplegar, todos los conductores tienen saldo 0, y encenderlo de golpe
--    bloquearia a los que trabajan hoy. La empresa lo enciende cuando la
--    recarga funcione y los conductores tengan saldo. Con el interruptor
--    apagado no se cobra ni se bloquea nada.
--
--  * El saldo puede quedar NEGATIVO: si la comision de un viaje supera lo que
--    queda, se descuenta completa igual. El conductor queda bloqueado hasta que
--    una recarga lo lleve de vuelta por encima del minimo; la recarga paga la
--    deuda primero, por simple suma. Con ofertas de hasta 5 veces la tarifa
--    (D277) esto puede pasar, y rechazar el viaje seria una regla mas dentro del
--    flujo critico de aceptar.

-- ---------------------------------------------------------------------------
-- Parametros
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value, description) values
  ('driver_balance_enforced', '0'::jsonb,
   'Interruptor del saldo de conductores. 0 = apagado (no se cobra comision ni se bloquea a nadie); 1 = encendido.'),
  ('commission_percent', '4'::jsonb,
   'Comision de la empresa, en porcentaje del valor acordado de cada servicio terminado (fare_amount).'),
  ('min_topup_amount', '10000'::jsonb,
   'Recarga minima del conductor, en pesos.');

-- ---------------------------------------------------------------------------
-- El libro
-- ---------------------------------------------------------------------------

create type public.ledger_entry_kind as enum ('topup', 'commission', 'adjustment');

-- `driver_id` y `ride_id` SIN llave foranea, a proposito: es un registro
-- contable y tiene que sobrevivir a la cuenta. Un conductor que borra su cuenta
-- (Fase 25) no puede llevarse con el sus movimientos, y una llave foranea o
-- bloquearia el borrado o lo arrastraria en cascada. Solo escriben las
-- funciones de este archivo, asi que la integridad la ponen ellas.
create table public.driver_ledger (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  kind public.ledger_entry_kind not null,
  -- Con signo: recargas y ajustes a favor suman, comisiones y ajustes en contra
  -- restan. El saldo es la suma de esta columna.
  amount integer not null,
  ride_id uuid,
  -- El id de la transaccion en Wompi, para las recargas. Unico: una notificacion
  -- repetida de la pasarela no puede acreditar dos veces.
  external_ref text,
  -- Obligatorio en los ajustes: quien toca el dinero explica por que.
  reason text,
  created_by uuid,
  created_at timestamptz not null default now(),

  constraint dl_amount_not_zero check (amount <> 0),
  constraint dl_amount_range check (amount between -10000000 and 10000000),
  constraint dl_topup_positive check (kind <> 'topup' or amount > 0),
  constraint dl_commission_negative check (kind <> 'commission' or amount < 0),
  constraint dl_commission_has_ride check (kind <> 'commission' or ride_id is not null),
  constraint dl_adjustment_has_reason
    check (kind <> 'adjustment' or (reason is not null and length(trim(reason)) >= 5)),
  constraint dl_reason_length check (reason is null or length(reason) <= 300)
);

-- Una comision por viaje: terminar dos veces el mismo viaje no puede cobrar dos.
create unique index dl_one_commission_per_ride
  on public.driver_ledger (ride_id) where kind = 'commission';

-- Una recarga por transaccion de la pasarela.
create unique index dl_one_topup_per_external_ref
  on public.driver_ledger (external_ref) where external_ref is not null;

create index dl_driver_created on public.driver_ledger (driver_id, created_at desc);

comment on table public.driver_ledger is
  'Libro de movimientos del saldo de los conductores. Solo se anade: nada se actualiza ni se borra, una correccion es otra fila.';

create function public.driver_ledger_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'El libro de movimientos solo admite filas nuevas'
    using errcode = 'P0001', hint = 'LEDGER_IS_APPEND_ONLY';
end;
$$;

create trigger driver_ledger_no_update_delete
  before update or delete on public.driver_ledger
  for each row execute function public.driver_ledger_append_only();

create trigger driver_ledger_no_truncate
  before truncate on public.driver_ledger
  for each statement execute function public.driver_ledger_append_only();

alter table public.driver_ledger enable row level security;

revoke all on public.driver_ledger from public, anon, authenticated;
grant select on public.driver_ledger to authenticated;

-- El conductor lee sus propios movimientos; el administrador, los de todos. Nadie
-- escribe directo: solo las funciones de abajo, que son `security definer`.
create policy driver_ledger_select_own on public.driver_ledger
  for select to authenticated
  using (driver_id = (select auth.uid()) or (select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Saldo y reglas
-- ---------------------------------------------------------------------------

create function public.driver_balance(p_driver uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(amount), 0)::integer from public.driver_ledger where driver_id = p_driver;
$$;

revoke all on function public.driver_balance(uuid) from public, anon, authenticated;

create function public.balance_enforced()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((public.get_setting('driver_balance_enforced', '0'))::numeric, 0) = 1;
$$;

revoke all on function public.balance_enforced() from public, anon, authenticated;

-- El saldo minimo para trabajar: el 4% del viaje minimo (la tarifa mas baja de la
-- tabla, hoy $4.000 -> $160). Por debajo de esto el conductor no podria pagar ni
-- la comision del servicio mas barato.
create function public.driver_min_balance()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select ceil(
    (public.get_setting('commission_percent', '4'))::numeric / 100
    * public.get_min_offer_amount()
  )::integer;
$$;

revoke all on function public.driver_min_balance() from public, anon, authenticated;

-- Verdadero si el cobro esta apagado o si el saldo alcanza. Es la unica pregunta
-- que hacen el reparto, el aceptar y el encender "disponible".
create function public.driver_can_work(p_driver uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.balance_enforced()
      or public.driver_balance(p_driver) >= public.driver_min_balance();
$$;

revoke all on function public.driver_can_work(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Lo que ve el conductor
-- ---------------------------------------------------------------------------

create function public.get_my_balance()
returns table (
  balance integer,
  min_required integer,
  enforced boolean,
  commission_percent numeric,
  min_topup integer,
  can_work boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    public.driver_balance((select auth.uid())),
    public.driver_min_balance(),
    public.balance_enforced(),
    (public.get_setting('commission_percent', '4'))::numeric,
    (public.get_setting('min_topup_amount', '10000'))::integer,
    public.driver_can_work((select auth.uid()))
  where exists (select 1 from public.drivers d where d.id = (select auth.uid()));
$$;

revoke all on function public.get_my_balance() from public, anon;
grant execute on function public.get_my_balance() to authenticated;

create function public.list_my_ledger(p_limit integer default 50)
returns table (
  id uuid,
  kind public.ledger_entry_kind,
  amount integer,
  ride_id uuid,
  reason text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select l.id, l.kind, l.amount, l.ride_id, l.reason, l.created_at
  from public.driver_ledger l
  where l.driver_id = (select auth.uid())
  order by l.created_at desc, l.id
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
$$;

revoke all on function public.list_my_ledger(integer) from public, anon;
grant execute on function public.list_my_ledger(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Lo que hace el administrador
-- ---------------------------------------------------------------------------

-- Es el camino para revertir un descuento en disputa -siempre dejando registro-
-- y, mientras Wompi no exista, tambien para acreditar saldo a mano. El motivo es
-- obligatorio y la accion queda en el registro de auditoria del panel.
create function public.admin_adjust_driver_balance(
  p_driver uuid,
  p_amount integer,
  p_reason text,
  p_ride_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ajustar un saldo'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if not exists (select 1 from public.drivers where id = p_driver) then
    raise exception 'No encontramos a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  if p_amount is null or p_amount = 0 or abs(p_amount) > 10000000 then
    raise exception 'El ajuste debe ser un valor distinto de cero'
      using errcode = 'P0001', hint = 'INVALID_ADJUSTMENT_AMOUNT';
  end if;

  if p_reason is null or length(trim(p_reason)) < 5 or length(p_reason) > 300 then
    raise exception 'Explica el motivo del ajuste (entre 5 y 300 caracteres)'
      using errcode = 'P0001', hint = 'ADJUSTMENT_REASON_REQUIRED';
  end if;

  insert into public.driver_ledger (driver_id, kind, amount, ride_id, reason, created_by)
  values (p_driver, 'adjustment', p_amount, p_ride_id, trim(p_reason), (select auth.uid()));

  v_balance := public.driver_balance(p_driver);

  perform public.log_admin_action(
    'adjust_driver_balance', 'driver_ledger', p_driver::text,
    null,
    jsonb_build_object('amount', p_amount, 'reason', trim(p_reason), 'ride_id', p_ride_id,
                       'balance_after', v_balance)
  );

  return v_balance;
end;
$$;

revoke all on function public.admin_adjust_driver_balance(uuid, integer, text, uuid) from public, anon;
grant execute on function public.admin_adjust_driver_balance(uuid, integer, text, uuid) to authenticated;

create function public.admin_list_driver_balances()
returns table (driver_id uuid, balance integer, can_work boolean)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, public.driver_balance(d.id), public.driver_can_work(d.id)
  from public.drivers d
  where public.is_admin();
$$;

revoke all on function public.admin_list_driver_balances() from public, anon;
grant execute on function public.admin_list_driver_balances() to authenticated;

create function public.admin_get_driver_ledger(p_driver uuid, p_limit integer default 100)
returns table (
  id uuid,
  kind public.ledger_entry_kind,
  amount integer,
  ride_id uuid,
  external_ref text,
  reason text,
  created_by_name text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select l.id, l.kind, l.amount, l.ride_id, l.external_ref, l.reason, p.full_name, l.created_at
  from public.driver_ledger l
    left join public.profiles p on p.id = l.created_by
  where public.is_admin()
    and l.driver_id = p_driver
  order by l.created_at desc, l.id
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

revoke all on function public.admin_get_driver_ledger(uuid, integer) from public, anon;
grant execute on function public.admin_get_driver_ledger(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Encender el interruptor apaga a quien no alcanza
-- ---------------------------------------------------------------------------

-- Los conductores que ya estan "disponibles" con saldo insuficiente no pasarian
-- por el disparador de encendido -ya estan encendidos-. Sin esto seguirian
-- conectados en la pantalla, aunque el reparto ya no les ofrezca nada.
create function public.turn_off_unfunded_drivers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Anidado a proposito: PostgreSQL no garantiza el orden de un `and`, y otras
  -- claves -la zona horaria- tienen un texto que no se puede convertir a numero.
  if new.key = 'driver_balance_enforced' then
    if (new.value #>> '{}')::numeric = 1 then
      update public.drivers d
      set is_available = false
      where d.is_available
        and not public.driver_can_work(d.id);
    end if;
  end if;

  return new;
end;
$$;

create trigger app_settings_turn_off_unfunded
  after update of value on public.app_settings
  for each row execute function public.turn_off_unfunded_drivers();

-- ---------------------------------------------------------------------------
-- complete_ride: descuenta la comision
-- ---------------------------------------------------------------------------

create or replace function public.complete_ride(p_ride_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_ride public.rides;
  v_distance integer;
  v_points integer;
  v_fare integer;
  v_commission integer;
begin
  v_ride := public.assert_ride_driver(p_ride_id, array['in_progress']::public.ride_status[]);

  -- Solo los puntos del recorrido, no los de la aproximacion. Hacen falta al
  -- menos dos; si el conductor no tuvo cobertura durante el viaje, se deja sin
  -- calcular en lugar de guardar un cero enganoso.
  select count(*) into v_points
  from public.ride_locations
  where ride_id = p_ride_id
    and recorded_at >= v_ride.started_at;

  if v_points >= 2 then
    select round(extensions.st_length(
             extensions.st_makeline(array_agg(location::extensions.geometry order by recorded_at))::extensions.geography
           ))::integer
    into v_distance
    from public.ride_locations
    where ride_id = p_ride_id
      and recorded_at >= v_ride.started_at;
  end if;

  update public.rides
  set status = 'completed',
      completed_at = now(),
      distance_m = v_distance,
      duration_s = extract(epoch from (now() - started_at))::integer
  where id = p_ride_id;

  update public.ride_requests
  set status = 'completed', completed_at = now()
  where id = v_ride.request_id;

  -- D278: la comision de la empresa, sobre el valor ACORDADO del servicio
  -- (`fare_amount`: lo que ofrecio el pasajero, D277). Se anota en el libro en la
  -- misma transaccion que cierra el viaje: o se cierra y se cobra, o no ocurre
  -- ninguna de las dos. Con el interruptor apagado no se cobra nada.
  if public.balance_enforced() then
    select fare_amount into v_fare from public.ride_requests where id = v_ride.request_id;

    if v_fare is not null then
      v_commission := round(v_fare * (public.get_setting('commission_percent', '4'))::numeric / 100)::integer;

      if v_commission > 0 then
        insert into public.driver_ledger (driver_id, kind, amount, ride_id)
        values (v_ride.driver_id, 'commission', -v_commission, v_ride.id);
      end if;
    end if;

    -- Si con esto ya no alcanza ni para el viaje minimo, se apaga "disponible":
    -- lo demas del reparto ya no le ofreceria nada, y dejarlo encendido en la
    -- pantalla seria decirle que trabaja cuando no. Sus otros viajes en curso
    -- siguen su camino; esto solo le cierra la puerta a los nuevos.
    if not public.driver_can_work(v_ride.driver_id) then
      update public.drivers set is_available = false
      where id = v_ride.driver_id and is_available;
    end if;
  end if;

  -- Terminar libera asientos pero no decide por el conductor si sigue
  -- trabajando: la disponibilidad no se toca por eso (ver 20260812083511). Solo
  -- se apaga por saldo, arriba.
end;
$function$
;

-- ---------------------------------------------------------------------------
-- accept_ride_offer: exige saldo
-- ---------------------------------------------------------------------------

create or replace function public.accept_ride_offer(p_offer_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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

  -- D278: la oferta pudo llegar cuando el saldo alcanzaba. Se mira otra vez al
  -- aceptar, mismo criterio que el bloqueo de la cuenta de arriba.
  if not public.driver_can_work(v_uid) then
    raise exception 'Tu saldo no alcanza para recibir servicios. Recarga para continuar'
      using errcode = 'P0001', hint = 'INSUFFICIENT_BALANCE';
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
$function$
;

-- ---------------------------------------------------------------------------
-- block_unavailable_driver: no se enciende sin saldo
-- ---------------------------------------------------------------------------

create or replace function public.block_unavailable_driver()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- D278: sin saldo para el viaje minimo no se puede encender. Apagarse sigue
  -- siendo siempre posible.
  if new.is_available and not coalesce(old.is_available, false)
     and not public.driver_can_work(new.id) then
    raise exception 'Tu saldo no alcanza para recibir servicios. Recarga para continuar'
      using errcode = 'P0001', hint = 'INSUFFICIENT_BALANCE';
  end if;

  return new;
end;
$function$
;

-- ---------------------------------------------------------------------------
-- find_available_drivers: solo con saldo
-- ---------------------------------------------------------------------------

create or replace function public.find_available_drivers(p_origin extensions.geography, p_passenger_count smallint, p_max_staleness interval DEFAULT NULL::interval)
 RETURNS TABLE(driver_id uuid, full_name text, unit_number integer, plate text, max_passengers smallint, rating_average numeric, distance_m double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  select
    d.id,
    p.full_name,
    v.unit_number,
    v.plate,
    v.max_passengers,
    d.rating_average,
    extensions.st_distance(dl.location, p_origin) as distance_m
  from public.drivers d
    join public.profiles p on p.id = d.id
    join public.driver_locations dl on dl.driver_id = d.id
    join public.driver_vehicle_assignments a
      on a.driver_id = d.id and a.unassigned_at is null
    join public.vehicles v on v.id = a.vehicle_id
  where d.is_available
    and d.approval_status = 'approved'
    -- D278: sin saldo para el viaje minimo no se le ofrece nada. Es la red de
    -- seguridad de los otros tres cortes: un conductor que quedo encendido, o
    -- al que un ajuste le bajo el saldo, no recibe ofertas que no podria aceptar.
    and public.driver_can_work(d.id)
    and p.status = 'active'
    and v.status = 'active'
    -- Asientos libres, no capacidad total. Un motorraton de tres que ya lleva
    -- dos personas solo sirve para una solicitud de una.
    and v.max_passengers - coalesce((
          select sum(r.passenger_count)
          from public.rides r
          where r.vehicle_id = v.id
            and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
        ), 0) >= p_passenger_count
    and dl.updated_at > now() - coalesce(
          p_max_staleness,
          make_interval(secs => (public.get_setting('driver_location_stale_seconds', '120'))::integer)
        )
  -- Se conserva el orden por cercania aunque con D160 ya no decida quien gana.
  -- Sigue sirviendo para dos cosas: la distancia que se guarda en cada oferta, y
  -- el dia que la empresa quiera volver a un reparto por tandas.
  order by dl.location <-> p_origin;
$function$
;

-- ---------------------------------------------------------------------------
-- admin_set_setting: rangos de los parametros nuevos
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_setting(p_key text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_before text;
  v_number numeric;
  v_new jsonb;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar la configuracion'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select value #>> '{}' into v_before from public.app_settings where key = p_key;

  if not found then
    -- No se crean parametros desde el panel. Una clave nueva no la lee nadie:
    -- las claves las inventa el codigo, no la pantalla.
    raise exception 'No existe ese parametro'
      using errcode = 'P0001', hint = 'SETTING_NOT_FOUND';
  end if;

  if coalesce(v_before, '') = coalesce(p_value, '') then
    raise exception 'Ese parametro ya vale eso'
      using errcode = 'P0001', hint = 'SETTING_UNCHANGED';
  end if;

  -- ---------------------------------------------------------------------------
  -- Validacion por clave. **CADA RANGO TIENE SU MOTIVO**, no son numeros
  -- redondos: son los limites donde el sistema deja de funcionar.
  -- ---------------------------------------------------------------------------
  if p_key = 'fare_timezone' then
    -- Se comprueba contra el catalogo de PostgreSQL, no contra una lista propia.
    if not exists (select 1 from pg_timezone_names where name = p_value) then
      raise exception 'Esa zona horaria no existe'
        using errcode = 'P0001', hint = 'INVALID_TIMEZONE';
    end if;
    v_new := to_jsonb(p_value);
  else
    begin
      v_number := p_value::numeric;
    exception when others then
      raise exception 'Ese parametro tiene que ser un numero'
        using errcode = 'P0001', hint = 'SETTING_MUST_BE_NUMBER';
    end;

    case p_key
      -- Horas del reloj. Fuera de 0..23 la franja nocturna no se puede evaluar.
      when 'night_fare_start_hour', 'night_fare_end_hour' then
        if v_number < 0 or v_number > 23 or v_number <> floor(v_number) then
          raise exception 'La hora debe ser un entero entre 0 y 23'
            using errcode = 'P0001', hint = 'INVALID_HOUR';
        end if;

      -- R11. Cero dejaria la aplicacion sin poder pedir un solo viaje de
      -- pasajeros; mas de 10 choca contra `vehicles_capacity_range`.
      when 'max_passengers_per_request' then
        if v_number < 1 or v_number > 10 or v_number <> floor(v_number) then
          raise exception 'El maximo de pasajeros debe ser un entero entre 1 y 10'
            using errcode = 'P0001', hint = 'INVALID_PASSENGER_MAX';
        end if;

      -- R2. Cero segundos caduca la oferta antes de que el conductor la vea;
      -- mas de cinco minutos deja al pasajero esperando a uno solo.
      when 'offer_response_seconds' then
        if v_number < 5 or v_number > 300 or v_number <> floor(v_number) then
          raise exception 'La ventana de oferta debe estar entre 5 y 300 segundos'
            using errcode = 'P0001', hint = 'INVALID_OFFER_WINDOW';
        end if;

      -- R1. Menos de un minuto caduca solicitudes que aun se estan repartiendo.
      when 'request_expiry_seconds' then
        if v_number < 60 or v_number > 3600 or v_number <> floor(v_number) then
          raise exception 'La caducidad debe estar entre 60 y 3600 segundos'
            using errcode = 'P0001', hint = 'INVALID_EXPIRY';
        end if;

      -- Coordenadas del centro del pueblo. **Mover esto cambia que lugares
      -- necesitan tarifa (D229) y de donde se mide D219**, asi que al menos se
      -- comprueba que sea una coordenada posible.
      when 'fare_center_lng' then
        if v_number < -180 or v_number > 180 then
          raise exception 'La longitud debe estar entre -180 y 180'
            using errcode = 'P0001', hint = 'INVALID_COORDINATE';
        end if;
      when 'fare_center_lat' then
        if v_number < -90 or v_number > 90 then
          raise exception 'La latitud debe estar entre -90 y 90'
            using errcode = 'P0001', hint = 'INVALID_COORDINATE';
        end if;

      -- Radios en kilometros. El de D230 pegado a cero desactiva el redondeo al
      -- destino mas cercano; muy grande vuelve a encarecer el pueblo, que es
      -- justo el problema que D231 corrigio midiendo.
      when 'rural_snap_max_km', 'unpriced_destination_max_km' then
        if v_number <= 0 or v_number > 50 then
          raise exception 'El radio debe estar entre 0 y 50 kilometros'
            using errcode = 'P0001', hint = 'INVALID_RADIUS';
        end if;

      -- R9. El conductor manda su posicion cada tantos segundos: en viaje cada
      -- 7-10, disponible cada 30. Por debajo de 3 s el temporizador se dispara
      -- casi en bucle y llena `driver_locations` -la tabla mas caliente del
      -- sistema- sin ganar precision; por encima de 30 el pasajero ve el
      -- motorraton dando saltos y roza el umbral de "sin senal".
      when 'location_interval_in_ride_seconds' then
        if v_number < 3 or v_number > 30 or v_number <> floor(v_number) then
          raise exception 'El intervalo en viaje debe ser un entero entre 3 y 30 segundos'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_INTERVAL';
        end if;

      -- Estando solo disponible la posicion sirve para elegir a quien ofrecer un
      -- servicio, no para verlo moverse: por debajo de 10 s es gasto de bateria y
      -- datos para nada. El maximo tiene que quedar por debajo de
      -- `driver_location_stale_seconds` o el conductor caducaria entre un envio y
      -- el siguiente y `find_available_drivers` no lo veria.
      when 'location_interval_available_seconds' then
        if v_number < 10 or v_number > 45 or v_number <> floor(v_number) then
          raise exception 'El intervalo disponible debe ser un entero entre 10 y 45 segundos'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_INTERVAL';
        end if;

      -- El "filtro de distancia minima" de D14/D189: adelanta un envio cuando el
      -- conductor ya recorrio esa distancia, y marca el paso del rastro. En 0,
      -- cada lectura del GPS -que llega con ruido de varios metros- dispara un
      -- envio. Por encima de 500 m el acelerador no salta nunca y el rastro
      -- queda demasiado disperso.
      when 'location_min_distance_m' then
        if v_number < 10 or v_number > 500 or v_number <> floor(v_number) then
          raise exception 'La distancia minima debe ser un entero entre 10 y 500 metros'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_DISTANCE';
        end if;

      -- Cuanto tiene que pasar sin noticias de un conductor para considerar su
      -- posicion caducada. `find_available_drivers` filtra por esto. En 0, nadie
      -- esta disponible nunca. Tiene que ser >= el maximo del intervalo
      -- disponible (45) con margen; por encima de 600 s un conductor que cerro la
      -- aplicacion hace diez minutos seguiria contando como disponible.
      when 'driver_location_stale_seconds' then
        if v_number < 90 or v_number > 600 or v_number <> floor(v_number) then
          raise exception 'La caducidad de la posicion debe ser un entero entre 90 y 600 segundos'
            using errcode = 'P0001', hint = 'INVALID_STALE_WINDOW';
        end if;

      -- Radio dentro del cual el conductor puede confirmar que llego al punto de
      -- recogida. En 0 no puede confirmar jamas -y el servicio se queda
      -- atascado-; por debajo de 20 m el error del GPS ya lo dejaria fuera
      -- estando encima. Por encima de 1 km "he llegado" pierde el sentido.
      when 'driver_arrival_radius_m' then
        if v_number < 20 or v_number > 1000 or v_number <> floor(v_number) then
          raise exception 'El radio de llegada debe ser un entero entre 20 y 1000 metros'
            using errcode = 'P0001', hint = 'INVALID_ARRIVAL_RADIUS';
        end if;

      -- Colchon alrededor del poligono de la zona de servicio. Cero es valido
      -- -exactamente el poligono-; por encima de 5 km el colchon se traga los
      -- municipios vecinos y se aceptarian viajes que no son de Amalfi.
      when 'service_area_margin_m' then
        if v_number < 0 or v_number > 5000 or v_number <> floor(v_number) then
          raise exception 'El margen del area debe ser un entero entre 0 y 5000 metros'
            using errcode = 'P0001', hint = 'INVALID_AREA_MARGIN';
        end if;

      -- Ventana de cancelacion sin penalizacion. Cero es una decision de negocio
      -- valida -se penaliza desde el primer segundo-; por encima de 600 s la
      -- penalizacion no existiria en la practica.
      when 'free_cancellation_seconds' then
        if v_number < 0 or v_number > 600 or v_number <> floor(v_number) then
          raise exception 'La ventana de cancelacion libre debe ser un entero entre 0 y 600 segundos'
            using errcode = 'P0001', hint = 'INVALID_FREE_CANCELLATION';
        end if;

      -- Cuanto se ensena el resumen del servicio recien terminado. En 0 no se
      -- ve; es una tarjeta de transicion, mas de una hora es estorbo.
      when 'finished_summary_minutes' then
        if v_number < 1 or v_number > 60 or v_number <> floor(v_number) then
          raise exception 'La ventana del resumen debe ser un entero entre 1 y 60 minutos'
            using errcode = 'P0001', hint = 'INVALID_SUMMARY_WINDOW';
        end if;

      -- R10 (D263). Cuanto lleva un conductor sin mandar posicion para que el
      -- tablero lo marque "sin senal". Por debajo de 60 s un hueco normal de GPS
      -- -un tunel, el pueblo- lo dispararia todo el rato; por encima de 900 s un
      -- conductor de verdad incomunicado pasaria un cuarto de hora sin que nadie
      -- lo note. La regla avisa, no cancela.
      when 'driver_signal_lost_seconds' then
        if v_number < 60 or v_number > 900 or v_number <> floor(v_number) then
          raise exception 'El umbral de senal perdida debe ser un entero entre 60 y 900 segundos'
            using errcode = 'P0001', hint = 'INVALID_SIGNAL_WINDOW';
        end if;

      -- D278. El interruptor solo admite 0 y 1: cualquier otro valor no seria ni
      -- apagado ni encendido y `balance_enforced` lo leeria como apagado sin
      -- avisar.
      when 'driver_balance_enforced' then
        if v_number not in (0, 1) then
          raise exception 'El interruptor solo puede ser 0 (apagado) o 1 (encendido)'
            using errcode = 'P0001', hint = 'INVALID_SWITCH';
        end if;

      -- D278. Por encima de 20% la comision se come el viaje; en 0 no hay
      -- negocio. Admite decimales (3,5).
      when 'commission_percent' then
        if v_number <= 0 or v_number > 20 then
          raise exception 'La comision debe estar entre 0 y 20 por ciento'
            using errcode = 'P0001', hint = 'INVALID_COMMISSION';
        end if;

      -- D278. Por debajo de mil pesos las comisiones de la pasarela se comen la
      -- recarga; por encima de un millon un conductor inmovilizaria mas plata de
      -- la que gana en un mes de servicios.
      when 'min_topup_amount' then
        if v_number < 1000 or v_number > 1000000 or v_number <> floor(v_number) then
          raise exception 'La recarga minima debe ser un entero entre 1.000 y 1.000.000'
            using errcode = 'P0001', hint = 'INVALID_MIN_TOPUP';
        end if;

      else
        -- Todas las claves que el panel deja editar tienen su rango arriba. Si
        -- una llega aqui es que se anadio al panel y se olvido su cota: se
        -- rechaza en vez de dejar guardar un valor sin validar.
        raise exception 'Ese parametro no tiene rango definido'
          using errcode = 'P0001', hint = 'SETTING_HAS_NO_RANGE';
    end case;

    v_new := to_jsonb(v_number);
  end if;

  update public.app_settings
  set value = v_new, updated_at = now()
  where key = p_key;

  perform public.log_admin_action(
    'set_setting', 'app_settings', p_key,
    jsonb_build_object('value', v_before),
    jsonb_build_object('value', p_value)
  );
end;
$function$
;
