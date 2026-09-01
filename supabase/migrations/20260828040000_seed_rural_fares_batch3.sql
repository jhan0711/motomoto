-- =============================================================================
-- LOS 8 DESTINOS RURALES QUE FALTABAN: la lista de la empresa queda completa
-- =============================================================================
--
-- **36 de 36.** Con estos ocho se cierra la lista que la empresa entrego el
-- 2026-08-25 al pedir el bloque especial de tarifas. Las coordenadas las trajo
-- el usuario el 2026-08-27, en `docs/destinos-rurales.csv`, y eran lo unico que
-- faltaba desde entonces: **el esquema no ha tenido que cambiar ni una linea**,
-- que era justo lo que se buscaba al dejarlas entrar como filas.
--
-- LO QUE SE MIDIO ANTES DE ESCRIBIR NADA, y no se dio por bueno:
--
--   - **los ocho caen dentro del area de servicio**, comprobado con
--     `is_within_service_area`, la misma que valida `request_ride`
--   - **ninguno repite nombre** con los 63 lugares que ya existen
--   - **todos estan lejos del centro** -de 1,5 a 9,6 km- asi que todos necesitan
--     tarifa propia, que es lo que D229 exige y aqui traen
--
-- LO QUE SE ENCONTRO MIDIENDO, Y SE DECIDIO CON EL USUARIO (D254). Cuatro
-- destinos de la zona de la mina quedan muy juntos y con precios muy distintos:
--
--     El Taparo ($12.000)         y Los Tanques ($17.000)        a  98 m
--     Entrada a la Mina ($15.000) y La Mina ($25.000)            a 232 m
--     El Taparo ($12.000)         y La Mina ($25.000)            a 528 m
--
-- Para comparar: la separacion minima entre los 28 ya cargados era de 219 m.
-- Esta es menos de la mitad, con el doble de diferencia de precio.
--
-- **Cuando importa y cuando no.** Si el pasajero elige el destino de la lista
-- -que es como se pide casi siempre- viaja el `place_id` y la tarifa es exacta:
-- ahi no hay ningun problema. Solo una **coordenada suelta** -"Tu ubicacion
-- actual" o una chincheta- se resuelve por D230 al lugar nombrado mas cercano, y
-- en esa zona 98 metros separan cobrar 12.000 de cobrar 17.000.
--
-- **No es un fallo del codigo ni de los datos**: la empresa tiene cuatro puntos
-- de referencia juntos en la zona de la mina, y sus precios reflejan lo lejos
-- que queda cada uno **por carretera**, no en linea recta. El usuario decidio
-- cargarlos tal cual, que es lo que respeta lo que la empresa cobra.
-- =============================================================================

do $carga$
declare
  v_place uuid;
  r record;
begin
  for r in
    select * from (values
      -- nombre, tarifa, latitud, longitud (convertidas de grados/minutos/segundos)
      ('Sorrento',          40000,  6 + 51.0/60 + 42.6/3600, -(75 +  0.0/60 +  3.5/3600)),
      ('Entrada a la Mina', 15000,  6 + 53.0/60 + 31.6/3600, -(75 +  4.0/60 +  4.3/3600)),
      ('Los Tanques',       17000,  6 + 53.0/60 + 37.3/3600, -(75 +  4.0/60 + 18.6/3600)),
      ('La Mina',           25000,  6 + 53.0/60 + 38.6/3600, -(75 +  4.0/60 +  1.5/3600)),
      ('La Aguacatera',     65000,  6 + 52.0/60 + 13.3/3600, -(75 +  5.0/60 + 43.1/3600)),
      -- La latitud de Cajamarca venia con un espacio de mas en el CSV. Se limpia
      -- aqui al convertirla: el numero es el mismo.
      ('Cajamarca',        100000,  6 + 49.0/60 + 44.6/3600, -(75 +  5.0/60 + 45.0/3600)),
      ('Palmitas',          35000,  6 + 52.0/60 + 19.4/3600, -(75 +  3.0/60 + 26.8/3600)),
      ('La Blanquita',      60000,  6 + 50.0/60 + 59.7/3600, -(75 +  3.0/60 +  8.1/3600))
    ) as t(nombre, tarifa, lat, lng)
  loop
    -- `sort_order` 20, igual que las dos tandas anteriores: separa visualmente
    -- los destinos rurales de los lugares urbanos de la Fase 9.
    insert into public.places (name, location, sort_order)
    values (
      r.nombre,
      extensions.st_setsrid(extensions.st_makepoint(r.lng, r.lat), 4326)::extensions.geography,
      20
    )
    returning id into v_place;

    -- **Tiene que ser un lugar Y una tarifa, no solo una tarifa.** D230 compara
    -- distancias contra `places` entero, asi que un destino sin fila en `places`
    -- no existiria para el redondeo.
    insert into public.rural_fares (place_id, amount)
    values (v_place, r.tarifa);
  end loop;
end
$carga$;


-- -----------------------------------------------------------------------------
-- Comprobacion: cada uno cobra lo suyo, preguntando a quien decide
-- -----------------------------------------------------------------------------
--
-- No basta con que las filas esten: se le pregunta a `quote_fare`, que es la
-- funcion que de verdad calcula lo que paga la gente. Se pregunta por el destino
-- exacto -con `place_id`- que es como llega desde la aplicacion.
select
  p.name,
  rf.amount as tarifa_cargada,
  q.total_amount as lo_que_cobra,
  q.is_rural,
  rf.amount = q.total_amount as coincide
from public.places p
join public.rural_fares rf on rf.place_id = p.id
cross join lateral public.quote_fare(
  'passenger'::public.service_type,
  1::smallint,
  (select (value #>> '{}')::double precision from public.app_settings where key='fare_center_lng'),
  (select (value #>> '{}')::double precision from public.app_settings where key='fare_center_lat'),
  extensions.st_x(p.location::extensions.geometry),
  extensions.st_y(p.location::extensions.geometry),
  null,
  p.id
) q
where p.name in ('Sorrento', 'Entrada a la Mina', 'Los Tanques', 'La Mina',
                 'La Aguacatera', 'Cajamarca', 'Palmitas', 'La Blanquita')
order by p.name;
