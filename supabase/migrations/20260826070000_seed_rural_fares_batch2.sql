-- =============================================================================
-- Bloque especial: segunda tanda de destinos rurales, cuatro nombres resueltos
-- =============================================================================
--
-- El usuario confirmo el 2026-08-26 las coordenadas que faltaban de Cañada
-- Honda (no "Cañonada", corregido antes) y Finca Posada, y resolvio los dos
-- nombres en duda de la primera tanda: La Vibora y Manzanares.
--
-- LAS DOS RESPUESTAS FUERON DISTINTAS, Y SE MIDIERON ANTES DE DECIDIR:
--
--   Manzanares    La coordenada nueva cae a 288 m de "Vereda Manzanares", que
--                 ya existe en la lista urbana desde la Fase 9. Esa distancia es
--                 ruido normal entre dos lecturas de GPS del mismo sitio, no dos
--                 sitios distintos. Se le agrega la tarifa rural AL LUGAR QUE YA
--                 EXISTE, sin crear uno nuevo. Confirmado por el usuario.
--
--   La Vibora     La coordenada nueva cae a 3.817 metros -casi 4 km- de "La
--                 víbora" que ya existe. Son dos sitios distintos con nombre
--                 parecido. El usuario decidio: la coordenada nueva se queda
--                 con el nombre "La víbora", y la urbana existente se retira de
--                 la vista del pasajero.
--
-- EL RETIRO NO ES UN BORRADO. `places_name_unique` es un indice unico SIN
-- filtro de estado -a diferencia de `places_active_idx`, que si lo tiene-, asi
-- que dos filas no pueden llamarse "la víbora" aunque una este desactivada. El
-- lugar viejo se renombra para liberar el nombre y se apaga con `is_active =
-- false`, que es el mismo patron que ya usa el proyecto para "un destino que la
-- empresa deja de atender" en `rural_fares.is_active`. Sigue en la tabla por si
-- algun dia hay que revisar un viaje antiguo que lo uso como referencia; el
-- historial de esos viajes no cambia, porque guarda el nombre como texto
-- congelado en `destination_label`, no una relacion viva.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- La víbora: se libera el nombre y entra el sitio real
-- -----------------------------------------------------------------------------

update public.places
set name = 'La víbora (registro anterior, desactivado 2026-08-26)',
    is_active = false
where name = 'La víbora';

insert into public.places (name, location, sort_order) values (
  'La víbora',
  extensions.st_setsrid(extensions.st_makepoint(-75.098667, 6.909556), 4326)::extensions.geography,
  20
);

insert into public.rural_fares (place_id, amount)
select id, 10800 from public.places where name = 'La víbora';


-- -----------------------------------------------------------------------------
-- Manzanares: tarifa sobre el lugar que ya existe, sin duplicarlo
-- -----------------------------------------------------------------------------

-- Se sube tambien a `sort_order` 20, el mismo criterio visual que los rurales de
-- la primera tanda: antes viajaba con los urbanos de la Fase 9 porque no tenia
-- tarifa, y ahora que la tiene pasa a agruparse con los suyos.
update public.places
set sort_order = 20
where name = 'Vereda Manzanares';

insert into public.rural_fares (place_id, amount)
select id, 12000 from public.places where name = 'Vereda Manzanares';


-- -----------------------------------------------------------------------------
-- Cañada Honda y Finca Posada: dos lugares nuevos, sin ambiguedad
-- -----------------------------------------------------------------------------

-- Los mas cercanos que ya existian eran Alto del Rio (219 m) y Finca Doña Lucia
-- (359 m). No es senal de duplicado: son nombres distintos con precios
-- distintos en la lista de la empresa, y la separacion tipica entre los 24
-- destinos rurales de la primera tanda ya bajaba hasta 314 m. Rural cerca de
-- rural es lo esperable en esta zona, no un error de transcripcion.

insert into public.places (name, location, sort_order) values
  ('Cañada Honda',
   extensions.st_setsrid(extensions.st_makepoint(-75.063083, 6.900000), 4326)::extensions.geography,
   20);

insert into public.rural_fares (place_id, amount)
select id, 12000 from public.places where name = 'Cañada Honda';

insert into public.places (name, location, sort_order) values
  ('Finca Posada',
   extensions.st_setsrid(extensions.st_makepoint(-75.119500, 6.892722), 4326)::extensions.geography,
   20);

insert into public.rural_fares (place_id, amount)
select id, 16000 from public.places where name = 'Finca Posada';
