/**
 * Traduccion de los errores de Supabase Auth.
 *
 * Supabase responde en ingles y con un vocabulario tecnico. Mostrar esos textos
 * tal cual seria inaceptable en una aplicacion cuyo idioma es el espanol.
 *
 * Se sigue el mismo criterio que ya usan las funciones de la base de datos
 * (D88): un mensaje en espanol para el usuario y un codigo estable para la
 * aplicacion. El codigo es lo que se compara en el codigo y en las pruebas; el
 * mensaje puede reescribirse sin romper nada.
 */

export interface AuthFailure {
  /** Codigo estable. Es lo que se compara, nunca el mensaje. */
  code: string;
  /** Texto listo para mostrar al usuario. */
  message: string;
}

/**
 * Codigos que devuelve Supabase Auth y su equivalente en espanol.
 *
 * La lista cubre lo que puede ocurrir de verdad en los cuatro formularios de
 * esta fase. Lo que no este aqui cae en el mensaje generico, que nunca deja al
 * usuario sin explicacion.
 */
const MESSAGES: Record<string, string> = {
  invalid_credentials: 'Correo o contraseña incorrectos.',
  email_not_confirmed: 'Todavía no has confirmado tu correo.',
  user_already_exists: 'Ya existe una cuenta con ese correo.',
  email_exists: 'Ya existe una cuenta con ese correo.',
  weak_password: 'Esa contraseña es demasiado débil. Elige otra más larga.',
  same_password: 'La contraseña nueva es igual a la anterior.',
  email_address_invalid: 'Ese correo electrónico no es válido.',
  user_banned: 'Esta cuenta está bloqueada. Comunícate con la empresa.',
  over_request_rate_limit: 'Demasiados intentos seguidos. Espera un momento y vuelve a intentarlo.',
  over_email_send_rate_limit: 'Se enviaron demasiados correos. Espera unos minutos.',

  // Los dos siguientes no son culpa del usuario: son un proyecto de Supabase mal
  // configurado. El usuario no puede hacer nada, asi que el mensaje no le pide
  // que lo intente de nuevo, que seria mentirle.
  email_provider_disabled: 'El acceso por correo no está habilitado. Avisa a la empresa.',
  signup_disabled: 'El registro de cuentas nuevas está deshabilitado.',

  // Sesion caducada o revocada. La aplicacion debe llevar al usuario al login.
  refresh_token_not_found: 'Tu sesión expiró. Inicia sesión de nuevo.',
  session_expired: 'Tu sesión expiró. Inicia sesión de nuevo.',
};

const NETWORK_CODE = 'network_error';
const NETWORK_MESSAGE = 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';

const UNKNOWN_CODE = 'unknown_error';
const UNKNOWN_MESSAGE = 'Ocurrió un error inesperado. Inténtalo de nuevo.';

/** Ver el comentario gemelo en features/ride/errors.ts. */
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
 * Acepta `unknown` a proposito: en tiempo de ejecucion aqui puede llegar un
 * AuthError de Supabase, un fallo de red del propio fetch o cualquier otra cosa.
 * Fiarse del tipo declarado y leer `.code` directamente provocaria un fallo
 * dentro del propio manejador de errores, que es el peor sitio posible.
 */
export function toAuthFailure(error: unknown): AuthFailure {
  if (typeof error !== 'object' || error === null) {
    return { code: UNKNOWN_CODE, message: UNKNOWN_MESSAGE };
  }

  const code = 'code' in error && typeof error.code === 'string' ? error.code : null;

  if (code !== null && code in MESSAGES) {
    // El operador de indexacion devuelve `string | undefined` por
    // noUncheckedIndexedAccess, y el `in` de arriba ya garantiza que existe.
    return { code, message: MESSAGES[code] ?? UNKNOWN_MESSAGE };
  }

  // Sin conexion, Supabase no llega a devolver un codigo: falla el fetch. Se
  // detecta por el nombre del error, que si es estable.
  const name = 'name' in error && typeof error.name === 'string' ? error.name : '';
  if (name === 'AuthRetryableFetchError' || name === 'TypeError') {
    return { code: NETWORK_CODE, message: NETWORK_MESSAGE };
  }

  // Y tambien por el texto, porque el nombre no siempre llega. En la Fase 16 se
  // vio que sin DNS el mensaje es `fetch failed: java.net.UnknownHostException`
  // dentro de un objeto corriente, sin `name` que valga. Misma lista que en
  // features/ride/errors.ts y por el mismo motivo.
  const message = 'message' in error && typeof error.message === 'string' ? error.message : '';
  if (NETWORK_HINTS.some((pista) => message.toLowerCase().includes(pista))) {
    return { code: NETWORK_CODE, message: NETWORK_MESSAGE };
  }

  return { code: code ?? UNKNOWN_CODE, message: UNKNOWN_MESSAGE };
}

export const AUTH_ERROR_CODES = {
  network: NETWORK_CODE,
  unknown: UNKNOWN_CODE,
} as const;
