-- =============================================================================
-- El listado de vehiculos devuelve los conductores como pares, no como dos
-- listas paralelas.
-- =============================================================================
--
-- QUE ESTABA MAL, y se corrige antes de que llegue a la pantalla.
-- `admin_list_vehicles` devolvia `drivers_label` -"Ana Gomez, Juan Perez"- y
-- `driver_ids` -un array-, las dos ordenadas por nombre. El panel necesita
-- emparejarlas para poder ofrecer "quitar a este de aqui", y la unica forma con
-- esa forma de dato es **partir el texto por comas y confiar en que el orden
-- coincida**.
--
-- Eso se rompe el dia que un conductor se llame "Gomez, Ana" o tenga una coma en
-- el nombre por un error de tecleo: el panel quitaria del turno a una persona
-- distinta de la que se pulso. **No es un fallo hipotetico de estilo: es un
-- desplazamiento de indices que borra la asignacion equivocada en silencio.**
--
-- Se cambia a un `jsonb` con los pares. `drivers_label` se conserva porque la
-- pantalla lo usa tal cual para escribir la linea, y calcularlo aqui evita que
-- cada sitio lo componga a su manera.
-- =============================================================================

drop function if exists public.admin_list_vehicles();

create or replace function public.admin_list_vehicles()
returns table (
  vehicle_id uuid,
  unit_number integer,
  plate text,
  model text,
  max_passengers smallint,
  status public.vehicle_status,
  notes text,

  driver_count integer,
  drivers_label text,
  -- [{ "id": "...", "name": "...", "is_available": true }, ...], por nombre.
  drivers jsonb,

  active_driver_id uuid,
  active_driver_name text,

  has_active_ride boolean,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with asignados as (
    select
      dva.vehicle_id,
      dva.driver_id,
      p.full_name,
      d.is_available
    from public.driver_vehicle_assignments dva
    join public.profiles p on p.id = dva.driver_id
    join public.drivers d on d.id = dva.driver_id
    where dva.unassigned_at is null
  ),
  al_volante as (
    -- El que tiene un servicio en marcha manda sobre el que solo esta
    -- disponible: si alguien esta conduciendo, ese es el que lleva la unidad.
    select distinct on (a.vehicle_id)
      a.vehicle_id, a.driver_id, a.full_name
    from asignados a
    left join public.rides r
      on r.driver_id = a.driver_id
     and r.vehicle_id = a.vehicle_id
     and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    where r.id is not null or a.is_available
    order by a.vehicle_id, (r.id is not null) desc, a.full_name
  )
  select
    v.id,
    v.unit_number,
    v.plate,
    v.model,
    v.max_passengers,
    v.status,
    v.notes,

    coalesce(count(a.driver_id), 0)::integer,
    nullif(string_agg(a.full_name, ', ' order by a.full_name), ''),
    coalesce(
      jsonb_agg(
        jsonb_build_object('id', a.driver_id, 'name', a.full_name,
                           'is_available', a.is_available)
        order by a.full_name
      ) filter (where a.driver_id is not null),
      '[]'::jsonb
    ),

    av.driver_id,
    av.full_name,

    exists (
      select 1 from public.rides r
      where r.vehicle_id = v.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    v.created_at
  from public.vehicles v
  left join asignados a on a.vehicle_id = v.id
  left join al_volante av on av.vehicle_id = v.id
  group by v.id, av.driver_id, av.full_name
  order by
    case v.status when 'active' then 0 when 'maintenance' then 1 else 2 end,
    v.unit_number;
$$;

comment on function public.admin_list_vehicles() is
  'Listado de vehiculos con sus conductores como pares id/nombre y quien va al volante.';

revoke all on function public.admin_list_vehicles() from public;
grant execute on function public.admin_list_vehicles() to authenticated;
