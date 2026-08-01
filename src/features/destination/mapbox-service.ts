import { AMALFI_BBOX, AMALFI_CENTER, type Coordinates } from '@/features/map/region';

import { fail, ok, type Result } from './types';

/**
 * Buscador de direcciones y camino inverso, contra Mapbox (D111, D128).
 *
 * Dos APIs distintas y por buenos motivos:
 *
 *   Buscar   -> Search Box. Es la unica que conoce los puntos de interes de
 *               Amalfi. En la evaluacion de la Fase 9 acerto 22 de 39 frente a
 *               los 3 de la API de geocodificacion, que solo indexa direcciones
 *               y divisiones administrativas. Trae 500 busquedas gratis al mes.
 *
 *   Invertir -> Geocoding v6. Para convertir un punto en texto las dos
 *               devolvieron exactamente lo mismo en los doce puntos probados,
 *               asi que se usa la que trae 100.000 gratis en vez de 500.
 *
 * Ninguna funcion lanza excepciones.
 */

const TOKEN = process.env.EXPO_PUBLIC_MAPBOX_SEARCH_TOKEN;

const SEARCH_BOX = 'https://api.mapbox.com/search/searchbox/v1';
const GEOCODE = 'https://api.mapbox.com/search/geocode/v6';

const PROXIMITY = `${AMALFI_CENTER.longitude},${AMALFI_CENTER.latitude}`;
const BBOX = AMALFI_BBOX.join(',');

/** Lo que devuelve el buscador antes de saber donde cae. */
export interface Suggestion {
  /** Identificador de Mapbox. Solo sirve dentro de la misma sesion. */
  id: string;
  name: string;
  detail: string | null;
}

const NO_TOKEN = () =>
  fail<never>(
    'MAPBOX_TOKEN_MISSING',
    'El buscador de direcciones no está configurado. Avisa a la empresa.',
  );

const NETWORK = () => fail<never>('NETWORK', 'No hay conexión. Revísala e inténtalo de nuevo.');

/**
 * Un testigo de sesion agrupa todo lo que el pasajero teclea en UNA busqueda.
 *
 * Es lo que hace viable el cupo de 500. Mapbox factura por sesion, no por
 * pulsacion: escribir "h-o-s-p-i-t-a-l" y elegir un resultado es una sola
 * sesion si todas las llamadas comparten este testigo. Uno nuevo por tecla
 * multiplicaria la factura por ocho.
 *
 * No hace falta que sea criptograficamente aleatorio. No es un secreto ni
 * autoriza nada: solo agrupa llamadas. Se genera sin dependencias para no
 * añadir una libreria de criptografia a la aplicacion por esto.
 */
export function newSessionToken(): string {
  const hex = (n: number) =>
    Array.from({ length: n }, () => Math.floor(Math.random() * 16).toString(16)).join('');
  return `${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}`;
}

/**
 * Sugerencias mientras el pasajero escribe.
 *
 * Se filtran las filas de tipo categoria: Mapbox devuelve entradas como
 * "Hospital" o "Parque" que no son sitios sino grupos, y en una lista de
 * destinos son ruido que no lleva a ninguna parte.
 */
export async function searchAddresses(
  query: string,
  sessionToken: string,
): Promise<Result<Suggestion[]>> {
  if (TOKEN === undefined || TOKEN === '') return NO_TOKEN();

  const url = new URL(`${SEARCH_BOX}/suggest`);
  url.searchParams.set('q', query);
  url.searchParams.set('access_token', TOKEN);
  url.searchParams.set('session_token', sessionToken);
  url.searchParams.set('proximity', PROXIMITY);
  url.searchParams.set('bbox', BBOX);
  url.searchParams.set('language', 'es');
  url.searchParams.set('country', 'co');
  url.searchParams.set('limit', '6');

  let body: unknown;
  try {
    const response = await fetch(url.toString());
    body = await response.json();
    if (!response.ok) {
      return fail('SEARCH_FAILED', 'El buscador no respondió. Inténtalo de nuevo.');
    }
  } catch {
    return NETWORK();
  }

  const suggestions = (body as { suggestions?: RawSuggestion[] }).suggestions ?? [];

  // flatMap y no filter + map: filtrar por `typeof x === 'string'` descarta la
  // fila en tiempo de ejecucion pero no estrecha el tipo, y el map siguiente
  // seguiria viendo un identificador que puede faltar.
  return ok(
    suggestions.flatMap<Suggestion>((s) => {
      if (s.feature_type === 'category') return [];
      if (typeof s.mapbox_id !== 'string' || s.mapbox_id === '') return [];
      if (typeof s.name !== 'string' || s.name === '') return [];
      if (!estaEnAmalfi(s.place_formatted)) return [];
      return [{ id: s.mapbox_id, name: s.name, detail: s.place_formatted ?? null }];
    }),
  );
}

interface RawSuggestion {
  mapbox_id?: string;
  name?: string;
  place_formatted?: string;
  feature_type?: string;
}

/**
 * Deja pasar solo lo que esta en Amalfi.
 *
 * El recuadro de busqueda cubre 25 km porque el municipio mide 1210 km², y a esa
 * distancia caben pueblos vecinos enteros. Sin este filtro, buscar "hospital"
 * ofrece el de Anori y el de Campamento con el mismo aspecto que el de aqui, y
 * el pasajero puede mandar al conductor a veinte kilometros fuera sin enterarse.
 *
 * Estrechar el recuadro no sirve: dejaria fuera las veredas, que si son
 * destinos validos.
 *
 * Se comprobo contra los 39 sitios de la evaluacion. Los 22 resultados que caen
 * dentro del casco traen "Amalfi" o un codigo postal 05284x en su texto; los 5
 * que caen fuera traen Anori (052850) o Carolina del Principe (051840). Ninguno
 * de los municipios vecinos observados empieza por 05284.
 */
function estaEnAmalfi(placeFormatted: string | undefined): boolean {
  if (placeFormatted === undefined) return false;
  return /amalfi/i.test(placeFormatted) || /\b05284\d\b/.test(placeFormatted);
}

/**
 * Convierte una sugerencia elegida en una coordenada.
 *
 * El buscador no devuelve coordenadas: hay que pedirlas en una segunda llamada,
 * y esta es la que cierra la sesion de facturacion. Por eso solo se llama cuando
 * el pasajero ya eligio, nunca mientras teclea.
 */
export async function retrieveSuggestion(
  id: string,
  sessionToken: string,
): Promise<Result<Coordinates>> {
  if (TOKEN === undefined || TOKEN === '') return NO_TOKEN();

  const url = new URL(`${SEARCH_BOX}/retrieve/${encodeURIComponent(id)}`);
  url.searchParams.set('access_token', TOKEN);
  url.searchParams.set('session_token', sessionToken);

  let body: unknown;
  try {
    const response = await fetch(url.toString());
    body = await response.json();
    if (!response.ok) {
      return fail(
        'RETRIEVE_FAILED',
        'No pudimos ubicar ese sitio. Elige otro o márcalo en el mapa.',
      );
    }
  } catch {
    return NETWORK();
  }

  const coordinates = (body as { features?: { geometry?: { coordinates?: number[] } }[] })
    .features?.[0]?.geometry?.coordinates;

  const longitude = coordinates?.[0];
  const latitude = coordinates?.[1];

  if (typeof longitude !== 'number' || typeof latitude !== 'number') {
    return fail('RETRIEVE_EMPTY', 'No pudimos ubicar ese sitio. Elige otro o márcalo en el mapa.');
  }

  return ok({ latitude, longitude });
}

/**
 * El texto de una coordenada: casi siempre una direccion de Amalfi.
 *
 * Devuelve null cuando lo unico que Mapbox sabe decir es el municipio. Un
 * destino que pone "Amalfi" no le sirve a nadie: el conductor tambien esta en
 * Amalfi. En ese caso quien llama debe pedirle al pasajero una referencia.
 */
export async function reverseGeocode(point: Coordinates): Promise<Result<string | null>> {
  if (TOKEN === undefined || TOKEN === '') return NO_TOKEN();

  const url = new URL(`${GEOCODE}/reverse`);
  url.searchParams.set('longitude', String(point.longitude));
  url.searchParams.set('latitude', String(point.latitude));
  url.searchParams.set('access_token', TOKEN);
  url.searchParams.set('language', 'es');

  let body: unknown;
  try {
    const response = await fetch(url.toString());
    body = await response.json();
    if (!response.ok) return fail('REVERSE_FAILED', 'No pudimos leer esa dirección.');
  } catch {
    return NETWORK();
  }

  const feature = (
    body as { features?: { properties?: { name?: string; feature_type?: string } }[] }
  ).features?.[0]?.properties;

  // 'address' y 'street' son utiles. 'place', 'region' o 'country' significan que
  // solo supo decir el municipio, el departamento o el pais.
  const useful = feature?.feature_type === 'address' || feature?.feature_type === 'street';

  return ok(useful && typeof feature?.name === 'string' ? feature.name : null);
}
