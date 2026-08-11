import { supabase } from '@/lib/supabase';
import type { Database } from '@/types/database';

import { toRideFailure, type RideFailure } from './errors';

/**
 * Capa de servicio de las solicitudes.
 *
 * Unico punto de la aplicacion que llama a request_ride, cancel_request y
 * get_active_request. Mismo criterio que auth-service: ninguna pantalla habla
 * directamente con Supabase, y ninguna funcion de aqui lanza excepciones. Todas
 * devuelven un resultado que obliga a mirar si salio bien, porque un `await` sin
 * `try` es la forma mas comun de que un error desaparezca sin dejar rastro.
 *
 * El cliente propone y el servidor decide. Aqui no se valida la zona de
 * servicio, ni la capacidad, ni si el pasajero ya tiene un servicio en curso:
 * todo eso vive en request_ride y llega de vuelta como un codigo traducido.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

export type RideRequestStatus = Database['public']['Enums']['ride_request_status'];

/** Un punto ya resuelto, tal y como lo entiende una persona y el backend. */
export interface RequestPoint {
  latitude: number;
  longitude: number;
  label: string;
}

/**
 * La solicitud viva del pasajero, ya lista para pintar.
 *
 * Es lo que devuelve get_active_request, traducido a los nombres que usa el
 * resto de la aplicacion y con el tipo de secondsRemaining corregido.
 */
/**
 * El conductor que ya tomo el servicio.
 *
 * Nulo mientras nadie lo ha aceptado, y esa es la diferencia que la pantalla
 * necesita: "buscando" y "ya viene" son dos cosas distintas, y hasta la Fase 13
 * el pasajero no tenia forma de distinguirlas.
 */
export interface AssignedDriver {
  rideId: string;
  name: string;
  /** Congelado al pedir el servicio, no leido del perfil. */
  phone: string;
  /**
   * Promedio de estrellas, o null si todavia no tiene ninguna.
   *
   * El servidor guarda un 0 cuando no hay calificaciones, y una calificacion
   * real nunca puede ser 0 porque el minimo es una estrella. Asi que ese cero
   * significa "sin calificar" y no "malisimo", y se traduce aqui para que
   * ninguna pantalla lo pinte como una nota.
   */
  rating: number | null;
  vehicle: { unitNumber: number; plate: string };
}

export interface ActiveRequest {
  id: string;
  status: RideRequestStatus;
  passengerCount: number;
  origin: RequestPoint;
  destination: RequestPoint;
  requestedAt: string;
  expiresAt: string;
  /** Quien viene a recogerlo, cuando ya hay alguien. */
  driver: AssignedDriver | null;
  /**
   * Segundos que le quedan a la busqueda, contados por el servidor.
   *
   * Nulo cuando el estado ya no es 'searching', porque ahi ese numero no
   * significa nada. El generador de tipos de Supabase lo declara como `number` a
   * secas, igual que hizo con `description` en la Fase 9, y es falso: la funcion
   * devuelve null en los demas estados. Se normaliza aqui para que la mentira no
   * se propague al resto de la aplicacion.
   */
  secondsRemaining: number | null;
}

/**
 * Un punto listo para enviar.
 *
 * Deliberadamente mas estrecho que ChosenPoint. Un ChosenPoint encaja aqui sin
 * conversion, pero la ubicacion actual del telefono tambien: no viene de la
 * lista, ni del buscador, ni de un punto del mapa, asi que obligarla a declarar
 * un `source` la obligaria a mentir en uno de los tres.
 */
export interface CreateRequestPoint {
  latitude: number;
  longitude: number;
  label: string;
  /** Solo cuando el punto salio de la lista curada de la empresa. */
  placeId?: string | null;
}

export interface CreateRequestInput {
  /**
   * Ya resuelto a coordenadas. En el borrador, un origen nulo significa "mi
   * ubicacion actual" (D137), y traducir eso a un punto concreto es cosa de la
   * pantalla, que es la unica que sabe donde esta el telefono en ese instante.
   */
  origin: CreateRequestPoint;
  destination: CreateRequestPoint;
  passengerCount: number;
}

/**
 * Crea la solicitud y la deja ofrecida a los conductores cercanos.
 *
 * Devuelve el identificador de la solicitud. Todo lo que puede salir mal llega
 * como codigo en el `hint` y sale de aqui ya traducido: sin motorratones
 * disponibles, fuera de la zona de servicio, un servicio ya en curso, la cuenta
 * bloqueada o el telefono sin registrar.
 */
export async function createRequest(input: CreateRequestInput): Promise<Result<string>> {
  const { data, error } = await supabase.rpc('request_ride', {
    p_origin_lng: input.origin.longitude,
    p_origin_lat: input.origin.latitude,
    p_origin_label: input.origin.label,
    p_destination_lng: input.destination.longitude,
    p_destination_lat: input.destination.latitude,
    p_destination_label: input.destination.label,
    p_passenger_count: input.passengerCount,
    // Solo viajan cuando el punto salio de la lista curada. Sirven para saber
    // despues que lugares se piden de verdad, sin tener que adivinarlo
    // comparando coordenadas.
    ...(input.origin.placeId != null ? { p_origin_place_id: input.origin.placeId } : {}),
    ...(input.destination.placeId != null
      ? { p_destination_place_id: input.destination.placeId }
      : {}),
  });

  if (error) {
    return fail(error);
  }

  // La funcion declara `returns uuid` y no puede devolver nulo sin lanzar antes,
  // pero el tipo generado no lo sabe. Se comprueba en lugar de forzar el tipo:
  // si algun dia cambiara, esto lo diria en vez de dejar un id vacio circulando.
  if (typeof data !== 'string' || data === '') {
    return fail(new Error('request_ride no devolvio un identificador'));
  }

  return ok(data);
}

/**
 * Cancela la solicitud del pasajero.
 *
 * El motivo es opcional a proposito: obligar a escribirlo en el MVP anadiria un
 * paso a alguien que ya decidio irse. La columna existe y el panel podra
 * explotarla en cuanto se pida el motivo (Fase 18).
 */
export async function cancelRequest(requestId: string, reason?: string): Promise<Result> {
  const { error } = await supabase.rpc('cancel_request', {
    p_request_id: requestId,
    ...(reason !== undefined && reason.trim() !== '' ? { p_reason: reason.trim() } : {}),
  });

  if (error) {
    return fail(error);
  }

  return ok(undefined);
}

/**
 * La solicitud viva del pasajero, o null si no tiene ninguna.
 *
 * Devolver null no es un error: es el caso normal, y por eso no viaja como
 * fallo. Un fallo aqui significa que no se pudo preguntar, que es otra cosa muy
 * distinta y se le cuenta al usuario de otra manera.
 */
export async function fetchActiveRequest(): Promise<Result<ActiveRequest | null>> {
  const { data, error } = await supabase.rpc('get_active_request');

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    id: row.id,
    status: row.status,
    passengerCount: row.passenger_count,
    origin: {
      latitude: row.origin_lat,
      longitude: row.origin_lng,
      label: row.origin_label,
    },
    destination: {
      latitude: row.destination_lat,
      longitude: row.destination_lng,
      label: row.destination_label,
    },
    requestedAt: row.requested_at,
    expiresAt: row.expires_at,
    // Aqui se corrige el tipo generado. Ver el comentario de ActiveRequest.
    secondsRemaining:
      typeof row.seconds_remaining === 'number' && Number.isFinite(row.seconds_remaining)
        ? row.seconds_remaining
        : null,
    driver: aConductorAsignado(row),
  });
}

/**
 * Arma el conductor a partir de las columnas sueltas que devuelve la funcion.
 *
 * Basta con mirar `ride_id`: o vienen todas las columnas del conductor o no
 * viene ninguna, porque salen del mismo LEFT JOIN. Aun asi se comprueba cada
 * campo antes de darlo por bueno, porque el generador de tipos de Supabase
 * declara como no nulos varios retornos que si lo admiten, y es la cuarta vez
 * que pasa en este proyecto.
 */
function aConductorAsignado(row: {
  ride_id: string | null;
  driver_name: string | null;
  driver_phone: string | null;
  driver_rating: number | null;
  vehicle_unit_number: number | null;
  vehicle_plate: string | null;
}): AssignedDriver | null {
  if (
    row.ride_id === null ||
    row.driver_name === null ||
    row.driver_phone === null ||
    row.vehicle_unit_number === null ||
    row.vehicle_plate === null
  ) {
    return null;
  }

  const promedio =
    typeof row.driver_rating === 'number' && Number.isFinite(row.driver_rating)
      ? row.driver_rating
      : 0;

  return {
    rideId: row.ride_id,
    name: row.driver_name,
    phone: row.driver_phone,
    rating: promedio > 0 ? promedio : null,
    vehicle: { unitNumber: row.vehicle_unit_number, plate: row.vehicle_plate },
  };
}
