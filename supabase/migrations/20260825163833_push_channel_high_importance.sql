-- =============================================================================
-- Fase 19, paso 2: el aviso entra por un canal que suena
-- =============================================================================
--
-- POR QUE. La primera version funcionaba —los dos avisos llegaron y se vieron
-- en la bandeja de los dos aparatos— pero **el usuario no se entero de que
-- habia llegado uno**: el canal de Android estaba en importancia DEFAULT, que
-- no suena ni se asoma, asi que "Tu motorratón llegó" quedo enterrado entre las
-- notificaciones del sistema y solo aparecio al desplegar la bandeja, cuatro
-- minutos tarde.
--
-- Los dos avisos de esta fase son justo los que no pueden pasar desapercibidos:
-- uno saca al pasajero a la calle y el otro le da al conductor los veinte
-- segundos de R2 para responder. Un aviso que no se nota no cumple ninguna de
-- las dos cosas.
--
-- QUE CAMBIA AQUI. Solo se anade `channelId` al cuerpo que se le manda a Expo.
-- El canal en si lo crea la aplicacion (`CANAL_SERVICIO` en
-- `use-push-registration.ts`), porque la configuracion de un canal de Android
-- vive en el aparato, no en el servidor.
--
-- LOS DOS NOMBRES TIENEN QUE COINCIDIR. Si se separan, el aviso entra por el
-- canal generico que crea Expo y vuelve a llegar callado: el mismo fallo, pero
-- mas dificil de ver porque todo lo demas sigue funcionando.
--
-- No hace falta recompilar el cliente de desarrollo: el canal se crea desde
-- JavaScript y esto es SQL.
-- =============================================================================

create or replace function public.send_push_notification(
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
        'sound', 'default',
        -- Ver la cabecera: tiene que ser el mismo que CANAL_SERVICIO.
        'channelId', 'service-alerts',
        -- Android descarta los avisos de baja prioridad cuando el aparato esta
        -- ahorrando bateria, que es exactamente cuando un conductor lleva el
        -- telefono en el bolsillo esperando trabajo.
        'priority', 'high'
      )
    );
  end if;
end;
$$;

comment on function public.send_push_notification is
  'Registra la notificacion y la envia por Expo Push si el usuario tiene token. Entra por el canal service-alerts, que suena.';
