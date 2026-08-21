import { toRideFailure, type RideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

/**
 * Capa de servicio de las calificaciones.
 *
 * Unico punto de la aplicacion que llama a `rate_ride`. Mismo criterio que el
 * resto: ninguna funcion lanza excepciones y todas devuelven un resultado que
 * obliga a mirar si salio bien.
 *
 * NO HAY FUNCION PARA EDITAR NI PARA BORRAR, y no es un olvido: la regla R8 dice
 * una calificacion por parte y por viaje, no editable. Lo sostiene un indice
 * unico en la tabla, asi que aqui no hace falta comprobarlo, solo no ofrecerlo.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

/** El minimo y el maximo son del esquema, no de la pantalla. */
export const MIN_STARS = 1;
export const MAX_STARS = 5;

/** Lo que admite la columna. La pantalla corta antes, para poder avisar. */
export const MAX_COMMENT = 1000;

/**
 * Califica un servicio terminado.
 *
 * `stars` va de 1 a 5: no existe el cero, y por eso la pantalla no deja enviar
 * sin elegir. Un cero significaria "sin calificar", que ya se representa con la
 * ausencia de fila.
 */
export async function rateRide(
  rideId: string,
  stars: number,
  comment?: string,
): Promise<Result<string>> {
  const limpio = comment?.trim() ?? '';

  const { data, error } = await supabase.rpc('rate_ride', {
    p_ride_id: rideId,
    p_stars: stars,
    ...(limpio !== '' ? { p_comment: limpio } : {}),
  });

  if (error) {
    return fail(error);
  }

  // La funcion declara `returns uuid` y no puede devolver nulo sin lanzar antes,
  // pero el tipo generado no lo sabe. Se comprueba en lugar de forzarlo.
  if (typeof data !== 'string' || data === '') {
    return fail(new Error('rate_ride no devolvio un identificador'));
  }

  return ok(data);
}

/**
 * Si esa persona ya califico ese viaje.
 *
 * SE FILTRA POR QUIEN CALIFICA, y no basta con el viaje. La politica
 * `ratings_select_involved` deja ver las dos filas de un mismo servicio —la que
 * uno dio y la que recibio—, asi que preguntar solo por el viaje diria "ya esta
 * calificado" en cuanto la otra parte lo hiciera. Son dos hechos distintos.
 */
export async function hasRated(rideId: string, raterId: string): Promise<Result<boolean>> {
  const { data, error } = await supabase
    .from('ratings')
    .select('id')
    .eq('ride_id', rideId)
    .eq('rater_id', raterId)
    .limit(1);

  if (error) {
    return fail(error);
  }

  return ok((data ?? []).length > 0);
}
