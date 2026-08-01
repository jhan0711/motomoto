import type { Coordinates } from '@/features/map/region';

import { AT_PLACE_METERS, NEAR_PLACE_METERS, nearestPlace } from './geo';
import { reverseGeocode } from './mapbox-service';
import type { Place } from './types';

/**
 * Como se llama un punto suelto del mapa.
 *
 * `label` en null significa que no supimos nombrarlo, y entonces la pantalla
 * tiene que pedirle una referencia al pasajero. No es un error: es el resultado
 * honesto para un punto en mitad del campo.
 */
export interface PointDescription {
  label: string | null;
  detail: string | null;
  /** Solo cuando el punto cae encima de un lugar de la lista. */
  placeId: string | null;
}

/**
 * Convierte una coordenada en algo que una persona entiende (D127).
 *
 * El orden importa y esta medido, no elegido a ojo. Sobre doce puntos repartidos
 * por Amalfi:
 *
 *   - Nuestra lista da nombres que el conductor reconoce ("El comando"), pero
 *     solo sirve cerca: mas alla de doscientos metros el lugar mas proximo ya no
 *     dice nada util.
 *   - Mapbox da una direccion casi siempre, y son correctas, pero son
 *     impersonales: "Calle 20 18 047".
 *
 * Ninguna de las dos basta sola, asi que se combinan.
 *
 * Encima de un lugar conocido NO se llama a la red. Ese es el caso frecuente, la
 * respuesta ya la tenemos en memoria, y en Amalfi la conexion es irregular:
 * elegir destino tiene que seguir funcionando sin ella.
 */
export async function describePoint(
  point: Coordinates,
  places: readonly Place[],
): Promise<PointDescription> {
  const nearest = nearestPlace(point, places);

  if (nearest !== null && nearest.meters <= AT_PLACE_METERS) {
    return {
      label: nearest.place.name,
      detail: nearest.place.description,
      // Sin placeId a proposito, aunque caiga sobre un lugar conocido. El
      // pasajero solto un punto en el mapa, no eligio ese lugar de la lista, y
      // la coordenada que vale es la suya. Decir lo contrario mandaria al
      // conductor a la puerta del sitio en vez de donde marco el pasajero.
      placeId: null,
    };
  }

  const address = await reverseGeocode(point);
  const street = address.ok ? address.data : null;

  if (nearest !== null && nearest.meters <= NEAR_PLACE_METERS) {
    return {
      label: `Cerca de ${nearest.place.name}`,
      detail: street,
      placeId: null,
    };
  }

  return { label: street, detail: null, placeId: null };
}
