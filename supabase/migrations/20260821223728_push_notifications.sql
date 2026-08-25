-- =============================================================================
-- Fase 19, paso 1: notificaciones push
-- =============================================================================
--
-- Cubre los dos momentos que el flujo de la seccion 7 deja escritos con todas
-- las letras: "El conductor confirma llegada. Estado DRIVER_ARRIVED y
-- notificacion push" (7.1) y "Llega una solicitud compatible: notificacion y
-- tarjeta..." (7.2). No se inventan mas eventos que esos dos.
--
-- COMO SE ENVIA. `pg_net`, no una Edge Function. El proyecto no tenia ninguna
-- funcion desplegada y anadir ese mecanismo habria significado una herramienta
-- nueva (`supabase functions deploy`) para un solo envio de HTTP. `pg_net` ya
-- viene con el proyecto de Supabase, se activa como cualquier otra extension y
-- la llamada vive en la misma migracion que todo lo demas. Es asincrona:
-- `net.http_post` devuelve un identificador de peticion al momento y el envio
-- de verdad ocurre despues, sin que nadie lo espere. Para un aviso que puede
-- fallar sin que nada dependa de el, es justo lo que hace falta.
--
-- QUE NO HACE FALTA TODAVIA. El servicio de Expo Push no exige credencial para
-- un envio sencillo como este, asi que no hay ningun secreto nuevo que guardar.
--
-- DISPARADORES Y NO FUNCIONES TOCADAS. Ni `confirm_driver_arrival` ni
-- `offer_request_to_drivers` se editan. Un disparador en `rides` y otro en
-- `ride_offers` reaccionan a las filas ya escritas, que es mas seguro
-- (nada que recrear desde su ultima version, la leccion de E30) y mas
-- correcto (una notificacion es un efecto de que el dato cambio, no un paso
-- mas dentro de la transicion que lo cambia).
-- =============================================================================

create extension if not exists pg_net;


-- -----------------------------------------------------------------------------
-- Donde vive el token del dispositivo
-- -----------------------------------------------------------------------------
--
-- Una columna y no una tabla aparte: un usuario, un token, el mas reciente. Es
-- la misma economia que D5 y D9 aplican al resto del modelo. Si algun dia hace
-- falta mandar a varios aparatos del mismo usuario a la vez, es una tabla
-- nueva y una migracion aditiva, no una que se anticipa sin necesidad.
--
-- Sin proteger en `protect_profile_columns`: no es un dato privilegiado, es
-- justo lo que el propio dueño de la cuenta tiene que poder escribir. Es una
-- excepcion acotada mas de las que ya describe D83: el cliente actualiza esta
-- columna en su propia fila, sin pasar por una funcion, con el mismo criterio
-- que `is_available` o `driver_locations`.

alter table public.profiles add column push_token text;

comment on column public.profiles.push_token is
  'Token de Expo Push del dispositivo mas reciente. Nulo si nunca se registro o se revoco.';


-- -----------------------------------------------------------------------------
-- El envio
-- -----------------------------------------------------------------------------

create function public.send_push_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text;
begin
  -- El historial se guarda siempre, tenga o no token: es lo que la pantalla
  -- de notificaciones (si llega a existir) va a leer, y no depende de que el
  -- envio push haya funcionado.
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, p_body, p_data);

  select push_token into v_token from public.profiles where id = p_user_id;

  if v_token is not null then
    perform net.http_post(
      url := 'https://exp.host/--/api/v2/push/send',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Accept', 'application/json'),
      body := jsonb_build_object(
        'to', v_token,
        'title', p_title,
        'body', p_body,
        'data', p_data,
        'sound', 'default'
      )
    );
  end if;
end;
$$;

comment on function public.send_push_notification is
  'Registra la notificacion y la envia por Expo Push si el usuario tiene token. No la llama la aplicacion directamente.';

-- Nadie la llama desde fuera: solo la usan los disparadores de abajo, que
-- corren con los privilegios del dueño de la funcion por ser SECURITY
-- DEFINER. Un cliente que la llamara directo podria mandarle notificaciones a
-- cualquiera con cualquier texto.
revoke all on function public.send_push_notification(uuid, text, text, text, jsonb)
  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- Al pasajero, cuando el conductor llega
-- -----------------------------------------------------------------------------

create function public.notify_driver_arrived()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_passenger uuid;
begin
  if new.status = 'driver_arrived' and old.status is distinct from 'driver_arrived' then
    select passenger_id into v_passenger
    from public.ride_requests where id = new.request_id;

    if v_passenger is not null then
      perform public.send_push_notification(
        v_passenger,
        'driver_arrived',
        'Tu motorratón llegó',
        'Te está esperando en el punto de recogida.',
        jsonb_build_object('rideId', new.id)
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger rides_notify_driver_arrived
  after update on public.rides
  for each row execute function public.notify_driver_arrived();


-- -----------------------------------------------------------------------------
-- Al conductor, cuando le llega una solicitud
-- -----------------------------------------------------------------------------
--
-- Una fila nueva en `ride_offers` ES una solicitud nueva ofrecida, sin
-- distinguir motivo: da igual si sale de `request_ride` o de un `cancel_ride`
-- que reofrece. Las dos veces hay un conductor esperando enterarse.

create function public.notify_new_offer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.send_push_notification(
    new.driver_id,
    'new_offer',
    'Nueva solicitud de servicio',
    'Tienes un servicio disponible cerca de ti.',
    jsonb_build_object('offerId', new.id)
  );

  return new;
end;
$$;

create trigger ride_offers_notify_new
  after insert on public.ride_offers
  for each row execute function public.notify_new_offer();
