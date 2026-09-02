import type { CargoItem, ServiceType } from '@/features/fare/types';
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

/**
 * El estado del viaje concreto, que es mas fino que el de la solicitud.
 *
 * La solicitud solo distingue "asignada" de "en curso". El viaje distingue si el
 * conductor todavia no ha salido, si va de camino, si ya llego a esperar o si el
 * pasajero va dentro, y esas cuatro cosas son las que el pasajero quiere saber
 * cuando mira el telefono.
 */
export type RideStatus = Database['public']['Enums']['ride_status'];

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
  /** En que va el viaje: si salio, si llego, si el pasajero ya va dentro. */
  rideStatus: RideStatus;
  /**
   * Su identificador, para suscribirse solo a su posicion.
   *
   * No es informacion nueva del conductor: el pasajero ya recibe su nombre y su
   * telefono desde la Fase 13. Es lo que permite que la suscripcion de tiempo
   * real lleve filtro en vez de escuchar los movimientos de toda la flota.
   */
  id: string;
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
  /** Lo que el pasajero escribio para que lo encuentren, o null si no escribio nada. */
  pickupReference: string | null;
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
  /** Pasajero solo o con carga, contra encomienda sola. */
  serviceType: ServiceType;
  /** Que es la encomienda. Nulo en un viaje de pasajeros. */
  parcelDescription: string | null;
  /**
   * El valor del servicio, ya congelado. Nulo en las solicitudes de antes de
   * D217, que se pidieron cuando la aplicacion todavia no calculaba nada.
   */
  fare: RequestFare | null;
}

/** El valor de un servicio ya pedido, con su desglose y de donde salio. */
export interface RequestFare {
  amount: number;
  tripAmount: number;
  cargoAmount: number;
  isNight: boolean;
  isRural: boolean;
  /** Nombre del destino rural que puso el precio. Nulo si es urbano. */
  reference: string | null;
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
  /**
   * Como encontrar al pasajero, en sus palabras. Opcional.
   *
   * Se envia tal cual y el servidor la recorta y la valida. Recortarla tambien
   * aqui pareceria mas prolijo y seria enganoso: dejaria dos sitios decidiendo
   * lo mismo, y el dia que uno cambiara el otro seguiria con la regla vieja.
   */
  pickupReference?: string | null;
  /** Pasajero solo o con carga, contra encomienda sola. Por defecto, pasajero. */
  serviceType?: ServiceType;
  /** Que es la encomienda. Solo aplica cuando `serviceType` es `'parcel'`. */
  parcelDescription?: string | null;
  /** Lo que lleva el servicio, sea un pasajero con carga o una encomienda sola. */
  cargo?: CargoItem[];
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
    // Solo viaja cuando hay algo escrito. El parametro tiene valor por defecto
    // en el servidor, asi que omitirlo es exactamente lo mismo que enviar nulo.
    ...(input.pickupReference != null && input.pickupReference.trim() !== ''
      ? { p_pickup_reference: input.pickupReference }
      : {}),
    // Los cuatro del bloque especial. Omitirlos deja el valor por defecto del
    // servidor, que es 'passenger' sin carga: un viaje de pasajeros normal
    // sigue enviandose exactamente igual que antes de que estos parametros
    // existieran.
    ...(input.serviceType != null ? { p_service_type: input.serviceType } : {}),
    ...(input.parcelDescription != null && input.parcelDescription.trim() !== ''
      ? { p_parcel_description: input.parcelDescription }
      : {}),
    ...(input.cargo != null && input.cargo.length > 0
      ? {
          p_cargo_type_ids: input.cargo.map((c) => c.cargoTypeId),
          p_cargo_quantities: input.cargo.map((c) => c.quantity),
        }
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
 * El servicio que acaba de terminar, para poder despedirse.
 *
 * Todo lo del viaje puede venir nulo, y hay que tratarlo como algo normal y no
 * como un fallo: la distancia se queda sin calcular cuando el conductor no tuvo
 * cobertura durante el recorrido, y el servidor prefiere no darla antes que dar
 * una inventada.
 */
export interface FinishedRequest {
  id: string;
  /**
   * El viaje concreto, que es lo que hace falta para calificar.
   *
   * Puede venir nulo: la solicitud esta terminada pero el viaje se lee por un
   * LEFT JOIN, y si algun dia no lo encuentra la despedida se pinta igual, solo
   * que sin ofrecer calificar.
   */
  rideId: string | null;
  /** Si quien mira ya califico este servicio. Ver la Fase 17. */
  alreadyRated: boolean;
  originLabel: string;
  destinationLabel: string;
  passengerCount: number;
  completedAt: string;
  meters: number | null;
  seconds: number | null;
  driverName: string | null;
  unitNumber: number | null;
}

/**
 * El ultimo servicio terminado del pasajero, si fue hace poco.
 *
 * Devolver null es el caso normal: significa que no hay nada de que despedirse.
 * Solo se pregunta cuando no hay servicio activo, que es cuando la respuesta
 * puede cambiar algo en pantalla.
 */
export async function fetchFinishedRequest(): Promise<Result<FinishedRequest | null>> {
  const { data, error } = await supabase.rpc('get_finished_request');

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    id: row.id,
    rideId: typeof row.ride_id === 'string' && row.ride_id !== '' ? row.ride_id : null,
    alreadyRated: row.already_rated === true,
    originLabel: row.origin_label,
    destinationLabel: row.destination_label,
    passengerCount: row.passenger_count,
    completedAt: row.completed_at,
    // El generador vuelve a declarar como no nulos tres retornos que si lo
    // admiten. Es la quinta vez, asi que se comprueban en lugar de confiar.
    meters: typeof row.distance_m === 'number' ? row.distance_m : null,
    seconds: typeof row.duration_s === 'number' ? row.duration_s : null,
    driverName: row.driver_name,
    unitNumber: typeof row.vehicle_unit_number === 'number' ? row.vehicle_unit_number : null,
  });
}

/**
 * Donde esta el conductor ahora mismo, y de cuando es ese dato.
 *
 * La antiguedad viaja siempre con la posicion y no es un extra. Un marcador
 * quieto puede significar que el motorraton esta parado en un semaforo o que el
 * conductor se quedo sin cobertura, y son cosas muy distintas para quien espera
 * en la calle. Sin este numero la pantalla no puede distinguirlas, y ensenaria
 * una posicion vieja como si fuera de ahora.
 */
export interface DriverLocation {
  latitude: number;
  longitude: number;
  /** Rumbo en grados, si el GPS lo dio. */
  heading: number | null;
  /**
   * Segundos transcurridos desde el envio.
   *
   * En la primera lectura y al volver de segundo plano lo cuenta el servidor
   * (`get_driver_location`). Entre eventos de tiempo real lo cuenta el telefono
   * a partir de `updatedAt`: solo alimenta un umbral de 120 s -"perdimos la
   * senal"-, no una cuenta atras, asi que el desvio del reloj del telefono no
   * cambia nada.
   */
  ageSeconds: number;
  /** Marca de tiempo del envio, en ISO. Para recalcular `ageSeconds`. */
  updatedAt: string;
}

/**
 * El aviso de que el conductor cancelo con el pasajero a bordo (D187, Fase 18).
 *
 * Solo existe para ESE caso. Si el conductor cancela antes de recoger, la
 * solicitud vuelve a 'searching' y se reofrece: el pasajero sigue viendo
 * "buscando motorratón", que ya es una pantalla honesta, y no necesita esto.
 */
export interface DriverCancelledNotice {
  id: string;
  originLabel: string;
  destinationLabel: string;
  cancelledAt: string;
  /** Nulo si el viaje del conductor no se pudo enlazar. Rarisimo, pero posible. */
  driverName: string | null;
}

/**
 * El ultimo servicio que el conductor cancelo con el pasajero dentro, si fue
 * hace poco.
 *
 * Mismo criterio que `fetchFinishedRequest`: devolver null es el caso normal,
 * y solo importa preguntar cuando no hay servicio activo.
 */
export async function fetchDriverCancelledNotice(): Promise<Result<DriverCancelledNotice | null>> {
  const { data, error } = await supabase.rpc('get_driver_cancelled_notice');

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    id: row.id,
    originLabel: row.origin_label,
    destinationLabel: row.destination_label,
    cancelledAt: row.cancelled_at,
    driverName: row.driver_name,
  });
}

/**
 * Lee la posicion del conductor asignado.
 *
 * Devolver null no es un error: significa que ese conductor no tiene posicion
 * registrada, o que quien pregunta no tiene derecho a verla. Las dos cosas se
 * tratan igual en la pantalla, que simplemente no pinta el motorraton.
 */
export async function fetchDriverLocation(
  driverId: string,
): Promise<Result<DriverLocation | null>> {
  const { data, error } = await supabase.rpc('get_driver_location', { p_driver_id: driverId });

  if (error) {
    return fail(error);
  }

  const row = (data ?? [])[0];
  if (row === undefined) {
    return ok(null);
  }

  return ok({
    latitude: row.latitude,
    longitude: row.longitude,
    // El generador declara numeric como number, pero la columna admite nulo.
    heading: row.heading,
    ageSeconds: row.age_seconds,
    updatedAt: row.updated_at,
  });
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
    pickupReference: row.pickup_reference,
    requestedAt: row.requested_at,
    expiresAt: row.expires_at,
    // Aqui se corrige el tipo generado. Ver el comentario de ActiveRequest.
    secondsRemaining:
      typeof row.seconds_remaining === 'number' && Number.isFinite(row.seconds_remaining)
        ? row.seconds_remaining
        : null,
    serviceType: row.service_type,
    parcelDescription: row.parcel_description,
    fare: aValorDelServicio(row),
    driver: aConductorAsignado(row),
  });
}

/**
 * Arma el valor del servicio a partir de las columnas sueltas.
 *
 * Igual que con el conductor: basta con mirar `fare_amount`, porque la
 * restriccion `rr_fare_all_or_nothing` del servidor garantiza que las cinco
 * columnas de valor llegan juntas o ninguna llega. Se comprueban las cinco de
 * todos modos por el mismo motivo de siempre: el tipo generado las declara como
 * no nulas y no lo son.
 */
function aValorDelServicio(row: {
  fare_amount: number | null;
  fare_trip_amount: number | null;
  fare_cargo_amount: number | null;
  fare_is_night: boolean | null;
  fare_is_rural: boolean | null;
  fare_reference: string | null;
}): RequestFare | null {
  if (
    row.fare_amount === null ||
    row.fare_trip_amount === null ||
    row.fare_cargo_amount === null ||
    row.fare_is_night === null ||
    row.fare_is_rural === null
  ) {
    return null;
  }

  return {
    amount: row.fare_amount,
    tripAmount: row.fare_trip_amount,
    cargoAmount: row.fare_cargo_amount,
    isNight: row.fare_is_night,
    isRural: row.fare_is_rural,
    reference: row.fare_reference,
  };
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
  ride_status: RideStatus | null;
  driver_id: string | null;
  driver_name: string | null;
  driver_phone: string | null;
  driver_rating: number | null;
  vehicle_unit_number: number | null;
  vehicle_plate: string | null;
}): AssignedDriver | null {
  if (
    row.ride_id === null ||
    row.ride_status === null ||
    row.driver_id === null ||
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
    rideStatus: row.ride_status,
    id: row.driver_id,
    name: row.driver_name,
    phone: row.driver_phone,
    rating: promedio > 0 ? promedio : null,
    vehicle: { unitNumber: row.vehicle_unit_number, plate: row.vehicle_plate },
  };
}
