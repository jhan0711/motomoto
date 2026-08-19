export interface Coordinates {
  latitude: number;
  longitude: number;
}

/**
 * Un area visible del mapa: su centro y cuanto abarca, en grados.
 *
 * **El tipo es nuestro desde el cambio a Mapbox.** Antes venia de
 * `react-native-maps`, y era la ultima atadura con esa libreria fuera de
 * `map.tsx`: tres archivos la importaban solo para nombrar este tipo. Al
 * definirlo aqui, cambiar de proveedor de mapas deja de tocar nada mas que el
 * componente.
 *
 * Se conserva la forma de "centro mas deltas" en lugar de pasarse a los limites
 * o al nivel de zoom que usa Mapbox por dentro. No es nostalgia: es lo que
 * entienden `regionAround` y `regionContaining`, que calculan encuadres sin
 * hablar con el mapa, y lo que permitio que este cambio no tocara ninguna
 * pantalla. La traduccion a lo que Mapbox quiere ocurre en un solo sitio.
 */
export interface Region extends Coordinates {
  /** Alto del area visible, en grados de latitud. Menor es mas cerca. */
  latitudeDelta: number;
  /** Ancho del area visible, en grados de longitud. */
  longitudeDelta: number;
}

/**
 * Parque principal de Amalfi. Verified against the municipal coordinates
 * (6°54'17" N, 75°04'36" W) during the Phase 8 provider evaluation.
 *
 * This is where the map opens before the device reports a position. A blank
 * screen would tell the passenger nothing; the town square tells them where the
 * service operates while the GPS gets a fix.
 */
export const AMALFI_CENTER: Coordinates = {
  latitude: 6.9047,
  longitude: -75.0767,
};

/**
 * Bounding box of the municipality, as Mapbox wants it:
 * minimum longitude, minimum latitude, maximum longitude, maximum latitude.
 *
 * Roughly 25 km around the town square, which covers Amalfi's 1210 km² well
 * enough to include the veredas. Every address search is restricted to this box.
 *
 * Restricting rather than merely biasing is the whole point. With a soft bias
 * the Phase 8 evaluation got a "Coliseo Municipal" thirty kilometres away and an
 * "Alcaldía" that belonged to Anorí, both looking perfectly plausible in a list.
 * The service does not leave the municipality, so neither should its results.
 */
export const AMALFI_BBOX = [-75.304, 6.68, -74.85, 7.13] as const;

/**
 * Deltas control the zoom level: they are the height and width of the visible
 * area, in degrees. Smaller means closer.
 *
 * Roughly: 1 degree of latitude is 111 km anywhere on Earth. At Amalfi's
 * latitude a degree of longitude is about 110 km, so the two deltas can stay
 * equal without the map looking stretched.
 */
const TOWN_DELTA = 0.02; // ~2.2 km across. The whole urban area.
const CLOSE_DELTA = 0.005; // ~550 m across. Street level.

/** Opening view: the town, before we know where the passenger is. */
export const AMALFI_REGION: Region = {
  ...AMALFI_CENTER,
  latitudeDelta: TOWN_DELTA,
  longitudeDelta: TOWN_DELTA,
};

/** Street-level view around a point. Used when recentering on the passenger. */
export function regionAround(coords: Coordinates): Region {
  return {
    ...coords,
    latitudeDelta: CLOSE_DELTA,
    longitudeDelta: CLOSE_DELTA,
  };
}

/**
 * Margen alrededor de lo que se encuadra.
 *
 * Sin el, la ruta empieza y acaba pegada al borde del recuadro y parece cortada.
 * Un cuarto a cada lado deja respirar a los marcadores de recogida y destino,
 * que se dibujan centrados sobre su punto y sobresaldrian.
 */
const FIT_MARGIN = 1.5;

/**
 * La vista mas cercana que se permite al encuadrar.
 *
 * Hace falta un suelo porque dos puntos separados por cincuenta metros darian un
 * delta minusculo, y el mapa entraria a un nivel de zoom donde solo se ve
 * asfalto sin referencias. Ahi el conductor no reconoce nada.
 */
const MIN_FIT_DELTA = 0.004;

/**
 * La region mas ajustada que contiene todos los puntos.
 *
 * Se calcula en lugar de usar `fitToCoordinates` de react-native-maps, que
 * necesita una referencia al mapa y esperar a que este listo. Para un recuadro
 * pequeno dentro de una tarjeta eso es mucha maquinaria y una fuente conocida de
 * mapas que aparecen en blanco cuando la llamada llega antes de tiempo. Un
 * calculo directo entra en `initialRegion` y no depende de ningun momento.
 *
 * Devuelve null con la lista vacia: no hay nada que encuadrar, y el que llama
 * decide que ensenar.
 */
export function regionContaining(points: Coordinates[]): Region | null {
  const primero = points[0];

  if (primero === undefined) {
    return null;
  }

  let minLat = primero.latitude;
  let maxLat = primero.latitude;
  let minLng = primero.longitude;
  let maxLng = primero.longitude;

  for (const punto of points) {
    minLat = Math.min(minLat, punto.latitude);
    maxLat = Math.max(maxLat, punto.latitude);
    minLng = Math.min(minLng, punto.longitude);
    maxLng = Math.max(maxLng, punto.longitude);
  }

  return {
    latitude: (minLat + maxLat) / 2,
    longitude: (minLng + maxLng) / 2,
    latitudeDelta: Math.max(MIN_FIT_DELTA, (maxLat - minLat) * FIT_MARGIN),
    longitudeDelta: Math.max(MIN_FIT_DELTA, (maxLng - minLng) * FIT_MARGIN),
  };
}
