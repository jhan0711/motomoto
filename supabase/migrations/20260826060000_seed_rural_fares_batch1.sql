-- =============================================================================
-- Bloque especial: primera tanda de destinos rurales, 24 de 36
-- =============================================================================
--
-- El usuario entrego `docs/destinos-rurales.csv` el 2026-08-26 con coordenadas
-- en grados/minutos/segundos. Se convirtieron a decimal y se verificaron una a
-- una contra `is_within_service_area` antes de escribir esta migracion: las 24
-- de aqui caen dentro del poligono de Amalfi.
--
-- LO QUE ESTA MIGRACION NO TRAE, y por que:
--
--   Cañada Onda y Finca Posada    Su longitud llego como "5°..." en vez de
--                                 "75°...", y eso las pone en el Atlantico. Es
--                                 casi con toda seguridad un digito perdido al
--                                 transcribir, pero una coordenada decide a
--                                 donde va un conductor real: se rechazo
--                                 corregirla sin confirmacion. Pendiente.
--
--   Otras 10                     Sin coordenada todavia: La Vibora, Manzanares,
--                                 Sorrento, Entrada a la Mina, Los Tanques, La
--                                 Mina, La Aguacatera, Cajamarca, Palmitas, La
--                                 Blanquita.
--
-- DOS NOMBRES QUE COINCIDEN CON LUGARES YA EXISTENTES SIGUEN SIN RESOLVER Y NO
-- ENTRAN AQUI TAMPOCO: "La Vibora" (posible "La víbora", a 1,34 km del parque,
-- muy cerca para 10.800) y "Manzanares" (posible "Vereda Manzanares", a 3,49
-- km, que si cuadra con sus 12.000). Estan en la lista de "sin coordenada" de
-- arriba porque el usuario tampoco las trajo en esta entrega.
--
-- CADA DESTINO ES UN LUGAR NUEVO EN `places`, no una fila que se cuelga sola de
-- `rural_fares`. Tiene que existir como lugar porque D230 compara la distancia
-- contra TODOS los lugares, no solo contra los que tienen tarifa: si Montanita
-- no fuera un lugar, nunca podria ganarle a un lugar urbano cercano cuando el
-- pasajero suelta una chincheta a su lado.
--
-- `sort_order` EN 20, DISTINTO DEL 0 Y EL 10 DE LOS LUGARES URBANOS DE LA FASE
-- 9. Eso los deja despues en cualquier lista que se ordene por `sort_order` y
-- nombre, que es una separacion visual util mientras no haya panel: un
-- administrador mirando la tabla ve primero lo urbano y despues lo rural.
-- =============================================================================

do $carga$
declare
  v_id uuid;
begin
  -- Se hace uno por uno y no con un solo INSERT masivo. Con 24 filas la
  -- diferencia de velocidad no importa, y a cambio, si algun dia una fila choca
  -- con `places_name_unique`, el mensaje de error senala la fila exacta y no dos
  -- docenas mezcladas.

  insert into public.places (name, location, sort_order) values
    ('Alto del Rio',
     extensions.st_setsrid(extensions.st_makepoint(-75.063222, 6.901972), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 10800);

  insert into public.places (name, location, sort_order) values
    ('Entrada Finca Ito',
     extensions.st_setsrid(extensions.st_makepoint(-75.115167, 6.896972), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 13000);

  insert into public.places (name, location, sort_order) values
    ('Tienda La Gurria',
     extensions.st_setsrid(extensions.st_makepoint(-75.053444, 6.913944), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 25000);

  insert into public.places (name, location, sort_order) values
    ('Finca Doña Lucia',
     extensions.st_setsrid(extensions.st_makepoint(-75.117333, 6.895139), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 14600);

  insert into public.places (name, location, sort_order) values
    ('Yolombito',
     extensions.st_setsrid(extensions.st_makepoint(-75.050806, 6.921250), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 28000);

  insert into public.places (name, location, sort_order) values
    ('Aeropuerto',
     extensions.st_setsrid(extensions.st_makepoint(-75.048889, 6.895056), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 30000);

  insert into public.places (name, location, sort_order) values
    ('Terminal Ito',
     extensions.st_setsrid(extensions.st_makepoint(-75.122806, 6.890333), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 18200);

  insert into public.places (name, location, sort_order) values
    ('La Laguna',
     extensions.st_setsrid(extensions.st_makepoint(-75.031556, 6.872750), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 32000);

  insert into public.places (name, location, sort_order) values
    ('Montañita',
     extensions.st_setsrid(extensions.st_makepoint(-75.122750, 6.903778), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 15000);

  insert into public.places (name, location, sort_order) values
    ('Escuela El Guaico',
     extensions.st_setsrid(extensions.st_makepoint(-75.137556, 6.888583), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 25000);

  insert into public.places (name, location, sort_order) values
    ('Boqueron',
     extensions.st_setsrid(extensions.st_makepoint(-74.994500, 6.861722), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 55000);

  insert into public.places (name, location, sort_order) values
    ('Caracolí',
     extensions.st_setsrid(extensions.st_makepoint(-75.134389, 6.878861), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 28000);

  insert into public.places (name, location, sort_order) values
    ('El Taparo',
     extensions.st_setsrid(extensions.st_makepoint(-75.071833, 6.894583), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 12000);

  insert into public.places (name, location, sort_order) values
    ('Alto del Oso',
     extensions.st_setsrid(extensions.st_makepoint(-75.149083, 6.878139), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 30200);

  insert into public.places (name, location, sort_order) values
    ('Morro Azul',
     extensions.st_setsrid(extensions.st_makepoint(-75.154333, 6.847833), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 36300);

  insert into public.places (name, location, sort_order) values
    ('La Guayana',
     extensions.st_setsrid(extensions.st_makepoint(-75.150250, 6.819083), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 48500);

  insert into public.places (name, location, sort_order) values
    ('Urbanización Divino Niño',
     extensions.st_setsrid(extensions.st_makepoint(-75.146083, 6.813861), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 52000);

  insert into public.places (name, location, sort_order) values
    ('El Poleo',
     extensions.st_setsrid(extensions.st_makepoint(-75.077500, 6.885389), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 28000);

  insert into public.places (name, location, sort_order) values
    ('El Mango',
     extensions.st_setsrid(extensions.st_makepoint(-75.142250, 6.810278), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 58000);

  insert into public.places (name, location, sort_order) values
    ('La Antena',
     extensions.st_setsrid(extensions.st_makepoint(-75.086361, 6.885333), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 40000);

  insert into public.places (name, location, sort_order) values
    ('Alto Peldar',
     extensions.st_setsrid(extensions.st_makepoint(-75.097167, 6.920806), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 20000);

  insert into public.places (name, location, sort_order) values
    ('Alto del Sapo',
     extensions.st_setsrid(extensions.st_makepoint(-75.098694, 6.935806), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 40000);

  insert into public.places (name, location, sort_order) values
    ('Calina',
     extensions.st_setsrid(extensions.st_makepoint(-75.093972, 6.932611), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 30000);

  insert into public.places (name, location, sort_order) values
    ('Caspete La Viborita',
     extensions.st_setsrid(extensions.st_makepoint(-75.073889, 6.932167), 4326)::extensions.geography,
     20)
  returning id into v_id;
  insert into public.rural_fares (place_id, amount) values (v_id, 50000);
end
$carga$;
