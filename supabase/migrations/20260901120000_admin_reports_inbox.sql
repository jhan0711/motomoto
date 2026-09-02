-- =============================================================================
-- LA BANDEJA DE REPORTES (Fase 20, paso 10a; D204)
-- =============================================================================
--
-- **Esto es lo que D204 prometio.** En la Fase 12 se decidio no poner el boton
-- de "reportar un problema" en la aplicacion porque no habia donde leer los
-- reportes: un boton que manda una queja que nadie puede ver **promete atencion
-- que no existe**. La bandeja se hace ahora, y el boton entra en el paso 10b.
--
-- LO QUE YA EXISTIA Y NO SE REHIZO. La tabla `reports` esta desde la Fase 1
-- -`20260729005909`- con sus estados, sus indices y su coherencia de resuelto.
-- Aqui no se toca su forma: **se le pone encima quien la gestiona**.
--
-- LO QUE SE ARREGLA DE PASO, Y NO ES MENOR. `reports_update_admin` es un
-- `for update` con `using (is_admin())`: dejaba al administrador **reescribir
-- cualquier columna del reporte, la descripcion incluida**. Es el mismo hueco
-- que se cerro en el paso 4c con las politicas `_all_admin`, y aqui pesa mas
-- que en un catalogo: **un reporte es lo que alguien dijo que le paso**. Si se
-- puede editar, deja de ser evidencia de nada, y quien lo escribio no tiene
-- forma de saber que se cambio. La politica se sustituye por una que solo deja
-- pasar la gestion, y un disparador vigila que las columnas del reportante no
-- se muevan **venga de donde venga la escritura**.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Lo que dijo quien reporto no se toca
-- -----------------------------------------------------------------------------

create or replace function public.protect_report_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- El servicio y la persona que reporto son de quien reporto; la categoria y
  -- la descripcion, tambien. Lo unico que la empresa anade es **como lo
  -- gestiono**: el estado, quien lo cerro, cuando y con que nota.
  if new.reporter_id is distinct from old.reporter_id
     or new.ride_id is distinct from old.ride_id
     or new.category is distinct from old.category
     or new.description is distinct from old.description
     or new.created_at is distinct from old.created_at
  then
    raise exception 'Un reporte no se puede modificar: solo se puede gestionar'
      using errcode = 'P0001', hint = 'REPORT_IS_IMMUTABLE';
  end if;

  new.updated_at := clock_timestamp();
  return new;
end;
$$;

comment on function public.protect_report_columns() is
  'Impide cambiar lo que dijo quien reporto; solo deja gestionar el reporte.';

drop trigger if exists reports_protect_columns on public.reports;
create trigger reports_protect_columns
  before update on public.reports
  for each row
  execute function public.protect_report_columns();


-- **SE CIERRA LA ESCRITURA DIRECTA.** La gestion pasa por
-- `admin_set_report_status`, que ademas deja rastro en la auditoria y avisa a
-- quien reporto. Sin esto, un `update` suelto desde el panel cambiaria el estado
-- sin que constara quien fue.
drop policy if exists "reports_update_admin" on public.reports;


-- -----------------------------------------------------------------------------
-- 2. La bandeja
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_reports(
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

    -- **LA CONTRAPARTE, VISTA DESDE QUIEN REPORTA.** Si el que se queja es el
    -- pasajero, interesa el conductor, y al reves. Un reporte sin saber contra
    -- quien va obliga a abrir el servicio para enterarse.
    case
      when rd.id is null then null
      when r.reporter_id = rq.passenger_id then cp_driver.full_name
      else cp_passenger.full_name
    end,

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


-- -----------------------------------------------------------------------------
-- 3. Las categorias que existen de verdad
-- -----------------------------------------------------------------------------
--
-- **NO SE INVENTA UN CATALOGO AQUI.** `category` es texto libre y la aplicacion
-- todavia no manda ninguna: el catalogo se decide en el paso 10b, con el
-- usuario, porque son categorias de su negocio y no del programa. Mientras
-- tanto el filtro se llena con **las que hay en los datos**, que es lo unico
-- cierto que se puede decir hoy.
create or replace function public.admin_list_report_categories()
returns table (category text, cuantos bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select r.category, count(*)
  from public.reports r
  where public.is_admin()
  group by r.category
  order by count(*) desc, r.category;
$$;

comment on function public.admin_list_report_categories() is
  'Las categorias de reporte que existen en los datos, para llenar el filtro.';


-- -----------------------------------------------------------------------------
-- 4. Gestionar un reporte
-- -----------------------------------------------------------------------------

create or replace function public.admin_set_report_status(
  p_report_id uuid,
  p_status public.report_status,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.reports%rowtype;
  v_actor uuid := auth.uid();
begin
  if not public.is_admin() then
    raise exception 'Solo la empresa puede gestionar los reportes'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_before from public.reports where id = p_report_id;
  if not found then
    raise exception 'Ese reporte no existe'
      using errcode = 'P0001', hint = 'REPORT_NOT_FOUND';
  end if;

  -- **RESOLVER EXIGE ESCRIBIR QUE SE HIZO.** Un reporte que pasa a resuelto sin
  -- una linea explicando por que no le sirve a nadie: ni al que se quejo, que no
  -- se entera de nada, ni a la empresa dentro de tres meses. Los otros dos
  -- estados no lo piden, porque "lo estoy mirando" no necesita explicacion.
  if p_status = 'resolved' and coalesce(trim(p_notes), '') = '' then
    raise exception 'Para cerrar un reporte hay que escribir que se hizo'
      using errcode = 'P0001', hint = 'RESOLUTION_NOTES_REQUIRED';
  end if;

  if v_before.status = p_status then
    raise exception 'Ese reporte ya esta en ese estado'
      using errcode = 'P0001', hint = 'REPORT_STATUS_UNCHANGED';
  end if;

  update public.reports set
    status = p_status,
    -- La coherencia de `reports_resolved_coherence` se respeta desde aqui:
    -- resuelto lleva fecha y los demas no. Reabrir un reporte la borra.
    resolved_at = case when p_status = 'resolved' then clock_timestamp() end,
    resolved_by = case when p_status = 'resolved' then v_actor end,
    resolution_notes = case
      when p_status = 'resolved' then trim(p_notes)
      else v_before.resolution_notes
    end
  where id = p_report_id;

  perform public.log_admin_action(
    'set_report_status', 'report', p_report_id::text,
    jsonb_build_object('status', v_before.status),
    jsonb_build_object('status', p_status, 'notes', nullif(trim(coalesce(p_notes, '')), ''))
  );

  -- **SE LE DICE A QUIEN REPORTO QUE SE RESOLVIO.** Es la mitad que faltaba de
  -- D204: la queja se atiende y **quien la puso se entera**. Solo al cerrar; que
  -- alguien este mirandolo no es noticia todavia.
  if p_status = 'resolved' then
    perform public.send_push_notification(
      v_before.reporter_id,
      'report_resolved',
      'Revisamos lo que nos contaste',
      'Ya revisamos el problema que reportaste. Abre la aplicacion para ver la respuesta.',
      jsonb_build_object('reportId', p_report_id)
    );
  end if;
end;
$$;

comment on function public.admin_set_report_status(uuid, public.report_status, text) is
  'Cambia el estado de un reporte, lo deja en la auditoria y avisa al cerrarlo.';


-- -----------------------------------------------------------------------------
-- 5. Las calificaciones, vistas en conjunto
-- -----------------------------------------------------------------------------
--
-- **ESTO NO REPITE `admin_get_ride_ratings` DEL PASO 8.** Aquella responde "que
-- pasa con este servicio" y se mira desde un servicio concreto. Esta responde la
-- pregunta contraria, que es la que hace falta para actuar: **donde estan las
-- malas**. Una empresa no revisa servicio por servicio buscando una estrella;
-- necesita que las peores salgan solas.
create or replace function public.admin_list_ratings(
  p_max_stars smallint default null,
  p_rated_id uuid default null,
  p_only_with_comment boolean default false,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  rating_id uuid,
  created_at timestamptz,
  stars smallint,
  comment text,
  rater_name text,
  rater_role public.user_role,
  rated_id uuid,
  rated_name text,
  rated_role public.user_role,
  ride_id uuid,
  request_id uuid,
  ride_route text,
  total_count bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    g.id,
    g.created_at,
    g.stars,
    g.comment,
    rater.full_name,
    rater.role,
    g.rated_id,
    rated.full_name,
    rated.role,
    g.ride_id,
    rd.request_id,
    case when rq.id is not null
      then rq.origin_label || ' → ' || rq.destination_label end,
    count(*) over ()
  from public.ratings g
  join public.profiles rater on rater.id = g.rater_id
  join public.profiles rated on rated.id = g.rated_id
  left join public.rides rd on rd.id = g.ride_id
  left join public.ride_requests rq on rq.id = rd.request_id
  where public.is_admin()
    and (p_max_stars is null or g.stars <= p_max_stars)
    and (p_rated_id is null or g.rated_id = p_rated_id)
    and (not coalesce(p_only_with_comment, false)
         or coalesce(trim(g.comment), '') <> '')
  -- Las peores primero y, empatadas, las mas recientes: es el orden en que se
  -- atienden.
  order by g.stars asc, g.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
$$;

comment on function public.admin_list_ratings(smallint, uuid, boolean, integer, integer) is
  'Las calificaciones en conjunto, las peores primero, para poder actuar.';


-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------
--
-- `revoke ... from anon, authenticated` ademas de `from public`: los permisos
-- por defecto de Supabase conceden `execute` a esos dos roles al crear la
-- funcion, asi que quitarselo a `public` no basta. Aprendido en el paso 4a.

revoke all on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) from public;
revoke all on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) from anon, authenticated;
grant execute on function public.admin_list_reports(public.report_status, timestamptz, timestamptz, text, integer, integer) to authenticated;

revoke all on function public.admin_list_report_categories() from public;
revoke all on function public.admin_list_report_categories() from anon, authenticated;
grant execute on function public.admin_list_report_categories() to authenticated;

revoke all on function public.admin_set_report_status(uuid, public.report_status, text) from public;
revoke all on function public.admin_set_report_status(uuid, public.report_status, text) from anon, authenticated;
grant execute on function public.admin_set_report_status(uuid, public.report_status, text) to authenticated;

revoke all on function public.admin_list_ratings(smallint, uuid, boolean, integer, integer) from public;
revoke all on function public.admin_list_ratings(smallint, uuid, boolean, integer, integer) from anon, authenticated;
grant execute on function public.admin_list_ratings(smallint, uuid, boolean, integer, integer) to authenticated;
