import type { ServiceType } from './types';

/**
 * Lo que la tabla de tarifas habria cobrado por un servicio (D277).
 *
 * Desde que el pasajero propone el valor, `fare_amount` es lo acordado y ya no
 * tiene por que coincidir con el desglose (`fare_trip_amount` y
 * `fare_cargo_amount`), que sigue siendo el de la tarifa oficial. Esta es la
 * misma cuenta que hace `quote_fare`: en una encomienda manda la mayor de las
 * dos partes, en un viaje de pasajeros se suman. Nulo si no hay desglose.
 */
export function officialFareAmount(
  serviceType: ServiceType,
  tripAmount: number | null,
  cargoAmount: number | null,
): number | null {
  if (tripAmount === null || cargoAmount === null) return null;
  return serviceType === 'parcel' ? Math.max(tripAmount, cargoAmount) : tripAmount + cargoAmount;
}
