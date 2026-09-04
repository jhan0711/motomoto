import { supabase } from '@/lib/supabase';
import type { Database } from '@/types/database';

import { toAuthFailure, type AuthFailure } from './errors';
import type {
  ChangeEmailValues,
  ChangePasswordValues,
  EditProfileValues,
  ForgotPasswordValues,
  LoginValues,
  RegisterValues,
} from './schemas';

/**
 * A donde vuelven los enlaces de los correos de la cuenta (recuperar contrasena,
 * confirmar la cuenta, cambiar el correo).
 *
 * Es un enlace de aplicacion de Android (`https://`), no el esquema `motomoto://`
 * (D95, hallazgo H7): Android verifica la propiedad del dominio contra
 * `https://amalfigo.app/.well-known/assetlinks.json` y entrega la URL a la app.
 *
 * CLAVE (revision del paso 6): las plantillas de correo del panel apuntan
 * DIRECTO a `{{ .SiteURL }}/auth?token_hash=...&type=...`, sin pasar por
 * `<proyecto>.supabase.co/auth/v1/verify`. Ese salto por supabase.co abria el
 * navegador y el App Link ya no se disparaba en el redirect (H7 una capa mas
 * arriba). Con el enlace directo, la primera navegacion ya es a `amalfigo.app`
 * y la app lo recibe; luego canjea el `token_hash` con `verifyOtp`.
 *
 * Este valor se sigue pasando como `redirectTo`/`emailRedirectTo` en las
 * llamadas de abajo: GoTrue exige que este en la lista de "Redirect URLs" del
 * panel aunque la plantilla ya no use `{{ .ConfirmationURL }}`.
 *
 * La ruta `/auth` la atiende `src/app/auth.tsx`, que solo espera mientras
 * `session.tsx` lee los parametros del enlace y decide que hacer.
 */
export const AUTH_CALLBACK_URL = 'https://amalfigo.app/auth';

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
export async function signUp(
  values: RegisterValues,
): Promise<Result<{ needsConfirmation: boolean }>> {
  const { data, error } = await supabase.auth.signUp({
    email: values.email,
    password: values.password,
    options: {
      // A donde vuelve el enlace de "confirma tu cuenta" del correo (Fase 25
      // paso 7b). Mismo enlace de aplicacion que la recuperacion, ver
      // AUTH_CALLBACK_URL.
      emailRedirectTo: AUTH_CALLBACK_URL,
      data: {
        full_name: values.fullName,
        phone: values.phone,
      },
    },
  });

  if (error) {
    return fail(error);
  }

  // Con "Confirm email" activado, Supabase no abre sesion: devuelve `session`
  // nula y manda el correo. Si el correo ya tenia cuenta, Supabase devuelve
  // exactamente lo mismo -sin identidades- para no revelar que existe (D74). En
  // los dos casos la pantalla dice "revisa tu correo", que es la respuesta
  // correcta para ambos.
  return ok({ needsConfirmation: data.session === null });
}

/**
 * Reenvia el correo de confirmacion de cuenta.
 *
 * Lo piden dos pantallas: el registro (por si el primer correo no llego) y el
 * login (cuando alguien intenta entrar con una cuenta sin confirmar). El limite
 * de envios de Supabase se traduce a un mensaje que el usuario entiende.
 */
export async function resendConfirmation(email: string): Promise<Result> {
  const { error } = await supabase.auth.resend({
    type: 'signup',
    email,
    options: { emailRedirectTo: AUTH_CALLBACK_URL },
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
 * El enlace del correo vuelve a la aplicacion por `AUTH_CALLBACK_URL`, un enlace
 * de aplicacion de Android (ver ahi el porque, D95/H7). Antes se usaba
 * `createURL('/reset-password')`, que daba `motomoto://` y no llegaba desde el
 * navegador del cliente de correo.
 */
export async function sendPasswordReset(values: ForgotPasswordValues): Promise<Result> {
  const { error } = await supabase.auth.resetPasswordForEmail(values.email, {
    redirectTo: AUTH_CALLBACK_URL,
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

  // `type=recovery` llega en la query del enlace directo nuevo
  // (`.../auth?token_hash=...&type=recovery`) o en el fragmento de los formatos
  // viejos (`#...type=recovery`); `parseLinkParams` lee los dos. El `includes`
  // es respaldo para enlaces `motomoto://reset-password` de bandejas antiguas.
  return params.type === 'recovery' || url.includes('/reset-password');
}

/**
 * Distingue un enlace de confirmacion de cuenta (Fase 25 paso 7b).
 *
 * Supabase manda `type=signup` en el fragmento. A diferencia de la
 * recuperacion, aqui no hay pantalla que llenar: el enlace abre la sesion y el
 * usuario ya puede usar la aplicacion.
 */
export function isConfirmationLink(url: string): boolean {
  return parseLinkParams(url).type === 'signup';
}

/**
 * Distingue un enlace de cambio de correo (Fase 25 paso 7c).
 *
 * Supabase manda `type=email_change` tanto en el enlace del correo nuevo como
 * en el del actual. Con el cambio seguro activado hay que abrir los dos para
 * que surta efecto.
 */
export function isEmailChangeLink(url: string): boolean {
  return parseLinkParams(url).type === 'email_change';
}

/**
 * Abre la sesion que viene dentro de un enlace del correo.
 *
 * Sirve para recuperacion (`type=recovery`) y para confirmacion de cuenta
 * (`type=signup`): el canje es identico, solo cambian los textos de error.
 * Acepta el formato nuevo (`token_hash` -> `verifyOtp`) y los viejos (`code`,
 * `access_token`) como respaldo. Es una sesion real y con todos los permisos
 * del usuario. Para la recuperacion, la aplicacion la marca ademas como
 * "recuperacion en curso" y no deja entrar a las pantallas normales hasta
 * cambiar la contrasena.
 */
async function abrirSesionDesdeEnlace(
  url: string,
  textos: { invalido: string; incompleto: string },
): Promise<Result> {
  const params = parseLinkParams(url);

  // Enlace caducado o ya usado. Supabase lo dice aqui, y es el caso mas frecuente
  // de todos: la gente abre el correo al dia siguiente.
  if (params.error_description !== undefined || params.error !== undefined) {
    return {
      ok: false,
      failure: {
        code: params.error_code ?? 'auth_link_invalid',
        message: textos.invalido,
      },
    };
  }

  // Enlace del correo con `token_hash` (Fase 25, revision del paso 6). Es el
  // formato que apunta DIRECTO a `https://amalfigo.app/auth?token_hash=...` sin
  // pasar por `<proyecto>.supabase.co/verify`. Ese salto por supabase.co era lo
  // que rompia el enlace de aplicacion: Android solo comprueba el App Link en la
  // primera navegacion, no en el redirect del navegador (H7, una capa mas
  // arriba). Con el enlace directo, Android entrega la URL a la app y aqui se
  // canjea el token con `verifyOtp`.
  if (params.token_hash !== undefined && params.type !== undefined) {
    const { error } = await supabase.auth.verifyOtp({
      type: params.type as 'recovery' | 'signup',
      token_hash: params.token_hash,
    });

    return error ? fail(error) : ok(undefined);
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
    failure: { code: 'auth_link_incomplete', message: textos.incompleto },
  };
}

export function completeRecoveryFromLink(url: string): Promise<Result> {
  return abrirSesionDesdeEnlace(url, {
    invalido: 'Ese enlace ya no es válido. Pide uno nuevo.',
    incompleto: 'Ese enlace está incompleto. Pide uno nuevo.',
  });
}

export function completeConfirmationFromLink(url: string): Promise<Result> {
  return abrirSesionDesdeEnlace(url, {
    invalido: 'Ese enlace de confirmación ya no es válido. Inicia sesión y pídelo de nuevo.',
    incompleto: 'Ese enlace de confirmación está incompleto. Inicia sesión y pídelo de nuevo.',
  });
}

/**
 * Estado en que queda un enlace de cambio de correo al abrirlo.
 *
 *   - `completo`: el correo ya cambio (se abrieron los dos enlaces, o el
 *     proyecto no exige el doble).
 *   - `falta_el_otro`: este enlace se acepto, pero el cambio no surte efecto
 *     hasta abrir el del otro correo.
 */
export type EmailChangeOutcome = 'completo' | 'falta_el_otro';

/**
 * Abre un enlace de cambio de correo.
 *
 * A diferencia de la confirmacion, "sin tokens" no es un error: con el cambio
 * seguro de Supabase, abrir solo uno de los dos enlaces devuelve un `message` y
 * ningun token, y el cambio queda a la espera del segundo. Solo cuando Supabase
 * devuelve una sesion nueva (los dos enlaces abiertos) el correo ha cambiado de
 * verdad; entonces se aplica para que la suscripcion de la sesion se entere.
 */
export async function completeEmailChangeFromLink(
  url: string,
): Promise<Result<EmailChangeOutcome>> {
  const params = parseLinkParams(url);

  if (params.error_description !== undefined || params.error !== undefined) {
    return {
      ok: false,
      failure: {
        code: params.error_code ?? 'email_change_link_invalid',
        message: 'Ese enlace de cambio de correo ya no es válido. Pídelo de nuevo desde tu perfil.',
      },
    };
  }

  // Enlace directo con `token_hash` (revision del paso 6, ver el comentario en
  // `abrirSesionDesdeEnlace`). Con el cambio seguro hay dos enlaces -uno al
  // correo actual y otro al nuevo- y cada uno trae su `token_hash`. Mientras
  // quede un `new_email` pendiente en el usuario, falta abrir el otro.
  if (params.token_hash !== undefined) {
    const { data, error } = await supabase.auth.verifyOtp({
      type: 'email_change',
      token_hash: params.token_hash,
    });

    if (error) {
      return fail(error);
    }

    const pendiente = (data.user as { new_email?: string | null } | null)?.new_email;

    return ok(pendiente ? 'falta_el_otro' : 'completo');
  }

  if (params.access_token !== undefined && params.refresh_token !== undefined) {
    const { error } = await supabase.auth.setSession({
      access_token: params.access_token,
      refresh_token: params.refresh_token,
    });

    return error ? fail(error) : ok('completo');
  }

  // Sin tokens y sin error: este lado quedo confirmado y falta el otro.
  return ok('falta_el_otro');
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
 * Cambia el correo desde dentro de la aplicacion, comprobando la contrasena.
 *
 * Levanta D101: se permitia mirar el correo pero no cambiarlo porque no habia
 * verificacion. Ahora Supabase manda un enlace al correo nuevo -y, con el
 * cambio seguro, tambien al actual- y el cambio no surte efecto hasta abrirlos.
 *
 * La contrasena actual se comprueba igual que en `changePassword` y por el
 * mismo motivo (D102): sin ella, un telefono desbloqueado un minuto es una
 * cuenta perdida. Se comprueba intentando iniciar sesion; un intento fallido no
 * afecta a la sesion abierta.
 */
export async function changeEmail(
  currentEmail: string,
  values: ChangeEmailValues,
): Promise<Result> {
  if (values.email === currentEmail) {
    return {
      ok: false,
      failure: { code: 'SAME_EMAIL', message: 'Ese ya es tu correo actual.' },
    };
  }

  const { error: reauthError } = await supabase.auth.signInWithPassword({
    email: currentEmail,
    password: values.currentPassword,
  });

  if (reauthError) {
    const failure = toAuthFailure(reauthError);

    return {
      ok: false,
      failure:
        failure.code === 'invalid_credentials'
          ? { code: 'INVALID_CURRENT_PASSWORD', message: 'La contraseña no es correcta.' }
          : failure,
    };
  }

  const { error } = await supabase.auth.updateUser(
    { email: values.email },
    { emailRedirectTo: AUTH_CALLBACK_URL },
  );

  return error ? fail(error) : ok(undefined);
}

/**
 * Elimina la cuenta del pasajero (Fase 26 paso 7b).
 *
 * Google Play lo exige para apps con registro. La logica esta en la funcion
 * `delete_my_account` de la base -que borra `auth.users` y anonimiza el
 * historial de viajes hacia el perfil marcador-; aqui se hace lo unico que la
 * funcion no puede: borrar el avatar del bucket (una funcion `security definer`
 * no toca `storage.objects` en el Supabase gestionado, y el cliente si tiene
 * permiso RLS sobre su propia carpeta).
 *
 * Solo pasajeros. Un conductor tiene vehiculo, turnos y documentos: su baja la
 * gestiona la empresa, y la funcion la rechaza con `ACCOUNT_DELETE_NOT_PASSENGER`.
 */
export async function deleteAccount(avatarPath: string | null): Promise<Result> {
  if (avatarPath !== null) {
    // Si falla, se sigue: un avatar huerfano es ruido de almacenamiento, no
    // motivo para dejar la cuenta a medio borrar.
    await supabase.storage.from('avatars').remove([avatarPath]);
  }

  const { error } = await supabase.rpc('delete_my_account');

  if (error) {
    const hint = typeof error.hint === 'string' ? error.hint.trim() : '';

    if (hint === 'ACCOUNT_DELETE_ACTIVE_RIDE') {
      return {
        ok: false,
        failure: {
          code: hint,
          message:
            'Tienes un servicio en curso. Termínalo o cancélalo antes de eliminar tu cuenta.',
        },
      };
    }

    if (hint === 'ACCOUNT_DELETE_NOT_PASSENGER') {
      return {
        ok: false,
        failure: {
          code: hint,
          message: 'Esta cuenta la gestiona la empresa. Comunícate con la administración.',
        },
      };
    }

    return fail(error);
  }

  // La cuenta ya no existe en el servidor. Se cierra la sesion en local -el
  // token en memoria ya no vale-, y el aviso de Supabase lleva a bienvenida.
  await supabase.auth.signOut({ scope: 'local' });

  return ok(undefined);
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
