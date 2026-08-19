-- =============================================================================
-- Fase 15, paso 1: el rol anon deja de poder llamar a las transiciones
-- =============================================================================
--
-- LO DESTAPO UNA PRUEBA. El script de transiciones esperaba que `anon` recibiera
-- "sin permiso" al intentar mover un viaje, y lo que recibio fue el error de
-- dentro de la funcion: "ese viaje no es tuyo". Es decir, **puede llamarlas**, y
-- lo unico que lo frena es la comprobacion que hay detras.
--
-- La comprobacion es solida: `assert_ride_driver` compara contra `auth.uid()`,
-- que sin sesion es nulo y no coincide con ningun conductor. Nadie puede mover un
-- viaje ajeno por esta via. Pero la seccion 13 de este documento dice que la
-- seguridad se hace por capas, y una puerta abierta con un guardia detras sigue
-- siendo una puerta abierta: el dia que alguien reescriba esa funcion sin
-- acordarse de la comprobacion, no queda nada.
--
-- Es el mismo pendiente que ya se cerro para `request_ride` en la Fase 14, con el
-- mismo razonamiento.
--
-- SOLO LAS CUATRO DE ESTE PASO. Quedan por revocar `accept_ride_offer`,
-- `reject_ride_offer`, `cancel_request` y `rate_ride`, ademas de un punado de
-- funciones de disparador que no deberian ser llamables por nadie. No se tocan
-- aqui porque no son de esta fase y porque revocar a ciegas puede romper algo que
-- si se use: se hacen en la Fase 22, mirando cada una. Queda escrito en los
-- pendientes.
--
-- Las funciones nacen con permiso de ejecucion para PUBLIC, que incluye a `anon`,
-- y `create or replace` conserva los permisos: por eso hay que revocar
-- explicitamente y volver a conceder a `authenticated`.
-- =============================================================================

revoke all on function public.start_driving_to_pickup(uuid) from public, anon;
revoke all on function public.confirm_driver_arrival(uuid) from public, anon;
revoke all on function public.start_ride(uuid) from public, anon;
revoke all on function public.complete_ride(uuid) from public, anon;

grant execute on function public.start_driving_to_pickup(uuid) to authenticated;
grant execute on function public.confirm_driver_arrival(uuid) to authenticated;
grant execute on function public.start_ride(uuid) to authenticated;
grant execute on function public.complete_ride(uuid) to authenticated;
