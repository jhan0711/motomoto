-- =============================================================================
-- Migracion 2: flota
-- =============================================================================
--
-- Conductores, vehiculos, la relacion entre ambos y la documentacion.
--
-- Es la migracion donde varias reglas de negocio de la Fase 0 dejan de ser
-- comprobaciones que el codigo debe recordar y pasan a ser restricciones que la
-- base de datos no permite violar. Cada una lleva anotada la regla que aplica.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: drivers
-- -----------------------------------------------------------------------------

-- Separada de profiles porque solo los conductores tienen estado de aprobacion,
-- disponibilidad y calificacion. Meter estas columnas en profiles dejaria la
-- mayoria vacia, ya que la mayoria de usuarios seran pasajeros.
create table public.drivers (
  id uuid primary key references public.profiles (id) on delete cascade,

  approval_status public.driver_approval_status not null default 'pending',
  approved_at timestamptz,
  approved_by uuid references public.profiles (id) on delete set null,

  -- Lo cambia el propio conductor desde la aplicacion.
  is_available boolean not null default false,

  -- Calificacion precalculada (decision D79). Nadie la escribe a mano: la
  -- mantiene el disparador que se crea junto a la tabla de calificaciones.
  rating_average numeric(3, 2) not null default 0
    constraint drivers_rating_range check (rating_average between 0 and 5),
  rating_count integer not null default 0
    constraint drivers_rating_count_positive check (rating_count >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Un conductor aprobado tiene que tener fecha de aprobacion. En un solo
  -- sentido: si mas tarde se le bloquea, la fecha original se conserva como
  -- historial.
  constraint drivers_approved_has_date check (
    approval_status <> 'approved' or approved_at is not null
  ),

  -- REGLA DE LA FASE 0: un conductor no puede operar sin aprobacion de la
  -- empresa. Esta restriccion la hace imposible de saltar: aunque la aplicacion
  -- tuviera un fallo y enviara is_available = true para un conductor pendiente,
  -- la base de datos rechaza la fila.
  constraint drivers_available_only_when_approved check (
    not is_available or approval_status = 'approved'
  )
);

comment on table public.drivers is
  'Datos propios del conductor. La clave primaria es la misma que su perfil.';
comment on column public.drivers.rating_average is
  'Precalculada. La mantiene un disparador, nunca la aplicacion.';

-- El indice que sostiene la consulta mas frecuente de la plataforma: buscar
-- conductores disponibles. Parcial, porque solo interesan los que lo estan.
create index drivers_available_idx on public.drivers (is_available)
  where is_available;

create index drivers_approval_status_idx on public.drivers (approval_status);

create trigger drivers_set_updated_at
  before update on public.drivers
  for each row execute function public.set_updated_at();

alter table public.drivers enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: vehicles
-- -----------------------------------------------------------------------------

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),

  -- DECISION D55: numero de motorraton. Entero, obligatorio y unico.
  -- Es como identifica la gente a las unidades a distancia, antes que la placa.
  unit_number integer not null
    constraint vehicles_unit_number_positive check (unit_number > 0),

  plate text not null
    constraint vehicles_plate_length check (length(plate) between 5 and 10),

  model text,

  -- REGLA R11 y decision D4: capacidad del vehiculo. El limite superior de 10 no
  -- es la capacidad de un motorraton, que son 3, sino un tope defensivo: impide
  -- que un error de tecleo cree una unidad de 300 plazas.
  max_passengers smallint not null
    constraint vehicles_capacity_range check (max_passengers between 1 and 10),

  status public.vehicle_status not null default 'active',
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint vehicles_unit_number_key unique (unit_number),
  constraint vehicles_plate_key unique (plate)
);

comment on table public.vehicles is
  'Motorratones de la flota. El numero de unidad es el identificador que usa la gente.';
comment on column public.vehicles.max_passengers is
  'Capacidad sin contar al conductor. Filtra que solicitudes puede atender.';

create index vehicles_status_idx on public.vehicles (status)
  where status = 'active';

-- Normaliza la placa antes de guardarla. Sin esto, 'abc12' y 'ABC12' serian dos
-- vehiculos distintos para la restriccion de unicidad, que es justo lo que no
-- queremos. Normalizar aqui y no en la aplicacion cubre tambien las altas hechas
-- desde el panel de Supabase o desde un script.
create or replace function public.normalize_vehicle_plate()
returns trigger
language plpgsql
as $$
begin
  new.plate = upper(regexp_replace(new.plate, '[^A-Za-z0-9]', '', 'g'));
  return new;
end;
$$;

create trigger vehicles_normalize_plate
  before insert or update of plate on public.vehicles
  for each row execute function public.normalize_vehicle_plate();

create trigger vehicles_set_updated_at
  before update on public.vehicles
  for each row execute function public.set_updated_at();

alter table public.vehicles enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: driver_vehicle_assignments
-- -----------------------------------------------------------------------------

-- Historial de que conductor opera que vehiculo. Se conserva cerrando el periodo
-- en lugar de borrando la fila, porque un viaje pasado debe poder responder
-- "quien conducia esta unidad aquel dia".
create table public.driver_vehicle_assignments (
  id uuid primary key default gen_random_uuid(),

  driver_id uuid not null references public.drivers (id) on delete cascade,

  -- restrict, no cascade: borrar un vehiculo con historial de asignaciones
  -- destruiria informacion operativa. Para retirarlo esta el estado 'retired'.
  vehicle_id uuid not null references public.vehicles (id) on delete restrict,

  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  assigned_by uuid references public.profiles (id) on delete set null,

  constraint dva_period_valid check (
    unassigned_at is null or unassigned_at > assigned_at
  )
);

comment on table public.driver_vehicle_assignments is
  'Periodos de asignacion. unassigned_at nulo significa asignacion vigente.';

-- Las dos restricciones que impiden el caos operativo. Indices unicos parciales:
-- solo se aplican a las filas sin fecha de fin, es decir, a las asignaciones
-- vigentes. El historial puede contener tantas filas cerradas como haga falta.
--
-- Sin la primera, un conductor podria figurar operando dos unidades a la vez.
-- Sin la segunda, dos conductores podrian aparecer al volante del mismo
-- motorraton, y un pasajero recibiria datos de un vehiculo que no es el que
-- viene por el.
create unique index dva_one_active_per_driver
  on public.driver_vehicle_assignments (driver_id)
  where unassigned_at is null;

create unique index dva_one_active_per_vehicle
  on public.driver_vehicle_assignments (vehicle_id)
  where unassigned_at is null;

alter table public.driver_vehicle_assignments enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: document_types
-- -----------------------------------------------------------------------------

-- DECISION D13: los tipos de documento son datos, no codigo. Anadir el SOAT o la
-- tecnomecanica el dia de manana sera insertar una fila desde el panel, no una
-- migracion ni un despliegue.
create table public.document_types (
  id uuid primary key default gen_random_uuid(),

  code text not null
    constraint document_types_code_format check (code ~ '^[a-z0-9_]{2,40}$'),
  name text not null,

  owner public.document_owner not null,
  requires_expiry boolean not null default false,
  is_active boolean not null default true,
  sort_order smallint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint document_types_code_key unique (code),

  -- Necesaria para la clave foranea compuesta de documents, mas abajo.
  constraint document_types_id_owner_key unique (id, owner)
);

comment on table public.document_types is
  'Catalogo editable de tipos de documento. Se amplia sin migraciones.';

create trigger document_types_set_updated_at
  before update on public.document_types
  for each row execute function public.set_updated_at();

alter table public.document_types enable row level security;

-- Los dos tipos con los que arranca el MVP, segun lo acordado en la Fase 0.
insert into public.document_types (code, name, owner, requires_expiry, sort_order)
values
  ('identity_document', 'Documento de identidad', 'driver', false, 10),
  ('vehicle_registration', 'Matricula del vehiculo', 'vehicle', false, 20);


-- -----------------------------------------------------------------------------
-- Tabla: documents
-- -----------------------------------------------------------------------------

create table public.documents (
  id uuid primary key default gen_random_uuid(),

  document_type_id uuid not null,

  -- Duplica el propietario del tipo para poder validarlo sin disparadores.
  -- Ver la clave foranea compuesta mas abajo.
  owner public.document_owner not null,

  driver_id uuid references public.drivers (id) on delete cascade,
  vehicle_id uuid references public.vehicles (id) on delete cascade,

  -- Ruta dentro de Supabase Storage. El archivo no se guarda en la base de datos.
  file_path text not null
    constraint documents_file_path_not_blank check (length(trim(file_path)) > 0),

  issued_at date,
  expires_at date,
  uploaded_by uuid references public.profiles (id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Un documento pertenece a un conductor o a un vehiculo, nunca a los dos ni a
  -- ninguno, y el campo rellenado tiene que corresponder con el tipo declarado.
  constraint documents_owner_target check (
    (owner = 'driver' and driver_id is not null and vehicle_id is null)
    or
    (owner = 'vehicle' and vehicle_id is not null and driver_id is null)
  ),

  -- Impide adjuntar un documento de conductor a un vehiculo. Una restriccion de
  -- verificacion no puede consultar otra tabla, pero una clave foranea
  -- compuesta si: al referenciar (id, owner) del catalogo, la base de datos
  -- exige que el propietario declarado aqui coincida con el del tipo.
  -- Declarativo, sin disparadores.
  constraint documents_type_matches_owner
    foreign key (document_type_id, owner)
    references public.document_types (id, owner)
    on delete restrict,

  constraint documents_dates_valid check (
    expires_at is null or issued_at is null or expires_at > issued_at
  )
);

comment on table public.documents is
  'Documentacion de conductores y vehiculos. El archivo vive en Storage.';
comment on constraint documents_type_matches_owner on public.documents is
  'Clave foranea compuesta: garantiza que el tipo de documento corresponde al propietario.';

create index documents_driver_idx on public.documents (driver_id)
  where driver_id is not null;
create index documents_vehicle_idx on public.documents (vehicle_id)
  where vehicle_id is not null;

-- Sostiene el aviso de vencimientos proximos en el panel administrativo.
create index documents_expiring_idx on public.documents (expires_at)
  where expires_at is not null;

create trigger documents_set_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();

alter table public.documents enable row level security;
