import { toRideFailure, type RideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

import type { EarningsPeriod, EarningsRow } from './types';

/**
 * Capa de servicio del recaudo del conductor (D217, paso 7).
 *
 * Unico punto de la aplicacion que llama a `list_driver_earnings`. Mismo
 * criterio que history-service y ride-service: ninguna funcion lanza
 * excepciones, todas devuelven un resultado que obliga a mirar si salio bien.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

/**
 * Los servicios completados del conductor en un periodo, del mas reciente al
 * mas antiguo.
 *
 * El periodo lo decide el servidor con su propio reloj (D154), no un rango de
 * instantes que mande el telefono: por eso esta funcion solo pasa la palabra
 * del periodo, nunca una fecha.
 */
export async function fetchDriverEarnings(period: EarningsPeriod): Promise<Result<EarningsRow[]>> {
  const { data, error } = await supabase.rpc('list_driver_earnings', { p_period: period });

  if (error) {
    return fail(error);
  }

  return ok(
    (data ?? []).map((row) => ({
      rideId: row.ride_id,
      requestId: row.request_id,
      completedAt: row.completed_at,
      originLabel: row.origin_label,
      destinationLabel: row.destination_label,
      serviceType: row.service_type,
      parcelDescription: typeof row.parcel_description === 'string' ? row.parcel_description : null,
      passengerCount: row.passenger_count,
      fareAmount: typeof row.fare_amount === 'number' ? row.fare_amount : null,
    })),
  );
}
