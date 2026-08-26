-- =============================================================================
-- Bloque especial, paso 1: las tarifas
-- =============================================================================
--
-- Cierra el requisito 3 del encargo del 2026-08-25: las tarifas no pueden estar
-- escritas en el codigo. Aqui se crean las tres tablas que las guardan y se
-- cargan los valores iniciales que dio la empresa.
--
-- ESTA MIGRACION NO CALCULA NADA. Solo guarda precios. El calculo del valor de
-- un servicio, que es donde estas tres tablas se cruzan, viene despues y en su
-- propia migracion. Se separan a proposito: un error en una tabla de precios se
-- corrige con un UPDATE, y un error en la formula se corrige reescribiendo una
-- funcion. Mezclarlos obligaria a revisar las dos cosas a la vez.
--
-- POR QUE NO SIRVE `app_settings`. Ya existe y guarda parametros operativos,
-- asi que la primera idea fue meter las tarifas ahi. No vale: es clave/valor
-- jsonb, sin activo/inactivo y sin forma de decir "este destino ya no se
-- atiende". Las 36 tarifas rurales tampoco caben en una fila sin convertirse en
-- un documento que nadie puede consultar por partes. Lo que si sigue en
-- `app_settings` son los parametros de la franja nocturna, al final del archivo,
-- porque eso si es un parametro operativo y no un precio.
--
-- LA MONEDA SON PESOS ENTEROS. Sin decimales y sin tipo numeric. En Colombia
-- nadie cobra centavos de peso, y un entero no admite el error de redondeo que
-- un decimal si permite. El techo de 1.000.000 es defensivo, del mismo tipo que
-- el limite de 10 pasajeros de la migracion 4: el valor real mas alto que dio la
-- empresa es 100.000, y un cero de mas escrito en el panel deberia rebotar aqui
-- y no aparecer en la pantalla de un pasajero.
--
-- LA TRAZABILIDAD NO ESTRENA TABLA. Ya existe `admin_audit_logs` con actor,
-- entidad, estado anterior y estado posterior. Cada tabla de aqui lleva ademas
-- `updated_at` y `updated_by` para la pregunta rapida de quien la toco la ultima
-- vez. El registro historico completo lo escribe el panel en la tabla que ya
-- hay, en la Fase 20. Crear una segunda auditoria en paralelo seria justo lo que
-- el encargo prohibe.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Tabla: urban_fares
-- -----------------------------------------------------------------------------

-- La tarifa dentro del municipio. Depende de dos cosas y de nada mas: cuantos
-- van y si es de noche.
--
-- SIN COLUMNA `is_active`, al reves que las otras dos tablas de este archivo, y
-- es deliberado. Desactivar un tipo de carga o un destino rural significa algo:
-- "esto ya no se ofrece". Desactivar "dos pasajeros de noche" no significa nada,
-- deja un hueco en una rejilla que tiene que estar completa, y el resultado
-- seria un servicio sin precio a las once de la noche. La empresa cambia estos
-- importes; no los apaga.
create table public.urban_fares (
  -- Clave compuesta y no un id sintetico: la rejilla ES la clave. Con esto no
  -- pueden existir dos precios para tres pasajeros de noche, que es el error que
  -- un id autogenerado dejaria entrar sin protestar.
  passenger_count smallint not null
    constraint uf_passenger_count_range check (passenger_count between 1 and 10),

  -- Cierto para la franja nocturna. Los valores nocturnos SUSTITUYEN a los
  -- diurnos, no se suman a ellos: de noche un pasajero paga 7.000, no 4.000 mas
  -- 7.000. Confirmado con el usuario el 2026-08-25.
  is_night boolean not null,

  amount integer not null
    constraint uf_amount_range check (amount > 0 and amount <= 1000000),

  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null,

  constraint urban_fares_pkey primary key (passenger_count, is_night)
);

comment on table public.urban_fares is
  'Tarifa dentro del municipio, por cantidad de pasajeros y franja horaria.';
comment on column public.urban_fares.is_night is
  'La fila nocturna sustituye a la diurna, no se suma a ella.';

create trigger urban_fares_set_updated_at
  before update on public.urban_fares
  for each row execute function public.set_updated_at();

alter table public.urban_fares enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: rural_fares
-- -----------------------------------------------------------------------------

-- El precio fijo de un destino de las afueras.
--
-- AQUI ES DONDE SE DECIDE QUE ES RURAL. No hay poligono urbano ni radio desde el
-- parque: un destino es rural si y solo si tiene fila activa en esta tabla. La
-- alternativa era dibujar un perimetro urbano, y se descarto con un dato: de los
-- 36 lugares que ya estan en `places`, 34 caen a menos de 2 km del parque, o sea
-- que la lista actual es practicamente toda urbana y el perimetro no separaria
-- nada que la empresa no haya separado ya al poner precio. Decidido con el
-- usuario el 2026-08-25.
--
-- SE COBRA PLANA, sin importar cuantos van. Tres personas a Montanita pagan
-- 15.000 entre todas y no 15.000 cada una. Por eso esta tabla no tiene columna
-- de cantidad de pasajeros y `urban_fares` si.
--
-- Y NO TIENE FRANJA NOCTURNA. La empresa entrego valores nocturnos de uno, dos y
-- tres pasajeros, que es la forma de la tarifa urbana; para los destinos rurales
-- no dio ninguno. Un destino rural cuesta lo mismo a las tres de la tarde que a
-- medianoche. Si algun dia cambia, se anade columna y se rellena; hoy inventar
-- un recargo seria inventar un precio.
create table public.rural_fares (
  -- El destino es la clave. Una fila por lugar, y ninguna posibilidad de que un
  -- sitio tenga dos precios distintos.
  --
  -- `on delete restrict` y no `set null` ni `cascade`. Si alguien borrara del
  -- panel un lugar con tarifa rural, el destino pasaria a cobrar tarifa urbana
  -- en silencio: 4.000 por un viaje de 100.000. Que la base lo impida obliga a
  -- quitar el precio antes, que es una decision consciente.
  place_id uuid primary key references public.places (id) on delete restrict,

  amount integer not null
    constraint rf_amount_range check (amount > 0 and amount <= 1000000),

  -- Aqui si tiene sentido: un destino que la empresa deja de atender se apaga y
  -- vuelve a cobrar tarifa urbana, sin perder el precio que tenia por si se
  -- reactiva. Borrar la fila perderia ese dato.
  is_active boolean not null default true,

  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

comment on table public.rural_fares is
  'Precio fijo de un destino de las afueras. Tener fila activa aqui es lo que hace rural a un destino.';
comment on column public.rural_fares.amount is
  'Se cobra por servicio, no por pasajero.';

-- Las 36 filas se cargan en la migracion siguiente, cuando esten las
-- coordenadas de los destinos que todavia no existen en `places`. De los 36
-- destinos que dio la empresa, solo uno coincide de nombre con un lugar ya
-- cargado, y esa coincidencia esta en duda: "La Vibora" se cobra a 10.800 y "La
-- vibora" de `places` esta a 1,34 km del parque. Pendiente de confirmar con la
-- empresa.

create trigger rural_fares_set_updated_at
  before update on public.rural_fares
  for each row execute function public.set_updated_at();

alter table public.rural_fares enable row level security;


-- -----------------------------------------------------------------------------
-- Tabla: cargo_types
-- -----------------------------------------------------------------------------

-- Los tipos de carga que la empresa transporta, con su precio.
--
-- NINGUNO OCUPA PUESTO, y por eso no hay columna que lo diga. Se llego a
-- proponer una: si la carga fuera delicada iria dentro del motorraton y quitaria
-- un asiento. El usuario lo aclaro el 2026-08-25: los seis tipos van en la
-- parrilla de arriba o en los huecos de adelante y de atras, asi que ninguno
-- quita puesto. Una columna que valiera cero en las seis filas y que ningun
-- codigo consultara seria terreno preparado para un caso que no existe.
--
-- Un mismo servicio puede llevar varias cargas, incluso de tipos distintos. Esa
-- lista es una tabla aparte y va en la migracion del tipo de servicio, no aqui:
-- esta tabla es el catalogo de precios, no lo que lleva cada viaje.
create table public.cargo_types (
  id uuid primary key default gen_random_uuid(),

  name text not null
    constraint cargo_types_name_length check (length(trim(name)) between 2 and 60),

  amount integer not null
    constraint ct_amount_range check (amount > 0 and amount <= 1000000),

  is_active boolean not null default true,

  -- Mismo criterio que en `places`: el orden de la lista lo fija la empresa, no
  -- el alfabeto ni la fecha de creacion.
  sort_order smallint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

comment on table public.cargo_types is
  'Catalogo de tipos de carga con su precio. Ninguno ocupa puesto en el motorraton.';

-- Sobre el nombre normalizado, igual que en `places`. Impide que el
-- administrador de de alta "Bulto de cafe" dos veces con precios distintos.
--
-- Arrastra el hallazgo H10, y queda dicho: normaliza mayusculas y espacios de
-- los extremos, pero no los del medio. "Caja  grande" con dos espacios entraria
-- como un tipo distinto. Importara cuando el panel permita crearlos (Fase 20),
-- que es exactamente lo que ya dice H10 de `places`.
create unique index cargo_types_name_unique on public.cargo_types (lower(trim(name)));

create index cargo_types_active_idx on public.cargo_types (sort_order, name) where is_active;

create trigger cargo_types_set_updated_at
  before update on public.cargo_types
  for each row execute function public.set_updated_at();

alter table public.cargo_types enable row level security;


-- -----------------------------------------------------------------------------
-- Politicas
-- -----------------------------------------------------------------------------

-- Las tres se leen desde la aplicacion y se escriben solo desde el panel.
--
-- Lectura abierta a cualquier autenticado, con el mismo criterio que
-- `app_settings` y `places`: un precio no es un secreto, es justo lo que el
-- pasajero tiene que ver antes de confirmar (D217). Lo que si esta cerrado es
-- escribirlos.
--
-- SIN POLITICA PARA `anon`. Nadie sin sesion tiene por que leer el tarifario.

create policy "urban_fares_select_authenticated"
  on public.urban_fares for select to authenticated
  using (true);

create policy "urban_fares_all_admin"
  on public.urban_fares for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Los inactivos solo los ve el administrador, igual que en `places`. Para el
-- pasajero un destino desactivado no existe, y ensenarle un precio que no se le
-- va a aplicar seria peor que no ensenarle nada.
create policy "rural_fares_select_active"
  on public.rural_fares for select to authenticated
  using (is_active or public.is_admin());

create policy "rural_fares_all_admin"
  on public.rural_fares for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "cargo_types_select_active"
  on public.cargo_types for select to authenticated
  using (is_active or public.is_admin());

create policy "cargo_types_all_admin"
  on public.cargo_types for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- -----------------------------------------------------------------------------
-- Valores iniciales: la tarifa urbana
-- -----------------------------------------------------------------------------

-- Los seis valores que dio la empresa. Son un punto de partida, no una verdad
-- del software: el dia que suban, se cambia un numero desde el panel y la
-- aplicacion se entera sola.
--
-- La rejilla llega hasta tres porque `max_passengers_per_request` vale tres. Si
-- alguien sube ese parametro sin anadir aqui las filas que faltan, el calculo no
-- encontrara tarifa. Eso NO se resuelve con un valor por defecto: cobrar cero, o
-- cobrar lo de tres personas a cuatro, seria un numero inventado en la pantalla
-- de un pasajero. La funcion de calculo tendra que fallar con un mensaje claro,
-- y queda anotado aqui para quien escriba esa funcion.
insert into public.urban_fares (passenger_count, is_night, amount) values
  (1, false, 4000),
  (2, false, 6200),
  (3, false, 8500),
  (1, true, 7000),
  (2, true, 12000),
  (3, true, 17000);


-- -----------------------------------------------------------------------------
-- Valores iniciales: los tipos de carga
-- -----------------------------------------------------------------------------

-- Las tarifas de carga 2026 que entrego la empresa.
--
-- Los nombres van con tilde: los ve el pasajero, y D56 pide espanol correcto en
-- lo que se muestra. Es dato de una tabla, no un mensaje de funcion, asi que no
-- le aplica H8.
insert into public.cargo_types (name, amount, sort_order) values
  ('Caja pequeña', 1700, 10),
  ('Caja grande', 2800, 20),
  ('Bicicleta', 2300, 30),
  ('Bulto de cemento', 2800, 40),
  ('Bulto de café', 4900, 50),
  ('Domicilios y encomiendas', 3800, 60);


-- -----------------------------------------------------------------------------
-- La franja nocturna, en app_settings
-- -----------------------------------------------------------------------------

-- Esto si es un parametro operativo y no un precio, asi que va donde ya viven
-- los otros nueve y no en una tabla nueva.
--
-- LA ZONA HORARIA ES EL DATO QUE FALTABA. Hoy ninguna migracion del proyecto
-- menciona zonas horarias y el servidor trabaja en UTC. Las diez de la noche en
-- Amalfi son las tres de la madrugada UTC del dia siguiente: sin esta linea, el
-- recargo nocturno entraria a las cinco de la tarde. Colombia no tiene horario
-- de verano, asi que la conversion es fija.
--
-- La franja se guarda como dos horas enteras y no como un rango de tiempo
-- porque es lo que la empresa dijo, "de diez de la noche a cinco de la manana",
-- y porque una hora entera es lo que un administrador puede cambiar sin
-- equivocarse. Que el inicio sea mayor que el fin es normal y no es un error:
-- significa que la franja cruza la medianoche.
insert into public.app_settings (key, value, description) values
  ('fare_timezone', '"America/Bogota"',
   'Zona horaria con la que se decide la franja nocturna. El servidor va en UTC.'),
  ('night_fare_start_hour', '22',
   'Hora local a la que empieza la tarifa nocturna urbana.'),
  ('night_fare_end_hour', '5',
   'Hora local a la que termina la tarifa nocturna urbana. La franja cruza la medianoche.');
