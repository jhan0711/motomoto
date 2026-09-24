-- Punto 2 del plan del 2026-09-23: el vehiculo se llama "motocarro", no
-- "motorraton". Este es el UNICO texto de cara al usuario que vive en la base
-- de datos y no en la app: la notificacion push que recibe el pasajero cuando
-- el conductor llega. Sin este cambio, la app diria "motocarro" en pantalla y
-- el telefono "motorraton" en la bandeja.
--
-- Los mensajes de `raise exception` que tambien dicen "motorraton" NO se tocan:
-- son cadenas tecnicas que la app y el panel traducen desde el codigo del
-- `hint`, asi que el usuario nunca las lee. Reescribir 16 funciones de
-- produccion solo para eso seria riesgo sin ganancia.

create or replace function public.notify_driver_arrived()
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
        'Tu motocarro llegó',
        'Te está esperando en el punto de recogida.',
        jsonb_build_object('rideId', new.id)
      );
    end if;
  end if;

  return new;
end;
$$;
