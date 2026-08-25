-- =============================================================================
-- Fase 19, paso 3: el canal se versiona a v2
-- =============================================================================
--
-- POR QUE HAY UN PASO 3. El paso 2 subio la importancia a MAX y creo el canal
-- `service-alerts`, pero lo creo con `sound: 'default'`, y en la configuracion
-- de un canal de Android esa propiedad NO significa "el sonido del sistema":
-- es el nombre de un archivo de sonido propio que tendria que venir empaquetado
-- en la aplicacion. Los dos aparatos mostraron el error en pantalla —"Custom
-- sound 'default' not found in native app"— y el aviso siguio llegando callado,
-- que era justo lo que el paso 2 venia a arreglar.
--
-- **La correccion no se puede aplicar sobre el canal existente.** Android
-- congela la configuracion de un canal en cuanto se crea; despues solo el
-- usuario puede tocarla desde los ajustes del sistema. Corregirlo es crear otro
-- con identificador nuevo, y versionarlo asi es lo que recomienda la propia
-- documentacion de Android. El cliente borra los dos anteriores al arrancar
-- para no dejar entradas muertas en los ajustes del usuario.
--
-- El `'sound', 'default'` del cuerpo de abajo se queda como estaba, y no es una
-- contradiccion: ese es de la API de Expo Push, donde 'default' SI significa el
-- sonido por defecto. Es la misma palabra con dos significados en dos sitios
-- distintos, que es exactamente por lo que se colo el error.
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
        -- Tiene que ser el mismo que CANAL_SERVICIO en
        -- `use-push-registration.ts`. Si los dos se separan, el aviso entra por
        -- el canal generico de Expo y vuelve a llegar callado.
        'channelId', 'service-alerts-v2',
        'priority', 'high'
      )
    );
  end if;
end;
$$;

comment on function public.send_push_notification is
  'Registra la notificacion y la envia por Expo Push si el usuario tiene token. Entra por el canal service-alerts-v2, que suena.';
