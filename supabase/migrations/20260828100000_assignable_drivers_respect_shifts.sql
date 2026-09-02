-- =============================================================================
-- LA LISTA DE ASIGNABLES TIENE QUE SABER DEL DOBLE TURNO
-- =============================================================================
--
-- **Lo encontro el usuario probando la pantalla**, que es donde se ven estas
-- cosas: elegia a "Segundo conductor", pulsaba Asignar y no pasaba nada.
--
-- LO QUE ESTABA PASANDO DE VERDAD. `admin_list_assignable_drivers` lo daba por
-- asignable -`can_assign = true`- y `admin_assign_driver` lo rechazaba con
-- `COMPANION_ALREADY_AVAILABLE`: "Otro conductor esta conectado con ese
-- motorraton". Los dos comparten el Motorraton 96, que es exactamente el doble
-- turno de D250, y su companero estaba conectado.
--
-- **El fallo no era la regla, era la incoherencia.** La comprobacion estaba
-- escrita en `admin_assign_driver` desde el primer dia y funcionaba: la lista
-- era la que no la conocia. Una lista que ofrece a alguien que luego se rechaza
-- **le hace perder tiempo al despachador con el pasajero esperando**, que es
-- justo el momento en que se usa esta pantalla.
--
-- REGLA QUE DEJA ESTO: **lo que la lista dice que se puede, la asignacion tiene
-- que aceptarlo.** Cualquier condicion nueva en `admin_assign_driver` hay que
-- espejarla aqui, y por eso las dos quedan escritas igual.
--
-- **EL MOTIVO DICE EL NOMBRE DEL COMPANERO**, no solo que no se puede. Es lo
-- mismo que decidio el mensaje del disparador en `20260827040000`: el
-- despachador que lo lee puede resolverlo llamando a esa persona, mientras que
-- un "no se puede" a secas lo deja sin saber que hacer.
-- =============================================================================

create or replace function public.admin_list_assignable_drivers(p_request_id uuid)
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  is_available boolean,
  unit_number integer,
  max_passengers smallint,
  rating_average numeric,
  distance_m integer,
  location_age_seconds integer,
  can_assign boolean,
  blocked_reason text
)
language sql
stable
security invoker
set search_path = public
as $$
  with solicitud as (
    select rr.origin, rr.passenger_count
    from public.ride_requests rr
    where rr.id = p_request_id
  )
  select
    d.id,
    p.full_name,
    p.phone,
    d.is_available,
    v.unit_number,
    v.max_passengers,
    d.rating_average,

    case when dl.location is not null
      then round(extensions.st_distance(dl.location, s.origin))::integer end,
    case when dl.updated_at is not null
      then greatest(0, extract(epoch from (now() - dl.updated_at)))::integer end,

    -- El orden de estas condiciones importa: se ensena **el primer motivo que
    -- impide asignar**, y estan puestas de la mas de fondo a la mas pasajera.
    (v.id is not null
     and not exists (
       select 1 from public.rides r
       where r.driver_id = d.id
         and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
     )
     and companero.driver_id is null
     and s.passenger_count <= v.max_passengers),

    case
      when v.id is null then 'Sin motorraton activo asignado'
      when exists (
        select 1 from public.rides r
        where r.driver_id = d.id
          and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      ) then 'Ya tiene un servicio en curso'
      when companero.driver_id is not null
        then companero.full_name || ' esta conectado con el motorraton '
             || v.unit_number || '. Solo uno puede llevarlo a la vez'
      when s.passenger_count > v.max_passengers
        then 'Su motorraton tiene ' || v.max_passengers || ' plazas'
    end
  from public.drivers d
  join public.profiles p on p.id = d.id
  cross join solicitud s
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id and v.status = 'active'
  left join public.driver_locations dl on dl.driver_id = d.id

  -- EL COMPANERO CONECTADO, si lo hay. Es la misma condicion que comprueba
  -- `admin_assign_driver` antes de crear el servicio, escrita igual a proposito:
  -- el mismo motorraton, la asignacion todavia viva y otra persona.
  left join lateral (
    select c.driver_id, cp.full_name
    from public.driver_vehicle_assignments c
    join public.drivers cd on cd.id = c.driver_id and cd.is_available
    join public.profiles cp on cp.id = c.driver_id
    where c.vehicle_id = v.id
      and c.unassigned_at is null
      and c.driver_id <> d.id
    limit 1
  ) companero on true

  where d.approval_status = 'approved'
    and p.status = 'active'
  -- Los asignables primero; entre ellos, los mas cerca del punto de recogida,
  -- que es el criterio del reparto automatico. Sin ubicacion, al final.
  order by
    (v.id is not null
     and not exists (
       select 1 from public.rides r
       where r.driver_id = d.id
         and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
     )
     and companero.driver_id is null) desc,
    extensions.st_distance(dl.location, s.origin) nulls last,
    p.full_name;
$$;

comment on function public.admin_list_assignable_drivers(uuid) is
  'Conductores a los que dar un servicio, por cercania, con el motivo de los que no.';

revoke all on function public.admin_list_assignable_drivers(uuid) from public;
revoke all on function public.admin_list_assignable_drivers(uuid) from anon, authenticated;
grant execute on function public.admin_list_assignable_drivers(uuid) to authenticated;
