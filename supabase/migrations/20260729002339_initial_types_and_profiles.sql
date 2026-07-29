-- =============================================================================
-- Migracion 1: extensiones, tipos enumerados, perfiles
-- =============================================================================
--
-- Sienta las bases sobre las que se apoyan todas las migraciones siguientes.
-- No crea ninguna tabla de negocio salvo profiles, que es la raiz de todo:
-- conductores, viajes, calificaciones y reportes cuelgan de ella.
--
-- Convencion de los valores enumerados: minusculas con guion bajo. La
-- documentacion funcional del proyecto los escribe en mayusculas (SEARCHING) por
-- ser la notacion habitual de una maquina de estados; aqui se almacenan en
-- minusculas siguiendo la convencion de PostgreSQL y para que coincidan con el
-- codigo de la aplicacion, que ya usa 'passenger' y 'driver'.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Extensiones
-- -----------------------------------------------------------------------------

-- PostGIS. Aporta el tipo geography y, sobre todo, los indices espaciales que
-- hacen viable la consulta central de la plataforma: los conductores
-- disponibles mas cercanos a un punto.
--
-- Se instala en el esquema extensions, que es donde Supabase espera las
-- extensiones. Por eso los tipos se declararan cualificados como
-- extensions.geography: asi funcionan sin depender de como quede configurado el
-- search_path de cada rol.
create extension if not exists postgis with schema extensions;


-- -----------------------------------------------------------------------------
-- Tipos enumerados
-- -----------------------------------------------------------------------------

-- Quien es cada usuario. El rol admin existe en la base de datos pero no inicia
-- sesion en la aplicacion movil: opera desde el panel web.
create type public.user_role as enum ('passenger', 'driver', 'admin');

-- Estado de una cuenta. Bloquear en lugar de borrar conserva el historial de
-- viajes, que es informacion operativa de la empresa.
create type public.user_status as enum ('active', 'blocked');

-- Un conductor no puede operar hasta que la empresa lo aprueba.
create type public.driver_approval_status as enum ('pending', 'approved', 'blocked');

create type public.vehicle_status as enum ('active', 'maintenance', 'retired');

-- Estado de la solicitud del grupo. 'expired' esta separado de 'cancelled' a
-- proposito: "nadie acepto" y "el usuario cancelo" son hechos operativos
-- distintos, y mezclarlos impide medir la cobertura real de la flota.
create type public.ride_request_status as enum (
  'searching',
  'assigned',
  'in_progress',
  'completed',
  'cancelled',
  'expired'
);

-- Estado del viaje de un vehiculo concreto.
create type public.ride_status as enum (
  'assigned',
  'driver_on_the_way',
  'driver_arrived',
  'in_progress',
  'completed',
  'cancelled'
);

-- Quien origino una accion. Acompana siempre a una cancelacion: una cancelacion
-- sin autor no permite distinguir un problema del conductor de uno del sistema.
create type public.actor_type as enum ('passenger', 'driver', 'admin', 'system');

create type public.ride_offer_response as enum ('pending', 'accepted', 'rejected', 'expired');

create type public.report_status as enum ('open', 'in_review', 'resolved');

-- Un documento pertenece a un conductor o a un vehiculo, nunca a ambos.
create type public.document_owner as enum ('driver', 'vehicle');


-- -----------------------------------------------------------------------------
-- Funcion auxiliar: mantener updated_at
-- -----------------------------------------------------------------------------

-- Se engancha como disparador en toda tabla con updated_at. Actualizar esa
-- columna desde la aplicacion es una promesa que tarde o temprano alguien
-- incumple; hacerlo en la base de datos no admite olvidos.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Disparador generico que actualiza updated_at en cada UPDATE.';


-- -----------------------------------------------------------------------------
-- Tabla: profiles
-- -----------------------------------------------------------------------------

-- Extiende auth.users, que es la tabla de Supabase Auth y no se puede modificar.
-- La clave primaria es la misma que la del usuario autenticado, de forma que
-- ambas tablas siempre estan en correspondencia uno a uno.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,

  full_name text not null
    constraint profiles_full_name_length check (length(trim(full_name)) between 2 and 120),

  -- Nullable a proposito. En el alta por correo todavia no se conoce, y se
  -- completa en el perfil. La regla de negocio "hace falta telefono para pedir
  -- un servicio" se aplica al crear la solicitud, no aqui: un perfil a medio
  -- rellenar es un estado legitimo, una solicitud sin telefono de contacto no.
  phone text
    constraint profiles_phone_format check (phone is null or phone ~ '^[0-9+() -]{7,20}$'),

  avatar_url text,

  role public.user_role not null default 'passenger',
  status public.user_status not null default 'active',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Datos comunes de todo usuario. Extiende auth.users con rol y estado.';
comment on column public.profiles.phone is
  'Como se coordinan conductor y pasajero. Obligatorio antes de solicitar un servicio.';

-- Los administradores filtran usuarios por rol y por estado desde el panel.
create index profiles_role_idx on public.profiles (role);
create index profiles_status_idx on public.profiles (status) where status = 'blocked';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Seguridad a nivel de fila activada desde el momento de la creacion. Sin
-- politicas, esto significa que nadie accede. Las politicas llegan en la
-- migracion 6; hasta entonces el estado seguro es el estado por defecto.
alter table public.profiles enable row level security;


-- -----------------------------------------------------------------------------
-- Creacion automatica del perfil al registrarse
-- -----------------------------------------------------------------------------

-- Supabase Auth inserta en auth.users cuando alguien se registra. Este
-- disparador crea su fila en profiles en la misma transaccion.
--
-- Hacerlo aqui y no desde la aplicacion evita el caso, nada teorico, de un
-- usuario que existe en auth.users pero no tiene perfil porque la app perdio la
-- conexion justo despues del registro. Ese usuario quedaria en un limbo del que
-- no se puede salir.
--
-- security definer es necesario porque el rol que ejecuta el registro no tiene
-- permiso de escritura sobre profiles. set search_path es obligatorio en toda
-- funcion security definer: sin el, un esquema malicioso en el search_path del
-- invocante podria suplantar las tablas que la funcion usa.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Usuario'),
    nullif(trim(new.raw_user_meta_data ->> 'phone'), '')
  );
  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Crea el perfil en la misma transaccion que el registro, para que no exista un usuario sin perfil.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
