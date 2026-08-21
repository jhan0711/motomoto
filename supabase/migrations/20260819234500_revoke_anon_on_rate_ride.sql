-- =============================================================================
-- Fase 17, paso 1: el rol anon deja de poder llamar a rate_ride
-- =============================================================================
--
-- LO VOLVIO A DESTAPAR UNA PRUEBA, y esta vez estaba anunciado. La migracion
-- `20260812084420_revoke_anon_on_ride_transitions.sql` cerro cuatro funciones en
-- la Fase 15 y dejo escrito, con nombre y apellido, que quedaban pendientes
-- `accept_ride_offer`, `reject_ride_offer`, `cancel_request` y **`rate_ride`**.
-- La prueba de calificaciones de esta fase lo comprobo: `anon` podia ejecutarla.
--
-- SE CIERRA SOLO ESTA, y no las otras tres. Es la funcion de la Fase 17, la que
-- van a llamar las pantallas que se escriben ahora, y la unica que esta fase
-- puede volver a probar de punta a punta. Las otras tres siguen donde estaban:
-- en la lista de la Fase 22, para mirarlas una por una. Revocar a ciegas lo que
-- no se puede volver a probar es como se rompe algo en silencio.
--
-- QUE PODIA HACER `anon` DE VERDAD, para no exagerar el hallazgo. Sin sesion,
-- `auth.uid()` es nulo, y `rater_id` no admite nulos: la calificacion NO llegaba
-- a entrar. Lo que si conseguia era distinguir las respuestas —"viaje no
-- encontrado", "solo se pueden calificar servicios terminados"— y con eso
-- averiguar si cierto identificador existe y en que estado esta. Es una fuga
-- pequena, pero la funcion es SECURITY DEFINER y corre como el dueno de la base
-- de datos: la puerta se cierra igual.
--
-- Las funciones nacen con permiso de ejecucion para PUBLIC, que incluye a
-- `anon`, y `create or replace` conserva los permisos: por eso hay que revocar
-- explicitamente y volver a conceder a `authenticated`.
-- =============================================================================

revoke all on function public.rate_ride(uuid, smallint, text) from public, anon;
grant execute on function public.rate_ride(uuid, smallint, text) to authenticated;

comment on function public.rate_ride is
  'Califica un servicio terminado en el que quien llama participo. Una por parte y por viaje (R8). Solo para usuarios con sesion.';
