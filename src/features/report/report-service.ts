import { toRideFailure, type RideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

/**
 * Capa de servicio de los reportes (D204).
 *
 * **SE ESCRIBE DIRECTO EN LA TABLA Y NO POR UNA FUNCION**, respetando lo que se
 * decidio al crear `reports_insert_own` en la Fase 1: reportar un problema no
 * puede romper nada -no cambia ningun estado de la operacion- y conviene que
 * sea lo mas facil posible. La politica limita lo unico que importa, que el
 * reporte salga a nombre de quien lo escribe.
 *
 * Mismo criterio que el resto de servicios: ninguna funcion lanza excepciones y
 * todas devuelven un resultado que obliga a mirar si salio bien.
 *
 * NO HAY FUNCION PARA EDITAR NI PARA BORRAR, y no es un olvido: un reporte es lo
 * que alguien dijo que le paso, y ni siquiera la empresa puede reescribirlo
 * (D258). Aqui simplemente no se ofrece.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

/**
 * Los limites son los de la columna -`reports_description_length`-, no los de
 * la pantalla. La pantalla los repite para poder avisar antes de enviar, que es
 * cuando el usuario todavia puede arreglarlo.
 */
export const MIN_DESCRIPCION = 10;
export const MAX_DESCRIPCION = 2000;

/**
 * Manda un reporte.
 *
 * `rideId` es opcional a proposito: **no todos los problemas son con un
 * servicio**. "La aplicacion se cerro sola" no tiene viaje al que colgarse, y
 * obligar a elegir uno haria que la gente escogiera cualquiera con tal de poder
 * enviar.
 */
export async function createReport(
  reporterId: string,
  category: string,
  description: string,
  rideId?: string,
): Promise<Result<string>> {
  const { data, error } = await supabase
    .from('reports')
    .insert({
      reporter_id: reporterId,
      category,
      description: description.trim(),
      ...(rideId !== undefined ? { ride_id: rideId } : {}),
    })
    .select('id')
    .single();

  if (error) {
    return fail(error);
  }

  if (data === null || typeof data.id !== 'string') {
    return fail(new Error('El reporte no devolvio un identificador'));
  }

  return ok(data.id);
}
