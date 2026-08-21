import { Redirect, Stack } from 'expo-router';

import { homeRouteFor, useSession } from '@/features/auth/session';

/**
 * Guardia de la zona del conductor, y la PILA que la envuelve.
 *
 * Las tres pestanas viven en `(tabs)`, un grupo que no aparece en la ruta: sus
 * direcciones siguen siendo /driver, /driver/history y /driver/profile.
 *
 * POR QUE UNA PILA POR ENCIMA DE LAS PESTANAS. En la Fase 17 el detalle de un
 * servicio y la pantalla de calificar estaban colgados directamente de las
 * pestanas, escondidos con `href: null`. Funcionaban, pero **volver atras
 * llevaba a la pestana anterior en lugar de a la pantalla anterior**: se
 * calificaba desde el historial y se aterrizaba en Inicio. Se vio en el
 * emulador, no en el codigo. Encima de las pestanas, una pila hace lo que
 * cualquiera espera.
 *
 * Como en el guardia del pasajero: esto decide que se pinta, no que se permite.
 * La autorizacion de verdad vive en las politicas de la Fase 5.
 */
export default function DriverLayout() {
  const { user, isLoading, canOperate, isRecoveringPassword } = useSession();

  if (isRecoveringPassword) {
    return <Redirect href="/reset-password" />;
  }

  if (isLoading) {
    return null;
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  // Antes que el rol. Un conductor pendiente de aprobacion o bloqueado tiene rol
  // de conductor y no debe llegar a la pantalla de operacion (flujo 7.2, paso 2).
  if (!canOperate) {
    return <Redirect href="/account-status" />;
  }

  if (user.role !== 'driver') {
    return <Redirect href={homeRouteFor(user.role)} />;
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
