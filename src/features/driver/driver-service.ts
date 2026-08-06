import { toRideFailure, type RideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';
import type { Database } from '@/types/database';

/**
 * Capa de servicio del conductor.
 *
 * Unico punto de la aplicacion que consulta su disponibilidad, su vehiculo y sus
 * ofertas. Mismo criterio que auth-service y ride-service: ninguna funcion lanza
 * excepciones y todas devuelven un resultado que obliga a mirar si salio bien.
 *
 * Comparte la traduccion de errores con el lado del pasajero, en
 * features/ride/errors.ts, porque los codigos vienen de las mismas funciones de
 * base de datos. Tener dos tablas de mensajes seria garantizar que se separan.
 */

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: RideFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toRideFailure(error) };
}

export type ApprovalStatus = Database['public']['Enums']['driver_approval_status'];

/** El motorraton que la empresa le asigno, tal como se le ensena a el. */
export interface DriverVehicle {
  /** DECISION D55: es como identifica la gente a las unidades, antes que la placa. */
  unitNumber: number;
  plate: string;
  model: string | null;
  maxPassengers: number;
}

export interface DriverState {
  isAvailable: boolean;
  approvalStatus: ApprovalStatus;
  ratingAverage: number;
  ratingCount: number;
  /**
   * Nulo cuando la empresa todavia no le asigno ninguno. No es un caso raro: un
   * conductor recien dado de alta esta exactamente asi, y sin vehiculo no puede
   * aceptar nada porque accept_ride_offer lo rechaza con NO_VEHICLE_ASSIGNED.
   */
  vehicle: DriverVehicle | null;
}

/** Una solicitud que le han ofrecido y todavia puede tomar. */
export interface DriverOffer {
  offerId: string;
  requestId: string;
  expiresAt: string;
  /** Contados por el servidor, no por el reloj del telefono. Mismo criterio que D154. */
  secondsRemaining: number;
  /** Del conductor al punto de recogida. Nulo si no se pudo calcular. */
  distanceM: number | null;
  passengerCount: number;
  origin: { latitude: number; longitude: number; label: string };
  destination: { latitude: number; longitude: number; label: string };
  requestedAt: string;
}

/**
 * Su estado y su vehiculo.
 *
 * Dos consultas y no una: la asignacion de vehiculo puede no existir, y un join
 * obligatorio devolveria cero filas para un conductor recien dado de alta, que
 * es justo el caso que hay que saber distinguir de "hubo un error".
 */
export async function fetchDriverState(driverId: string): Promise<Result<DriverState>> {
  const { data: driver, error: driverError } = await supabase
    .from('drivers')
    .select('is_available, approval_status, rating_average, rating_count')
    .eq('id', driverId)
    .single();

  if (driverError) {
    return fail(driverError);
  }

  const { data: assignment, error: assignmentError } = await supabase
    .from('driver_vehicle_assignments')
    .select('vehicles (unit_number, plate, model, max_passengers)')
    .eq('driver_id', driverId)
    .is('unassigned_at', null)
    .maybeSingle();

  if (assignmentError) {
    return fail(assignmentError);
  }

  const vehiculo = assignment?.vehicles ?? null;

  return ok({
    isAvailable: driver.is_available,
    approvalStatus: driver.approval_status,
    ratingAverage: Number(driver.rating_average),
    ratingCount: driver.rating_count,
    vehicle:
      vehiculo === null
        ? null
        : {
            unitNumber: vehiculo.unit_number,
            plate: vehiculo.plate,
            model: vehiculo.model,
            maxPassengers: vehiculo.max_passengers,
          },
  });
}

/**
 * Enciende o apaga la disponibilidad.
 *
 * Es una de las seis excepciones acotadas de D83: el cliente escribe directo en
 * lugar de pasar por una funcion. Puede permitirselo porque la politica
 * `drivers_update_own` lo limita a su propia fila y el disparador
 * `drivers_protect_columns` impide que de paso se apruebe a si mismo o se suba
 * la calificacion.
 *
 * Si intenta ponerse disponible sin estar aprobado, la restriccion
 * `drivers_available_only_when_approved` lo rechaza en la base de datos. La
 * pantalla no deberia dejarle llegar ahi, pero la comprobacion de verdad esta
 * donde no se puede saltar.
 */
export async function setAvailability(driverId: string, available: boolean): Promise<Result> {
  const { error } = await supabase
    .from('drivers')
    .update({ is_available: available })
    .eq('id', driverId);

  if (error) {
    // 23514 es una violacion de restriccion CHECK. Aqui solo puede ser una: que
    // no este aprobado. El mensaje generico de PostgreSQL no le sirve de nada.
    if (error.code === '23514') {
      return {
        ok: false,
        failure: {
          code: 'DRIVER_NOT_APPROVED',
          message: 'Tu cuenta todavía no está aprobada por la empresa.',
        },
      };
    }
    return fail(error);
  }

  return ok(undefined);
}

/**
 * Registra donde esta el conductor ahora mismo.
 *
 * Es la otra excepcion de D83 en la que el cliente escribe directo, y aqui no
 * cabe otra: la posicion se manda cada treinta segundos y meterla por una
 * funcion no anadiria ninguna comprobacion que las politicas
 * `driver_locations_insert_own` y `_update_own` no hagan ya.
 *
 * El punto viaja como texto en formato EWKT. Se comprobo contra el servidor que
 * PostgREST lo acepta para una columna geography, tanto con SRID declarado como
 * sin el. Se declara igualmente, para no depender de que el sistema suponga bien
 * cual es.
 *
 * `updated_at` no se envia: la columna tiene valor por defecto al insertar y un
 * disparador que la reescribe al actualizar. Mandarla seria darle un valor que
 * la base de datos va a ignorar, y ademas es justo lo que decide si este
 * conductor sigue siendo elegible.
 */
export async function reportLocation(
  driverId: string,
  coords: { latitude: number; longitude: number },
  extras?: { heading?: number | null; speedKmh?: number | null; accuracyM?: number | null },
): Promise<Result> {
  const { error } = await supabase.from('driver_locations').upsert(
    {
      driver_id: driverId,
      location: `SRID=4326;POINT(${coords.longitude} ${coords.latitude})`,
      heading: extras?.heading ?? null,
      speed_kmh: extras?.speedKmh ?? null,
      accuracy_m: extras?.accuracyM ?? null,
    },
    { onConflict: 'driver_id' },
  );

  if (error) {
    return fail(error);
  }

  return ok(undefined);
}

/** Las solicitudes que puede tomar ahora mismo. */
export async function fetchOffers(): Promise<Result<DriverOffer[]>> {
  const { data, error } = await supabase.rpc('list_driver_offers');

  if (error) {
    return fail(error);
  }

  return ok(
    (data ?? []).map((fila) => ({
      offerId: fila.offer_id,
      requestId: fila.request_id,
      expiresAt: fila.expires_at,
      secondsRemaining: fila.seconds_remaining,
      // Tercera vez que el generador de tipos declara como no nulo un retorno
      // que si lo admite, despues de `description` en la Fase 9 y de
      // `seconds_remaining` en la 11. La columna distance_m acepta nulos.
      distanceM:
        typeof fila.distance_m === 'number' && Number.isFinite(fila.distance_m)
          ? fila.distance_m
          : null,
      passengerCount: fila.passenger_count,
      origin: {
        latitude: fila.origin_lat,
        longitude: fila.origin_lng,
        label: fila.origin_label,
      },
      destination: {
        latitude: fila.destination_lat,
        longitude: fila.destination_lng,
        label: fila.destination_label,
      },
      requestedAt: fila.requested_at,
    })),
  );
}

export type RideStatus = Database['public']['Enums']['ride_status'];

/**
 * Un viaje que el conductor lleva en curso, con quien va dentro.
 *
 * Aqui si estan el nombre y el telefono. Es lo que separa una oferta, donde el
 * conductor decide con el viaje, de un servicio aceptado, donde ya se
 * comprometio a recoger a alguien concreto.
 */
export interface DriverRide {
  rideId: string;
  requestId: string;
  status: RideStatus;
  passengerCount: number;
  origin: { latitude: number; longitude: number; label: string };
  destination: { latitude: number; longitude: number; label: string };
  passengerName: string;
  /** Congelado al pedir el servicio, no leido del perfil. */
  passengerPhone: string;
  acceptedAt: string;
}

/**
 * Los viajes en curso del conductor.
 *
 * Pueden ser varios desde D161, que sustituyo a la regla R7. Van todos en el
 * mismo motorraton: el disparador `enforce_ride_capacity` no admite que un
 * conductor tenga servicios activos en dos unidades a la vez, y por eso la
 * pantalla puede sumar los pasajeros de esta lista para saber cuantos asientos
 * le quedan libres sin preguntarselo al servidor.
 */
export async function fetchActiveRides(): Promise<Result<DriverRide[]>> {
  const { data, error } = await supabase.rpc('list_driver_active_rides');

  if (error) {
    return fail(error);
  }

  return ok(
    (data ?? []).map((fila) => ({
      rideId: fila.ride_id,
      requestId: fila.request_id,
      status: fila.status,
      passengerCount: fila.passenger_count,
      origin: {
        latitude: fila.origin_lat,
        longitude: fila.origin_lng,
        label: fila.origin_label,
      },
      destination: {
        latitude: fila.destination_lat,
        longitude: fila.destination_lng,
        label: fila.destination_label,
      },
      passengerName: fila.passenger_name,
      passengerPhone: fila.passenger_phone,
      acceptedAt: fila.accepted_at,
    })),
  );
}

/**
 * Toma el servicio. Devuelve el identificador del viaje creado.
 *
 * Aqui no hay ninguna comprobacion previa a proposito. Preguntar "sigue libre?"
 * y despues aceptar deja una rendija entre las dos llamadas por la que se cuela
 * el otro conductor. La base de datos resuelve la carrera con un indice unico
 * parcial, y quien pierde recibe REQUEST_ALREADY_TAKEN, que no es un error sino
 * el desenlace normal de que dos personas quieran el mismo viaje.
 *
 * Desde D161 hay una segunda carrera con el mismo criterio, y esta la puede
 * perder un conductor contra si mismo: con dos ofertas vivas a la vez puede
 * aceptar una y quedarse sin sitio para la otra. El servidor responde
 * VEHICLE_CAPACITY_EXCEEDED y tampoco es un fallo.
 */
export async function acceptOffer(offerId: string): Promise<Result<string>> {
  const { data, error } = await supabase.rpc('accept_ride_offer', { p_offer_id: offerId });

  if (error) {
    return fail(error);
  }

  if (typeof data !== 'string' || data === '') {
    return fail(new Error('accept_ride_offer no devolvio un identificador'));
  }

  return ok(data);
}

/**
 * Rechaza la solicitud.
 *
 * REGLA R12: no se le vuelve a ofrecer. Es definitivo y por eso la pantalla no
 * deberia pedirlo con un boton facil de tocar sin querer.
 */
export async function rejectOffer(offerId: string): Promise<Result> {
  const { error } = await supabase.rpc('reject_ride_offer', { p_offer_id: offerId });

  if (error) {
    return fail(error);
  }

  return ok(undefined);
}
