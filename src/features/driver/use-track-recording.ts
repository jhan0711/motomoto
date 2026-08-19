import { useEffect, useRef } from 'react';

import { distanceInMeters } from '@/features/destination/geo';
import type { Coordinates } from '@/features/map/region';
import { useNumericSetting } from '@/features/ride/settings';

import { recordTrackPoint } from './driver-service';

/**
 * Graba el rastro de los viajes en curso, un punto cada 50 metros (regla R9).
 *
 * POR QUE NO CADA DIEZ SEGUNDOS. `useLocationReporting` ya manda la posicion
 * actual con esa cadencia, y con ella basta para que el pasajero vea moverse el
 * motorraton. El rastro es otra cosa: es el registro del viaje, y guardar un
 * punto cada diez segundos llenaria la tabla de puntos casi identicos cuando el
 * conductor esta parado en un semaforo. El filtro por distancia (D14: "con
 * filtro de distancia minima") guarda un punto solo cuando de verdad avanzo.
 *
 * SOLO DURANTE 'in_progress', que es lo que significa "en viaje". La lista de
 * ride ids que recibe son los viajes con el pasajero ya a bordo. La aproximacion
 * hasta la recogida no es parte del recorrido, y `complete_ride` la deja fuera
 * aunque llegara a colarse.
 *
 * UN VEHICULO, VARIOS VIAJES (D161). El conductor puede llevar dos o tres
 * pasajeros a la vez, cada uno con su propio rastro. Como es un solo motorraton
 * en una sola posicion, la referencia del ultimo punto grabado es compartida:
 * cuando el vehiculo avanza 50 metros se anade un punto al rastro de CADA viaje
 * en curso. Asi cada pasajero tiene el registro de su tramo.
 *
 * EL PRIMER PUNTO SE GRABA SIN ESPERAR. Al arrancar un recorrido la referencia
 * esta vacia, asi que la primera posicion se guarda tal cual: es el punto de
 * subida. A partir de ahi manda el filtro de 50 metros. Un viaje muy corto, de
 * menos de 50 metros de recorrido, se queda con un solo punto y `complete_ride`
 * deja la distancia sin calcular, que es preferible a inventarla.
 */

/** Valor de reserva si no se puede leer el parametro. Es el de la regla R9. */
const DISTANCIA_MINIMA_M = 50;

export function useTrackRecording(rideIds: readonly string[], coords: Coordinates | null): void {
  const distanciaMinima = useNumericSetting('location_min_distance_m', DISTANCIA_MINIMA_M);

  /** El ultimo punto que se llego a grabar. Compartido: es un solo vehiculo. */
  const ultimoGrabadoRef = useRef<Coordinates | null>(null);

  // La lista llega como array nuevo en cada render. Se compara por su contenido,
  // no por identidad, para no reejecutar el efecto sin que cambie de verdad.
  const clave = rideIds.join('|');

  useEffect(() => {
    const ids = clave === '' ? [] : clave.split('|');

    // Sin viajes en curso no hay rastro que grabar. Se limpia la referencia para
    // que el proximo viaje empiece grabando su punto de subida, en lugar de
    // medir los 50 metros desde donde termino el anterior.
    if (ids.length === 0) {
      ultimoGrabadoRef.current = null;
      return;
    }

    if (coords === null) return;

    const ultimo = ultimoGrabadoRef.current;
    if (ultimo !== null && distanceInMeters(ultimo, coords) < distanciaMinima) {
      return;
    }

    // Se apunta antes de las inserciones, no despues: si dos lecturas del GPS
    // llegan casi juntas, la segunda no debe volver a grabar el mismo punto por
    // no haberse actualizado todavia la referencia.
    ultimoGrabadoRef.current = coords;

    for (const id of ids) {
      // Fuego y olvido: un punto perdido es un hueco en el rastro, y el rastro
      // tolera huecos. No se reintenta ni se avisa.
      void recordTrackPoint(id, coords);
    }
  }, [clave, coords, distanciaMinima]);
}
