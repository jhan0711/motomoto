import { Linking } from 'react-native';

import type { Coordinates } from '@/features/map/region';

/**
 * Llevar al conductor hasta un punto, con la aplicacion que el ya usa.
 *
 * DECISION D157, CERRADA AQUI. Durante la Fase 11 se pregunto por construir una
 * navegacion propia con el SDK de Mapbox y se decidio que no, por dos razones
 * que siguen valiendo. Cuesta 0,08 dolares por viaje pasando los mil al mes, en
 * una plataforma que no cobra nada (D8). Y sobre todo no resuelve el problema de
 * fondo: llevar al conductor con mucha precision hasta una coordenada que puede
 * no ser donde esta la persona. Eso lo arregla la referencia escrita del paso 1,
 * no un mapa mejor.
 *
 * Un enlace cuesta cero, y el conductor ya sabe usar la aplicacion que abre.
 *
 * POR QUE `geo:` Y NO `waze://` NI `google.navigation:`, QUE ERA EL PRIMER
 * INTENTO. Los esquemas propios de cada aplicacion arrancan la guia por voz
 * directamente, que es un toque menos para alguien que va a conducir. El
 * problema es saber cual esta instalada: desde Android 11, `canOpenURL` responde
 * que no a cualquier esquema que la aplicacion no haya declarado antes en su
 * manifiesto. Declararlos significa tocar el manifiesto, y eso obliga a
 * recompilar el cliente de desarrollo.
 *
 * `geo:` no necesita nada de eso. Es el esquema estandar de Android para "un
 * punto en el mapa", y el sistema responde con SU PROPIO SELECTOR, que ya lista
 * solo las aplicaciones instaladas y recuerda la elegida si el conductor marca
 * "siempre". Se paga un toque de mas, el de pulsar "ir" dentro de la aplicacion
 * que se abra.
 *
 * Es un intercambio consciente y reversible: el dia que haya que recompilar por
 * otra cosa (la Fase 25 recompila de todas formas), se pueden anadir los dos
 * paquetes al manifiesto y arrancar la guia directamente. Mientras tanto esto
 * funciona hoy, sin pedirle al usuario que compile.
 *
 * EL NOMBRE DEL SITIO VIAJA EN LA DIRECCION, entre parentesis. Es lo que hace
 * que el conductor vea "El parque" en su navegador y no unas coordenadas, y lo
 * que le permite reconocer si el punto es el que espera antes de arrancar.
 *
 * Ninguna funcion de este archivo lanza excepciones.
 */

/**
 * Abre la navegacion hacia un punto.
 *
 * Devuelve false si no se pudo abrir nada, para que la pantalla pueda decirlo en
 * lugar de quedarse callada.
 */
export async function openNavigation(point: Coordinates, label: string): Promise<boolean> {
  const coords = `${point.latitude},${point.longitude}`;

  // El nombre puede llevar espacios, tildes y parentesis. Sin codificar, un
  // parentesis dentro del texto cerraria el del formato y el punto se perderia.
  const destino = `geo:${coords}?q=${coords}(${encodeURIComponent(label)})`;

  try {
    await Linking.openURL(destino);
    return true;
  } catch {
    // Un telefono sin ninguna aplicacion de mapas instalada. Raro pero posible,
    // y la direccion de Google Maps por navegador funciona con solo tener datos.
    try {
      await Linking.openURL(
        'https://www.google.com/maps/dir/?api=1' + `&destination=${coords}&travelmode=driving`,
      );
      return true;
    } catch {
      return false;
    }
  }
}
