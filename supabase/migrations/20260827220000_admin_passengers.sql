-- =============================================================================
-- FASE 20, PASO 7: listado de pasajeros con bloqueo
-- =============================================================================
--
-- EL PASO MAS CORTO DE LA FASE, y conviene decir por que: **el bloqueo ya
-- existe**. `admin_set_account_status` se construyo en el paso 2 y sirve igual
-- para un pasajero que para un conductor -por eso se llama "cuenta" y no
-- "conductor"-, con su auditoria y su regla de no bloquearse a uno mismo. Aqui
-- solo falta **la lista desde la que decidir**.
--
-- QUE NECESITA VER LA EMPRESA DE UN PASAJERO, y por que cada dato:
--
--   - **cuantos servicios lleva y como acabaron**. Un pasajero con quince
--     cancelaciones y dos viajes es un problema distinto de uno con diecisiete
--     viajes: el primero esta haciendo perder desplazamientos a los conductores
--   - **su calificacion**, la que le ponen los conductores. Existe desde la Fase
--     17 en los dos sentidos, pero **nunca se ha mirado**: `drivers` tiene su
--     media precalculada y el pasajero no, asi que hay que calcularla aqui
--   - **si tiene un servicio en curso**, para no bloquear a alguien que va
--     subido en un motorraton ahora mismo
--
-- LA MEDIA DEL PASAJERO SE CALCULA, NO SE GUARDA. `drivers.rating_average` esta
-- precalculada porque **se lee en cada oferta**: el pasajero ve la nota de su
-- conductor antes de aceptar. La del pasajero se mira desde una sola pantalla y
-- de vez en cuando, asi que un disparador que la mantuviera seria mas cosas que
-- pueden desincronizarse a cambio de nada.
-- =============================================================================

create or replace function public.admin_list_passengers()
returns table (
  passenger_id uuid,
  full_name text,
  phone text,
  status public.user_status,
  created_at timestamptz,

  -- Como le ha ido con la aplicacion. Los tres desenlaces por separado, no un
  -- total: "veinte servicios" no dice si fueron bien.
  completed_count integer,
  cancelled_count integer,
  expired_count integer,

  -- La nota que le ponen los conductores, calculada al vuelo.
  rating_average numeric,
  rating_count integer,

  -- Mismo criterio que D244 con los conductores: no se bloquea a ciegas a quien
  -- esta a mitad de servicio.
  has_active_request boolean,

  last_request_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    p.id,
    p.full_name,
    p.phone,
    p.status,
    p.created_at,

    count(*) filter (where rr.status = 'completed')::integer,
    count(*) filter (where rr.status = 'cancelled')::integer,
    count(*) filter (where rr.status = 'expired')::integer,

    -- `round(..., 2)` y no el numero crudo: 4.3333333 no dice nada mas que 4,33
    -- y ensucia la pantalla. Nulo cuando no hay ninguna, que es distinto de cero.
    (select round(avg(r.stars)::numeric, 2) from public.ratings r where r.rated_id = p.id),
    (select count(*)::integer from public.ratings r where r.rated_id = p.id),

    bool_or(rr.status in ('searching', 'assigned', 'in_progress')),

    max(rr.requested_at)
  from public.profiles p
  left join public.ride_requests rr on rr.passenger_id = p.id
  where p.role = 'passenger'
  group by p.id
  -- Los que mas han usado la aplicacion recientemente, primero: es el orden en
  -- que la empresa los reconoce.
  order by max(rr.requested_at) desc nulls last, p.full_name;
$$;

comment on function public.admin_list_passengers() is
  'Pasajeros con sus desenlaces, su calificacion y si tienen un servicio en curso.';

revoke all on function public.admin_list_passengers() from public;
grant execute on function public.admin_list_passengers() to authenticated;


-- -----------------------------------------------------------------------------
-- admin_get_passenger_rides
-- -----------------------------------------------------------------------------
--
-- El detalle de un pasajero: sus ultimos servicios. Sirve para responder la
-- pregunta que sigue al listado -"¿por que cancela tanto?"- antes de decidir si
-- se le bloquea.
--
-- **Es de solo lectura y no reemplaza al listado de servicios del paso 8**, que
-- mirara la operacion entera. Este mira a una persona.
create or replace function public.admin_get_passenger_rides(
  p_passenger_id uuid,
  p_limit integer default 20
)
returns table (
  request_id uuid,
  status public.ride_request_status,
  service_type public.service_type,
  origin_label text,
  destination_label text,
  fare_amount integer,
  requested_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,
  driver_name text
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    rr.id,
    rr.status,
    rr.service_type,
    rr.origin_label,
    rr.destination_label,
    rr.fare_amount,
    rr.requested_at,
    rr.cancelled_by,
    rr.cancellation_reason,
    dp.full_name
  from public.ride_requests rr
  left join public.rides r on r.request_id = rr.id and r.status <> 'cancelled'
  left join public.profiles dp on dp.id = r.driver_id
  where rr.passenger_id = p_passenger_id
  order by rr.requested_at desc
  -- Tope de 50 en el servidor, como el historial de la Fase 16 (D199): por la
  -- API cualquiera puede pedir sin techo.
  limit least(coalesce(p_limit, 20), 50);
$$;

comment on function public.admin_get_passenger_rides(uuid, integer) is
  'Ultimos servicios de un pasajero, para decidir sobre su cuenta.';

revoke all on function public.admin_get_passenger_rides(uuid, integer) from public;
grant execute on function public.admin_get_passenger_rides(uuid, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- No se bloquea a quien va montado en un motorraton
-- -----------------------------------------------------------------------------
--
-- `admin_set_account_status` es del paso 2 y no miraba servicios en curso: en
-- aquel momento se penso para conductores, y para ellos la proteccion se puso en
-- `admin_set_driver_approval` (D244).
--
-- **Bloquear la cuenta de un pasajero a mitad de viaje no es lo mismo que
-- retirarle la aprobacion a un conductor**, pero se parece bastante: el servicio
-- sigue vivo, el conductor sigue conduciendo, y el pasajero deja de poder abrir
-- la aplicacion para ver donde va o para cancelar.
--
-- Aun asi **NO se prohibe, se avisa** (D253). Es la diferencia con D244: alli lo
-- que se protege es a un tercero -el pasajero que va dentro-; aqui el afectado es
-- el propio bloqueado, y **puede haber una urgencia real que justifique dejarlo
-- fuera ahora mismo**. Se pide un motivo escrito y queda en la auditoria.
create or replace function public.admin_set_account_status(
  p_user_id uuid,
  p_status public.user_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.profiles;
  v_active_request uuid;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar el estado de una cuenta'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if p_user_id = (select auth.uid()) then
    raise exception 'No puedes cambiar el estado de tu propia cuenta'
      using errcode = 'P0001', hint = 'CANNOT_CHANGE_OWN_ACCOUNT';
  end if;

  select * into v_before from public.profiles where id = p_user_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  if v_before.status = p_status then
    raise exception 'Esa cuenta ya esta en ese estado'
      using errcode = 'P0001', hint = 'STATUS_UNCHANGED';
  end if;

  -- **BLOQUEAR A ALGUIEN CON UN SERVICIO EN CURSO EXIGE MOTIVO ESCRITO.** No se
  -- prohibe -puede haber una urgencia-, pero deja de ser un clic distraido: si
  -- se hace, se explica, y la explicacion queda registrada.
  if p_status = 'blocked' then
    select rr.id into v_active_request
    from public.ride_requests rr
    where rr.passenger_id = p_user_id
      and rr.status in ('searching', 'assigned', 'in_progress')
    limit 1;

    if v_active_request is not null
       and length(trim(coalesce(p_reason, ''))) < 10 then
      raise exception 'Esa persona tiene un servicio en curso. Escribe el motivo del bloqueo, de al menos 10 caracteres'
        using errcode = 'P0001', hint = 'ACTIVE_RIDE_NEEDS_REASON';
    end if;
  end if;

  perform set_config('motomoto.admin_action', 'on', true);

  update public.profiles set status = p_status where id = p_user_id;

  perform set_config('motomoto.admin_action', 'off', true);

  perform public.log_admin_action(
    case when p_status = 'blocked' then 'block_account' else 'unblock_account' end,
    'profiles',
    p_user_id::text,
    jsonb_build_object('status', v_before.status),
    jsonb_build_object('status', p_status, 'reason', p_reason,
                       -- Queda escrito si se hizo con un servicio vivo: es el
                       -- dato que explicara la decision dentro de seis meses.
                       'had_active_request', v_active_request is not null)
  );
end;
$$;

comment on function public.admin_set_account_status(uuid, public.user_status, text) is
  'Bloquea o desbloquea una cuenta dejando registro. Con servicio en curso, exige motivo.';
