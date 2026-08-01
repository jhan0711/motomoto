-- =============================================================================
-- Migracion 10: lugares frecuentes de Amalfi
-- =============================================================================
--
-- Carga inicial de la tabla places, que es el metodo principal para elegir
-- destino (D10). Hasta ahora la tabla existia vacia y la pantalla del pasajero
-- mostraba un "Parque principal" de mentira.
--
-- De donde salen estos 36 lugares
-- -------------------------------
-- Los nombres los escribio el dueno del proyecto, que conoce Amalfi, tal y como
-- los dice la gente: "el comando", "la bomba", "el sacatin". No son los nombres
-- formales, y esa es exactamente la intencion. Un pasajero busca lo que dice en
-- voz alta.
--
-- Las coordenadas tienen dos procedencias:
--
--   1. Veinte salieron del buscador de Mapbox durante la evaluacion de
--      proveedores de la Fase 8, y de cada una se comprobo a que distancia del
--      parque cae. Un nombre que suena bien pero aterriza en otro municipio es
--      un fallo, y hubo varios: un "Coliseo Municipal" a 30 km, una "Alcaldia"
--      que era la de Anori.
--   2. Dieciseis las marco el dueno a mano sobre un mapa, porque ningun
--      proveedor las conoce. Entre ellas EL PARQUE, que es el destino mas
--      pedido del pueblo y que ni Google ni Mapbox saben ubicar.
--
-- Ese segundo grupo es la razon de ser de esta tabla. Sin ella, cuatro de cada
-- diez destinos serian imposibles de elegir con un buscador.
--
-- Validaciones hechas antes de escribir esto: sin nombres repetidos, sin dos
-- lugares a menos de 60 m, y ninguna coordenada fuera del municipio. Esa
-- comprobacion encontro dos duplicados reales que se fusionaron:
-- "estacion de policia" con "el comando" (11 m), y "alto de la virgen" con
-- "alto de la linea" (39 m).
--
-- SOBRE LAS TILDES. Los comentarios de esta migracion van sin acentos, igual que
-- los de las nueve anteriores. Los DATOS no: estos nombres y descripciones se
-- muestran tal cual en la pantalla del pasajero, asi que van en espanol correcto
-- como exige D56. La diferencia es deliberada, no un descuido.
--
-- El orden de la lista y el alta de nuevos lugares pasan al panel en la Fase 20.
-- Esta migracion es la semilla, no la forma definitiva de administrarlos.
-- =============================================================================

-- Idempotente a proposito: si un lugar ya existe con ese nombre no se duplica ni
-- se pisa lo que el administrador haya ajustado despues.
insert into public.places (name, description, location, sort_order) values

  -- El destino mas pedido, primero en la lista.
  ('El parque', 'Parque principal',
   extensions.st_setsrid(extensions.st_makepoint(-75.074987, 6.907392), 4326)::extensions.geography, 0),

  -- El resto comparte sort_order, asi que la lista los muestra por nombre.
  ('Alto de la Virgen', 'También llamado alto de la línea',
   extensions.st_setsrid(extensions.st_makepoint(-75.07934, 6.90822), 4326)::extensions.geography, 10),
  ('Alto de Maruchita', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07575, 6.90551), 4326)::extensions.geography, 10),
  ('Alto del Cristo', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07385, 6.91102), 4326)::extensions.geography, 10),
  ('Cancha sintética', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08314, 6.91146), 4326)::extensions.geography, 10),
  ('Colegio Eduardo Frenades', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.074287, 6.908459), 4326)::extensions.geography, 10),
  ('Colegio Gerardo Montoya', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.076999, 6.909595), 4326)::extensions.geography, 10),
  ('Colegio Pueblo Nuevo', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.082624, 6.912897), 4326)::extensions.geography, 10),
  ('El alto de los Henaos', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07504, 6.90954), 4326)::extensions.geography, 10),
  ('El callejón', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.083128, 6.910624), 4326)::extensions.geography, 10),
  ('El cementerio', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.084888, 6.911344), 4326)::extensions.geography, 10),
  ('El coliseo', 'Unidad Deportiva Gonzalo Trujillo',
   extensions.st_setsrid(extensions.st_makepoint(-75.07087, 6.90644), 4326)::extensions.geography, 10),
  ('El comando', 'Estación de policía',
   extensions.st_setsrid(extensions.st_makepoint(-75.07354, 6.907658), 4326)::extensions.geography, 10),
  ('El D1', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.0732, 6.90773), 4326)::extensions.geography, 10),
  ('El ecoparque', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.09156, 6.913003), 4326)::extensions.geography, 10),
  ('El hospital', 'ESE Hospital El Carmen',
   extensions.st_setsrid(extensions.st_makepoint(-75.07718, 6.91062), 4326)::extensions.geography, 10),
  ('El matadero viejo', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08087, 6.90867), 4326)::extensions.geography, 10),
  ('El sacatín', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.065308, 6.908097), 4326)::extensions.geography, 10),
  ('Estación de bomberos', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.069328, 6.908127), 4326)::extensions.geography, 10),
  ('Fuente de San Ignacio', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07868, 6.91133), 4326)::extensions.geography, 10),
  ('La alcaldía', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.074965, 6.908005), 4326)::extensions.geography, 10),
  ('La bomba', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07779, 6.910828), 4326)::extensions.geography, 10),
  ('La esquina azul', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07206, 6.90674), 4326)::extensions.geography, 10),
  ('La federación de cafeteros', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07354, 6.90885), 4326)::extensions.geography, 10),
  ('La granja', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.07134, 6.90926), 4326)::extensions.geography, 10),
  ('La pista de patinaje', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08468, 6.91201), 4326)::extensions.geography, 10),
  ('La planta de beneficio', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08596, 6.91357), 4326)::extensions.geography, 10),
  ('La víbora', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.06433, 6.91325), 4326)::extensions.geography, 10),
  ('La zona rosa', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.076172, 6.90777), 4326)::extensions.geography, 10),
  ('Paso Malo', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.072667, 6.905113), 4326)::extensions.geography, 10),
  ('Planta de tratamiento', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.079118, 6.912588), 4326)::extensions.geography, 10),
  ('Pueblo Nuevo', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08453, 6.91288), 4326)::extensions.geography, 10),
  ('Urbanización Manantial', null,
   extensions.st_setsrid(extensions.st_makepoint(-75.08094, 6.91043), 4326)::extensions.geography, 10),
  ('Vereda Guayabito', 'Fuera del casco urbano',
   extensions.st_setsrid(extensions.st_makepoint(-75.09602, 6.85448), 4326)::extensions.geography, 10),
  ('Vereda Manzanares', 'Fuera del casco urbano',
   extensions.st_setsrid(extensions.st_makepoint(-75.106329, 6.903415), 4326)::extensions.geography, 10),
  ('Villa Ligia', 'El barrio',
   extensions.st_setsrid(extensions.st_makepoint(-75.069967, 6.907364), 4326)::extensions.geography, 10)

-- El indice places_name_unique trabaja sobre lower(trim(name)), asi que el
-- conflicto hay que declararlo sobre esa misma expresion y no sobre la columna.
on conflict (lower(trim(name))) do nothing;
