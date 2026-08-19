-- =============================================================================
-- Fase 16, paso 5: H15 queda dicho tal y como es
-- =============================================================================
--
-- NO CAMBIA NINGUN COMPORTAMIENTO. Cambia lo que la base de datos dice de si
-- misma, que hasta hoy no era cierto.
--
-- EL HALLAZGO. La politica `profiles_select_ride_counterpart` se escribio en la
-- Fase 5 con este comentario al lado: "Solo durante el servicio y solo de la
-- persona con la que comparte viaje". La segunda mitad se cumple; la primera no.
-- `shares_ride_with` exige una fila en `rides` pero NO mira su estado, asi que
-- un conductor que llevo a alguien una vez puede leer su nombre y su telefono
-- mientras esa fila exista, es decir, siempre. Lo mismo vale para
-- `driver_linked_to_request`, que ademas deja a la vista `contact_phone`, que es
-- donde vive de verdad el telefono del pasajero.
--
-- LA DECISION, tomada al cerrar la Fase 16 y con el usuario: el comportamiento
-- se queda como esta HOY y se cierra en la Fase 22, seguridad y auditoria. El
-- motivo es que arreglarlo bien obliga a que el telefono deje de ser una columna
-- legible y pase a viajar solo por funciones que comprueban el estado del
-- servicio, y eso toca los caminos vivos de las fases 12 a 14 —asignacion,
-- seguimiento y ciclo del servicio— que no se pueden volver a verificar con un
-- solo emulador y sin movimiento. Cambiar hoy lo que no se puede probar hoy es
-- justo la clase de arreglo que rompe otra cosa en silencio.
--
-- LO QUE SI ESTA CERRADO YA, en la Fase 16: ninguna pantalla del historial
-- ensena el telefono, y el nombre del pasajero solo viaja en las ofertas que el
-- conductor acepto. Eso no depende de estas politicas, se aplica dentro de
-- `list_driver_history` y `get_driver_job`.
--
-- PLAN PARA LA FASE 22, para no volver a razonarlo desde cero:
--
--   1. Quitar el permiso de columna: `revoke select (phone) on public.profiles`
--      y `revoke select (contact_phone) on public.ride_requests` a
--      `authenticated`.
--   2. Pasar a SECURITY DEFINER las tres funciones que si necesitan el telefono
--      —`get_active_request`, `list_driver_active_rides` y la que use la Fase 19
--      para notificar— comprobando dentro que el servicio esta vivo.
--   3. Estrechar `shares_ride_with` y `driver_linked_to_request` a los estados
--      en curso, y dejar que el historial siga dando el NOMBRE por funcion.
--   4. Volver a pasar las pruebas de las fases 12 a 16 y el ciclo completo en
--      dispositivo.
-- =============================================================================

comment on function public.shares_ride_with is
  'Cierto si el usuario actual comparte O COMPARTIO ALGUN DIA un viaje con esa persona. No mira el estado del viaje: el acceso al perfil de la contraparte no caduca. Hallazgo H15, se estrecha en la Fase 22.';

comment on function public.driver_linked_to_request is
  'Cierto si al conductor se le ofrecio esa solicitud alguna vez o la atendio. No mira el estado ni la fecha, asi que deja legible contact_phone de forma indefinida. Hallazgo H15, se estrecha en la Fase 22.';

-- El comentario va tambien en la politica, que es donde lo va a leer quien
-- audite la tabla sin pasar por las funciones.
comment on policy "profiles_select_ride_counterpart" on public.profiles is
  'El pasajero ve a su conductor y el conductor a su pasajero. OJO: no solo durante el servicio, tambien despues, para siempre. Hallazgo H15.';
