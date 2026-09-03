import * as Linking from 'expo-linking';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import {
  completeConfirmationFromLink,
  completeRecoveryFromLink,
  fetchDriver,
  fetchProfile,
  isConfirmationLink,
  isRecoveryLink,
  onAuthUserChange,
  signOut as requestSignOut,
  type AuthUser,
} from './auth-service';

/**
 * Sesion de la aplicacion, sobre Supabase Auth.
 *
 * Sustituye a la sesion simulada de la Fase 4. La forma que se exporta es la
 * misma a proposito (D69): las guardias y las pantallas siguen leyendo `user` e
 * `isLoading` y no hubo que tocar ninguna. Lo unico que desaparecio es
 * `signInAs`, que era el atajo de desarrollo.
 *
 * Aqui viven dos cosas distintas que conviene no confundir:
 *
 *   - QUIEN tiene la sesion abierta. Lo sabe Supabase, y llega por el aviso de
 *     cambio de estado.
 *   - QUE puede hacer esa persona. Eso es el rol y el estado de la cuenta, y se
 *     leen de la tabla profiles, nunca del token. El token se emite al iniciar
 *     sesion y no se entera de que un administrador bloquee la cuenta diez
 *     minutos despues.
 */

/**
 * Roles del sistema, tal y como estan en la base de datos.
 *
 * `admin` y `super_admin` estan incluidos aunque trabajen desde el panel web. Si
 * uno inicia sesion aqui, es mejor reconocerlo y explicarle donde debe entrar
 * que fingir que su cuenta no existe. Para la aplicacion movil los dos son lo
 * mismo: se van a la pantalla de estado de cuenta.
 */
export type UserRole = 'passenger' | 'driver' | 'admin' | 'super_admin';

export type AccountStatus = 'active' | 'blocked';

export type DriverApproval = 'pending' | 'approved' | 'blocked';

export interface SessionUser {
  id: string;
  fullName: string;
  phone: string | null;
  /**
   * Viene de `auth.users`, no de `profiles`: es la credencial de acceso y no un
   * dato del perfil. No se puede cambiar desde la aplicacion en el MVP, porque
   * con la confirmacion de correo desactivada (D91) el cambio seria inmediato y
   * sin verificar, y quien tuviera el telefono desbloqueado un minuto podria
   * apuntar la cuenta a su propio correo y quedarse con ella.
   */
  email: string | null;
  /**
   * Ruta de la foto dentro del bucket, no una direccion. El bucket es privado y
   * las direcciones se firman al mostrarlas, asi que guardar una aqui seria
   * guardar algo que caduca.
   */
  avatarPath: string | null;
  role: UserRole;
  /**
   * Una cuenta bloqueada mantiene la sesion abierta a proposito, para poder
   * explicarle al usuario que esta bloqueada. No puede hacer nada: las politicas
   * RLS de la Fase 5 se lo impiden aunque la interfaz fallara.
   */
  status: AccountStatus;
  /**
   * Solo para conductores. Null en un pasajero, y tambien en un conductor cuyo
   * perfil existe pero no tiene ficha, que es una anomalia de datos y no debe
   * confundirse con "pendiente de aprobacion".
   */
  approvalStatus: DriverApproval | null;
}

interface SessionValue {
  /** Null cuando no hay nadie dentro. */
  user: SessionUser | null;
  /**
   * Cierto mientras se restaura la sesion guardada. Las guardias deben esperar a
   * que sea falso antes de redirigir; si no, un usuario que ya tenia sesion ve
   * la pantalla de bienvenida durante un instante en cada arranque.
   */
  isLoading: boolean;
  /** Mensaje en espanol cuando la sesion existe pero el perfil no se pudo leer. */
  error: string | null;
  /**
   * Si esta persona puede usar la aplicacion ahora mismo.
   *
   * Falso para una cuenta bloqueada, para un conductor que aun no ha sido
   * aprobado y para un administrador. Se calcula en un solo sitio porque
   * repartir esta condicion por las pantallas garantiza que alguna se olvide de
   * comprobarla.
   *
   * No es una medida de seguridad: decide que se muestra. Lo que de verdad
   * impide operar son las politicas RLS y las funciones de la Fase 5.
   */
  canOperate: boolean;
  /**
   * Cierto desde que se abre un enlace de recuperacion hasta que la contrasena
   * se cambia.
   *
   * Importa mas de lo que parece: el enlace del correo abre una sesion completa,
   * no un permiso limitado. Sin esta marca, quien pulse el enlace entraria
   * directamente a la aplicacion sin llegar a cambiar la contrasena, y seguiria
   * sin poder entrar la proxima vez.
   */
  isRecoveringPassword: boolean;
  /** Mensaje cuando el enlace estaba caducado, ya usado o incompleto. */
  recoveryError: string | null;
  /**
   * Mensaje cuando el enlace de confirmacion de cuenta fallo (Fase 25 paso 7b).
   *
   * A diferencia de la recuperacion no hay pantalla que bloquear: si el enlace
   * abre bien, el usuario queda con sesion y las guardias lo llevan a su zona.
   * Solo hay que enseñar el error si el enlace estaba caducado.
   */
  confirmationError: string | null;
  /** Cierra la recuperacion. La llama la pantalla al guardar la contrasena. */
  endPasswordRecovery: () => void;
  signOut: () => void;
  /** Vuelve a leer el perfil. Lo necesitara la edicion de perfil de la Fase 7. */
  refreshProfile: () => void;
}

const SessionContext = createContext<SessionValue | null>(null);

/** Estado de la suscripcion a Supabase Auth. */
interface AuthState {
  /** Falso hasta el primer aviso. Distingue "aun no se sabe" de "no hay nadie". */
  checked: boolean;
  authUser: AuthUser | null;
}

/**
 * Perfil ya cargado, junto al usuario al que pertenece.
 *
 * Lleva el `userId` dentro a proposito. Sin el no habria forma de distinguir un
 * perfil recien cargado del perfil de quien acaba de cerrar sesion, y durante un
 * instante se mostraria el nombre del usuario anterior.
 */
interface LoadedProfile {
  userId: string;
  user: SessionUser | null;
  error: string | null;
}

/**
 * Cuanto se espera al arranque antes de darse por vencido.
 *
 * Quince segundos es mucho para una red buena y poco para quedarse colgado. El
 * numero sale de lo que se vio en la tablet: con la red bien, el perfil llega en
 * 1,4 s; con la red trabada, no llegaba nunca.
 */
const ARRANQUE_TIMEOUT_MS = 15000;

/**
 * Le pone un limite a una espera que no lo tiene.
 *
 * EL FALLO QUE ARREGLA, encontrado en la tablet: si la peticion del perfil se
 * queda a medias —red que va y viene, que es lo normal en Amalfi— no falla ni
 * responde, y la aplicacion se queda en "Cargando" **para siempre**, sin error,
 * sin reintentar y sin salida. La pantalla de entrada ya sabia enseñar el error
 * y ofrecer las dos cosas; lo que faltaba era que el error llegara a existir.
 *
 * No cancela la peticion, porque `fetch` de React Native no lo permite sin un
 * AbortController que habria que llevar hasta la capa de datos. Lo que hace es
 * dejar de esperarla: si contesta despues, su resultado ya no le importa a
 * nadie.
 */
async function conLimite<T>(tarea: Promise<T>, siTarda: T): Promise<T> {
  let temporizador: ReturnType<typeof setTimeout> | undefined;

  const limite = new Promise<T>((resolve) => {
    temporizador = setTimeout(() => resolve(siTarda), ARRANQUE_TIMEOUT_MS);
  });

  try {
    return await Promise.race([tarea, limite]);
  } finally {
    clearTimeout(temporizador);
  }
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({ checked: false, authUser: null });
  const [loaded, setLoaded] = useState<LoadedProfile | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  const [recovery, setRecovery] = useState<{ active: boolean; error: string | null }>({
    active: false,
    error: null,
  });
  const [confirmationError, setConfirmationError] = useState<string | null>(null);

  // Enlaces de recuperacion de contrasena.
  //
  // Se atienden los dos caminos por los que puede llegar el enlace: la
  // aplicacion cerrada, que se abre con el (getInitialURL), y la aplicacion ya
  // abierta en segundo plano (el evento 'url'). Atender solo uno deja un fallo
  // que aparece exactamente la mitad de las veces.
  useEffect(() => {
    function handleUrl(url: string | null) {
      if (url === null) {
        return;
      }

      if (isRecoveryLink(url)) {
        // Se marca antes de abrir la sesion, no despues. Al abrirla, las guardias
        // reaccionan de inmediato, y si la marca llegara tarde darian tiempo a
        // colar al usuario en la pantalla principal.
        setRecovery({ active: true, error: null });

        void completeRecoveryFromLink(url).then((result) => {
          if (!result.ok) {
            setRecovery({ active: true, error: result.failure.message });
          }
        });
        return;
      }

      if (isConfirmationLink(url)) {
        // Aqui no se bloquea nada: si el enlace abre bien, la suscripcion de
        // Supabase avisa del cambio y las guardias llevan al usuario a su zona.
        setConfirmationError(null);

        void completeConfirmationFromLink(url).then((result) => {
          if (!result.ok) {
            setConfirmationError(result.failure.message);
          }
        });
      }
    }

    void Linking.getInitialURL().then(handleUrl);
    const subscription = Linking.addEventListener('url', (event) => handleUrl(event.url));

    return () => subscription.remove();
  }, []);

  // Suscripcion a Supabase. El primer aviso trae la sesion guardada en el
  // dispositivo, y es lo que hace que la sesion sobreviva a cerrar la app.
  useEffect(() => {
    const unsubscribe = onAuthUserChange((authUser) => {
      setAuth({ checked: true, authUser });
    });

    return unsubscribe;
  }, []);

  // Carga del perfil. Va en un efecto separado y no dentro del aviso anterior
  // porque Supabase desaconseja llamarle desde dentro de su propio manejador:
  // la llamada espera a un candado que el manejador todavia no ha soltado y la
  // aplicacion se queda colgada sin ningun error.
  useEffect(() => {
    const { checked, authUser } = auth;

    // Sin sesion no hay nada que cargar. El estado de "nadie dentro" se deduce
    // mas abajo en lugar de escribirse aqui: un setState sincrono en el cuerpo
    // de un efecto provoca renderizados en cascada, y el compilador de React lo
    // rechaza con razon.
    if (!checked || authUser === null) {
      return;
    }

    const userId = authUser.id;

    let active = true;

    void (async () => {
      const result = await conLimite(fetchProfile(userId), {
        ok: false as const,
        failure: {
          code: 'startup_timeout',
          message: 'No pudimos cargar tu cuenta. Revisa tu conexión e inténtalo de nuevo.',
        },
      });

      // El proveedor pudo desmontarse, o pudo entrar otro usuario, mientras la
      // consulta viajaba. Escribir el resultado ahora pondria en pantalla el
      // perfil de quien ya no esta.
      if (!active) {
        return;
      }

      if (!result.ok) {
        setLoaded({ userId, user: null, error: result.failure.message });
        return;
      }

      const profile = result.data;

      // La ficha de conductor solo se consulta para conductores. Pedirla siempre
      // seria una consulta de mas en cada arranque de cada pasajero, que son la
      // inmensa mayoria.
      let approvalStatus: DriverApproval | null = null;

      if (profile.role === 'driver') {
        const driverResult = await conLimite(fetchDriver(userId), {
          ok: false as const,
          failure: {
            code: 'startup_timeout',
            message: 'No pudimos cargar tu cuenta. Revisa tu conexión e inténtalo de nuevo.',
          },
        });

        if (!active) {
          return;
        }

        if (!driverResult.ok) {
          setLoaded({ userId, user: null, error: driverResult.failure.message });
          return;
        }

        approvalStatus = driverResult.data?.approval_status ?? null;
      }

      setLoaded({
        userId,
        user: {
          id: profile.id,
          fullName: profile.full_name,
          phone: profile.phone,
          email: authUser.email,
          avatarPath: profile.avatar_path,
          role: profile.role,
          status: profile.status,
          approvalStatus,
        },
        error: null,
      });
    })();

    return () => {
      active = false;
    };
  }, [auth, reloadCount]);

  // Estado derivado, no almacenado. El perfil cargado solo cuenta si pertenece a
  // quien tiene la sesion abierta ahora mismo.
  const profileIsCurrent = loaded !== null && loaded.userId === auth.authUser?.id;
  const isLoading = !auth.checked || (auth.authUser !== null && !profileIsCurrent);
  const user = profileIsCurrent ? loaded.user : null;
  const error = profileIsCurrent ? loaded.error : null;

  // Un conductor necesita ademas estar aprobado. Un administrador nunca opera
  // desde el movil, por muy activa que este su cuenta.
  const canOperate =
    user !== null &&
    user.status === 'active' &&
    (user.role === 'passenger' || (user.role === 'driver' && user.approvalStatus === 'approved'));

  // No devuelve promesa a proposito: las pantallas lo llaman desde un onPress y
  // no tienen nada que esperar. El usuario desaparece cuando Supabase avisa del
  // cambio, que es la unica fuente de verdad.
  const signOut = useCallback(() => {
    void requestSignOut();
  }, []);

  const refreshProfile = useCallback(() => {
    setReloadCount((count) => count + 1);
  }, []);

  const endPasswordRecovery = useCallback(() => {
    setRecovery({ active: false, error: null });
  }, []);

  const value = useMemo<SessionValue>(
    () => ({
      user,
      isLoading,
      error,
      canOperate,
      isRecoveringPassword: recovery.active,
      recoveryError: recovery.error,
      confirmationError,
      endPasswordRecovery,
      signOut,
      refreshProfile,
    }),
    [
      user,
      isLoading,
      error,
      canOperate,
      recovery,
      confirmationError,
      endPasswordRecovery,
      signOut,
      refreshProfile,
    ],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

/**
 * Lee la sesion actual.
 *
 * Lanza excepcion si se usa fuera del proveedor. Es deliberado (D75): devolver
 * null se confundiria con una sesion cerrada, y el fallo apareceria como un
 * bucle de redirecciones imposible de diagnosticar.
 */
export function useSession(): SessionValue {
  const context = useContext(SessionContext);

  if (context === null) {
    throw new Error('useSession debe usarse dentro de SessionProvider');
  }

  return context;
}

/**
 * Ruta principal de cada rol. La usan las guardias y el arranque.
 *
 * Un administrador no tiene zona propia en la aplicacion movil, asi que su
 * destino es la pantalla que le explica donde debe entrar.
 */
export function homeRouteFor(role: UserRole): '/passenger' | '/driver' | '/account-status' {
  if (role === 'driver') {
    return '/driver';
  }

  return role === 'admin' || role === 'super_admin' ? '/account-status' : '/passenger';
}
