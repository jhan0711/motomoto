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
 * Se pide `overview=false` a proposito: hoy solo hacen falta los dos numeros y
 * no el dibujo de la ruta. Descargar la geometria en cada confirmacion seria
 * pagar datos moviles por algo que nadie mira todavia. La Fase 14, que si tiene
 * que pintarla, la pedira entonces.
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
  if (TOKEN === undefined || TOKEN === '') {
    return { ok: false, code: 'MAPBOX_TOKEN_MISSING' };
  }

  const coords =
    `${origin.longitude},${origin.latitude};` + `${destination.longitude},${destination.latitude}`;

  const url =
    `${DIRECTIONS}/${coords}` +
    `?access_token=${TOKEN}&overview=false&alternatives=false&steps=false`;

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
      return { ok: true, estimate: null };
    }

    const primera: unknown = rutas[0];
    if (typeof primera !== 'object' || primera === null) {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    const distancia = 'distance' in primera ? primera.distance : null;
    const duracion = 'duration' in primera ? primera.duration : null;

    if (typeof distancia !== 'number' || typeof duracion !== 'number') {
      return { ok: false, code: 'MAPBOX_ERROR' };
    }

    return {
      ok: true,
      estimate: { meters: Math.round(distancia), seconds: Math.round(duracion) },
    };
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
