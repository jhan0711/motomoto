import { supabase } from '@/lib/supabase';

import { fail, ok, type Place, type Result } from './types';

/**
 * Lectura de los lugares frecuentes del municipio.
 *
 * Va por la funcion `list_places` y no por un select directo a la tabla. El
 * motivo esta en la migracion 11: la columna es de tipo geography y la API REST
 * la devuelve como binario en hexadecimal, que habria que descifrar aqui. La
 * funcion ya entrega latitud y longitud como numeros.
 *
 * Igual que en autenticacion, ninguna funcion de este archivo lanza
 * excepciones: devuelven un resultado que obliga a comprobar si salio bien.
 */

export async function fetchPlaces(): Promise<Result<Place[]>> {
  const { data, error } = await supabase.rpc('list_places');

  if (error) {
    return fail(
      'PLACES_FETCH_FAILED',
      'No pudimos cargar los lugares. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  return ok(
    (data ?? []).map((row) => ({
      id: row.id,
      name: row.name,
      // El generador de tipos declara `description` como `string`, pero la
      // columna admite nulos y la mayoria de los lugares no tienen aclaracion.
      // Se normaliza aqui para que el resto de la aplicacion no herede la
      // mentira del tipo generado.
      description: row.description === null || row.description === '' ? null : row.description,
      latitude: row.lat,
      longitude: row.lng,
    })),
  );
}
