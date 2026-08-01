-- =============================================================================
-- Migracion 11: leer los lugares desde la aplicacion
-- =============================================================================
--
-- Por que hace falta una funcion para algo tan simple como listar una tabla.
--
-- La columna places.location es de tipo geography. Al pedirla por la API REST,
-- PostgREST la devuelve como el texto de su representacion binaria:
--
--   0101000020E610000002284696CCC452C0AE9B525E2BA11B40
--
-- Eso es un punto valido, pero para sacarle la latitud y la longitud habria que
-- descifrar EWKB hexadecimal en el telefono. Escribir ese decodificador seria
-- meter en la aplicacion un trozo de codigo delicado, dificil de probar y facil
-- de romper, para resolver algo que la base de datos ya sabe hacer.
--
-- Esta funcion devuelve latitud y longitud como numeros y se acabo el problema.
--
-- SECURITY INVOKER, que es lo contrario de lo habitual en este esquema. Las
-- funciones auxiliares de politicas son security definer porque necesitan
-- saltarse la seguridad de fila para romper recursiones. Esta no: se ejecuta con
-- los permisos de quien llama, asi que las politicas de places se siguen
-- aplicando y un bloqueo futuro sobre la tabla sigue valiendo aqui.
-- =============================================================================

create or replace function public.list_places()
returns table (
  id uuid,
  name text,
  description text,
  lat double precision,
  lng double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    p.id,
    p.name,
    p.description,
    -- st_y es la latitud y st_x la longitud. El orden se confunde con facilidad
    -- porque el punto se construye al reves, con la longitud primero.
    extensions.st_y(p.location::extensions.geometry),
    extensions.st_x(p.location::extensions.geometry)
  from public.places p
  where p.is_active
  order by p.sort_order, p.name;
$$;

comment on function public.list_places is
  'Lugares frecuentes activos, con la coordenada ya separada en latitud y longitud.';

-- El rol anonimo no tiene nada que hacer aqui. Que la lista de destinos de un
-- municipio no sea secreta no es razon para publicarla sin sesion.
revoke all on function public.list_places() from public, anon;
grant execute on function public.list_places() to authenticated;
