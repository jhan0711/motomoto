import { toRideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

import { fail, ok, type CargoType, type Result } from './types';

/**
 * El catalogo de tipos de carga que ofrece la empresa.
 *
 * Select directo a la tabla y no una funcion, al reves que `places`: aqui no
 * hay ninguna columna geography que decodificar, asi que una funcion de solo
 * lectura no aportaria nada sobre lo que ya hace la politica
 * `cargo_types_select_active`. Mismo criterio que usa auth-service.ts para leer
 * `drivers`.
 */
export async function fetchCargoTypes(): Promise<Result<CargoType[]>> {
  const { data, error } = await supabase
    .from('cargo_types')
    .select('id, name, amount')
    .eq('is_active', true)
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true });

  if (error) {
    return fail(toRideFailure(error));
  }

  return ok((data ?? []).map((row) => ({ id: row.id, name: row.name, amount: row.amount })));
}
