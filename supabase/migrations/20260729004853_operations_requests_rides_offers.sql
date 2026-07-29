-- =============================================================================
-- Migracion 4: operacion
-- =============================================================================
--
-- El nucleo del sistema. Solicitudes, viajes, ofertas a conductores y recorrido.
--
-- Aqui se materializan como estructura varias situaciones que la Fase 0 marco
-- como criticas, entre ellas la mas dificil de todas: dos conductores aceptando
-- la misma solicitud en el mismo instante.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: ride_requests
-- -----------------------------------------------------------------------------

-- La solicitud del grupo. Separada del viaje concreto (decision D5), que es lo
-- que permitira mas adelante repartir un grupo de cinco personas entre dos
-- motorratones sin rehacer la logica existente.
create table public.ride_requests (
  id uuid primary key default gen_random_uuid(),

  -- restrict, no cascade: borrar un pasajero no debe borrar el historial
  -- operativo de la empresa. Para dar de baja a alguien esta el estado blocked.
  passenger_id uuid not null references public.profiles (id) on delete restrict,

  status public.ride_request_status not null default 'searching',

  -- REGLA R11. El limite duro de 10 es defensivo. El maximo real, 3, es
  -- configurable y se aplica al crear la solicitud, no aqui: si estuviera fijado
  -- en el esquema, cambiarlo exigiria una migracion.
  passenger_count smallint not null
    constraint rr_passenger_count_range check (passenger_count between 1 and 10),

  origin extensions.geography(Point, 4326) not null,
  origin_label text not null
    constraint rr_origin_label_not_blank check (length(trim(origin_label)) > 0),
  origin_place_id uuid references public.places (id) on delete set null,

  destination extensions.geography(Point, 4326) not null,
  destination_label text not null
    constraint rr_destination_label_not_blank check (length(trim(destination_label)) > 0),
  destination_place_id uuid references public.places (id) on delete set null,

  -- Telefono congelado en el momento de la solicitud, no leido del perfil.
  --
  -- Dos motivos. Uno: si el pasajero cambia de numero manana, el registro del
  -- viaje debe conservar el que era valido entonces. Dos: esta columna es donde
  -- se hace efectiva la obligatoriedad del telefono, que en profiles admite nulo
  -- porque un perfil recien creado todavia no lo tiene.
  contact_phone text not null
    constraint rr_contact_phone_format check (contact_phone ~ '^[0-9+() -]{7,20}$'),

  requested_at timestamptz not null default now(),

  -- REGLA R1: la solicitud caduca si nadie acepta.
  expires_at timestamptz not null,

  assigned_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,

  cancelled_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Una cancelacion sin autor no permite distinguir un abandono del pasajero de
  -- un fallo del sistema, y esa distincion es justo la que necesita la empresa
  -- para decidir si hay un problema con la flota.
  constraint rr_cancelled_needs_actor check (
    cancelled_at is null or cancelled_by is not null
  ),
  constraint rr_cancelled_status_matches check (
    (status = 'cancelled') = (cancelled_at is not null)
  ),
  constraint rr_expiry_after_request check (expires_at > requested_at)
);

comment on table public.ride_requests is
  'Solicitud de un grupo. Puede dar lugar a uno o varios viajes.';
comment on column public.ride_requests.contact_phone is
  'Congelado al solicitar. Aqui se hace obligatorio el telefono.';

-- REGLA R6: un pasajero solo puede tener una solicitud activa.
--
-- Indice unico parcial sobre los estados vivos. Su historial puede tener cientos
-- de solicitudes terminadas, pero solo una en curso. Sin esto, pulsar dos veces
-- el boton crearia dos solicitudes y dos conductores acudirian al mismo sitio.
create unique index rr_one_active_per_passenger
  on public.ride_requests (passenger_id)
  where status in ('searching', 'assigned', 'in_progress');

-- Sostiene el proceso que caduca las solicitudes desatendidas.
create index rr_searching_expiry_idx on public.ride_requests (expires_at)
  where status = 'searching';

create index rr_passenger_history_idx on public.ride_requests (passenger_id, requested_at desc);
create index rr_origin_geo_idx on public.ride_requests using gist (origin);

create trigger ride_requests_set_updated_at
  before update on public.ride_requests
  for each row execute function public.set_updated_at();

alter table public.ride_requests enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: rides
-- -----------------------------------------------------------------------------

-- El viaje de UN vehiculo. Hoy siempre hay uno por solicitud; la estructura
-- admite varios sin cambios.
create table public.rides (
  id uuid primary key default gen_random_uuid(),

  request_id uuid not null references public.ride_requests (id) on delete cascade,
  driver_id uuid not null references public.drivers (id) on delete restrict,
  vehicle_id uuid not null references public.vehicles (id) on delete restrict,

  status public.ride_status not null default 'assigned',

  -- Cuantas personas del grupo van en ESTE vehiculo. Con un solo motorraton
  -- coincide con el total de la solicitud; el dia que se reparta un grupo, cada
  -- viaje llevara su parte.
  passenger_count smallint not null
    constraint rides_passenger_count_range check (passenger_count between 1 and 10),

  accepted_at timestamptz not null default now(),
  driver_arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,

  cancelled_at timestamptz,
  cancelled_by public.actor_type,
  cancellation_reason text,

  -- Se calculan al finalizar, a partir del recorrido registrado.
  distance_m integer
    constraint rides_distance_positive check (distance_m is null or distance_m >= 0),
  duration_s integer
    constraint rides_duration_positive check (duration_s is null or duration_s >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint rides_cancelled_needs_actor check (
    cancelled_at is null or cancelled_by is not null
  ),

  -- La linea de tiempo tiene que ser coherente. Esta restriccion hace imposible
  -- registrar un viaje que empezo antes de que el conductor llegara, o que
  -- termino antes de empezar. No es teorico: son los estados que quedan cuando
  -- una app pierde conexion y reintenta transiciones en desorden.
  constraint rides_timeline_order check (
    (driver_arrived_at is null or driver_arrived_at >= accepted_at)
    and (started_at is null or (driver_arrived_at is not null and started_at >= driver_arrived_at))
    and (completed_at is null or (started_at is not null and completed_at >= started_at))
  )
);

comment on table public.rides is
  'Viaje de un vehiculo concreto para una solicitud.';

-- REGLA R7: un conductor no puede estar en dos viajes a la vez.
create unique index rides_one_active_per_driver
  on public.rides (driver_id)
  where status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

-- Ni un vehiculo. Son reglas distintas: un conductor podria tener asignado un
-- vehiculo y ser sustituido, y sin esta segunda restriccion la misma unidad
-- podria figurar en dos servicios simultaneos.
create unique index rides_one_active_per_vehicle
  on public.rides (vehicle_id)
  where status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

create index rides_request_idx on public.rides (request_id);
create index rides_driver_history_idx on public.rides (driver_id, accepted_at desc);

create trigger rides_set_updated_at
  before update on public.rides
  for each row execute function public.set_updated_at();

alter table public.rides enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: ride_offers
-- -----------------------------------------------------------------------------

-- A que conductores se ofrecio cada solicitud y que respondieron.
create table public.ride_offers (
  id uuid primary key default gen_random_uuid(),

  request_id uuid not null references public.ride_requests (id) on delete cascade,
  driver_id uuid not null references public.drivers (id) on delete cascade,

  offered_at timestamptz not null default now(),

  -- REGLA R2: el conductor tiene un tiempo limitado para responder.
  expires_at timestamptz not null,

  response public.ride_offer_response not null default 'pending',
  responded_at timestamptz,

  -- Distancia al punto de recogida en el momento de la oferta. Se guarda porque
  -- explica por que se le ofrecio a este conductor y no a otro, informacion util
  -- cuando haya que revisar por que un servicio tardo.
  distance_m integer,

  -- REGLA R12: a un conductor no se le vuelve a ofrecer una solicitud que ya
  -- rechazo. La restriccion de unicidad lo hace estructural: un segundo intento
  -- de ofertar no es un caso a comprobar en el codigo, es una fila que la base
  -- de datos rechaza.
  constraint ro_one_offer_per_driver unique (request_id, driver_id),

  constraint ro_response_coherence check (
    (response = 'pending') = (responded_at is null)
  ),
  constraint ro_expiry_after_offer check (expires_at > offered_at)
);

comment on table public.ride_offers is
  'Registro de ofertas. Permite no reofrecer y auditar por que tardo una asignacion.';

-- LA RESTRICCION MAS IMPORTANTE DE ESTA MIGRACION.
--
-- Situacion de la Fase 0: "Dos conductores intentan aceptar simultaneamente".
--
-- Con este indice unico parcial, solo puede existir UNA oferta aceptada por
-- solicitud. Si dos conductores pulsan aceptar en el mismo milisegundo, ambas
-- transacciones intentan marcar su oferta como aceptada y PostgreSQL deja pasar
-- exactamente una: la segunda recibe una violacion de unicidad.
--
-- No hay bloqueos que gestionar ni ventanas de tiempo que afinar. La condicion
-- de carrera no se mitiga: no puede ocurrir.
create unique index ro_one_accepted_per_request
  on public.ride_offers (request_id)
  where response = 'accepted';

-- El conductor consulta sus ofertas pendientes constantemente.
create index ro_driver_pending_idx on public.ride_offers (driver_id, offered_at desc)
  where response = 'pending';

create index ro_expiry_idx on public.ride_offers (expires_at)
  where response = 'pending';

alter table public.ride_offers enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: ride_locations
-- -----------------------------------------------------------------------------

-- DECISION D14, segunda mitad: el recorrido historico.
--
-- Solo se inserta durante un viaje activo. Es la tabla que mas filas va a
-- acumular de todo el sistema, por eso el identificador es un entero grande y no
-- un UUID: ocupa la mitad, se indexa mejor y aqui no aporta nada la opacidad de
-- un UUID.
create table public.ride_locations (
  id bigint generated always as identity primary key,

  ride_id uuid not null references public.rides (id) on delete cascade,

  location extensions.geography(Point, 4326) not null,
  recorded_at timestamptz not null default now(),

  speed_kmh numeric(5, 2)
    constraint ride_locations_speed_positive check (speed_kmh is null or speed_kmh >= 0),
  accuracy_m numeric(7, 2)
    constraint ride_locations_accuracy_positive check (accuracy_m is null or accuracy_m >= 0)
);

comment on table public.ride_locations is
  'Recorrido de un viaje. Se alimenta solo mientras el viaje esta en curso.';

-- Reconstruir el recorrido de un viaje en orden es la consulta principal.
create index ride_locations_ride_idx on public.ride_locations (ride_id, recorded_at);

alter table public.ride_locations enable row level security;
