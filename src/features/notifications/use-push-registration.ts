import Constants from 'expo-constants';
import * as Notifications from 'expo-notifications';
import { useEffect, useRef } from 'react';
import { Platform } from 'react-native';

import { savePushToken } from './notifications-service';

/**
 * El canal de Android por el que entran los dos avisos del servicio.
 *
 * Tiene que coincidir con el `channelId` que manda `send_push_notification` en
 * el servidor. Si los dos se separan, el aviso entra por el canal generico que
 * crea Expo y se pierde la importancia alta: llegaria igual, pero callado, que
 * es justo el fallo que este canal existe para arreglar.
 */
export const CANAL_SERVICIO = 'service-alerts-v2';

/**
 * Los identificadores que quedaron atras, para borrarlos al arrancar.
 *
 * Android congela la configuracion de un canal en cuanto se crea: a partir de
 * ahi solo el usuario puede cambiarla desde los ajustes del sistema. Corregir
 * un canal, entonces, no es editarlo sino crear otro con identificador nuevo, y
 * versionarlo asi es la practica que la propia documentacion de Android
 * recomienda. Estos dos se borran para no dejarle al usuario tres entradas en
 * sus ajustes de notificaciones, dos de ellas muertas.
 *
 *   - `default`: el primero, en importancia DEFAULT. Llegaba callado
 *   - `service-alerts`: el segundo, ya en MAX, pero creado con un `sound`
 *     invalido que Android rechazo
 */
const CANALES_VIEJOS = ['default', 'service-alerts'];

/**
 * Como se comporta un aviso que llega con la aplicacion abierta.
 *
 * Se muestra igual que si la aplicacion estuviera cerrada. La alternativa,
 * apagarlo porque la pantalla ya se actualiza sola por tiempo real (Fase 13),
 * fallaria justo cuando mas importa: el conductor mirando el mapa mientras
 * conduce no ve la pantalla, y el pasajero puede tener el telefono bloqueado
 * en el bolsillo.
 */
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

/**
 * Pide permiso, obtiene el token de Expo Push y lo guarda en el perfil.
 *
 * Cubre los dos avisos que la seccion 7 deja escritos: al pasajero cuando el
 * conductor llega, al conductor cuando le llega una solicitud. El servidor ya
 * sabe cuando enviar (Fase 19, disparadores en `rides` y `ride_offers`); lo
 * unico que falta del lado del telefono es que el servidor tenga a donde
 * mandarlo.
 *
 * Corre una vez por sesion abierta, no por pantalla: se llama desde el layout
 * raiz, dentro de `SessionProvider`, para que no dependa de por cual de las
 * dos zonas (pasajero o conductor) entro la persona.
 *
 * Sin pedir permiso de nuevo si ya se decidio antes (concedido o no): Android
 * no vuelve a preguntar solo, y machacar al usuario con el mismo dialogo en
 * cada arranque enseñaria a rechazarlo por reflejo.
 */
export function usePushRegistration(userId: string | null): void {
  // El identificador del usuario para el que ya se registro el token en esta
  // sesion de la aplicacion. Evita repetir el registro en cada renderizado, y
  // detecta el cambio de una cuenta a otra en el mismo aparato.
  const registradoPara = useRef<string | null>(null);

  useEffect(() => {
    if (userId === null) {
      // No hay nadie: si un momento antes SI habia alguien, se borra su token
      // para que este aparato deje de recibir avisos de una cuenta cerrada.
      if (registradoPara.current !== null) {
        registradoPara.current = null;
        void savePushToken(null);
      }
      return;
    }

    if (registradoPara.current === userId) {
      return;
    }

    let vigente = true;

    void (async () => {
      const token = await obtenerToken();

      if (!vigente || token === null) {
        return;
      }

      registradoPara.current = userId;
      void savePushToken(token);
    })();

    return () => {
      vigente = false;
    };
  }, [userId]);
}

/**
 * El token de Expo Push de este aparato, o null si no se pudo conseguir.
 *
 * Nunca lanza: un permiso negado, un emulador sin Play Services o cualquier
 * otro tropiezo son el caso normal en desarrollo, no un fallo que deba
 * interrumpir el arranque de la aplicacion.
 *
 * PERO SI DEJA RASTRO, y esta parte se aprendio fallando. La primera version
 * devolvia null en silencio en los cuatro caminos, asi que cuando el token no
 * llego al servidor no habia forma de saber por cual de ellos: el permiso
 * estaba concedido, la fila seguia vacia y el registro no decia nada. La causa
 * real era que faltaba `google-services.json` —Expo Push usa FCM por debajo en
 * Android— y costo mas encontrarla que arreglarla. Un fallo que no se anuncia
 * cuesta el doble.
 */
async function obtenerToken(): Promise<string | null> {
  try {
    if (Platform.OS === 'android') {
      // Obligatorio antes de pedir el permiso: sin un canal, Android 8 y
      // posteriores no muestran nada aunque el envio funcione.
      //
      // MAX y no DEFAULT, y esto se decidio mirando la pantalla. Con DEFAULT el
      // aviso llegaba —"Tu motocarro llegó" estaba en la bandeja— pero el
      // usuario no se enteraba: sin sonido y sin asomarse, quedaba enterrado
      // entre las notificaciones del sistema. Los dos avisos de esta fase son
      // justo los que no pueden pasar desapercibidos: uno saca al pasajero a la
      // calle y el otro le da al conductor veinte segundos para responder (R2).
      // MAX es lo que hace que Android lo muestre flotando y con sonido.
      //
      // `vibrationPattern` va explicito porque en algunas capas de Android el
      // canal no vibra si no se le dice, aunque la importancia lo permita.
      //
      // El porque del identificador versionado esta arriba, en CANALES_VIEJOS.
      // SIN `sound`, y esto costo un error en pantalla. Aqui esa propiedad NO
      // significa "el sonido del sistema": es el nombre de un archivo de sonido
      // propio que tendria que venir empaquetado en la aplicacion. Al pasarle
      // 'default' salto en los dos aparatos "Custom sound 'default' not found
      // in native app". Omitiendola, el canal usa el sonido de notificacion del
      // sistema, que es justo lo que se queria.
      //
      // No confundir con el 'sound' que manda `send_push_notification` en el
      // servidor: ese es de la API de Expo Push, donde 'default' SI significa
      // el sonido por defecto.
      await Notifications.setNotificationChannelAsync(CANAL_SERVICIO, {
        name: 'Avisos del servicio',
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        enableVibrate: true,
      });

      // Falla sin consecuencias si no existen, que es el caso de cualquier
      // instalacion nueva.
      await Promise.all(
        CANALES_VIEJOS.map((id) =>
          Notifications.deleteNotificationChannelAsync(id).catch(() => {}),
        ),
      );
    }

    const permiso = await Notifications.getPermissionsAsync();
    const concedido =
      permiso.status === 'granted'
        ? true
        : (await Notifications.requestPermissionsAsync()).status === 'granted';

    if (!concedido) {
      console.warn('[push] Sin permiso de notificaciones. No habra token.');
      return null;
    }

    const projectId = Constants.expoConfig?.extra?.eas?.projectId;
    if (typeof projectId !== 'string') {
      console.warn('[push] Falta extra.eas.projectId en app.config.ts. No habra token.');
      return null;
    }

    const resultado = await Notifications.getExpoPushTokenAsync({ projectId });
    return resultado.data;
  } catch (error) {
    // El sitio por el que se cuela el fallo de FCM, que es el mas probable de
    // los cuatro y el unico que no se puede deducir mirando la pantalla.
    console.warn('[push] No se pudo obtener el token:', error);
    return null;
  }
}
