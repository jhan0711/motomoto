/**
 * Traduccion de los errores que devuelven las funciones de la base de datos.
 *
 * Hermano de features/auth/errors.ts y con el mismo criterio (D88, D96): un
 * codigo estable para comparar en el codigo y en las pruebas, y un mensaje en
 * espanol solo para mostrar. El codigo es lo que se compara, nunca el texto.
 *
 * Por que se traduce aqui y no se muestra el mensaje del servidor. Las funciones
 * de la base de datos ya devuelven un texto en espanol, pero escrito sin tildes
 * (hallazgo H8), lo que incumple D56. Ademas, mostrar el mensaje del servidor
 * ataria los textos de la interfaz al esquema: cambiar una frase exigiria una
 * migracion. Con esta capa, el servidor manda el codigo y la aplicacion decide
 * como se lo cuenta al usuario.
 *
 * Como llegan. Cuando una funcion hace `raise ... using hint = 'X'`, PostgREST
 * devuelve ese texto en el campo `hint` del error, y en `code` el SQLSTATE, que
 * siempre es P0001. Por eso lo que se lee aqui es `hint` y no `code`.
 */

export interface RideFailure {
  /** Codigo estable. Es lo que se compara, nunca el mensaje. */
  code: string;
  /** Texto listo para mostrar al usuario. */
  message: string;
}

/**
 * Codigos que pueden llegar en esta fase y su equivalente en espanol.
 *
 * Cubre lo que request_ride, cancel_request y get_active_request pueden lanzar
 * de verdad hoy. Los codigos del conductor, que son otros doce, se anaden en las
 * fases 12 y 13 cuando existan las pantallas que los provocan. Lo que no este
 * aqui cae en el mensaje generico, que nunca deja al usuario sin explicacion.
 */
const MESSAGES: Record<string, string> = {
  // Lo que el pasajero puede provocar y puede corregir.
  ORIGIN_OUT_OF_AREA: 'El punto de recogida está fuera de la zona de servicio.',
  DESTINATION_OUT_OF_AREA: 'El destino está fuera de la zona de servicio.',
  PASSENGER_COUNT_OUT_OF_RANGE: 'Esa cantidad de pasajeros no está permitida.',
  // No deberia llegar nunca: el campo corta a 80 caracteres. Se traduce igual,
  // porque el limite del campo es comodidad y el del servidor es la regla, y el
  // dia que alguien llame a la API sin pasar por la pantalla este es el aviso
  // que recibe.
  PICKUP_REFERENCE_TOO_LONG: 'La referencia del punto de recogida es demasiado larga.',
  PHONE_REQUIRED: 'Necesitas registrar un teléfono antes de pedir un servicio.',

  // Situaciones normales de la operación. No son fallos de nadie, y por eso el
  // texto no pide disculpas ni sugiere reintentar sin sentido.
  NO_DRIVERS_AVAILABLE: 'No hay motorratones disponibles en este momento.',
  ACTIVE_REQUEST_EXISTS: 'Ya tienes un servicio en curso.',

  // Cancelacion.
  REQUEST_NOT_FOUND: 'No encontramos esa solicitud.',
  /**
   * Lo lanzan DOS sitios, y por eso el texto es generico.
   *
   * Hasta la Fase 15 solo lo producia `cancel_request`, asi que decia "ya no se
   * puede cancelar desde aqui". Ahora lo lanza tambien `assert_ride_driver`
   * cuando el conductor intenta una transicion que su viaje no admite, y ese
   * texto seria falso: nadie estaba cancelando nada. Pasa cuando dos toques
   * seguidos llegan al servidor, o cuando el conductor toca "llegué" en un viaje
   * que el pasajero acaba de cancelar.
   */
  INVALID_STATE_TRANSITION: 'Ese servicio ya no admite esa acción.',

  // Estados de la cuenta. El usuario no puede resolverlos por su cuenta, asi que
  // el mensaje le dice a quien acudir en lugar de invitarle a insistir.
  ACCOUNT_BLOCKED: 'Tu cuenta está bloqueada. Comunícate con la empresa.',
  NOT_A_PASSENGER: 'Esta cuenta no puede solicitar servicios.',
  PROFILE_NOT_FOUND: 'No encontramos tu perfil. Cierra sesión y vuelve a entrar.',

  // Lado del conductor, desde la Fase 12.
  //
  // REQUEST_ALREADY_TAKEN merece atencion: no es un fallo, es el desenlace normal
  // de que varios conductores vean la misma solicitud. El criterio de aceptacion
  // 3 lo dice con todas las letras: quien pierde "recibe un mensaje claro, no un
  // error". Por eso el texto no se disculpa ni sugiere reintentar.
  REQUEST_ALREADY_TAKEN: 'Otro motorratón tomó este servicio.',
  OFFER_EXPIRED: 'Se acabó el tiempo para responder a esta solicitud.',
  OFFER_ALREADY_ANSWERED: 'Ya habías respondido a esta solicitud.',
  OFFER_NOT_AVAILABLE: 'Esa solicitud ya no está disponible.',
  OFFER_NOT_FOUND: 'Esa solicitud no es tuya.',
  NO_VEHICLE_ASSIGNED: 'No tienes un motorratón asignado. Comunícate con la empresa.',

  // Recoger pasajeros en ruta, decision D161.
  //
  // VEHICLE_CAPACITY_EXCEEDED es el hermano de REQUEST_ALREADY_TAKEN y merece el
  // mismo trato: tampoco es un fallo. Ahora que un conductor puede tener dos
  // ofertas vivas a la vez, puede aceptar una y descubrir al tocar la otra que ya
  // no le caben. Pasa entre la oferta y el toque, y no hay nada que corregir.
  VEHICLE_CAPACITY_EXCEEDED: 'Ya no te quedan asientos libres para ese servicio.',
  DRIVER_VEHICLE_CONFLICT: 'Tienes un servicio en curso con otro motorratón.',

  // Las transiciones del servicio, desde la Fase 15.
  RIDE_NOT_FOUND: 'Ese servicio ya no es tuyo.',
  /**
   * REGLA R5, y es el unico de los tres que el conductor puede resolver.
   *
   * El servidor mide la distancia de verdad antes de dejar anunciar la llegada,
   * asi que el mensaje dice que hacer —acercarse— en lugar de limitarse a
   * negarse. El servidor incluye los metros en su texto, pero aqui se traduce
   * desde el codigo (D155) y ese numero se pierde: cambiarlo por "acercate mas"
   * es preferible a mostrar el texto del servidor, que viene sin tildes (H8).
   */
  TOO_FAR_FROM_PICKUP: 'Todavía estás lejos del punto de recogida. Acércate para confirmar.',
};

const NETWORK_CODE = 'network_error';
const NETWORK_MESSAGE = 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';

const UNKNOWN_CODE = 'unknown_error';
const UNKNOWN_MESSAGE = 'Ocurrió un error inesperado. Inténtalo de nuevo.';

/**
 * Textos de red que devuelve un fetch caido.
 *
 * PostgREST no llega a responder, asi que no hay ni codigo ni pista: lo unico
 * que queda es el mensaje del error de red. React Native dice "Network request
 * failed" y los navegadores "Failed to fetch"; el segundo hace falta porque la
 * aplicacion tambien se ejecuta en web durante el desarrollo.
 *
 * LAS DOS ULTIMAS SE ANADIERON EN LA FASE 16, y merecen explicacion porque esta
 * lista parecia completa. Se apago la red del emulador y el historial no dijo
 * "no hay conexion", dijo "ocurrio un error inesperado". El mensaje real era
 * `fetch failed: java.net.UnknownHostException: Unable to resolve host ...`:
 * "fetch failed" y no "failed to fetch", que es lo mismo escrito al reves y no
 * casaba con ninguna. Sin DNS el aparato ni siquiera intenta conectarse, que es
 * justo lo que pasa cuando alguien se queda sin datos en la carretera.
 *
 * Afecta a toda la aplicacion, no solo al historial: cualquier pantalla que
 * fallara sin conexion daba el mensaje generico.
 */
const NETWORK_HINTS = [
  'network request failed',
  'failed to fetch',
  'fetch failed',
  'network error',
  'unable to resolve host',
  'unknownhostexception',
];

/**
 * Convierte cualquier error en algo que se pueda mostrar y comparar.
 *
 * Acepta `unknown` a proposito, igual que toAuthFailure: aqui puede llegar un
 * PostgrestError, un fallo de red o cualquier otra cosa. Fiarse del tipo
 * declarado y leer `.hint` directamente provocaria un fallo dentro del propio
 * manejador de errores, que es el peor sitio posible.
 */
export function toRideFailure(error: unknown): RideFailure {
  if (typeof error !== 'object' || error === null) {
    return { code: UNKNOWN_CODE, message: UNKNOWN_MESSAGE };
  }

  // PostgREST manda cadena vacia, no nulo, cuando la funcion no puso pista. Por
  // eso no basta con comprobar que sea una cadena.
  const hint = 'hint' in error && typeof error.hint === 'string' ? error.hint.trim() : '';

  if (hint !== '' && hint in MESSAGES) {
    // El indexado devuelve `string | undefined` por noUncheckedIndexedAccess, y
    // el `in` de arriba ya garantiza que existe.
    return { code: hint, message: MESSAGES[hint] ?? UNKNOWN_MESSAGE };
  }

  const message = 'message' in error && typeof error.message === 'string' ? error.message : '';
  const name = 'name' in error && typeof error.name === 'string' ? error.name : '';

  if (name === 'TypeError' || NETWORK_HINTS.some((h) => message.toLowerCase().includes(h))) {
    return { code: NETWORK_CODE, message: NETWORK_MESSAGE };
  }

  // Se conserva la pista aunque no se sepa traducir: en un informe de error vale
  // mucho mas leer 'OFFER_EXPIRED' que 'unknown_error'.
  return { code: hint !== '' ? hint : UNKNOWN_CODE, message: UNKNOWN_MESSAGE };
}

/**
 * Los codigos sobre los que la interfaz decide algo, no solo mostrar un texto.
 *
 * Se exponen como constantes para que una pantalla no compare contra una cadena
 * escrita a mano, que es como se cuelan las erratas que nadie ve hasta que el
 * caso ocurre de verdad.
 */
export const RIDE_ERROR_CODES = {
  noDrivers: 'NO_DRIVERS_AVAILABLE',
  activeRequest: 'ACTIVE_REQUEST_EXISTS',
  originOutOfArea: 'ORIGIN_OUT_OF_AREA',
  destinationOutOfArea: 'DESTINATION_OUT_OF_AREA',
  accountBlocked: 'ACCOUNT_BLOCKED',
  phoneRequired: 'PHONE_REQUIRED',

  // El conductor perdio la carrera. La pantalla lo trata distinto que a un
  // error: retira la tarjeta sin alarma y sigue esperando la siguiente.
  requestAlreadyTaken: 'REQUEST_ALREADY_TAKEN',
  offerExpired: 'OFFER_EXPIRED',
  offerAlreadyAnswered: 'OFFER_ALREADY_ANSWERED',
  noVehicle: 'NO_VEHICLE_ASSIGNED',

  // Se lleno entre que le llego la oferta y la toco. La pantalla retira la
  // tarjeta y vuelve a leer sus viajes, porque el motorraton ya no esta como ella
  // creia.
  vehicleCapacityExceeded: 'VEHICLE_CAPACITY_EXCEEDED',

  // El viaje ya no esta donde la pantalla creia: o lo cancelaron, o dos toques
  // seguidos llegaron al servidor. En los dos casos hay que releer, no insistir.
  invalidTransition: 'INVALID_STATE_TRANSITION',
  rideNotFound: 'RIDE_NOT_FOUND',

  // Este NO significa que el viaje haya cambiado: significa que el conductor
  // esta lejos. La pantalla lo distingue porque no tiene que releer nada, solo
  // dejar que se acerque y vuelva a tocar.
  tooFarFromPickup: 'TOO_FAR_FROM_PICKUP',

  network: NETWORK_CODE,
  unknown: UNKNOWN_CODE,
} as const;
