import { toRideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

import { fail, ok, type CargoItem, type FareQuote, type Result, type ServiceType } from './types';

export interface QuoteFareInput {
  serviceType: ServiceType;
  passengerCount: number;
  /**
   * Los dos extremos, no solo el destino (D233). Un viaje hacia una vereda
   * cuesta lo mismo que el mismo viaje de vuelta: el conductor recorre la
   * misma distancia en los dos sentidos, asi que el origen decide el precio
   * tanto como el destino.
   */
  originLatitude: number;
  originLongitude: number;
  originPlaceId?: string | null;
  destinationLatitude: number;
  destinationLongitude: number;
  destinationPlaceId?: string | null;
  cargo: CargoItem[];
}

/**
 * Cuanto va a costar el servicio, antes de pedirlo.
 *
 * Llama a la MISMA funcion que usara `request_ride` para congelar el valor
 * (`quote_fare`), y esa es la unica razon de que exista este archivo en lugar
 * de calcular algo parecido en el telefono: si el calculo vivera aqui tambien,
 * el dia que alguien tocara la formula del servidor sin tocar esta, el pasajero
 * veria un numero y pagaria otro.
 *
 * Sin `p_at`: se deja que el servidor use su propio reloj, que es el mismo que
 * usara al crear la solicitud un instante despues. Pasar la hora del telefono
 * abriria la puerta a la que D219... no, a la que motivo D222: la hora que
 * decide el recargo nocturno no puede ser la que alguien cambio en los ajustes.
 */
export async function quoteFare(input: QuoteFareInput): Promise<Result<FareQuote>> {
  const { data, error } = await supabase.rpc('quote_fare', {
    p_service_type: input.serviceType,
    p_passenger_count: input.passengerCount,
    p_origin_lng: input.originLongitude,
    p_origin_lat: input.originLatitude,
    p_destination_lng: input.destinationLongitude,
    p_destination_lat: input.destinationLatitude,
    ...(input.originPlaceId != null ? { p_origin_place_id: input.originPlaceId } : {}),
    ...(input.destinationPlaceId != null
      ? { p_destination_place_id: input.destinationPlaceId }
      : {}),
    ...(input.cargo.length > 0
      ? {
          p_cargo_type_ids: input.cargo.map((c) => c.cargoTypeId),
          p_cargo_quantities: input.cargo.map((c) => c.quantity),
        }
      : {}),
  });

  if (error) {
    return fail(toRideFailure(error));
  }

  const row = (data ?? [])[0];

  if (row === undefined) {
    return fail(toRideFailure(new Error('quote_fare no devolvio ninguna fila')));
  }

  return ok({
    isRural: row.is_rural,
    isNight: row.is_night,
    tripAmount: row.trip_amount,
    cargoAmount: row.cargo_amount,
    totalAmount: row.total_amount,
    reference: row.reference === null || row.reference === '' ? null : row.reference,
  });
}

/** Una linea de carga ya guardada, con su nombre y su precio congelado. */
export interface RequestCargoLine {
  cargoTypeName: string;
  quantity: number;
  unitAmount: number;
}

/**
 * La carga de una solicitud concreta, con el nombre de cada tipo.
 *
 * Select directo, con el mismo criterio que `fetchCargoTypes`: no hay geografia
 * que decodificar. La politica `ride_request_cargo_select_participants` ya deja
 * pasar al dueno de la solicitud y al conductor vinculado; no hace falta ninguna
 * funcion nueva para exponer lo mismo que la politica ya permite.
 */
export async function fetchRequestCargo(requestId: string): Promise<Result<RequestCargoLine[]>> {
  const { data, error } = await supabase
    .from('ride_request_cargo')
    .select('quantity, unit_amount, cargo_types(name)')
    .eq('request_id', requestId);

  if (error) {
    return fail(toRideFailure(error));
  }

  return ok(
    (data ?? []).map((row) => ({
      // El generador declara la relacion embebida como un arreglo aunque solo
      // pueda traer una fila, porque no conoce la relacion 1:1 que aqui si hay
      // por la clave foranea. Se toma el primer elemento y, si faltara, un
      // nombre generico en vez de romper la lista entera por una fila.
      cargoTypeName: row.cargo_types?.name ?? 'Carga',
      quantity: row.quantity,
      unitAmount: row.unit_amount,
    })),
  );
}
