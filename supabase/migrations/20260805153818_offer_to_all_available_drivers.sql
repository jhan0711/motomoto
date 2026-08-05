-- =============================================================================
-- Fase 12B: a quien se le ofrece una solicitud, y cuando
-- =============================================================================
--
-- Tres cosas que van juntas porque son el mismo asunto.
--
-- DECISION D160: la solicitud se ofrece a TODOS los conductores disponibles, no
-- a los cinco mas cercanos. Ese cinco era el valor por defecto de un parametro y
-- no una decision: la regla R4, aprobada en la Fase 0, dice "se ofrece la
-- solicitud a todos los conductores disponibles del municipio". El codigo no la
-- cumplia.
--
-- **D160 DEJA OBSOLETA A D7.** La asignacion deja de ser "automatica por
-- cercania" y pasa a ser del primero que acepte. Con todas las ofertas creadas a
-- la vez, quien gana es quien toca antes, no quien esta mas cerca. Se eligio a
-- sabiendas: en un pueblo con pocos motorratones se parece a la radio de toda la
-- vida, donde todos oyen la llamada. La distancia se sigue guardando en cada
-- oferta, asi que el conductor ve a que distancia esta la recogida y la empresa
-- puede revisar despues a quien le llego.
--
-- HALLAZGO H12: `driver_location_stale_seconds` existe en `app_settings` con la
-- descripcion de la regla R10 y no lo leia nadie. Los dos minutos estaban
-- fijados como valor por defecto de un parametro. Hoy los dos valores coinciden,
-- pero el dia que la empresa lo cambiara desde el panel no habria pasado nada.
--
-- HALLAZGO H13: la solicitud se ofrecia una sola vez, al crearla. Con D160 ya no
-- hace falta reofrecer por tandas, pero queda un hueco: un conductor que se pone
-- disponible treinta segundos despues no ve una solicitud que aun tiene cuatro
-- minutos de vida. Lo cierra el barrido periodico de mas abajo.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- H12: la antiguedad maxima de la ubicacion sale de la configuracion
-- -----------------------------------------------------------------------------

-- El parametro se conserva, pero su valor por defecto pasa a ser nulo y eso
-- significa "usa lo que diga la configuracion". Asi quien necesite forzar otro
-- valor, como una prueba, puede seguir haciendolo.
create or replace function public.find_available_drivers(
  p_origin extensions.geography,
  p_passenger_count smallint,
  p_max_staleness interval default null
)
returns table (
  driver_id uuid,
  full_name text,
  unit_number integer,
  plate text,
  max_passengers smallint,
  rating_average numeric,
  distance_m double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    d.id,
    p.full_name,
    v.unit_number,
    v.plate,
    v.max_passengers,
    d.rating_average,
    extensions.st_distance(dl.location, p_origin) as distance_m
  from public.drivers d
    join public.profiles p on p.id = d.id
    join public.driver_locations dl on dl.driver_id = d.id
    join public.driver_vehicle_assignments a
      on a.driver_id = d.id and a.unassigned_at is null
    join public.vehicles v on v.id = a.vehicle_id
  where d.is_available
    and d.approval_status = 'approved'
    and p.status = 'active'
    and v.status = 'active'
    and v.max_passengers >= p_passenger_count
    and dl.updated_at > now() - coalesce(
          p_max_staleness,
          make_interval(secs => (public.get_setting('driver_location_stale_seconds', '120'))::integer)
        )
  -- Se conserva el orden por cercania aunque con D160 ya no decida quien gana.
  -- Sigue sirviendo para dos cosas: la distancia que se guarda en cada oferta, y
  -- el dia que la empresa quiera volver a un reparto por tandas.
  order by dl.location <-> p_origin;
$$;

comment on function public.find_available_drivers is
  'Conductores aptos para una solicitud. La antiguedad maxima de la ubicacion sale de app_settings.';

revoke all on function public.find_available_drivers(extensions.geography, smallint, interval)
  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- D160: se ofrece a todos, no a cinco
-- -----------------------------------------------------------------------------

create or replace function public.offer_request_to_drivers(
  p_request_id uuid,
  p_limit integer default null
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request public.ride_requests;
  v_seconds integer;
  v_count integer := 0;
begin
  select * into v_request from public.ride_requests where id = p_request_id;
  if not found or v_request.status <> 'searching' then
    return 0;
  end if;

  v_seconds := (public.get_setting('offer_response_seconds', '20'))::integer;

  -- REGLA R12: no se reofrece a quien ya recibio la oferta. El filtro evita el
  -- intento y la restriccion de unicidad lo garantiza aunque el filtro fallara.
  --
  -- Consecuencia que conviene tener presente: esa restriccion es mas estricta
  -- que R12. Impide una segunda oferta tambien a quien simplemente dejo caducar
  -- la primera sin responder, no solo a quien la rechazo. Se deja asi: quien
  -- ignoro una solicitud hace veinte segundos probablemente ignore la siguiente.
  --
  -- LIMIT con valor nulo en PostgreSQL significa sin limite, asi que el valor
  -- por defecto de p_limit es lo que hace efectiva la decision D160 sin ninguna
  -- rama condicional.
  insert into public.ride_offers (request_id, driver_id, expires_at, distance_m)
  select p_request_id, d.driver_id, now() + make_interval(secs => v_seconds), round(d.distance_m)
  from public.find_available_drivers(
         v_request.origin,
         v_request.passenger_count
       ) d
  where not exists (
    select 1 from public.ride_offers o
    where o.request_id = p_request_id and o.driver_id = d.driver_id
  )
  limit p_limit;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.offer_request_to_drivers is
  'Ofrece una solicitud a los conductores disponibles. Sin limite por defecto (D160, R4).';

revoke all on function public.offer_request_to_drivers(uuid, integer) from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- H13: quien se conecta tarde tambien ve las solicitudes vivas
-- -----------------------------------------------------------------------------

-- Sin esto, ofrecer "a todos" significa en realidad "a todos los que ya estaban
-- conectados en el instante exacto de crear la solicitud". Un conductor que
-- enciende su disponibilidad medio minuto despues no veria un servicio al que
-- aun le quedan cuatro minutos y medio.
--
-- No hace falta llevar cuenta de nada: offer_request_to_drivers ya descarta a
-- quien tiene oferta, asi que llamarla de nuevo solo alcanza a los nuevos.
create or replace function public.offer_pending_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request record;
  v_total integer := 0;
begin
  for v_request in
    select id from public.ride_requests
    where status = 'searching' and expires_at > now()
    order by requested_at
  loop
    v_total := v_total + public.offer_request_to_drivers(v_request.id);
  end loop;

  return v_total;
end;
$$;

comment on function public.offer_pending_requests is
  'Ofrece las solicitudes vivas a los conductores que se conectaron despues de crearlas.';

revoke all on function public.offer_pending_requests() from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- La tarea programada pasa a hacer las dos cosas
-- -----------------------------------------------------------------------------

-- El orden importa y por eso van en una sola tarea y no en dos: primero se
-- caducan las solicitudes agotadas y despues se ofrecen las que siguen vivas.
-- Al reves se crearian ofertas para solicitudes que mueren en el mismo barrido.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'expire-stale-requests') then
    perform cron.unschedule('expire-stale-requests');
  end if;
  if exists (select 1 from cron.job where jobname = 'ride-request-sweep') then
    perform cron.unschedule('ride-request-sweep');
  end if;
end;
$$;

select cron.schedule(
  'ride-request-sweep',
  '* * * * *',
  'select public.expire_stale_requests(); select public.offer_pending_requests();'
);
