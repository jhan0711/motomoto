-- =============================================================================
-- Bloque especial: D234, la busqueda del punto mas cercano vuelve a comparar
-- contra TODOS los lugares, no solo los rurales
-- =============================================================================
--
-- Corrige un error del asistente en D233, encontrado por el usuario probando
-- en la tablet y en el emulador el 2026-08-26: al pedir un servicio con "Tu
-- ubicacion actual" como origen -un punto sin `place_id`, en pleno pueblo, a
-- 800 m u 1,4 km del parque- la aplicacion cobraba tarifa rural (Alto del Rio,
-- La vibora) en vez de urbana.
--
-- LA CAUSA. D230 ya habia resuelto exactamente este problema para el destino:
-- "gana el punto nombrado mas cercano, sea urbano o rural", comparando contra
-- TODOS los lugares activos. Al escribir D233, que reparte esa misma logica
-- entre origen y destino, la nueva funcion auxiliar `rural_fare_for_point` se
-- escribio comparando solo contra los lugares que YA TIENEN tarifa rural
-- (`join public.rural_fares rf on rf.place_id = pl.id`), sin mirar si algun
-- lugar urbano estaba mas cerca todavia. Eso deshizo D230 sin darse cuenta: un
-- punto sin `place_id` vuelve a buscar el rural mas cercano dentro del radio,
-- nunca lo compara contra el pueblo.
--
-- Con `place_id` -eligiendo de la lista- nunca paso: ese camino usa el lugar
-- exacto y no busca nada. Por eso las capturas de la Estacion de bomberos y El
-- callejon salian bien y solo fallaba "Tu ubicacion actual".
--
-- LA CORRECCION. Vuelve el `left join` de D230 dentro de `rural_fare_for_point`:
-- se busca el lugar activo mas cercano entre TODOS, y solo si ese lugar tiene
-- tarifa rural se devuelve. Que el mas cercano sea urbano es la respuesta
-- correcta y frecuente -"esto es urbano"-, no que no se encontro nada.
-- =============================================================================

create or replace function public.rural_fare_for_point(
  p_lng double precision,
  p_lat double precision,
  p_place_id uuid default null
)
returns table (
  amount integer,
  place_name text,
  distance_m integer
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_punto   extensions.geography;
  v_limite  double precision;
  v_cercano record;
begin
  -- El lugar exacto no se redondea a otro (D230): si tiene tarifa propia, es
  -- esa y punto. Esta parte no cambia; nunca tuvo el error.
  if p_place_id is not null then
    return query
      select rf.amount, pl.name, 0
      from public.rural_fares rf
        join public.places pl on pl.id = rf.place_id
      where rf.place_id = p_place_id
        and rf.is_active;
    return;
  end if;

  v_punto  := extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography;
  v_limite := (public.get_setting('rural_snap_max_km', '3'))::double precision;

  -- D234, restaura D230: se compara contra TODOS los lugares activos, no solo
  -- los que tienen tarifa rural. Si el mas cercano es urbano, esta funcion no
  -- devuelve fila -"urbano" es una respuesta valida-, en vez de seguir
  -- buscando hasta encontrar un rural mas lejos.
  select pl.name,
         round(extensions.st_distance(pl.location, v_punto))::integer as m,
         rf.amount
    into v_cercano
  from public.places pl
    left join public.rural_fares rf on rf.place_id = pl.id and rf.is_active
  where pl.is_active
    and extensions.st_dwithin(pl.location, v_punto, v_limite * 1000)
  order by pl.location <-> v_punto
  limit 1;

  if found and v_cercano.amount is not null then
    return query select v_cercano.amount, v_cercano.name, v_cercano.m;
  end if;

  return;
end;
$$;

comment on function public.rural_fare_for_point is
  'La tarifa rural de un punto -por lugar exacto, o por el lugar activo mas cercano de TODOS si ese es rural (D230/D234)-, o ninguna fila si el mas cercano es urbano.';
