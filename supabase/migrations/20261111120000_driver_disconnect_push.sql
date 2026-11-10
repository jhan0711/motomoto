-- =============================================================================
-- D298. Avisar al conductor cuando el SERVIDOR lo desconecta
-- =============================================================================
--
-- La migracion D296 hace que el servidor apague la disponibilidad en dos casos
-- que no decide el conductor: ignora K ofertas seguidas, o su sesion cumple las
-- horas maximas. Con la app minimizada no se entera: el interruptor queda
-- apagado y no entiende por que dejo de recibir servicios.
--
-- Esto anade el aviso: una notificacion push ("Te desconectamos") cuyo dato
-- `driverDisconnected` lleva, al tocarla, a la pantalla del conductor, donde la
-- app explica el motivo y ofrece volver a conectarse.
--
-- Solo se redefinen dos funciones, con el mismo cuerpo de D296 mas la llamada a
-- `send_push_notification`. No cambia datos ni esquema, y solo actua en modo
-- 'session': mientras `availability_mode` siga en 'location' no desconecta a
-- nadie y, por tanto, no manda nada.
-- =============================================================================

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

  elsif old.response = 'pending' and new.response = 'expired'
        and new.expires_at <= now() then
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

create or replace function public.expire_driver_sessions()
 returns integer
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_id uuid;
  v_count integer := 0;
begin
  -- Solo en modo 'session'. En 'location' no hay sesiones que cerrar.
  if coalesce(public.get_setting('availability_mode', '"location"') #>> '{}', 'location') <> 'session' then
    return 0;
  end if;

  perform set_config('app.driver_session_write', 'on', true);

  for v_id in
    update public.drivers
    set is_available = false, disconnect_reason = 'session_expired'
    where is_available
      and availability_started_at is not null
      and availability_started_at < now()
        - make_interval(hours => (public.get_setting('driver_max_session_hours', '12'))::integer)
    returning id
  loop
    v_count := v_count + 1;
    perform public.send_push_notification(
      v_id,
      'driver_disconnected',
      'Tu turno terminó',
      'Cerramos tu turno por llevar muchas horas conectado. Abre la app si sigues trabajando.',
      jsonb_build_object('driverDisconnected', true)
    );
  end loop;

  return v_count;
end;
$function$;
