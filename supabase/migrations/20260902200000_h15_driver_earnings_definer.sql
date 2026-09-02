-- =============================================================================
-- FASE 22, PASO 2 (continuacion): `list_driver_earnings` pasa a definer.
-- =============================================================================
--
-- QUE FALTABA. La migracion `20260902190000` estrecho `driver_linked_to_request`
-- a los estados en curso y paso a `security definer` las seis funciones de
-- historial. Se dejo fuera `list_driver_earnings` -el recaudo del conductor-,
-- que tambien es `security invoker` y lee `ride_requests` de viajes ya
-- COMPLETADOS: al estrecharse la politica, dejo de ver esas solicitudes y
-- devolvia cero filas. Lo cazo `prueba_recaudo.sql` (checks 3, 5, 6, 11).
--
-- Su `where d.driver_id = (select auth.uid())` es su propia puerta, igual que
-- las otras seis, asi que ejecutarla con privilegios no expone nada ajeno.
-- =============================================================================

alter function public.list_driver_earnings(text, date, date) security definer;
