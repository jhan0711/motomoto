-- =============================================================================
-- Bloque especial, paso 2: tipo de servicio y carga
-- =============================================================================
--
-- Cierra los requisitos 1, 2 y 4 del encargo del 2026-08-25: la encomienda como
-- servicio independiente con su descripcion, el pasajero con carga, y que la
-- carga sea una lista y no un dato suelto (D224).
--
-- LOS TRES CASOS NO SE CONFUNDEN, que es lo que pidio la empresa con esas
-- palabras. Se distinguen con dos datos y no con tres valores de un enum:
--
--   pasajero solo          service_type = 'passenger', sin filas de carga
--   pasajero + carga       service_type = 'passenger', con filas de carga
--   encomienda sola        service_type = 'parcel',    passenger_count = 0
--
-- Un tercer valor de enum, 'passenger_with_cargo', habria sido un dato que
-- puede contradecir a otro: nada impediria guardarlo sin filas de carga, o
-- guardar 'passenger' con tres bultos. Aqui la contradiccion no cabe.
--
-- ESTA MIGRACION SIGUE SIN CALCULAR NADA. Guarda que se lleva; cuanto vale es el
-- paso siguiente. Por eso `ride_requests` no estrena todavia columna de valor.
--
-- COMPATIBILIDAD: `service_type` entra con valor por defecto 'passenger', asi
-- que las
-- solicitudes que ya existen quedan bien clasificadas y `request_ride`
-- sigue funcionando sin tocarla. Se toca en el paso siguiente, y cuando se haga
-- hay que partir de su ULTIMA version aplicada,
-- `20260811184748_pickup_reference.sql`, por lo que costo E30.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El tipo de servicio
-- -----------------------------------------------------------------------------

-- Dos valores, no tres. El razonamiento esta arriba.
create type public.service_type as enum ('passenger', 'parcel');

comment on type public.service_type is
  'Que se transporta. Con carga o sin ella es lo mismo: lo dice ride_request_cargo.';

alter table public.ride_requests
  add column service_type public.service_type not null default 'passenger';

comment on column public.ride_requests.service_type is
  'passenger: van personas, con carga o sin ella. parcel: encomienda sin nadie a bordo.';


-- -----------------------------------------------------------------------------
-- La descripcion de la encomienda
-- -----------------------------------------------------------------------------

-- "Caja con documentos", "bulto de cafe", "repuestos". El tipo de carga dice
-- cuanto cuesta; esto dice que es.
--
-- OBLIGATORIA EN LA ENCOMIENDA Y PROHIBIDA EN EL VIAJE DE PASAJEROS. El encargo
-- decia "debe permitir una descripcion", que es mas suave, y aqui se aprieta a
-- proposito: el conductor tiene que decidir si acepta llevar algo sin nadie que
-- se lo explique por el camino, y "encomienda" a secas no es informacion
-- suficiente para esa decision. Si la empresa prefiere que sea opcional, se
-- afloja quitando la primera mitad de la restriccion.
--
-- Prohibida en el viaje de pasajeros porque ahi ya esta `pickup_reference` para
-- las aclaraciones, y dos campos libres que dicen cosas parecidas acaban
-- llenandose al azar.
alter table public.ride_requests
  add column parcel_description text
    constraint rr_parcel_description_matches_service check (
      case service_type
        when 'parcel' then parcel_description is not null
                       and length(trim(parcel_description)) between 3 and 120
        when 'passenger' then parcel_description is null
      end
    );

comment on column public.ride_requests.parcel_description is
  'Que es la encomienda, en palabras del pasajero. Obligatoria si service_type es parcel.';


-- -----------------------------------------------------------------------------
-- Cero pasajeros, y solo en la encomienda
-- -----------------------------------------------------------------------------

-- La restriccion original exigia entre 1 y 10, asi que hasta hoy la base de
-- datos rechazaba una encomienda. Se sustituye en lugar de anadirle otra encima
-- para que no queden dos reglas hablando del mismo rango.
--
-- EL CERO NO SE ABRE EN GENERAL, que era la forma facil y la equivocada: un
-- viaje de pasajeros con cero pasajeros no significa nada y, peor, no ocuparia
-- asiento en `enforce_ride_capacity`, con lo que un conductor podria acumular
-- viajes fantasma sin llenar nunca el motorraton. La condicion ata el cero al
-- tipo de servicio, y de paso obliga a lo contrario: una encomienda no puede
-- llevar pasajeros, porque eso ya es un pasajero con carga.
alter table public.ride_requests
  drop constraint rr_passenger_count_range;

alter table public.ride_requests
  add constraint rr_passenger_count_matches_service check (
    case service_type
      when 'parcel' then passenger_count = 0
      when 'passenger' then passenger_count between 1 and 10
    end
  );

comment on column public.ride_requests.passenger_count is
  'Personas a bordo. Cero exactamente cuando el servicio es una encomienda.';

-- `rides` tiene la misma restriccion y hay que aflojarla igual, porque
-- `accept_ride_offer` copia aqui el valor de la solicitud.
--
-- AQUI SI QUEDA EL RANGO ABIERTO DE 0 A 10, sin atarlo al tipo de servicio, y se
-- dice por que: esta tabla no tiene la columna `service_type` y una restriccion
-- CHECK no puede mirar otra tabla. La regla de verdad vive en `ride_requests`,
-- que es donde nace el dato. Lo que si se conserva es el techo.
--
-- No afecta al reparto de asientos: `enforce_ride_capacity` suma con `sum(...)`,
-- y un cero suma cero, que es exactamente lo que tiene que pasar cuando la carga
-- va en la parrilla (D220). Comprobado en el codigo de la funcion antes de tocar
-- nada.
alter table public.rides
  drop constraint rides_passenger_count_range;

alter table public.rides
  add constraint rides_passenger_count_range check (passenger_count between 0 and 10);


-- -----------------------------------------------------------------------------
-- Tabla: ride_request_cargo
-- -----------------------------------------------------------------------------

-- Lo que lleva cada servicio. Es la tabla que hace posible "agregar otra carga"
-- (D224), tanto en el pasajero con carga como en la encomienda, y con tipos
-- distintos en el mismo viaje.
--
-- Cuelga de la solicitud y no del viaje: lo que se lleva se decide al pedir, y
-- tiene que existir antes de que ningun conductor acepte, porque es justo lo que
-- necesita saber para decidir si acepta.
create table public.ride_request_cargo (
  id uuid primary key default gen_random_uuid(),

  -- `cascade` aqui si, al reves que en casi todo el proyecto: estas filas no son
  -- historial propio, son parte de la solicitud. Una solicitud borrada no debe
  -- dejar sus bultos flotando sin dueno.
  request_id uuid not null references public.ride_requests (id) on delete cascade,

  -- `restrict` para que el panel no pueda borrar un tipo de carga que ya viajo.
  -- Para retirarlo de la lista esta `cargo_types.is_active`, que no destruye
  -- nada. Es el mismo criterio que `rural_fares` con los lugares.
  cargo_type_id uuid not null references public.cargo_types (id) on delete restrict,

  -- Cuantos bultos de ESE tipo. El limite de 20 es defensivo, del mismo tipo que
  -- el de 10 pasajeros: no es la capacidad real de un motorraton, es el techo
  -- que impide que un cero de mas convierta 2 cajas en 20.
  quantity smallint not null default 1
    constraint rrc_quantity_range check (quantity between 1 and 20),

  -- EL PRECIO CONGELADO (D225). Mismo criterio que `contact_phone` desde la Fase
  -- 5: si la empresa sube el bulto de cafe manana, este servicio tiene que
  -- seguir diciendo lo que costo hoy. Leerlo de `cargo_types` al consultar el
  -- historial haria que los servicios viejos cambiaran de precio solos.
  unit_amount integer not null
    constraint rrc_unit_amount_range check (unit_amount > 0 and unit_amount <= 1000000),

  created_at timestamptz not null default now(),

  -- Dos filas del mismo tipo en la misma solicitud son una sola fila con
  -- cantidad dos. Sin esto, "agregar otra carga" pulsado dos veces sobre el
  -- mismo tipo dejaria dos lineas que dicen lo mismo, y el dia que alguien
  -- quiera corregir la cantidad no sabria cual tocar.
  constraint rrc_one_line_per_type unique (request_id, cargo_type_id)
);

comment on table public.ride_request_cargo is
  'Lo que lleva cada solicitud. Una linea por tipo de carga, con su cantidad y su precio congelado.';
comment on column public.ride_request_cargo.unit_amount is
  'Precio por unidad en el momento de pedir. No se relee de cargo_types.';

-- La consulta natural es "que lleva esta solicitud", y sale en las pantallas del
-- pasajero, del conductor y en los dos historiales.
create index rrc_request_idx on public.ride_request_cargo (request_id);

alter table public.ride_request_cargo enable row level security;


-- -----------------------------------------------------------------------------
-- Politicas de la carga
-- -----------------------------------------------------------------------------

-- LA VE EL CONDUCTOR ANTES DE ACEPTAR, y es una diferencia deliberada con el
-- nombre y el telefono del pasajero, que desde la Fase 12 no viajan hasta que
-- acepta (D172).
--
-- El motivo es que no es lo mismo. Quien es el pasajero no cambia la decision de
-- aceptar, y por eso se guarda. Que lleve una bicicleta si la cambia: el
-- conductor tiene que poder decir que no a algo que no puede transportar. Un
-- conductor que acepta a ciegas y descubre el bulto al llegar es un servicio
-- cancelado en el sitio, que es peor para todos.
--
-- `driver_linked_to_request` cubre las dos situaciones, la oferta y el viaje ya
-- aceptado, y esta desde la Fase 5.
create policy "ride_request_cargo_select_participants"
  on public.ride_request_cargo for select to authenticated
  using (
    public.owns_request(request_id)
    or public.driver_linked_to_request(request_id)
    or public.is_admin()
  );

-- SIN POLITICA DE INSERCION, ACTUALIZACION NI BORRADO PARA NADIE, y no es un
-- olvido. Estas filas nacen dentro de `request_ride`, que es `security definer`
-- y no las evalua, en la misma transaccion que la solicitud. Dejar que el
-- telefono escriba aqui por su cuenta permitiria una solicitud con carga
-- guardada a medias, o carga anadida despues de que el conductor viera el precio
-- que acepto.
--
-- El administrador tampoco escribe: corregir la carga de un servicio ya pedido
-- no es una operacion que exista. Si algun dia hace falta, sera una funcion con
-- su regla, no una politica abierta.


-- -----------------------------------------------------------------------------
-- Lo que queda apuntado para el paso siguiente
-- -----------------------------------------------------------------------------

-- Dos reglas que este archivo NO puede garantizar, porque cruzan tablas y una
-- restriccion CHECK solo ve su propia fila. Las tendra que aplicar `request_ride`
-- y las tendran que probar sus pruebas:
--
--   1. Una encomienda necesita AL MENOS UNA linea de carga. Sin ella no habria
--      nada que transportar, y el valor caeria a la tarifa base por defecto: una
--      encomienda de contenido desconocido cobrada como si fuera minima.
--
--   2. `unit_amount` tiene que copiarse de `cargo_types.amount` en ese momento y
--      del tipo que se esta guardando. Si se copia mal, el precio congelado
--      congela un numero equivocado y ya no hay forma de saberlo.
