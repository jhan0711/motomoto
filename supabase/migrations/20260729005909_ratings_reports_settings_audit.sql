-- =============================================================================
-- Migracion 5: calificaciones, reportes, notificaciones, configuracion, auditoria
-- =============================================================================
--
-- Cierra el modelo de 17 tablas. Aqui vive tambien el disparador que mantiene la
-- calificacion precalculada del conductor (decision D79) y los parametros
-- operativos que la empresa podra ajustar sin tocar codigo.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: ratings
-- -----------------------------------------------------------------------------

create table public.ratings (
  id uuid primary key default gen_random_uuid(),

  ride_id uuid not null references public.rides (id) on delete cascade,
  rater_id uuid not null references public.profiles (id) on delete cascade,
  rated_id uuid not null references public.profiles (id) on delete cascade,

  stars smallint not null
    constraint ratings_stars_range check (stars between 1 and 5),
  comment text
    constraint ratings_comment_length check (comment is null or length(comment) <= 1000),

  created_at timestamptz not null default now(),

  -- REGLA R8: una calificacion por servicio y por parte, no editable.
  -- Con esta restriccion, "ya calificaste este viaje" no es un mensaje que la
  -- aplicacion deba recordar comprobar: es una fila que no entra.
  constraint ratings_one_per_ride_per_rater unique (ride_id, rater_id),

  constraint ratings_no_self check (rater_id <> rated_id)
);

comment on table public.ratings is
  'Calificaciones entre pasajero y conductor. Una por parte y por viaje.';

create index ratings_rated_idx on public.ratings (rated_id, created_at desc);
create index ratings_ride_idx on public.ratings (ride_id);

alter table public.ratings enable row level security;


-- -----------------------------------------------------------------------------
-- Disparador: mantener la calificacion precalculada del conductor
-- -----------------------------------------------------------------------------

-- DECISION D79. La columna drivers.rating_average es un dato duplicado a
-- proposito, y lo que hace segura esa duplicacion es que NADIE la escribe a
-- mano: solo esta funcion.
--
-- Recalcula el promedio completo en lugar de ajustarlo de forma incremental.
-- Con las cifras de este proyecto son unas pocas decenas de filas por conductor,
-- y a cambio el resultado es siempre exacto: un calculo incremental acumula
-- desviaciones y, si alguna vez se corrige una calificacion a mano, queda mal
-- para siempre.
--
-- Si rated_id es un pasajero, el UPDATE no encuentra fila en drivers y no hace
-- nada. No hace falta comprobar el rol.
create or replace function public.refresh_driver_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid;
begin
  v_driver := coalesce(new.rated_id, old.rated_id);

  update public.drivers d
  set rating_average = coalesce(s.promedio, 0),
      rating_count = coalesce(s.total, 0)
  from (
    select round(avg(stars), 2) as promedio, count(*) as total
    from public.ratings
    where rated_id = v_driver
  ) s
  where d.id = v_driver;

  return null;
end;
$$;

comment on function public.refresh_driver_rating() is
  'Unica escritora de drivers.rating_average. Recalcula el promedio completo.';

create trigger ratings_refresh_driver
  after insert or update or delete on public.ratings
  for each row execute function public.refresh_driver_rating();


-- -----------------------------------------------------------------------------
-- Tabla: reports
-- -----------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),

  reporter_id uuid not null references public.profiles (id) on delete cascade,

  -- set null, no cascade: si el viaje se borra, el reporte sobrevive. Un
  -- problema reportado es informacion que la empresa necesita conservar.
  ride_id uuid references public.rides (id) on delete set null,

  category text not null
    constraint reports_category_not_blank check (length(trim(category)) > 0),
  description text not null
    constraint reports_description_length check (length(trim(description)) between 10 and 2000),

  status public.report_status not null default 'open',
  resolved_at timestamptz,
  resolved_by uuid references public.profiles (id) on delete set null,
  resolution_notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint reports_resolved_coherence check (
    (status = 'resolved') = (resolved_at is not null)
  )
);

comment on table public.reports is
  'Problemas reportados por pasajeros o conductores, con su gestion.';

create index reports_open_idx on public.reports (created_at desc) where status <> 'resolved';
create index reports_reporter_idx on public.reports (reporter_id, created_at desc);

create trigger reports_set_updated_at
  before update on public.reports
  for each row execute function public.set_updated_at();

alter table public.reports enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: notifications
-- -----------------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles (id) on delete cascade,

  type text not null
    constraint notifications_type_not_blank check (length(trim(type)) > 0),
  title text not null,
  body text not null,

  -- Datos para que la app sepa a donde navegar al tocarla: identificador del
  -- viaje, de la solicitud, lo que corresponda segun el tipo.
  data jsonb not null default '{}'::jsonb,

  read_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.notifications is
  'Historial de notificaciones enviadas. El envio push es aparte.';

-- La consulta habitual: las no leidas de un usuario, mas recientes primero.
create index notifications_unread_idx on public.notifications (user_id, created_at desc)
  where read_at is null;

alter table public.notifications enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: app_settings
-- -----------------------------------------------------------------------------

-- Los parametros operativos de la Fase 0. Estan aqui y no en el codigo porque la
-- empresa debe poder ajustarlos sin esperar a una nueva version en la tienda.
--
-- El valor es jsonb y no un tipo concreto para admitir numeros, textos, booleanos
-- y estructuras sin cambiar el esquema cada vez.
create table public.app_settings (
  key text primary key
    constraint app_settings_key_format check (key ~ '^[a-z0-9_]{3,60}$'),
  value jsonb not null,
  description text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

comment on table public.app_settings is
  'Parametros operativos ajustables desde el panel, sin desplegar la app.';

create trigger app_settings_set_updated_at
  before update on public.app_settings
  for each row execute function public.set_updated_at();

alter table public.app_settings enable row level security;

-- Valores iniciales: las reglas R1 a R11 aprobadas en la Fase 0.
insert into public.app_settings (key, value, description) values
  ('request_expiry_seconds', '300',
   'R1. Tiempo maximo buscando conductor antes de caducar la solicitud.'),
  ('offer_response_seconds', '20',
   'R2. Tiempo que tiene un conductor para responder a una oferta.'),
  ('free_cancellation_seconds', '120',
   'R3. Margen tras la asignacion para cancelar sin consecuencia.'),
  ('driver_arrival_radius_m', '150',
   'R5. Distancia al punto de recogida que habilita el boton He llegado.'),
  ('driver_location_stale_seconds', '120',
   'R10. Antiguedad a partir de la cual se considera que el conductor perdio cobertura.'),
  ('location_interval_available_seconds', '30',
   'R9. Cada cuanto envia posicion un conductor disponible.'),
  ('location_interval_in_ride_seconds', '10',
   'R9. Cada cuanto envia posicion un conductor en viaje.'),
  ('location_min_distance_m', '50',
   'R9. Desplazamiento minimo para registrar un punto del recorrido.'),
  ('max_passengers_per_request', '3',
   'R11. Maximo de pasajeros por solicitud. Limitado por la capacidad del motorraton.');


-- -----------------------------------------------------------------------------
-- Funcion auxiliar: leer un parametro
-- -----------------------------------------------------------------------------

-- La usaran las funciones de transicion de la migracion 6 para no repetir
-- consultas ni, peor, fijar los valores en el codigo.
create or replace function public.get_setting(p_key text, p_default jsonb default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select value from public.app_settings where key = p_key), p_default);
$$;

comment on function public.get_setting is
  'Lee un parametro operativo. Devuelve el valor por defecto si no existe.';


-- -----------------------------------------------------------------------------
-- Tabla: admin_audit_logs
-- -----------------------------------------------------------------------------

-- Registro de acciones administrativas sensibles: aprobar o bloquear un
-- conductor, cancelar un servicio, asignar un vehiculo.
--
-- actor_id admite nulo y se pone a nulo si el administrador se borra. Es
-- deliberado: un registro de auditoria que desaparece con su autor no sirve como
-- auditoria. Es mejor conservar "alguien hizo esto" que perder el hecho.
create table public.admin_audit_logs (
  id bigint generated always as identity primary key,

  actor_id uuid references public.profiles (id) on delete set null,

  action text not null
    constraint audit_action_not_blank check (length(trim(action)) > 0),
  entity_type text not null,
  entity_id text,

  -- Estado anterior y posterior. Permite responder "quien cambio esto y que
  -- habia antes", que es la pregunta que se hace siempre despues del problema.
  before_data jsonb,
  after_data jsonb,

  created_at timestamptz not null default now()
);

comment on table public.admin_audit_logs is
  'Auditoria de acciones administrativas. Solo se inserta, nunca se modifica.';

create index audit_actor_idx on public.admin_audit_logs (actor_id, created_at desc);
create index audit_entity_idx on public.admin_audit_logs (entity_type, entity_id, created_at desc);

alter table public.admin_audit_logs enable row level security;
