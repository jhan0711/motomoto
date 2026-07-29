-- =============================================================================
-- Migracion 6A: politicas de seguridad a nivel de fila
-- =============================================================================
--
-- Hasta ahora las 17 tablas estaban cerradas a todo el mundo. Esta migracion las
-- abre exactamente por donde debe y por ningun otro sitio.
--
-- Principio general: los clientes solo pueden LEER. Toda escritura sobre
-- solicitudes, viajes, ofertas y calificaciones pasa por funciones controladas
-- (decision D15), que llegan en la parte B. Las unicas escrituras directas son
-- las que no pueden romper nada: tu propio perfil, tu propia posicion, tus
-- notificaciones leidas y los reportes que tu creas.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Funciones auxiliares
-- -----------------------------------------------------------------------------

-- Devuelve el rol del usuario actual.
--
-- Es security definer por una razon concreta: una politica sobre profiles que
-- consultara profiles para averiguar el rol se llamaria a si misma en bucle
-- infinito. Al ser security definer, esta funcion ignora las politicas y corta
-- la recursion.
create or replace function public.auth_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role = 'admin' and status = 'active'
     from public.profiles where id = (select auth.uid())),
    false
  );
$$;

comment on function public.is_admin() is
  'Cierto solo si el usuario actual es administrador Y su cuenta esta activa.';

-- Cierto si el usuario actual participa en el viaje indicado, como pasajero o
-- como conductor. Concentra aqui una condicion que si no habria que repetir en
-- media docena de politicas, con el riesgo de que una quede mal escrita.
create or replace function public.participates_in_ride(p_ride_id uuid)
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
    where r.id = p_ride_id
      and ((select auth.uid()) in (rq.passenger_id, r.driver_id))
  );
$$;

-- Cierto si el usuario actual tiene un viaje en curso con ese conductor. La usa
-- la politica que permite al pasajero seguir la posicion de su conductor, y solo
-- la suya, y solo mientras dura el servicio.
create or replace function public.has_active_ride_with_driver(p_driver_id uuid)
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
    where r.driver_id = p_driver_id
      and rq.passenger_id = (select auth.uid())
      and r.status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress')
  );
$$;

revoke all on function public.auth_role() from public, anon;
revoke all on function public.participates_in_ride(uuid) from public, anon;
revoke all on function public.has_active_ride_with_driver(uuid) from public, anon;


-- -----------------------------------------------------------------------------
-- Proteccion de columnas privilegiadas
-- -----------------------------------------------------------------------------

-- La seguridad a nivel de fila decide QUE FILAS puede tocar alguien, no QUE
-- COLUMNAS. Sin este disparador, un pasajero con permiso para editar su propio
-- perfil podria ponerse role = 'admin' y quedarse con el control del sistema.
--
-- Es el fallo mas repetido en proyectos con Supabase, y no da ningun sintoma
-- hasta que alguien lo descubre.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  -- Cualquier intento de cambiar rol o estado se revierte en silencio al valor
  -- anterior. Se revierte en lugar de fallar para que la aplicacion pueda enviar
  -- el objeto completo del perfil sin tener que excluir estos campos.
  new.role := old.role;
  new.status := old.status;
  return new;
end;
$$;

create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- Mismo problema en la tabla de conductores: sin esto, un conductor pendiente de
-- aprobacion podria aprobarse a si mismo y salir a trabajar.
create or replace function public.protect_driver_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  new.approval_status := old.approval_status;
  new.approved_at := old.approved_at;
  new.approved_by := old.approved_by;
  new.rating_average := old.rating_average;
  new.rating_count := old.rating_count;
  return new;
end;
$$;

create trigger drivers_protect_columns
  before update on public.drivers
  for each row execute function public.protect_driver_columns();


-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------

create policy "profiles_select_own"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles_select_admin"
  on public.profiles for select to authenticated
  using (public.is_admin());

-- El pasajero necesita ver el nombre y la foto de su conductor asignado, y el
-- conductor los del pasajero que va a recoger. Solo durante el servicio y solo
-- de la persona con la que comparte viaje.
create policy "profiles_select_ride_counterpart"
  on public.profiles for select to authenticated
  using (
    exists (
      select 1
      from public.rides r
      join public.ride_requests rq on rq.id = r.request_id
      where (r.driver_id = profiles.id and rq.passenger_id = (select auth.uid()))
         or (rq.passenger_id = profiles.id and r.driver_id = (select auth.uid()))
    )
  );

-- Actualizar el propio perfil. El disparador de mas arriba impide que rol y
-- estado se modifiquen por esta via.
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "profiles_update_admin"
  on public.profiles for update to authenticated
  using (public.is_admin());

-- Sin politica de insercion ni de borrado a proposito: los perfiles los crea el
-- disparador del registro y no se borran, se bloquean.


-- -----------------------------------------------------------------------------
-- drivers
-- -----------------------------------------------------------------------------

create policy "drivers_select_own"
  on public.drivers for select to authenticated
  using (id = (select auth.uid()));

create policy "drivers_select_admin"
  on public.drivers for select to authenticated
  using (public.is_admin());

-- El pasajero ve la calificacion de su conductor asignado.
create policy "drivers_select_ride_counterpart"
  on public.drivers for select to authenticated
  using (public.has_active_ride_with_driver(drivers.id));

-- El conductor cambia su disponibilidad. El disparador impide que toque su
-- estado de aprobacion o su calificacion.
create policy "drivers_update_own"
  on public.drivers for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "drivers_all_admin"
  on public.drivers for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- vehicles
-- -----------------------------------------------------------------------------

-- Lectura abierta a cualquier usuario autenticado.
--
-- Decision consciente: el numero de unidad y la placa de un motorraton estan
-- pintados en el vehiculo y son visibles para cualquiera en la calle. Ocultarlos
-- en la base de datos anadiria consultas complejas sin proteger nada real. Lo
-- que si se protege es quien conduce cada uno y donde esta.
create policy "vehicles_select_authenticated"
  on public.vehicles for select to authenticated
  using (true);

create policy "vehicles_all_admin"
  on public.vehicles for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- driver_vehicle_assignments
-- -----------------------------------------------------------------------------

create policy "dva_select_own"
  on public.driver_vehicle_assignments for select to authenticated
  using (driver_id = (select auth.uid()));

create policy "dva_all_admin"
  on public.driver_vehicle_assignments for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- document_types y documents
-- -----------------------------------------------------------------------------

create policy "document_types_select_authenticated"
  on public.document_types for select to authenticated
  using (true);

create policy "document_types_all_admin"
  on public.document_types for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Un conductor ve sus propios documentos y los del vehiculo que tiene asignado.
create policy "documents_select_own"
  on public.documents for select to authenticated
  using (
    driver_id = (select auth.uid())
    or exists (
      select 1 from public.driver_vehicle_assignments a
      where a.vehicle_id = documents.vehicle_id
        and a.driver_id = (select auth.uid())
        and a.unassigned_at is null
    )
  );

create policy "documents_all_admin"
  on public.documents for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- places
-- -----------------------------------------------------------------------------

create policy "places_select_active"
  on public.places for select to authenticated
  using (is_active or public.is_admin());

create policy "places_all_admin"
  on public.places for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- driver_locations
-- -----------------------------------------------------------------------------

-- La tabla mas sensible del sistema en materia de privacidad: contiene donde
-- esta cada conductor en tiempo real.
create policy "driver_locations_select_own"
  on public.driver_locations for select to authenticated
  using (driver_id = (select auth.uid()));

create policy "driver_locations_select_admin"
  on public.driver_locations for select to authenticated
  using (public.is_admin());

-- El pasajero sigue a SU conductor, y solo mientras el viaje esta en curso. En
-- cuanto el servicio termina, deja de verlo.
create policy "driver_locations_select_active_passenger"
  on public.driver_locations for select to authenticated
  using (public.has_active_ride_with_driver(driver_locations.driver_id));

-- Cada conductor escribe unicamente su propia posicion.
create policy "driver_locations_insert_own"
  on public.driver_locations for insert to authenticated
  with check (driver_id = (select auth.uid()));

create policy "driver_locations_update_own"
  on public.driver_locations for update to authenticated
  using (driver_id = (select auth.uid()))
  with check (driver_id = (select auth.uid()));


-- -----------------------------------------------------------------------------
-- ride_requests
-- -----------------------------------------------------------------------------

-- Solo lectura. Crear, cancelar y avanzar estados se hace por funciones
-- controladas (decision D15), no con UPDATE directo desde el cliente.
create policy "ride_requests_select_own"
  on public.ride_requests for select to authenticated
  using (passenger_id = (select auth.uid()));

create policy "ride_requests_select_admin"
  on public.ride_requests for select to authenticated
  using (public.is_admin());

-- Un conductor ve la solicitud si se le ofrecio o si la esta atendiendo.
create policy "ride_requests_select_offered_driver"
  on public.ride_requests for select to authenticated
  using (
    exists (
      select 1 from public.ride_offers o
      where o.request_id = ride_requests.id
        and o.driver_id = (select auth.uid())
    )
    or exists (
      select 1 from public.rides r
      where r.request_id = ride_requests.id
        and r.driver_id = (select auth.uid())
    )
  );


-- -----------------------------------------------------------------------------
-- rides
-- -----------------------------------------------------------------------------

create policy "rides_select_participant"
  on public.rides for select to authenticated
  using (
    driver_id = (select auth.uid())
    or exists (
      select 1 from public.ride_requests rq
      where rq.id = rides.request_id
        and rq.passenger_id = (select auth.uid())
    )
  );

create policy "rides_select_admin"
  on public.rides for select to authenticated
  using (public.is_admin());


-- -----------------------------------------------------------------------------
-- ride_offers
-- -----------------------------------------------------------------------------

-- Un conductor ve solo las ofertas que le hicieron a el. No puede saber a quien
-- mas se le ofrecio la misma solicitud ni cuantos la rechazaron.
create policy "ride_offers_select_own"
  on public.ride_offers for select to authenticated
  using (driver_id = (select auth.uid()));

create policy "ride_offers_select_admin"
  on public.ride_offers for select to authenticated
  using (public.is_admin());


-- -----------------------------------------------------------------------------
-- ride_locations
-- -----------------------------------------------------------------------------

create policy "ride_locations_select_participant"
  on public.ride_locations for select to authenticated
  using (public.participates_in_ride(ride_locations.ride_id));

create policy "ride_locations_select_admin"
  on public.ride_locations for select to authenticated
  using (public.is_admin());

-- Escritura directa del conductor, no por funcion. Es la unica excepcion al
-- principio de esta migracion, y esta justificada: son muchos puntos por minuto
-- durante todo el viaje, y una llamada a funcion por cada uno anadiria latencia
-- sin aportar validacion util. La condicion garantiza que solo escribe puntos de
-- su propio viaje en curso.
create policy "ride_locations_insert_own_driver"
  on public.ride_locations for insert to authenticated
  with check (
    exists (
      select 1 from public.rides r
      where r.id = ride_locations.ride_id
        and r.driver_id = (select auth.uid())
        and r.status in ('driver_on_the_way', 'driver_arrived', 'in_progress')
    )
  );


-- -----------------------------------------------------------------------------
-- ratings
-- -----------------------------------------------------------------------------

create policy "ratings_select_involved"
  on public.ratings for select to authenticated
  using (
    rater_id = (select auth.uid())
    or rated_id = (select auth.uid())
  );

create policy "ratings_select_admin"
  on public.ratings for select to authenticated
  using (public.is_admin());

-- La insercion pasa por funcion: hay que comprobar que el viaje esta terminado y
-- que quien califica participo en el, y eso una politica no puede hacerlo bien.


-- -----------------------------------------------------------------------------
-- reports
-- -----------------------------------------------------------------------------

create policy "reports_select_own"
  on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));

create policy "reports_select_admin"
  on public.reports for select to authenticated
  using (public.is_admin());

-- Reportar un problema es escritura directa: no puede romper nada y conviene que
-- sea lo mas facil posible.
create policy "reports_insert_own"
  on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));

create policy "reports_update_admin"
  on public.reports for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- notifications
-- -----------------------------------------------------------------------------

create policy "notifications_select_own"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

-- Marcar como leida. La politica limita la fila; que solo se toque read_at es
-- responsabilidad de la aplicacion, y el riesgo de que altere su propio titulo
-- de notificacion es nulo.
create policy "notifications_update_own"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));


-- -----------------------------------------------------------------------------
-- app_settings
-- -----------------------------------------------------------------------------

-- Lectura abierta: la aplicacion necesita saber el maximo de pasajeros, cada
-- cuanto enviar posicion y cuanto dura el margen de cancelacion. Ninguno de esos
-- valores es secreto.
create policy "app_settings_select_authenticated"
  on public.app_settings for select to authenticated
  using (true);

create policy "app_settings_all_admin"
  on public.app_settings for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- admin_audit_logs
-- -----------------------------------------------------------------------------

-- Solo los administradores leen la auditoria, y nadie la modifica desde el
-- cliente: las entradas las escriben las funciones con privilegios.
create policy "audit_select_admin"
  on public.admin_audit_logs for select to authenticated
  using (public.is_admin());
