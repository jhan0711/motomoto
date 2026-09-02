import { createURL } from 'expo-linking';

import { supabase } from '@/lib/supabase';
import type { Database } from '@/types/database';

import { toAuthFailure, type AuthFailure } from './errors';
import type {
  ChangePasswordValues,
  EditProfileValues,
  ForgotPasswordValues,
  LoginValues,
  RegisterValues,
} from './schemas';

/**
 * Capa de servicio de autenticacion.
 *
 * Es el unico punto de la aplicacion que llama a supabase.auth. Ninguna pantalla
 * habla directamente con Supabase: asi los mensajes en espanol, el registro de
 * errores y las reglas de esta fase estan en un solo sitio y no repartidos por
 * cuatro formularios.
 *
 * Ninguna funcion lanza excepciones. Todas devuelven un resultado que obliga a
 * mirar si salio bien, porque un `await` sin `try` es la forma mas comun de que
 * un error de autenticacion desaparezca sin dejar rastro.
 */

export type Profile = Database['public']['Tables']['profiles']['Row'];
export type Driver = Database['public']['Tables']['drivers']['Row'];

export type Result<T = void> = { ok: true; data: T } | { ok: false; failure: AuthFailure };

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toAuthFailure(error) };
}

/**
 * Registro de un pasajero.
 *
 * Solo se registran pasajeros. Las cuentas de conductor las crea el
 * administrador (seccion 6 del documento), y el rol nunca viaja en esta
 * llamada: `handle_new_user` crea el perfil con rol 'passenger' y el disparador
 * `profiles_protect_columns` impide cambiarlo despues. Verificado contra el
 * servidor: un registro que envia "role":"admin" en los metadatos sigue saliendo
 * como pasajero.
 *
 * El nombre y el telefono viajan en los metadatos porque es el disparador de la
 * base de datos, y no la aplicacion, quien crea el perfil. Si lo creara la app
 * con un segundo INSERT, un corte de red entre las dos llamadas dejaria un
 * usuario sin perfil, en un limbo del que no se puede salir.
 */
export async function signUp(values: RegisterValues): Promise<Result> {
  const { error } = await supabase.auth.signUp({
    email: values.email,
    password: values.password,
    options: {
      data: {
        full_name: values.fullName,
        phone: values.phone,
      },
    },
  });

  return error ? fail(error) : ok(undefined);
}

/** Inicio de sesion. Sirve igual para pasajero y para conductor. */
export async function signIn(values: LoginValues): Promise<Result> {
  const { error } = await supabase.auth.signInWithPassword({
    email: values.email,
    password: values.password,
  });

  return error ? fail(error) : ok(undefined);
}

/**
 * Cierre de sesion.
 *
 * El cierre normal avisa al servidor para invalidar el token en todos los
 * dispositivos. Si no hay conexion, esa llamada falla, y sin el segundo intento
 * el usuario se quedaria dentro de la aplicacion despues de haber pulsado
 * "Cerrar sesión", que es justo lo contrario de lo que pidio.
 *
 * Por eso el fallo de red degrada a un cierre local: se borra la sesion del
 * dispositivo aunque el servidor no se entere. El token caduca solo.
 */
export async function signOut(): Promise<Result> {
  const { error } = await supabase.auth.signOut();

  if (!error) {
    return ok(undefined);
  }

  const { error: localError } = await supabase.auth.signOut({ scope: 'local' });

  return localError ? fail(localError) : ok(undefined);
}

/**
 * Datos que solo conoce Supabase Auth y no estan en la tabla profiles.
 *
 * El correo es el caso claro: vive en `auth.users`, no en `profiles`, porque es
 * la credencial de acceso y no un dato del perfil. La pantalla de perfil lo
 * muestra, asi que la sesion tiene que traerlo.
 */
export interface AuthUser {
  id: string;
  email: string | null;
}

/**
 * Avisa cada vez que cambia quien tiene la sesion abierta.
 *
 * Devuelve solo lo imprescindible y no la sesion completa: de quien hay que
 * cargar el perfil, y su correo. El resto de la sesion, incluidos los tokens, no
 * tiene por que salir de este archivo.
 *
 * Supabase emite un primer aviso nada mas suscribirse, con la sesion que estaba
 * guardada en el dispositivo. Ese primer aviso es lo que restaura la sesion al
 * abrir la aplicacion: por eso no hace falta consultarla ademas por separado.
 */
export function onAuthUserChange(listener: (user: AuthUser | null) => void): () => void {
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    const authUser = session?.user ?? null;

    listener(authUser === null ? null : { id: authUser.id, email: authUser.email ?? null });
  });

  return () => data.subscription.unsubscribe();
}

/**
 * Solicitud de recuperacion de contrasena.
 *
 * D74: la pantalla muestra siempre la misma confirmacion, exista o no la cuenta.
 * Por eso aqui no se distingue "correo no encontrado": permitiria averiguar que
 * correos tienen cuenta en la plataforma probandolos uno a uno.
 *
 * Los errores que si se devuelven son los que el usuario puede entender y
 * remediar: falta de conexion y limite de envios. Callarlos dejaria a alguien
 * esperando un correo que nunca se envio.
 *
 * El enlace del correo vuelve a la propia aplicacion mediante un enlace profundo
 * (D94). `createURL` construye la direccion correcta para cada entorno: dentro
 * de Expo Go es una direccion exp://, y en la aplicacion instalada es
 * motomoto://. Escribirla a mano funcionaria en uno de los dos y fallaria en el
 * otro, siempre en el que no estas mirando.
 */
export async function sendPasswordReset(values: ForgotPasswordValues): Promise<Result> {
  const { error } = await supabase.auth.resetPasswordForEmail(values.email, {
    redirectTo: createURL('/reset-password'),
  });

  return error ? fail(error) : ok(undefined);
}

/**
 * Reparte los parametros que trae el enlace del correo.
 *
 * Vienen en dos sitios distintos segun el flujo que use el proyecto: en la
 * cadena de consulta (`?code=...`) o en el fragmento (`#access_token=...`). Se
 * leen los dos y se decide despues, en lugar de dar por supuesto cual es: el
 * flujo depende de como este configurado el cliente y de la version, y
 * equivocarse produce un enlace que no hace nada sin decir por que.
 */
function parseLinkParams(url: string): Record<string, string> {
  const params: Record<string, string> = {};
  const [beforeFragment, fragment] = url.split('#');
  const query = beforeFragment?.split('?')[1];

  for (const chunk of [query, fragment]) {
    if (chunk === undefined || chunk === '') {
      continue;
    }

    for (const pair of chunk.split('&')) {
      const [rawKey, rawValue] = pair.split('=');

      if (rawKey !== undefined && rawValue !== undefined) {
        params[decodeURIComponent(rawKey)] = decodeURIComponent(rawValue.replace(/\+/g, ' '));
      }
    }
  }

  return params;
}

/** Distingue un enlace de recuperacion de cualquier otra apertura de la app. */
export function isRecoveryLink(url: string): boolean {
  const params = parseLinkParams(url);

  return params.type === 'recovery' || url.includes('/reset-password');
}

/**
 * Abre la sesion que viene dentro del enlace del correo.
 *
 * Es una sesion real y con todos los permisos del usuario, no un permiso
 * limitado a cambiar la contrasena. Por eso la aplicacion la marca como
 * "recuperacion en curso" y no deja entrar a las pantallas normales hasta que la
 * contrasena se ha cambiado.
 */
export async function completeRecoveryFromLink(url: string): Promise<Result> {
  const params = parseLinkParams(url);

  // Enlace caducado o ya usado. Supabase lo dice aqui, y es el caso mas frecuente
  // de todos: la gente abre el correo al dia siguiente.
  if (params.error_description !== undefined || params.error !== undefined) {
    return {
      ok: false,
      failure: {
        code: params.error_code ?? 'recovery_link_invalid',
        message: 'Ese enlace ya no es válido. Pide uno nuevo.',
      },
    };
  }

  if (params.code !== undefined) {
    const { error } = await supabase.auth.exchangeCodeForSession(params.code);

    return error ? fail(error) : ok(undefined);
  }

  if (params.access_token !== undefined && params.refresh_token !== undefined) {
    const { error } = await supabase.auth.setSession({
      access_token: params.access_token,
      refresh_token: params.refresh_token,
    });

    return error ? fail(error) : ok(undefined);
  }

  return {
    ok: false,
    failure: {
      code: 'recovery_link_incomplete',
      message: 'Ese enlace está incompleto. Pide uno nuevo.',
    },
  };
}

/**
 * Cambia la contrasena del usuario que tiene la sesion abierta.
 *
 * Se usa al final del enlace de recuperacion. Ahi no se pide la contrasena
 * anterior, y es correcto: quien llega por el enlace ya demostro tener acceso al
 * correo de la cuenta, que es la prueba que sustituye a la contrasena olvidada.
 *
 * Para el cambio desde dentro de la aplicacion se usa `changePassword`, que si
 * la pide.
 */
export async function updatePassword(password: string): Promise<Result> {
  // GoTrue revoca por su cuenta todas las demas sesiones al cambiar la contrasena
  // -incluida, en el cambio desde dentro de la aplicacion, la sesion previa a la
  // reautenticacion de `changePassword`-. Solo sobrevive la que hace la peticion.
  // Verificado contra el servidor en `supabase/dev-tools/prueba_cambio_contrasena_sesiones.mjs`.
  const { error } = await supabase.auth.updateUser({ password });

  return error ? fail(error) : ok(undefined);
}

/**
 * Cambia la contrasena desde dentro de la aplicacion, comprobando la actual.
 *
 * Supabase no exige la contrasena anterior para cambiarla. Aceptar eso
 * significaria que un telefono desbloqueado durante un minuto es una cuenta
 * perdida: cualquiera abre el perfil, cambia la contrasena y se queda con ella.
 *
 * No existe un endpoint para "comprobar esta contrasena", asi que se comprueba
 * de la unica forma posible: intentando iniciar sesion con ella. Si falla, no se
 * toca nada. Un intento fallido no afecta a la sesion que ya estaba abierta.
 */
export async function changePassword(email: string, values: ChangePasswordValues): Promise<Result> {
  const { error: reauthError } = await supabase.auth.signInWithPassword({
    email,
    password: values.currentPassword,
  });

  if (reauthError) {
    // Se traduce aqui y no en el mapa general: en esta pantalla
    // `invalid_credentials` significa "la actual no es correcta", no "correo o
    // contrasena incorrectos", que confundiria al usuario.
    const failure = toAuthFailure(reauthError);

    return {
      ok: false,
      failure:
        failure.code === 'invalid_credentials'
          ? {
              code: 'INVALID_CURRENT_PASSWORD',
              message: 'La contraseña actual no es correcta.',
            }
          : failure,
    };
  }

  return updatePassword(values.password);
}

/**
 * Perfil del usuario que tiene la sesion abierta.
 *
 * De aqui salen el rol y el estado de la cuenta, que son lo que deciden que
 * navegacion se muestra. No se leen del token: el token se emite al iniciar
 * sesion y no se entera de que un administrador bloquee la cuenta diez minutos
 * despues.
 *
 * `maybeSingle` en vez de `single` porque "no hay perfil" no es un error de
 * base de datos, es un caso que hay que distinguir y tratar.
 */
export async function fetchProfile(userId: string): Promise<Result<Profile>> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle();

  if (error) {
    return fail(error);
  }

  if (data === null) {
    return {
      ok: false,
      failure: {
        code: 'PROFILE_NOT_FOUND',
        message: 'No encontramos tu perfil. Comunícate con la empresa.',
      },
    };
  }

  return ok(data);
}

/**
 * Guarda el nombre y el telefono del perfil.
 *
 * Solo esas dos columnas, escritas de forma explicita. Enviar el objeto completo
 * del perfil seria mas comodo y peor: cualquier campo que se anada en el futuro
 * viajaria sin que nadie lo haya decidido, y bastaria un descuido para intentar
 * escribir rol o estado.
 *
 * La fila la limita la politica `profiles_update_own`, que solo deja tocar la
 * propia. El `eq` de aqui no es la proteccion, es claridad: si la politica
 * fallara, esto no salvaria nada.
 */
export async function updateProfile(userId: string, values: EditProfileValues): Promise<Result> {
  const { error } = await supabase
    .from('profiles')
    .update({ full_name: values.fullName, phone: values.phone })
    .eq('id', userId);

  return error ? fail(error) : ok(undefined);
}

/**
 * Ficha de conductor del usuario que tiene la sesion abierta.
 *
 * Devuelve null sin error cuando no existe, que es lo normal en un pasajero. Un
 * conductor con perfil pero sin ficha si es una anomalia, y quien decide que
 * hacer con ella es la sesion, no esta funcion.
 *
 * El estado de aprobacion se lee de aqui y no del perfil porque es un dato del
 * conductor: un pasajero no tiene aprobacion que valga.
 */
export async function fetchDriver(userId: string): Promise<Result<Driver | null>> {
  const { data, error } = await supabase.from('drivers').select('*').eq('id', userId).maybeSingle();

  return error ? fail(error) : ok(data);
}
