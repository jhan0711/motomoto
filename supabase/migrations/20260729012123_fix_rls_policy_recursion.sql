-- =============================================================================
-- Correccion: recursion infinita en las politicas
-- =============================================================================
--
-- La migracion anterior provocaba el error 42P17, recursion infinita en la
-- politica de rides. El ciclo era este:
--
--   consulta a rides
--     -> politica rides_select_participant
--        -> consulta ride_requests
--           -> politica ride_requests_select_offered_driver
--              -> consulta rides
--                 -> vuelta al principio
--
-- Causa: cuatro politicas consultaban otra tabla protegida con una subconsulta
-- directa. Cada una de esas consultas dispara a su vez las politicas de la tabla
-- consultada, y si dos tablas se referencian mutuamente el ciclo no termina.
--
-- REGLA que se establece a partir de aqui y que la migracion anterior aplicaba
-- solo a medias: toda politica que necesite consultar otra tabla protegida debe
-- hacerlo a traves de una funcion security definer. Esas funciones ignoran las
-- politicas, y ahi se corta el ciclo.
--
-- Las politicas que ya usaban funciones (participates_in_ride,
-- has_active_ride_with_driver) no estaban afectadas y no se tocan.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Funciones auxiliares que faltaban
-- -----------------------------------------------------------------------------

-- Cierto si el usuario actual es el pasajero que hizo la solicitud.
create or replace function public.owns_request(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ride_requests
    where id = p_request_id
      and passenger_id = (select auth.uid())
  );
$$;

-- Cierto si al usuario actual, como conductor, se le ofrecio esa solicitud o la
-- esta atendiendo.
create or replace function public.driver_linked_to_request(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ride_offers
    where request_id = p_request_id
      and driver_id = (select auth.uid())
  )
  or exists (
    select 1 from public.rides
    where request_id = p_request_id
      and driver_id = (select auth.uid())
  );
$$;

-- Cierto si el usuario actual comparte o compartio algun viaje con esa persona,
-- en cualquier sentido: pasajero mirando a su conductor o al reves.
create or replace function public.shares_ride_with(p_other_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rides r
    join public.ride_requests rq on rq.id = r.request_id
    where (r.driver_id = p_other_id and rq.passenger_id = (select auth.uid()))
       or (rq.passenger_id = p_other_id and r.driver_id = (select auth.uid()))
  );
$$;

-- Cierto si el usuario actual es el conductor de ese viaje y el viaje esta en
-- curso. La usa la politica de escritura del recorrido.
create or replace function public.is_active_driver_of_ride(p_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.rides
    where id = p_ride_id
      and driver_id = (select auth.uid())
      and status in ('driver_on_the_way', 'driver_arrived', 'in_progress')
  );
$$;

revoke all on function public.owns_request(uuid) from public, anon;
revoke all on function public.driver_linked_to_request(uuid) from public, anon;
revoke all on function public.shares_ride_with(uuid) from public, anon;
revoke all on function public.is_active_driver_of_ride(uuid) from public, anon;


-- -----------------------------------------------------------------------------
-- Politicas reescritas
-- -----------------------------------------------------------------------------

-- profiles: el pasajero ve a su conductor y viceversa.
drop policy if exists "profiles_select_ride_counterpart" on public.profiles;

create policy "profiles_select_ride_counterpart"
  on public.profiles for select to authenticated
  using (public.shares_ride_with(profiles.id));


-- rides: lo ven sus participantes.
drop policy if exists "rides_select_participant" on public.rides;

create policy "rides_select_participant"
  on public.rides for select to authenticated
  using (
    rides.driver_id = (select auth.uid())
    or public.owns_request(rides.request_id)
  );


-- ride_requests: la ve el conductor al que se le ofrecio o que la atiende.
drop policy if exists "ride_requests_select_offered_driver" on public.ride_requests;

create policy "ride_requests_select_offered_driver"
  on public.ride_requests for select to authenticated
  using (public.driver_linked_to_request(ride_requests.id));


-- ride_locations: el conductor escribe los puntos de su viaje en curso.
drop policy if exists "ride_locations_insert_own_driver" on public.ride_locations;

create policy "ride_locations_insert_own_driver"
  on public.ride_locations for insert to authenticated
  with check (public.is_active_driver_of_ride(ride_locations.ride_id));
