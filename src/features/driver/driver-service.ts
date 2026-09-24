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

/** El motocarro que la empresa le asigno, tal como se le ensena a el. */
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
  /**
   * El valor que propuso el pasajero (D277). Es lo que el conductor cobra si
   * acepta, y lo que decide si le conviene. Nulo solo en solicitudes viejas, de
   * antes de que existieran las tarifas.
   */
  fareAmount: number | null;
  /**
   * Lo que la tabla de tarifas habria cobrado por ese viaje. Sirve para que el
   * conductor vea cuanto se aparta la oferta de la tarifa; nulo cuando no hay.
   */
  fareOfficialAmount: number | null;
  /** Pasajero (con o sin carga) o encomienda sola. */
  serviceType: 'passenger' | 'parcel';
  /** Que es la encomienda. Solo viene cuando `serviceType` es `'parcel'`. */
  parcelDescription: string | null;
  /** La carga en una linea, "2 × Caja, 1 × Bicicleta". Nulo si no lleva. */
  cargoSummary: string | null;
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
 * UNA DE LAS SEIS EXCEPCIONES ACOTADAS DE D83: el cliente escribe directo en
 * lugar de pasar por una funcion, en los dos sentidos. Puede permitirselo
 * porque la politica `drivers_update_own` lo limita a su propia fila y el
 * disparador `drivers_protect_columns` impide que de paso se apruebe a si
 * mismo o se suba la calificacion.
 *
 * ENTRE EL 2026-09-16 Y EL 2026-09-23 apagar exigio un motivo del catalogo
 * (D270), pasando por `set_driver_unavailable`. Se revirtio (D275): la
 * empresa pidio quitarlo, no aporto lo que se esperaba. Volvio a ser un
 * UPDATE directo, igual que encender.
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
    // 23514 es una violacion de restriccion CHECK. Solo puede pasar al
    // encender: que no este aprobado. El mensaje generico de PostgreSQL no le
    // sirve de nada.
    if (error.code === '23514') {
      return {
        ok: false,
        failure: {
          code: 'DRIVER_NOT_APPROVED',
          message: 'Tu cuenta todavía no está aprobada por la empresa.',
        },
      };
    }

    /*
     * DOBLE TURNO (D246). Cuando su companero de motocarro ya esta conectado,
     * el disparador `drivers_one_available_per_vehicle` responde con un mensaje
     * que **dice quien es y con que unidad**: "Juan Perez ya esta conectado con
     * el motocarro 99".
     *
     * Aqui se prefiere ese mensaje al texto fijo del catalogo, y es la unica vez
     * en el proyecto que se hace. El motivo es que el dato viene del servidor y
     * no se puede tener en el cliente: con el nombre delante, el conductor
     * resuelve llamando a su companero; sin el, tiene que llamar a la oficina
     * para preguntar quien esta conectado.
     *
     * Sigue siendo el `hint` el que decide -D88-, no el texto. Si el mensaje
     * llegara vacio, el catalogo pone el respaldo.
     */
    if (error.hint?.trim() === 'COMPANION_ALREADY_AVAILABLE' && error.message.trim() !== '') {
      return {
        ok: false,
        failure: { code: 'COMPANION_ALREADY_AVAILABLE', message: error.message },
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

/**
 * Graba un punto del recorrido de un viaje en curso.
 *
 * Es la tercera excepcion de D83 en la que el cliente escribe directo en una
 * tabla, por lo mismo que `reportLocation`: pasar cada punto por una funcion no
 * anadiria ninguna comprobacion que la politica `ride_locations_insert_own_driver`
 * no haga ya. Esa politica solo deja insertar en un viaje que es de quien llama y
 * esta activo, asi que un conductor no puede escribir en el recorrido de otro.
 *
 * DISTINTO DE `reportLocation`, y conviene no confundirlos. Aquel sobrescribe la
 * UNICA fila de `driver_locations` con la posicion de ahora, para las busquedas y
 * para que el pasajero vea moverse el motocarro. Este ANADE una fila a
 * `ride_locations`, que es el rastro del viaje: nunca se sobrescribe y solo se
 * llena durante el recorrido. De ese rastro sale la distancia que calcula
 * `complete_ride`.
 *
 * Un fallo se devuelve pero no se reintenta: un punto perdido es un hueco en el
 * rastro, y el rastro tolera huecos. Lo que el pasajero ve en vivo va por otra
 * tabla, y `complete_ride` mide con los puntos que haya.
 */
export async function recordTrackPoint(
  rideId: string,
  coords: { latitude: number; longitude: number },
): Promise<Result> {
  const { error } = await supabase.from('ride_locations').insert({
    ride_id: rideId,
    location: `SRID=4326;POINT(${coords.longitude} ${coords.latitude})`,
  });

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
      // El generador de tipos declara estos como no nulos; pueden serlo. Misma
      // trampa que `distance_m` arriba.
      fareAmount: typeof fila.fare_amount === 'number' ? fila.fare_amount : null,
      fareOfficialAmount:
        typeof fila.fare_official_amount === 'number' ? fila.fare_official_amount : null,
      serviceType: fila.service_type,
      parcelDescription: fila.parcel_description ? fila.parcel_description : null,
      // El servidor separa con " x " porque el texto de la base va sin simbolos;
      // aqui se le da la forma que se lee bien en pantalla.
      cargoSummary: fila.cargo_summary ? fila.cargo_summary.replace(/ x /g, ' × ') : null,
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
  /**
   * Como encontrar al pasajero, escrito por el. Null cuando no escribio nada.
   *
   * Llega aqui y no en la oferta a proposito (D172): es del mismo lado de la
   * linea que el nombre y el telefono, y aparece cuando el conductor se
   * compromete a recoger a alguien concreto.
   */
  pickupReference: string | null;
  passengerName: string;
  /** Congelado al pedir el servicio, no leido del perfil. */
  passengerPhone: string;
  acceptedAt: string;
}

/**
 * Los viajes en curso del conductor.
 *
 * Pueden ser varios desde D161, que sustituyo a la regla R7. Van todos en el
 * mismo motocarro: el disparador `enforce_ride_capacity` no admite que un
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
      pickupReference: fila.pickup_reference,
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

/**
 * Las cuatro transiciones del servicio (Fase 15).
 *
 * LAS FUNCIONES YA EXISTIAN DESDE LA FASE 5, escritas y probadas antes de que
 * hubiera una sola pantalla que las llamara. Esto no anade logica: la conecta.
 *
 * Cada una comprueba en el servidor dos cosas que el cliente no puede garantizar
 * (D15): que el viaje es de quien llama, y que el estado actual admite esa
 * transicion. Por eso aqui no hay ninguna comprobacion previa. Preguntar "sigue
 * en camino?" antes de llamar solo abriria una ventana entre la respuesta y la
 * llamada, que es el mismo razonamiento que ya se aplico al aceptar una oferta.
 *
 * `confirmArrival` es la unica que ademas valida contra el mundo fisico: la
 * regla R5 no deja anunciar la llegada a mas de 150 metros del punto de
 * recogida, medidos contra la ultima posicion enviada. Si el conductor no tiene
 * posicion reciente se le permite igualmente, porque en zona de montana perder
 * cobertura es normal y bloquear el servicio por eso seria peor que fiarse.
 */
async function transicion(rpc: RideTransitionRpc, rideId: string): Promise<Result> {
  const { error } = await supabase.rpc(rpc, { p_ride_id: rideId });

  if (error) {
    return fail(error);
  }

  return ok(undefined);
}

/**
 * Los nombres de las cuatro funciones, tipados contra el esquema real.
 *
 * Escribirlos sueltos en cada llamada dejaria que una errata pasara el
 * compilador y fallara en el telefono; asi el tipo generado los valida.
 */
type RideTransitionRpc =
  'start_driving_to_pickup' | 'confirm_driver_arrival' | 'start_ride' | 'complete_ride';

/** Sale hacia el punto de recogida. */
export function startDrivingToPickup(rideId: string): Promise<Result> {
  return transicion('start_driving_to_pickup', rideId);
}

/** Anuncia que llego. Sujeto a la regla R5. */
export function confirmArrival(rideId: string): Promise<Result> {
  return transicion('confirm_driver_arrival', rideId);
}

/** Arranca con el pasajero a bordo. */
export function startRide(rideId: string): Promise<Result> {
  return transicion('start_ride', rideId);
}

/** Termina el servicio. */
export function completeRide(rideId: string): Promise<Result> {
  return transicion('complete_ride', rideId);
}

/**
 * Cancela el servicio (Fase 18).
 *
 * `cancel_ride` existe desde la Fase 5 y hasta ahora ninguna pantalla lo
 * llamaba, mismo caso que las cuatro transiciones de arriba. El servidor
 * decide que pasa segun donde iba el viaje: antes de recoger, la solicitud
 * vuelve a 'searching' y se reofrece a otros conductores; con el pasajero ya
 * a bordo, se cancela con el (D187).
 *
 * El motivo es opcional, mismo criterio que `cancelRequest` del lado del
 * pasajero: obligar a escribirlo anadiria un paso a quien ya decidio no
 * seguir.
 */
export async function cancelRide(rideId: string, reason?: string): Promise<Result> {
  const { error } = await supabase.rpc('cancel_ride', {
    p_ride_id: rideId,
    ...(reason !== undefined && reason.trim() !== '' ? { p_reason: reason.trim() } : {}),
  });

  if (error) {
    return fail(error);
  }

  return ok(undefined);
}
