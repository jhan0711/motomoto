-- =============================================================================
-- Migracion 3: geografia
-- =============================================================================
--
-- Lugares frecuentes del municipio y posicion actual de cada conductor.
--
-- El recorrido historico de los viajes (ride_locations) no esta aqui: depende de
-- la tabla rides, que se crea en la migracion 4. Va con ella.
--
-- Los tipos geograficos se escriben cualificados como extensions.geography
-- porque PostGIS esta instalado en el esquema extensions. Asi no dependen de
-- como quede configurado el search_path de cada rol.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: places
-- -----------------------------------------------------------------------------

-- DECISION D10. En Amalfi la gente no se ubica por nomenclatura de calles: dice
-- "el parque", "el hospital", "la subida al colegio". Esta lista curada por la
-- empresa es el metodo principal para elegir destino, por delante del buscador
-- de direcciones.
create table public.places (
  id uuid primary key default gen_random_uuid(),

  name text not null
    constraint places_name_length check (length(trim(name)) between 2 and 120),
  description text,

  -- SRID 4326 es el sistema de coordenadas de GPS: latitud y longitud sobre el
  -- elipsoide WGS84. El tipo geography, y no geometry, hace que las distancias
  -- salgan en metros reales sobre la superficie terrestre y no en grados.
  location extensions.geography(Point, 4326) not null,

  is_active boolean not null default true,
  sort_order smallint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.places is
  'Lugares frecuentes del municipio, gestionados por la empresa desde el panel.';

-- Impide que el administrador de de alta "Parque principal" dos veces por
-- descuido. Sobre el nombre normalizado, para que "PARQUE PRINCIPAL" tampoco
-- pase.
create unique index places_name_unique on public.places (lower(trim(name)));

-- Indice espacial. Lo usa cualquier consulta que ordene o filtre por cercania.
create index places_location_idx on public.places using gist (location);

-- La lista que ve el pasajero: solo activos, en el orden que fija la empresa.
create index places_active_idx on public.places (sort_order, name) where is_active;

create trigger places_set_updated_at
  before update on public.places
  for each row execute function public.set_updated_at();

alter table public.places enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: driver_locations
-- -----------------------------------------------------------------------------

-- DECISION D14, primera mitad: la posicion actual.
--
-- La clave primaria es el conductor, asi que hay como maximo una fila por
-- conductor y las actualizaciones la sobrescriben. Esta tabla no crece nunca.
--
-- Por que importa: con 30 conductores enviando posicion cada 30 segundos durante
-- 12 horas, insertar en lugar de sobrescribir generaria unas 43.000 filas al dia
-- de datos que a nadie le interesan. El recorrido que si interesa se guarda
-- aparte, y solo durante un viaje activo.
create table public.driver_locations (
  driver_id uuid primary key references public.drivers (id) on delete cascade,

  location extensions.geography(Point, 4326) not null,

  -- Rumbo en grados. Permite orientar el marcador del vehiculo en el mapa en
  -- lugar de mostrarlo siempre mirando al norte.
  heading numeric(5, 2)
    constraint driver_locations_heading_range check (heading is null or heading between 0 and 360),

  speed_kmh numeric(5, 2)
    constraint driver_locations_speed_positive check (speed_kmh is null or speed_kmh >= 0),

  -- Precision declarada por el GPS, en metros. Sirve para descartar posiciones
  -- poco fiables: en zona montanosa como Amalfi es habitual recibir lecturas con
  -- cientos de metros de error.
  accuracy_m numeric(7, 2)
    constraint driver_locations_accuracy_positive check (accuracy_m is null or accuracy_m >= 0),

  updated_at timestamptz not null default now()
);

comment on table public.driver_locations is
  'Una fila por conductor, sobrescrita. Posicion actual, no historial.';
comment on column public.driver_locations.updated_at is
  'Antiguedad de la lectura. Una posicion vieja equivale a un conductor sin cobertura.';

create index driver_locations_geo_idx on public.driver_locations using gist (location);

-- Permite descartar rapido las posiciones caducadas al buscar conductores.
create index driver_locations_updated_idx on public.driver_locations (updated_at desc);

create trigger driver_locations_set_updated_at
  before update on public.driver_locations
  for each row execute function public.set_updated_at();

alter table public.driver_locations enable row level security;


-- -----------------------------------------------------------------------------
-- Funcion: buscar conductores disponibles
-- -----------------------------------------------------------------------------

-- La consulta central de la plataforma, y la razon por la que se eligio PostGIS.
--
-- Aplica de una sola vez todos los filtros que exige la Fase 0:
--   - el conductor esta disponible y aprobado por la empresa
--   - su cuenta no esta bloqueada
--   - tiene un vehiculo asignado vigente y ese vehiculo esta operativo
--   - la capacidad del vehiculo alcanza para el grupo (regla R11)
--   - su ultima posicion es reciente: un conductor sin cobertura no sirve
--
-- REGLA R4 revisada: no hay radio de corte. Amalfi cabe holgadamente en el radio
-- que habriamos puesto, asi que se devuelven todos los candidatos ordenados por
-- cercania y decide quien llama.
--
-- El operador <-> ordena por distancia usando el indice espacial. Sin el, cada
-- busqueda recorreria la tabla entera calculando distancias una por una.
create or replace function public.find_available_drivers(
  p_origin extensions.geography,
  p_passenger_count smallint,
  p_max_staleness interval default interval '2 minutes'
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
    and dl.updated_at > now() - p_max_staleness
  order by dl.location <-> p_origin;
$$;

comment on function public.find_available_drivers is
  'Conductores aptos para una solicitud, ordenados por cercania. Uso interno del proceso de asignacion.';

-- Es security definer, asi que ignora las politicas de seguridad de fila. Por
-- eso se le retira el permiso de ejecucion a los roles publicos: un pasajero no
-- debe poder listar toda la flota ni saber donde esta cada conductor.
--
-- La invocara el proceso de asignacion en la migracion 6, que si es accesible y
-- solo devuelve el conductor finalmente asignado.
revoke all on function public.find_available_drivers(extensions.geography, smallint, interval)
  from public, anon, authenticated;
