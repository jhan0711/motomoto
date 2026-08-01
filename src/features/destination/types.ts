import type { Coordinates } from '@/features/map/region';

/** Un lugar frecuente del municipio, gestionado por la empresa. */
export interface Place extends Coordinates {
  id: string;
  name: string;
  /**
   * Aclaracion opcional bajo el nombre: "Estación de policía" bajo "El comando".
   *
   * Se tipa como `string | null` a proposito. El generador de tipos de Supabase
   * lo declara como `string` para el retorno de la funcion, y eso es falso: la
   * columna admite nulos y la mayoria de los lugares no tienen aclaracion.
   */
  description: string | null;
}

/** De donde salio un destino. Cambia lo que se le puede mostrar al pasajero. */
export type DestinationSource =
  /** De la lista curada de la empresa. El caso bueno: nombre reconocible. */
  | 'place'
  /** Del buscador de direcciones de Mapbox. */
  | 'search'
  /** De un punto que el pasajero solto en el mapa. */
  | 'map';

/**
 * Un origen o un destino ya elegido.
 *
 * Guarda siempre la coordenada, que es lo unico que el backend necesita, mas el
 * texto con el que se le enseña a una persona. El conductor no puede trabajar
 * con "6,9047 / -75,0767".
 */
export interface ChosenPoint extends Coordinates {
  /** Linea principal: "El comando", "Cerca de El parque", "Calle 20 18 047". */
  label: string;
  /** Linea de apoyo, cuando aporta algo: la direccion bajo el nombre del lugar. */
  detail: string | null;
  source: DestinationSource;
  /** Presente solo cuando viene de la lista. Lo necesita `request_ride`. */
  placeId: string | null;
}

/** Mismo criterio que en autenticacion (D88, D96): codigo estable y mensaje. */
export interface DestinationFailure {
  /** Lo que se compara en el codigo y en las pruebas. */
  code: string;
  /** Lo que se le muestra al pasajero. */
  message: string;
}

export type Result<T> = { ok: true; data: T } | { ok: false; failure: DestinationFailure };

export function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

export function fail<T = never>(code: string, message: string): Result<T> {
  return { ok: false, failure: { code, message } };
}
