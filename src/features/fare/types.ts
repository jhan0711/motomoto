import type { RideFailure } from '@/features/ride/errors';

/**
 * Tipos del bloque especial: tarifas, encomiendas y carga.
 *
 * Mismo criterio que destination/types.ts: cada modulo de funcionalidad tiene su
 * propio Result en lugar de importar el de ride-service.ts, porque este tambien
 * tiene sus propias funciones que fallan de formas distintas.
 */
export type Result<T> = { ok: true; data: T } | { ok: false; failure: RideFailure };

export function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

export function fail<T = never>(failure: RideFailure): Result<T> {
  return { ok: false, failure };
}

/**
 * Que se transporta. Con carga o sin ella es lo mismo tipo: la carga es una
 * lista aparte, no un tercer valor (D224). Confundir "pasajero con carga" con
 * "encomienda" en un enum de tres habria permitido guardar una encomienda con
 * pasajeros a bordo sin que nada lo impidiera en el tipo.
 */
export type ServiceType = 'passenger' | 'parcel';

/** Un tipo de carga del catalogo de la empresa, con su precio de hoy. */
export interface CargoType {
  id: string;
  name: string;
  amount: number;
}

/**
 * Una linea de carga a medio elegir, antes de confirmar.
 *
 * No lleva precio: el precio de cada linea sale del catalogo mientras se esta
 * eligiendo, y se congela en el servidor solo cuando `request_ride` la guarda
 * (D225). Guardarlo aqui tambien crearia dos copias del mismo dato que podrian
 * desincronizarse si el catalogo cambia mientras el pasajero decide.
 */
export interface CargoItem {
  cargoTypeId: string;
  quantity: number;
}

/**
 * El valor de un servicio, con su desglose. Lo que devuelve `quote_fare`.
 *
 * `reference` es el nombre del punto que puso el precio -"Montañita", "El
 * Taparo"- y viene nulo en un viaje urbano, que no tiene de que colgarse (D226,
 * D230).
 */
export interface FareQuote {
  isRural: boolean;
  isNight: boolean;
  tripAmount: number;
  cargoAmount: number;
  totalAmount: number;
  reference: string | null;
}
