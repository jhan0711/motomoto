-- =============================================================================
-- LA CONTRAPARTE SOLO SI QUIEN REPORTA ESTUVO EN ESE VIAJE
-- =============================================================================
--
-- **Salio mirando la pantalla antes de ensenarsela al usuario**, con los datos
-- sembrados: un reporte de una persona que **no participo en el viaje** apuntaba
-- como contraparte a la pasajera de ese viaje. La regla estaba escrita como un
-- `case` de dos ramas -"si el que reporta es el pasajero, el conductor; si no,
-- el pasajero"-, y ese "si no" se tragaba tambien **al que no era ninguno de los
-- dos**.
--
-- POR QUE PUEDE PASAR DE VERDAD Y NO ES SOLO COSA DE LOS DATOS DE PRUEBA.
-- `reports_insert_own` solo comprueba que el reportante sea uno mismo: **nada
-- obliga a que el `ride_id` sea de un viaje suyo**. Se deja asi a proposito
-- -alguien puede tener motivos para senalar un servicio que vio- pero entonces
-- la bandeja **no puede inventarse una contraparte**.
--
-- **UN DATO DE MAS QUE SENALA A LA PERSONA EQUIVOCADA ES PEOR QUE NO TENERLO.**
-- Sobre esa linea se decide a quien se llama para pedir explicaciones.
-- =============================================================================

-- **SE SUELTA ANTES DE RECREARLA**, y no es opcional: la funcion gana una
-- columna -`reporter_was_in_ride`- y `create or replace` **no puede cambiar el
-- tipo de retorno** de una funcion que ya existe. Postgres lo rechaza sin decir
-- cual es el motivo, asi que queda escrito aqui.
drop function if exists public.admin_list_reports(
  public.report_status, timestamptz, timestamptz, text, integer, integer);

create function public.admin_list_reports(
  p_status public.report_status default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  report_id uuid,
  created_at timestamptz,
  status public.report_status,
  category text,
  description text,
  reporter_id uuid,
  reporter_name text,
  reporter_phone text,
  reporter_role public.user_role,
  ride_id uuid,
  ride_requested_at timestamptz,
  ride_route text,
  counterpart_name text,
  reporter_was_in_ride boolean,
  resolved_at timestamptz,
  resolved_by_name text,
  resolution_notes text,
  total_count bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    r.id,
    r.created_at,
    r.status,
    r.category,
    r.description,
    r.reporter_id,
    rp.full_name,
    rp.phone,
    rp.role,
    r.ride_id,
    rq.requested_at,
    case when rq.id is not null
      then rq.origin_label || ' → ' || rq.destination_label end,

    -- **LA CONTRAPARTE, Y SOLO SI LA HAY.** Las tres ramas son explicitas y no
    -- hay un `else` que recoja lo que sobre: el que reporta es el pasajero del
    -- viaje -y entonces interesa el conductor-, es el conductor -y entonces
    -- interesa el pasajero-, o **no es ninguno de los dos, y entonces no hay
    -- contraparte que ensenar**.
    case
      when rd.id is null then null
      when r.reporter_id = rq.passenger_id then cp_driver.full_name
      when r.reporter_id = rd.driver_id then cp_passenger.full_name
    end,

    -- Y se dice explicitamente, para que la pantalla pueda avisar en vez de
    -- callarse: un reporte sobre un servicio ajeno se lee distinto.
    case when rd.id is null then null
      else (r.reporter_id = rq.passenger_id or r.reporter_id = rd.driver_id) end,

    r.resolved_at,
    solver.full_name,
    r.resolution_notes,

    -- El total de lo filtrado lo cuenta el servidor y viaja en cada fila: sin
    -- esto la pantalla pediria el listado entero solo para saber cuantas
    -- paginas hay. Mismo criterio que `admin_list_rides` en el paso 8.
    count(*) over ()
  from public.reports r
  join public.profiles rp on rp.id = r.reporter_id
  left join public.rides rd on rd.id = r.ride_id
  left join public.ride_requests rq on rq.id = rd.request_id
  left join public.profiles cp_driver on cp_driver.id = rd.driver_id
  left join public.profiles cp_passenger on cp_passenger.id = rq.passenger_id
  left join public.profiles solver on solver.id = r.resolved_by
  where public.is_admin()
    and (p_status is null or r.status = p_status)
    and (p_from is null or r.created_at >= p_from)
    and (p_to is null or r.created_at < p_to)
    and (
      p_search is null or trim(p_search) = ''
      or rp.full_name ilike '%' || trim(p_search) || '%'
      or rp.phone like '%' || trim(p_search) || '%'
      or r.description ilike '%' || trim(p_search) || '%'
      or r.category ilike '%' || trim(p_search) || '%'
    )
  -- **LOS SIN RESOLVER PRIMERO, Y DENTRO DE ELLOS LOS MAS VIEJOS**, que es al
  -- reves que en el resto de listados del panel. Una bandeja no se lee como un
  -- historial: lo urgente es lo que lleva mas tiempo esperando respuesta.
  order by
    (r.status = 'resolved'),
    case when r.status = 'resolved' then r.created_at end desc,
    case when r.status <> 'resolved' then r.created_at end asc
  limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
$$;

comment on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) is
  'La bandeja de reportes: los sin resolver primero y los mas viejos arriba.';

revoke all on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) from public;
revoke all on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) from anon, authenticated;
grant execute on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) to authenticated;
