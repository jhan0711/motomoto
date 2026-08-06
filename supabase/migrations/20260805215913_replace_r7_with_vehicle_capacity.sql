-- =============================================================================
-- D161, paso 1: la regla R7 se sustituye por una regla de capacidad
-- =============================================================================
--
-- R7 decia "viajes activos simultaneos por conductor: 1", y lo hacian cumplir
-- dos indices unicos parciales. La decision D161 permite que un conductor
-- recoja a otro pasajero si le queda de camino y le sobran asientos, asi que la
-- pregunta deja de ser "cuantos viajes" y pasa a ser "cuanta gente".
--
-- POR QUE UN DISPARADOR Y NO UN INDICE. Un indice unico sabe decir "este valor
-- ya esta", pero no sabe sumar. La regla nueva es una suma contra la capacidad
-- del motorraton, y eso no se expresa en un indice.
--
-- Perder el indice significa perder la garantia que daba el motor, asi que hay
-- que reponerla a mano: el disparador bloquea el conductor y su vehiculo antes
-- de contar. Sin ese bloqueo, dos aceptaciones simultaneas leerian las dos "hay
-- sitio" y las dos escribirian. Es exactamente la carrera que el indice
-- rides_one_active_per_vehicle impedia gratis.
--
-- QUE NO CAMBIA EN ESTE PASO. Al aceptar, `accept_ride_offer` sigue apagando la
-- disponibilidad del conductor, y `find_available_drivers` sigue mirando ese si
-- o no. Nadie va a recibir todavia una segunda oferta: esta migracion abre la
-- puerta pero no empuja a nadie a cruzarla. Eso son los pasos 2 y 3.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Fuera los dos indices de R7
-- -----------------------------------------------------------------------------

drop index if exists public.rides_one_active_per_driver;
drop index if exists public.rides_one_active_per_vehicle;

-- Los dos indices que se van no solo prohibian: tambien servian para buscar los
-- viajes activos de un conductor o de un vehiculo. Esa parte hace falta ahora
-- mas que antes, porque la suma de la capacidad la consulta en cada aceptacion.
-- Se reponen sin el unique.
create index rides_active_by_driver_idx
  on public.rides (driver_id)
  where status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

create index rides_active_by_vehicle_idx
  on public.rides (vehicle_id)
  where status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');


-- -----------------------------------------------------------------------------
-- La regla de capacidad
-- -----------------------------------------------------------------------------

-- SECURITY DEFINER a proposito. La suma tiene que ver TODOS los viajes activos
-- del vehiculo, y bajo RLS un conductor solo ve los suyos. Una suma que no ve
-- todas las filas se queda corta, y quedarse corta aqui significa dejar entrar a
-- un pasajero que no cabe.
create or replace function public.enforce_ride_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_capacity smallint;
  v_taken smallint;
  v_other_vehicle uuid;
begin
  -- Un viaje que termina o se cancela no ocupa asiento. No hay nada que validar.
  if new.status not in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress') then
    return new;
  end if;

  -- Los dos bloqueos van siempre en este orden, conductor y despues vehiculo.
  -- El orden es lo unico que evita el abrazo mortal cuando dos transacciones
  -- tocan las mismas dos filas.
  perform 1 from public.drivers where id = new.driver_id for update;

  select max_passengers into v_capacity
  from public.vehicles
  where id = new.vehicle_id
  for update;

  if v_capacity is null then
    raise exception 'El motorraton no existe'
      using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
  end if;

  -- Un conductor puede llevar varios viajes, pero todos en el mismo motorraton.
  -- Esto es lo que queda vivo del segundo indice: sin ello, reasignarle otro
  -- vehiculo a mitad de servicio le dejaria dos unidades en la calle a la vez.
  select r.vehicle_id into v_other_vehicle
  from public.rides r
  where r.driver_id = new.driver_id
    and r.id <> new.id
    and r.vehicle_id <> new.vehicle_id
    and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  limit 1;

  if v_other_vehicle is not null then
    raise exception 'Ya tienes un servicio en curso con otro motorraton'
      using errcode = 'P0001', hint = 'DRIVER_VEHICLE_CONFLICT';
  end if;

  -- `id <> new.id` deja fuera a la propia fila. En un INSERT no sobra, porque el
  -- valor por defecto de la clave ya esta puesto cuando corre un BEFORE; en un
  -- UPDATE evita que el viaje se cuente a si mismo dos veces.
  select coalesce(sum(r.passenger_count), 0) into v_taken
  from public.rides r
  where r.vehicle_id = new.vehicle_id
    and r.id <> new.id
    and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  if v_taken + new.passenger_count > v_capacity then
    raise exception 'El motorraton no tiene asientos libres suficientes'
      using errcode = 'P0001', hint = 'VEHICLE_CAPACITY_EXCEEDED';
  end if;

  return new;
end;
$$;

comment on function public.enforce_ride_capacity is
  'Sustituye a R7: la suma de pasajeros activos de un motorraton no pasa de su capacidad.';


-- -----------------------------------------------------------------------------
-- Cuando se comprueba
-- -----------------------------------------------------------------------------

create trigger rides_enforce_capacity_on_insert
  before insert on public.rides
  for each row execute function public.enforce_ride_capacity();

-- En un UPDATE casi nunca hay nada que revisar. Las transiciones normales de un
-- servicio, de asignado a en camino y de ahi a en curso, no mueven ni un asiento.
-- La condicion deja pasar esas sin bloquear ninguna fila, y solo llama al
-- disparador cuando cambia el vehiculo, cambia la cantidad de gente, o un viaje
-- que estaba muerto vuelve a estar activo.
create trigger rides_enforce_capacity_on_update
  before update on public.rides
  for each row
  when (
    new.vehicle_id is distinct from old.vehicle_id
    or new.passenger_count is distinct from old.passenger_count
    or (
      old.status not in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      and new.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
    )
  )
  execute function public.enforce_ride_capacity();
