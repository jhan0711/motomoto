import * as Notifications from 'expo-notifications';
import { useRouter } from 'expo-router';
import { useEffect } from 'react';

import { rutaDelAviso } from './route-for-notification';

/**
 * Lleva a la pantalla que corresponde cuando se toca un aviso (D158/D219).
 *
 * ENCONTRADO EL 2026-09-29: no existia ningun manejador de "aviso tocado" en
 * toda la aplicacion. El conductor recibia la notificacion de una solicitud
 * nueva, la tocaba, la aplicacion se abria... y si se habia quedado en otra
 * pestana -Perfil, Recaudo- o en medio de un dialogo, ahi se quedaba: la
 * oferta estaba llegando por tiempo real a la pestana de Inicio, pero nada lo
 * llevaba hasta ella. Es justo lo que el usuario describio mirando la
 * pantalla: "toco la notificacion, la app se abre, pero el panel queda
 * vacio".
 *
 * Este archivo no decide SI la oferta sigue vigente ni la vuelve a pedir -eso
 * ya lo hace `useDriverOffers` en cuanto la pestana de Inicio esta montada-:
 * solo se asegura de que el toque termine en esa pestana. Mismo criterio para
 * el pasajero con el aviso de "tu motocarro llego". La decision de a donde ir
 * vive en `route-for-notification.ts`, aparte, para poder probarla con jest.
 */
export function useNotificationResponseNavigation(): void {
  const router = useRouter();

  useEffect(() => {
    function manejar(respuesta: Notifications.NotificationResponse) {
      const ruta = rutaDelAviso(respuesta.notification.request.content.data);
      if (ruta !== null) router.replace(ruta);
    }

    /*
     * El toque que abre la aplicacion desde cerrada no lo recibe el listener
     * de aqui abajo -se registra un instante despues de que ya paso-, asi que
     * hay que preguntar aparte por la ULTIMA respuesta. Se limpia enseguida:
     * sin esto, la proxima vez que la persona abra la app por el icono -sin
     * tocar ningun aviso- seguiria leyendo esta misma respuesta vieja y la
     * mandaria a un sitio que no pidio.
     */
    void Notifications.getLastNotificationResponseAsync().then((respuesta) => {
      if (respuesta !== null) {
        manejar(respuesta);
        void Notifications.clearLastNotificationResponseAsync();
      }
    });

    const suscripcion = Notifications.addNotificationResponseReceivedListener(manejar);
    return () => suscripcion.remove();
  }, [router]);
}
