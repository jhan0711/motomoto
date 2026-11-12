-- =============================================================================
-- D309. Recordatorio de oferta: una segunda llamada al conductor que la dejo caducar
-- =============================================================================
--
-- PROBLEMA (Jhan, 2026-11-12). Pasado el tiempo de la oferta, esta no volvia a
-- salir. La regla R12 -"no se reofrece a quien ya la recibio"- esta garantizada
-- por `ro_one_offer_per_driver UNIQUE (request_id, driver_id)`, y era estricta
-- adrede: "quien ignoro una solicitud hace veinte segundos probablemente ignore
-- la siguiente". Pero la solicitud del PASAJERO vive 5 minutos
-- (`request_expiry_seconds` = 300) y la pantalla le dice "Buscando motocarro 4:56"
-- cuando ya nadie puede aceptarla: sobraban 4 minutos y medio de espera inutil.
--
-- DECISION (Jhan: "hacemos las dos"):
--   1. `offer_response_seconds` de 30 a 60 s (ajuste de configuracion, ya hecho).
--   2. ESTO: un recordatorio UNA SOLA VEZ, con notificacion, a quien dejo caducar
--      la oferta SIN responder.
--
-- COMO. No se crea una oferta nueva (la restriccion de unicidad se mantiene): se
-- RENUEVA la misma fila. Pasa de 'expired' a 'pending' con un `expires_at` nuevo
-- y `reminded_at` anotado. `reminded_at` es lo que impide un segundo recordatorio.
--   * La app del conductor NO cambia: ya vuelve a cargar su lista cuando una
--     oferta cambia (UPDATE), y `list_driver_offers` devuelve las pendientes
--     vigentes.
--   * `accept_ride_offer` tampoco cambia: acepta una oferta 'pending' no vencida.
--   * La notificacion sale de un disparador sobre `reminded_at`, igual que la de
--     la oferta nueva sale de `notify_new_offer`.
--
-- A QUIEN SE RECUERDA. Solo a quien dejo caducar sin responder: el que RECHAZO no
-- (R12 sigue valiendo para el). Y solo si sigue siendo elegible AHORA (disponible,
-- con saldo, etc.: se reutiliza `find_available_drivers`) y si a la solicitud le
-- queda tiempo.
--
-- EL CONTADOR DE OFERTAS SIN RESPONDER (D296). Una oferta ignorada cuenta una vez
-- para desconectar al conductor a las K seguidas. El recordatorio NO debe contar
-- doble: `track_offer_response` solo cuenta la primera caducidad (`reminded_at is
-- null`). Si el conductor RESPONDE al recordatorio, el contador vuelve a cero como
-- siempre.
--
-- INTERRUPTOR: `offer_reminder_enabled` = 0 lo apaga sin publicar nada.
-- Los dos parametros nuevos no tienen rango en `admin_set_setting`: se cambian por
-- SQL (mismo caso que los de D296).
-- =============================================================================

alter table public.ride_offers add column reminded_at timestamptz;

comment on column public.ride_offers.reminded_at is
  'D309. Cuando se le volvio a ofrecer (recordatorio unico). Nulo = nunca se le recordo.';

insert into public.app_settings (key, value, description) values
  ('offer_reminder_enabled', '1',
   'D309. 1 = se manda un recordatorio unico a quien dejo caducar una oferta sin responder; 0 = apagado.'),
  ('offer_reminder_delay_seconds', '15',
   'D309. Segundos que deben pasar desde que caduco la oferta antes de recordarla.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 1. El contador de ofertas sin responder: solo la primera caducidad cuenta
-- ---------------------------------------------------------------------------

create or replace function public.track_offer_response()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_request_status public.ride_request_status;
  v_count integer;
  v_k integer;
begin
  perform set_config('app.driver_session_write', 'on', true);

  if old.response = 'pending' and new.response in ('accepted', 'rejected') then
    update public.drivers
    set unanswered_offers = 0, last_seen_at = now()
    where id = new.driver_id;

  -- D309: `new.reminded_at is null`. Una oferta recordada que vuelve a caducar ya
  -- conto la primera vez; no se cuenta dos veces por la misma solicitud.
  elsif old.response = 'pending' and new.response = 'expired'
        and new.expires_at <= now()
        and new.reminded_at is null then
    select status into v_request_status
    from public.ride_requests where id = new.request_id;

    if v_request_status = 'searching' then
      update public.drivers
      set unanswered_offers = unanswered_offers + 1
      where id = new.driver_id and is_available
      returning unanswered_offers into v_count;

      v_k := (public.get_setting('driver_max_unanswered_offers', '3'))::integer;

      -- Siempre se cuenta; solo se DESCONECTA (y se avisa) en modo 'session'.
      if v_count is not null and v_count >= v_k
         and coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') = 'session' then
        update public.drivers
        set is_available = false, disconnect_reason = 'unanswered_offers'
        where id = new.driver_id;

        perform public.send_push_notification(
          new.driver_id,
          'driver_disconnected',
          'Te desconectamos',
          'No respondiste varias solicitudes seguidas. Abre la app para volver a conectarte.',
          jsonb_build_object('driverDisconnected', true)
        );
      end if;
    end if;
  end if;

  return null;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. El recordatorio
-- ---------------------------------------------------------------------------

create function public.remind_unanswered_offers()
 returns integer
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare
  v_window integer;
  v_delay integer;
  v_count integer;
begin
  if (public.get_setting('offer_reminder_enabled', '1'))::integer <> 1 then
    return 0;
  end if;

  v_window := (public.get_setting('offer_response_seconds', '30'))::integer;
  v_delay  := (public.get_setting('offer_reminder_delay_seconds', '15'))::integer;

  with candidatas as (
    select o.id
    from public.ride_offers o
    join public.ride_requests r on r.id = o.request_id
    where o.response = 'expired'              -- dejo caducar (NO rechazo)
      and o.reminded_at is null               -- una sola vez
      and o.expires_at <= now() - make_interval(secs => v_delay)
      and r.status = 'searching'
      -- A la solicitud le tiene que quedar tiempo para que valga la pena.
      and r.expires_at > now() + interval '20 seconds'
      -- Sigue siendo elegible AHORA: disponible, con saldo, ubicacion, asientos...
      and exists (
        select 1
        from public.find_available_drivers(r.origin, r.passenger_count) f
        where f.driver_id = o.driver_id
      )
    for update of o skip locked
  )
  update public.ride_offers o
  set response = 'pending',
      responded_at = null,
      -- La nueva ventana, pero nunca mas alla de la vida de la solicitud.
      expires_at = least(
        now() + make_interval(secs => v_window),
        (select r.expires_at from public.ride_requests r where r.id = o.request_id)
      ),
      reminded_at = now()
  from candidatas c
  where o.id = c.id;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

revoke all on function public.remind_unanswered_offers() from public, anon, authenticated;
grant execute on function public.remind_unanswered_offers() to service_role;

-- ---------------------------------------------------------------------------
-- 3. La notificacion
-- ---------------------------------------------------------------------------

create function public.notify_offer_reminder()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  perform public.send_push_notification(
    new.driver_id,
    'offer_reminder',
    'Todavía hay un pasajero esperando',
    'Nadie ha tomado la solicitud. Todavía puedes aceptarla.',
    jsonb_build_object('offerId', new.id)
  );

  return new;
end;
$function$;

create trigger ride_offers_notify_reminder
  after update of reminded_at on public.ride_offers
  for each row
  when (old.reminded_at is null and new.reminded_at is not null)
  execute function public.notify_offer_reminder();

-- ---------------------------------------------------------------------------
-- 4. Cada minuto, junto al barrido que ya caduca las ofertas
-- ---------------------------------------------------------------------------

select cron.schedule('offer-reminder-sweep', '* * * * *', 'select public.remind_unanswered_offers()');
