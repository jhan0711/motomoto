import type { Coordinates } from '@/features/map/region';

/**
 * Distancia y tiempo estimados del viaje, contra Mapbox Directions (D149).
 *
 * Por que una llamada de red y no la linea recta que ya tenemos en geo.ts.
 * Amalfi es de montana y la carretera no va recta: la linea recta se queda
 * corta. Y el tiempo directamente no existiria, habria que inventarse una
 * velocidad y multiplicar, que es ensenarle al pasajero un numero fabricado.
 *
 * Cupo: 100.000 peticiones gratis al mes, verificado en la pagina de precios de
 * Mapbox antes de decidir. Es una llamada por viaje confirmado, doscientas veces
 * mas holgado que el cupo del buscador, que si hay que vigilar.
 *
 * `fetchRouteEstimate` pide `overview=false` a proposito: al pasajero solo le
 * hacen falta los dos numeros y no el dibujo de la ruta. Descargar la geometria
 * en cada confirmacion seria pagar datos moviles por algo que nadie mira.
 *
 * Ese "todavia" se acabo con D161. `fetchRouteGeometry`, mas abajo, si pide el
 * trazado, y lo hace para el conductor: sin ver por donde va cada viaje no puede
 * juzgar si una solicitud nueva le queda de camino, que es la decision que D161
 * pone en sus manos. Son dos funciones y no una porque son dos usos distintos
 * con costes distintos, y mezclarlos obligaria al pasajero a descargar un dibujo
 * que nadie le va a ensenar.
 *
 * AVISO SOBRE EL TIEMPO: el perfil `driving` calcula para un coche. Un
 * motorraton va mas despacio, asi que el tiempo saldra optimista. No se le
 * aplica ningun factor de correccion porque seria inventarse otro numero; con
 * viajes reales encima se podra calibrar de verdad (Fase 24).
 *
 * Ninguna funcion de este archivo lanza excepciones.
 */

// El mismo token publico de la cuenta que usa el buscador. La variable se llama
// SEARCH por la Fase 9, cuando era su unico uso. Renombrarla obligaria a tocar
// el .env y a reiniciar Metro, asi que se deja para la limpieza de la Fase 25.
const TOKEN = process.env.EXPO_PUBLIC_MAPBOX_SEARCH_TOKEN;

const DIRECTIONS = 'https://api.mapbox.com/directions/v5/mapbox/driving';

/**
 * Corte de la espera.
 *
 * La estimacion es un adorno informativo: el viaje se puede pedir igual sin
 * ella. Dejar que una red lenta congele el boton de confirmar seria cambiar algo
 * prescindible por algo esencial.
 */
const TIMEOUT_MS = 6000;

export interface RouteEstimate {
  meters: number;
  seconds: number;
}

export type RouteResult =
  | { ok: true; estimate: RouteEstimate | null }
  | { ok: false; code: 'MAPBOX_TOKEN_MISSING' | 'NETWORK' | 'TIMEOUT' | 'MAPBOX_ERROR' };

/**
 * Estimacion del viaje, o null si Mapbox responde que no hay ruta.
 *
 * La diferencia entre `{ ok: true, estimate: null }` y `{ ok: false }` importa y
 * no es cosmetica. El primero significa "pregunte y no hay camino"; el segundo,
 * "no pude preguntar". Confundirlos es exactamente el error E19 de la Fase 9,
 * cuando un fallo de red se le mostraba al pasajero como si el sitio no
 * existiera. La pantalla puede acabar ocultando la estimacion en los dos casos,
 * pero el registro y las pruebas necesitan saber cual fue.
 */
export async function fetchRouteEstimate(
  origin: Coordinates,
  destination: Coordinates,
): Promise<RouteResult> {
  const ruta = await pedirRuta(origin, destination, 'overview=false');

  if (!ruta.ok) {
    return { ok: false, code: ruta.code };
  }

  if (ruta.route === null) {
    return { ok: true, estimate: null };
  }

  const distancia = 'distance' in ruta.route ? ruta.route.distance : null;
  const duracion = 'duration' in ruta.route ? ruta.route.duration : null;

  if (typeof distancia !== 'number' || typeof duracion !== 'number') {
    return { ok: false, code: 'MAPBOX_ERROR' };
  }

  return {
    ok: true,
    estimate: { meters: Math.round(distancia), seconds: Math.round(duracion) },
  };
}

type RutaCruda =
  | { ok: true; route: object | null }
  | { ok: false; code: 'MAPBOX_TOKEN_MISSING' | 'NETWORK' | 'TIMEOUT' | 'MAPBOX_ERROR' };

/**
 * La peticion a Mapbox, sin interpretar la respuesta.
 *
 * Existe porque la estimacion y el trazado piden lo mismo a la misma API y solo
 * se diferencian en un parametro y en que campo leen despues. Todo lo delicado,
 * que es el corte por tiempo, distinguir un abort de una caida de red y separar
 * "no hay camino" de "no pude preguntar", estaba escrito una vez y tenia que
 * seguir estandolo.
 *
 * `route` a null significa que Mapbox contesto y no hay camino. Un fallo va por
 * `ok: false`.
 */
async function pedirRuta(
  origin: Coordinates,
  destination: Coordinates,
  parametros: string,
): Promise<RutaCruda> {
  if (TOKEN === undefined || TOKEN === '') {
    return { ok: false, code: 'MAPBOX_TOKEN_MISSING' };
  }

  const coords =
    `${origin.longitude},${origin.latitude};` + `${destination.longitude},${destination.latitude}`;

  const url =
    `${DIRECTIONS}/${coords}` +
    `?access_token=${TOKEN}&${parametros}&alternatives=false&steps=false`;

  const controller = new AbortController();
  const corte = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const respuesta = await fetch(url, { signal: controller.signal });

    if (!respuesta.ok) {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    const cuerpo: unknown = await respuesta.json();

    if (typeof cuerpo !== 'object' || cuerpo === null || !('routes' in cuerpo)) {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    const rutas = cuerpo.routes;
    if (!Array.isArray(rutas) || rutas.length === 0) {
      // Mapbox contesto y dice que no hay camino entre los dos puntos. Es una
      // respuesta valida, no un fallo.
      return { ok: true, route: null };
    }

    const primera: unknown = rutas[0];
    if (typeof primera !== 'object' || primera === null) {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    return { ok: true, route: primera };
  } catch (error) {
    // Un abort tambien entra por aqui, y conviene distinguirlo: "tardo
    // demasiado" y "no hay red" se parecen en la pantalla pero no en el registro.
    const nombre = error instanceof Error ? error.name : '';
    return { ok: false, code: nombre === 'AbortError' ? 'TIMEOUT' : 'NETWORK' };
  } finally {
    clearTimeout(corte);
  }
}

/**
 * El trazado de la ruta, para dibujarlo en un mapa.
 *
 * DECISION D161: esto es lo que hace posible recoger pasajeros en ruta. El
 * servidor no calcula desvios ni decide si una solicitud "queda de camino": lo
 * juzga el conductor, y para juzgarlo necesita verlo.
 *
 * Dos parametros de la peticion merecen explicacion.
 *
 * `overview=simplified` y no `full`. La ruta se pinta en un recuadro de pocos
 * centimetros dentro de una tarjeta. El trazado completo trae cientos de puntos
 * que ahi no se distinguen de la version simplificada, y se pagan en datos
 * moviles con el telefono del conductor.
 *
 * `geometries=geojson` y no `polyline6`. La codificada ocupa bastante menos,
 * pero hay que decodificarla, y eso son treinta lineas de manipulacion de bits
 * que habria que escribir y probar. Con GeoJSON las coordenadas vienen listas.
 * Sobre una ruta simplificada la diferencia son unos pocos kilobytes por
 * peticion, y no compensa meter un decodificador propio en el proyecto.
 *
 * OJO AL ORDEN: GeoJSON da [longitud, latitud], al reves de como los nombra
 * react-native-maps. Invertirlo no da error, solo pone Amalfi en Somalia.
 */
export type RouteGeometryResult =
  | { ok: true; coordinates: Coordinates[] | null }
  | { ok: false; code: 'MAPBOX_TOKEN_MISSING' | 'NETWORK' | 'TIMEOUT' | 'MAPBOX_ERROR' };

export async function fetchRouteGeometry(
  origin: Coordinates,
  destination: Coordinates,
): Promise<RouteGeometryResult> {
  const ruta = await pedirRuta(origin, destination, 'overview=simplified&geometries=geojson');

  if (!ruta.ok) {
    return { ok: false, code: ruta.code };
  }

  if (ruta.route === null) {
    return { ok: true, coordinates: null };
  }

  const geometria = 'geometry' in ruta.route ? ruta.route.geometry : null;

  if (typeof geometria !== 'object' || geometria === null || !('coordinates' in geometria)) {
    return { ok: false, code: 'MAPBOX_ERROR' };
  }

  const puntos: unknown = geometria.coordinates;

  if (!Array.isArray(puntos) || puntos.length < 2) {
    // Una linea de un punto no es una ruta. Se trata como "no hay camino" en
    // lugar de devolver algo que el mapa no sabe dibujar.
    return { ok: true, coordinates: null };
  }

  const coordenadas: Coordinates[] = [];

  for (const punto of puntos) {
    if (!Array.isArray(punto) || punto.length < 2) {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    const lng: unknown = punto[0];
    const lat: unknown = punto[1];

    if (typeof lng !== 'number' || typeof lat !== 'number') {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    coordenadas.push({ latitude: lat, longitude: lng });
  }

  return { ok: true, coordinates: coordenadas };
}

/**
 * Distancia en el formato que se le ensena a una persona.
 *
 * Por debajo del kilometro va en metros redondeados a la cincuentena: decirle a
 * alguien que su viaje son 847 metros finge una precision que no existe, porque
 * el origen ya lleva el error del GPS encima.
 */
export function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.max(50, Math.round(meters / 50) * 50)} m`;
  }
  const km = meters / 1000;
  // Coma decimal, que es lo que se usa en espanol.
  return `${km.toFixed(1).replace('.', ',')} km`;
}

/** Duracion legible. Nunca "0 min": un viaje siempre dura algo. */
export function formatDuration(seconds: number): string {
  const minutos = Math.max(1, Math.round(seconds / 60));
  if (minutos < 60) {
    return `${minutos} min`;
  }
  const horas = Math.floor(minutos / 60);
  const resto = minutos % 60;
  return resto === 0 ? `${horas} h` : `${horas} h ${resto} min`;
}
