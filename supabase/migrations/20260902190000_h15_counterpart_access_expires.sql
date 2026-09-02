-- =============================================================================
-- FASE 22, PASO 2: el acceso al nombre y al telefono de la contraparte caduca
-- al terminar el servicio. Cierra H15.
-- =============================================================================
--
-- EL HALLAZGO (Fase 5, dicho de verdad en `20260819223000`). Las politicas
-- `profiles_select_ride_counterpart` y `ride_requests_select_offered_driver` se
-- apoyan en `shares_ride_with` y `driver_linked_to_request`, que devuelven
-- `true` **para siempre**: un conductor que llevo a alguien una vez -o al que
-- solo se le ofrecio un servicio- puede leer su `full_name`, su `phone` y el
-- `contact_phone` de la solicitud mientras esa fila exista. El telefono es lo
-- que mas pesa: `contact_phone` es donde vive de verdad.
--
-- LA VIA ELEGIDA (con el usuario, 2026-09-02): estrechar las dos funciones a los
-- estados en curso, y pasar a `security definer` las seis funciones de historial
-- que hoy leen el NOMBRE de la contraparte apoyandose en esa RLS floja. Asi el
-- historial sigue diciendo con quien fue el viaje -el nombre no es dato
-- sensible y ya se ve en la propia pantalla-, pero **por consulta directa a la
-- tabla no se saca nada de la contraparte en cuanto el servicio acaba**.
--
-- SE DESCARTO revocar `select (phone)` a nivel de columna: obligaba a pasar a
-- `security definer` con `is_admin()` dentro a `admin_get_ride_detail` y
-- `admin_list_active_services` -el tablero, que se consulta cada diez segundos-,
-- y eso revierte D242, que las dejo `invoker` a proposito.
--
-- QUE NO SE TOCA, y por que sigue bien:
--   - `get_active_request` y `list_driver_active_rides` siguen siendo `invoker`:
--     solo leen el telefono cuando hay un viaje en curso, y ahi las funciones
--     estrechadas siguen devolviendo `true`.
--   - Las funciones `admin_*` se apoyan en `*_select_admin` (`is_admin()`), que
--     esto no toca.
--   - `avatars_select` usa `shares_ride_with`: la foto de la contraparte deja de
--     verse al terminar. Ninguna pantalla de historial la muestra -solo la
--     propia-, asi que no se pierde nada visible.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Las dos funciones de enlace, estrechadas a los estados en curso
-- -----------------------------------------------------------------------------

create or replace function public.shares_ride_with(p_other_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  -- Solo mientras el viaje esta vivo. Una fila en `rides` que ya termino o se
  -- cancelo no da acceso al perfil de la otra persona.
  select exists (
    select 1
    from public.rides r
    join public.ride_requests rq on rq.id = r.request_id
    where r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
      and (
        (r.driver_id = p_other_id and rq.passenger_id = (select auth.uid()))
        or (rq.passenger_id = p_other_id and r.driver_id = (select auth.uid()))
      )
  );
$$;

create or replace function public.driver_linked_to_request(p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  -- Una oferta viva -pendiente y sin caducar- para poder decidir, o un viaje en
  -- curso. Una oferta ya respondida o un viaje terminado no dan acceso a la
  -- solicitud ni, con ella, a `contact_phone`.
  select exists (
    select 1 from public.ride_offers
    where request_id = p_request_id
      and driver_id = (select auth.uid())
      and response = 'pending'
      and expires_at > now()
  )
  or exists (
    select 1 from public.rides
    where request_id = p_request_id
      and driver_id = (select auth.uid())
      and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  );
$$;

comment on function public.shares_ride_with is
  'Cierto solo mientras el usuario actual comparte un viaje EN CURSO con esa persona. Al terminar o cancelarse el viaje, el acceso al perfil de la contraparte se corta. H15 cerrado en la Fase 22.';

comment on function public.driver_linked_to_request is
  'Cierto solo si el conductor tiene una oferta viva sobre esa solicitud o un viaje en curso. Al responder la oferta o terminar el viaje, deja de ver la solicitud y su contact_phone. H15 cerrado en la Fase 22.';

comment on policy "profiles_select_ride_counterpart" on public.profiles is
  'El pasajero ve a su conductor y el conductor a su pasajero SOLO mientras el servicio esta en curso (shares_ride_with). El historial da el nombre por funcion security definer. H15.';

comment on policy "ride_requests_select_offered_driver" on public.ride_requests is
  'El conductor ve la solicitud mientras tiene una oferta viva o un viaje en curso (driver_linked_to_request). Despues, no. H15.';


-- -----------------------------------------------------------------------------
-- 2. El historial sigue dando el NOMBRE: sus funciones pasan a definer
-- -----------------------------------------------------------------------------
--
-- Las seis leen `profiles.full_name` de la contraparte para un servicio que ya
-- termino, donde `shares_ride_with` ya devuelve `false`. Todas filtran por
-- `auth.uid()` en su `where` -son su propia puerta-, asi que ejecutarlas con
-- privilegios no expone nada de otro usuario. Se usa `alter function` y no
-- `create or replace` para no reescribir el cuerpo (regla 6).

alter function public.get_passenger_trip(uuid) security definer;
alter function public.get_driver_job(uuid) security definer;
alter function public.list_driver_history(integer, integer) security definer;
alter function public.list_passenger_history(integer, integer) security definer;
alter function public.get_finished_request() security definer;
alter function public.get_driver_cancelled_notice() security definer;


-- -----------------------------------------------------------------------------
-- 3. La carga de una solicitud pasa por funcion
-- -----------------------------------------------------------------------------
--
-- `fetchRequestCargo` leia `ride_request_cargo` directo, apoyandose en
-- `ride_request_cargo_select_participants`, que usa `driver_linked_to_request`.
-- Al estrecharla, el conductor perderia el desglose de carga de sus viajes
-- pasados. Los nombres de los tipos de carga no son dato sensible, asi que la
-- funcion mantiene el enlace permanente -oferta o viaje, en cualquier estado-.

create or replace function public.list_request_cargo(p_request_id uuid)
returns table (cargo_type_name text, quantity smallint, unit_amount integer)
language sql
stable
security definer
set search_path = public
as $$
  select ct.name, rrc.quantity, rrc.unit_amount
  from public.ride_request_cargo rrc
  join public.cargo_types ct on ct.id = rrc.cargo_type_id
  where rrc.request_id = p_request_id
    and (
      public.owns_request(p_request_id)
      or exists (
        select 1 from public.ride_offers o
        where o.request_id = p_request_id and o.driver_id = (select auth.uid())
      )
      or exists (
        select 1 from public.rides d
        where d.request_id = p_request_id and d.driver_id = (select auth.uid())
      )
      or public.is_admin()
    )
  order by ct.sort_order, ct.name;
$$;

comment on function public.list_request_cargo is
  'La carga de una solicitud, con el nombre de cada tipo. Para el dueno, el conductor vinculado (oferta o viaje, cualquier estado) y el administrador.';

revoke all on function public.list_request_cargo(uuid) from public, anon;
grant execute on function public.list_request_cargo(uuid) to authenticated;
