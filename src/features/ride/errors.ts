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
  PHONE_REQUIRED: 'Necesitas registrar un teléfono antes de pedir un servicio.',

  // Situaciones normales de la operación. No son fallos de nadie, y por eso el
  // texto no pide disculpas ni sugiere reintentar sin sentido.
  NO_DRIVERS_AVAILABLE: 'No hay motorratones disponibles en este momento.',
  ACTIVE_REQUEST_EXISTS: 'Ya tienes un servicio en curso.',

  // Cancelacion.
  REQUEST_NOT_FOUND: 'No encontramos esa solicitud.',
  INVALID_STATE_TRANSITION: 'Ese servicio ya no se puede cancelar desde aquí.',

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
 */
const NETWORK_HINTS = ['network request failed', 'failed to fetch', 'network error'];

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
  noVehicle: 'NO_VEHICLE_ASSIGNED',

  network: NETWORK_CODE,
  unknown: UNKNOWN_CODE,
} as const;
