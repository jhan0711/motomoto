import { toRideFailure, type RideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';
import type { Database } from '@/types/database';

/**
 * Capa de servicio del historial.
 *
 * Unico punto de la aplicacion que llama a `list_passenger_history` y, desde el
 * paso 3, a `list_driver_history`. Mismo criterio que ride-service y
 * driver-service: ninguna funcion lanza excepciones, todas devuelven un
 * resultado que obliga a mirar si salio bien.
 *
 * Comparte la traduccion de errores con las dos, en features/ride/errors.ts,
 * porque los codigos vienen de las mismas funciones de base de datos.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

/**
 * Cuantas filas se piden de una vez.
 *
 * Veinte llenan mas de una pantalla en el telefono mas alto, asi que el
 * pasajero nunca ve el final de la lista antes de que llegue la siguiente
 * tanda. El servidor corta en 50 aunque se le pida mas.
 */
export const HISTORY_PAGE_SIZE = 20;

export type PassengerTripStatus = Database['public']['Enums']['ride_request_status'];
export type Actor = Database['public']['Enums']['actor_type'];

/**
 * Un servicio cerrado, tal y como se le ensena al pasajero.
 *
 * `status` solo puede traer los tres finales: terminado, cancelado y caducado.
 * El tipo abarca los seis porque es el del esquema, y estrecharlo aqui a mano
 * seria repetir una regla que ya vive en la funcion.
 *
 * TODO LO DEL VIAJE PUEDE VENIR NULO, y es lo normal: una solicitud que caduco
 * no tuvo conductor, y una que si lo tuvo puede no tener distancia si el
 * conductor se quedo sin cobertura durante el recorrido.
 */
export interface PassengerTrip {
  requestId: string;
  status: PassengerTripStatus;
  requestedAt: string;
  /** Cuando dejo de estar viva, sea por terminar, por cancelarse o por caducar. */
  finishedAt: string;
  originLabel: string;
  destinationLabel: string;
  passengerCount: number;
  cancelledBy: Actor | null;
  cancellationReason: string | null;
  rideId: string | null;
  meters: number | null;
  seconds: number | null;
  driverName: string | null;
  unitNumber: number | null;
  plate: string | null;
}

/**
 * Una pagina del historial del pasajero, de la mas reciente a la mas antigua.
 *
 * Devolver menos filas de las pedidas significa que no hay mas. Es el contrato
 * que usa el gancho para saber cuando dejar de pedir.
 */
export async function fetchPassengerHistory(
  limit: number,
  offset: number,
): Promise<Result<PassengerTrip[]>> {
  const { data, error } = await supabase.rpc('list_passenger_history', {
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return fail(error);
  }

  return ok(
    (data ?? []).map((row) => ({
      requestId: row.request_id,
      status: row.status,
      requestedAt: row.requested_at,
      finishedAt: row.finished_at,
      originLabel: row.origin_label,
      destinationLabel: row.destination_label,
      passengerCount: row.passenger_count,
      // El generador de tipos declara como no nulas siete columnas que si
      // admiten nulo. Es la sexta vez que pasa en el proyecto, asi que se
      // comprueban en lugar de confiar: un nulo colado como string revienta
      // mas tarde y lejos, al pintarlo.
      cancelledBy: texto(row.cancelled_by) as Actor | null,
      cancellationReason: texto(row.cancellation_reason),
      rideId: texto(row.ride_id),
      meters: numero(row.distance_m),
      seconds: numero(row.duration_s),
      driverName: texto(row.driver_name),
      unitNumber: numero(row.vehicle_unit_number),
      plate: texto(row.vehicle_plate),
    })),
  );
}

/**
 * Como acabo una oferta, que es la unidad del historial del conductor.
 *
 * Son cinco y no cuatro. `taken_by_other` esta separado de `expired` a
 * proposito: cuando otro conductor acepta primero, las ofertas que seguian
 * pendientes se marcan caducadas en la base de datos, y sin distinguirlo la
 * pantalla le diria "se agoto el tiempo" a alguien que no dejo pasar nada.
 */
export type JobOutcome =
  | 'completed'
  | 'cancelled'
  | 'rejected'
  | 'taken_by_other'
  | 'expired'
  /** No es del servidor: es lo que se pinta si algun dia llega un valor que esta pantalla no conoce. */
  | 'unknown';

/**
 * Una oferta cerrada, tal y como se le ensena al conductor.
 *
 * NO ES UN VIAJE, y esa es la diferencia con `PassengerTrip`. Aqui hay una fila
 * por cada vez que el sistema le propuso un servicio, lo tomara o no, porque
 * "cuantas rechace" solo se puede leer si las rechazadas estan.
 *
 * `passengerName` viene en blanco en todo lo que no acepto. Quien es el
 * pasajero no se ve hasta aceptar, desde la Fase 12, y el servidor lo aplica:
 * no es una decision de esta pantalla.
 */
export interface DriverJob {
  offerId: string;
  requestId: string;
  rideId: string | null;
  outcome: JobOutcome;
  offeredAt: string;
  finishedAt: string;
  originLabel: string;
  destinationLabel: string;
  passengerCount: number;
  /** Lo que habia hasta el punto de recogida cuando le llego la oferta. */
  pickupMeters: number | null;
  meters: number | null;
  seconds: number | null;
  cancelledBy: Actor | null;
  passengerName: string | null;
}

/** Una pagina del historial del conductor, de la mas reciente a la mas antigua. */
export async function fetchDriverHistory(
  limit: number,
  offset: number,
): Promise<Result<DriverJob[]>> {
  const { data, error } = await supabase.rpc('list_driver_history', {
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    return fail(error);
  }

  return ok(
    (data ?? []).map((row) => ({
      offerId: row.offer_id,
      requestId: row.request_id,
      rideId: texto(row.ride_id),
      // La funcion devuelve `text` y no un tipo enumerado, asi que aqui se
      // comprueba de verdad en vez de forzarlo: un valor nuevo en el servidor
      // sin su rama en la pantalla se veria como un desenlace desconocido, y no
      // como una fila rota.
      outcome: aOutcome(row.outcome),
      offeredAt: row.offered_at,
      finishedAt: row.finished_at,
      originLabel: row.origin_label,
      destinationLabel: row.destination_label,
      passengerCount: row.passenger_count,
      pickupMeters: numero(row.pickup_distance_m),
      meters: numero(row.distance_m),
      seconds: numero(row.duration_s),
      cancelledBy: texto(row.cancelled_by) as Actor | null,
      passengerName: texto(row.passenger_name),
    })),
  );
}

const OUTCOMES: readonly JobOutcome[] = [
  'completed',
  'cancelled',
  'rejected',
  'taken_by_other',
  'expired',
];

function aOutcome(valor: string): JobOutcome {
  // Un valor nuevo en el servidor no se disfraza del que mas se le parezca. Se
  // marca como desconocido, que en pantalla es una fila completa sin etiqueta
  // inventada, y no una mentira con buen aspecto.
  return OUTCOMES.includes(valor as JobOutcome) ? (valor as JobOutcome) : 'unknown';
}

function texto(valor: string | null): string | null {
  return typeof valor === 'string' && valor !== '' ? valor : null;
}

function numero(valor: number | null): number | null {
  return typeof valor === 'number' && Number.isFinite(valor) ? valor : null;
}

/**
 * Un servicio cerrado del pasajero, con todo lo que no cabia en la lista.
 *
 * La linea de tiempo sale del viaje, no de la solicitud: solo el viaje sabe
 * cuando el conductor llego a esperar, y ese es el momento que la gente
 * recuerda. En una solicitud que caduco no hay ninguna de las cuatro horas.
 */
export interface PassengerTripDetail extends PassengerTrip {
  pickupReference: string | null;
  expiresAt: string;
  cancelledAt: string | null;
  acceptedAt: string | null;
  driverArrivedAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
}

/** Un servicio cerrado del pasajero. Devolver null es "no es tuyo o no existe". */
export async function fetchPassengerTrip(
  requestId: string,
): Promise<Result<PassengerTripDetail | null>> {
  const { data, error } = await supabase.rpc('get_passenger_trip', {
    p_request_id: requestId,
  });

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    requestId: row.request_id,
    status: row.status,
    requestedAt: row.requested_at,
    // El detalle no trae `finished_at` calculado: aqui estan las horas sueltas,
    // que es justo lo que esta pantalla necesita, y la de cierre se arma con las
    // mismas tres candidatas que usa la lista.
    finishedAt: texto(row.completed_at) ?? texto(row.cancelled_at) ?? row.expires_at,
    originLabel: row.origin_label,
    destinationLabel: row.destination_label,
    pickupReference: texto(row.pickup_reference),
    passengerCount: row.passenger_count,
    expiresAt: row.expires_at,
    cancelledAt: texto(row.cancelled_at),
    cancelledBy: texto(row.cancelled_by) as Actor | null,
    cancellationReason: texto(row.cancellation_reason),
    rideId: texto(row.ride_id),
    acceptedAt: texto(row.accepted_at),
    driverArrivedAt: texto(row.driver_arrived_at),
    startedAt: texto(row.started_at),
    completedAt: texto(row.completed_at),
    meters: numero(row.distance_m),
    seconds: numero(row.duration_s),
    driverName: texto(row.driver_name),
    unitNumber: numero(row.vehicle_unit_number),
    plate: texto(row.vehicle_plate),
  });
}

/**
 * Una oferta cerrada del conductor, con su linea de tiempo.
 *
 * `passengerName` y `pickupReference` van en blanco si no la acepto. Los dos son
 * datos de una persona concreta, y el servidor los retiene: no depende de que
 * esta pantalla se acuerde de no pintarlos.
 */
export interface DriverJobDetail extends DriverJob {
  offerExpiresAt: string;
  /** Cuando dejo de estar pendiente, la respondiera el o la respondiera el reloj. */
  respondedAt: string | null;
  pickupReference: string | null;
  requestedAt: string;
  acceptedAt: string | null;
  driverArrivedAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
}

/** Una oferta cerrada del conductor. Devolver null es "no es tuya o no existe". */
export async function fetchDriverJob(offerId: string): Promise<Result<DriverJobDetail | null>> {
  const { data, error } = await supabase.rpc('get_driver_job', { p_offer_id: offerId });

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    offerId: row.offer_id,
    requestId: row.request_id,
    rideId: texto(row.ride_id),
    outcome: aOutcome(row.outcome),
    offeredAt: row.offered_at,
    offerExpiresAt: row.offer_expires_at,
    respondedAt: texto(row.responded_at),
    finishedAt:
      texto(row.completed_at) ??
      texto(row.cancelled_at) ??
      texto(row.responded_at) ??
      row.offer_expires_at,
    requestedAt: row.requested_at,
    originLabel: row.origin_label,
    destinationLabel: row.destination_label,
    pickupReference: texto(row.pickup_reference),
    passengerCount: row.passenger_count,
    pickupMeters: numero(row.pickup_distance_m),
    acceptedAt: texto(row.accepted_at),
    driverArrivedAt: texto(row.driver_arrived_at),
    startedAt: texto(row.started_at),
    completedAt: texto(row.completed_at),
    cancelledAt: texto(row.cancelled_at),
    cancelledBy: texto(row.cancelled_by) as Actor | null,
    cancellationReason: texto(row.cancellation_reason),
    meters: numero(row.distance_m),
    seconds: numero(row.duration_s),
    passengerName: texto(row.passenger_name),
  });
}
