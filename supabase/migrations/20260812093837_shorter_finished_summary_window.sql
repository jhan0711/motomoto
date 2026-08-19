-- =============================================================================
-- Fase 15, paso 2: la despedida dura cinco minutos, no treinta
-- =============================================================================
--
-- LO DECIDIO UNA CAPTURA. La primera version puso la ventana en treinta minutos,
-- razonando que el pasajero podia guardarse el telefono al bajarse y abrir la
-- aplicacion un rato despues. Al probarlo se vio lo que ese razonamiento no
-- cubria: **entrar a la aplicacion para pedir OTRO servicio y encontrarse la
-- despedida del anterior**, con su boton "Listo" que hay que tocar para poder
-- seguir. La pantalla saludaba con el pasado.
--
-- Cinco minutos cubren para lo que se penso: bajarse, guardar el telefono,
-- volver a mirarlo. Pasado ese rato, quien abre la aplicacion viene a otra cosa.
--
-- SE CAMBIAN LOS DOS SITIOS. `get_setting` devuelve el valor por defecto de la
-- llamada solo si la fila no existe, asi que dejar uno en 30 y otro en 5 seria
-- dejar puesta una trampa para el dia que alguien borre la fila. Ahora la fila
-- existe, es visible desde el panel y el valor de reserva dice lo mismo.
-- =============================================================================

insert into public.app_settings (key, value, description) values
  ('finished_summary_minutes', '5',
   'Cuanto tiempo se le sigue mostrando al pasajero el resumen de su ultimo servicio terminado.')
on conflict (key) do update set value = excluded.value;

create or replace function public.get_finished_request()
returns table (
  id uuid,
  origin_label text,
  destination_label text,
  passenger_count smallint,
  completed_at timestamptz,
  distance_m integer,
  duration_s integer,
  driver_name text,
  vehicle_unit_number integer
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.origin_label,
    r.destination_label,
    r.passenger_count,
    r.completed_at,
    v.distance_m,
    v.duration_s,
    p.full_name,
    veh.unit_number
  from public.ride_requests r
    left join lateral (
      select d.distance_m, d.duration_s, d.driver_id, d.vehicle_id
      from public.rides d
      where d.request_id = r.id and d.status = 'completed'
      order by d.completed_at desc
      limit 1
    ) v on true
    left join public.profiles p on p.id = v.driver_id
    left join public.vehicles veh on veh.id = v.vehicle_id
  where r.passenger_id = (select auth.uid())
    and r.status = 'completed'
    and r.completed_at > now() - make_interval(
      mins => (public.get_setting('finished_summary_minutes', '5'))::integer
    )
  order by r.completed_at desc
  limit 1;
$$;

comment on function public.get_finished_request is
  'El ultimo servicio terminado del pasajero, si fue hace muy poco. Cero o una fila.';
