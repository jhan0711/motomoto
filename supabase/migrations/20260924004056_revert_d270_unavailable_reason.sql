-- =============================================================================
-- D275: reversion de D270 (motivo al desconectarse)
-- =============================================================================
--
-- LA EMPRESA PIDIO QUITARLO (2026-09-23), un poco mas de una semana despues de
-- pedirlo (2026-09-15). No aporto lo que se esperaba en la practica.
--
-- SE REVIERTE ENTERO, NO SOLO SE DEJA DE EXIGIR. Dejar el catalogo, la funcion
-- y las columnas sin usar "por si se retoma despues" es codigo muerto que
-- alguien tendria que volver a entender desde cero si algun dia se retoma; mas
-- facil escribir la migracion otra vez con lo que se sepa entonces.
--
-- ORDEN: primero `admin_list_drivers` vuelve a su forma de antes de D270
-- -misma tecnica de `drop` + `create` completo, Postgres no deja anadir ni
-- quitar columnas de un `returns table` con `create or replace`-, despues el
-- disparador y la funcion que dependen de las columnas, y las columnas y el
-- tipo al final, que es lo unico de lo que dependen las otras piezas.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El panel: `admin_list_drivers` vuelve a su forma anterior a D270
-- -----------------------------------------------------------------------------

drop function public.admin_list_drivers();

create function public.admin_list_drivers()
returns table (
  driver_id uuid,
  full_name text,
  phone text,
  account_status public.user_status,
  approval_status public.driver_approval_status,
  approved_at timestamptz,
  is_available boolean,
  rating_average numeric,
  rating_count integer,

  vehicle_id uuid,
  unit_number integer,
  plate text,

  has_active_ride boolean,

  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    d.id,
    p.full_name,
    p.phone,
    p.status,
    d.approval_status,
    d.approved_at,
    d.is_available,
    d.rating_average,
    d.rating_count,

    v.id,
    v.unit_number,
    v.plate,

    exists (
      select 1 from public.rides r
      where r.driver_id = d.id
        and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    ),

    d.created_at
  from public.drivers d
  join public.profiles p on p.id = d.id
  left join public.driver_vehicle_assignments dva
    on dva.driver_id = d.id and dva.unassigned_at is null
  left join public.vehicles v on v.id = dva.vehicle_id
  order by
    case d.approval_status when 'pending' then 0 when 'approved' then 1 else 2 end,
    p.full_name;
$$;

comment on function public.admin_list_drivers() is
  'Listado de conductores para el panel, con su vehiculo asignado y si esta ocupado.';

revoke all on function public.admin_list_drivers() from public;
grant execute on function public.admin_list_drivers() to authenticated;


-- -----------------------------------------------------------------------------
-- El disparador y la funcion de D270
-- -----------------------------------------------------------------------------

drop trigger drivers_clear_unavailable_reason on public.drivers;
drop function public.clear_unavailable_reason_on_available();

drop function public.set_driver_unavailable(public.driver_unavailable_reason_code, text);


-- -----------------------------------------------------------------------------
-- Las columnas y el catalogo
-- -----------------------------------------------------------------------------

alter table public.drivers
  drop constraint drivers_unavailable_reason_needs_otro,
  drop constraint drivers_unavailable_reason_length,
  drop column unavailable_reason_code,
  drop column unavailable_reason;

drop type public.driver_unavailable_reason_code;
