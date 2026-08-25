import { toAuthFailure } from '@/features/auth/errors';
import { supabase } from '@/lib/supabase';

import type { Result } from '@/features/auth/auth-service';

/**
 * Guarda el token de Expo Push del dispositivo, o lo borra.
 *
 * Escritura directa a `profiles`, sin pasar por una funcion (Fase 19,
 * excepcion acotada mas de las que ya describe D83): la columna no esta
 * protegida por `protect_profile_columns` porque es justo lo que el dueño de
 * la cuenta tiene que poder escribir.
 *
 * Se llama con `null` al cerrar sesion desde este dispositivo, para que un
 * telefono compartido o reinstalado no siga recibiendo avisos de una cuenta
 * que ya no es la suya.
 */
export async function savePushToken(token: string | null): Promise<Result> {
  const { data: sesion } = await supabase.auth.getUser();
  const uid = sesion.user?.id;

  if (uid === undefined) {
    return { ok: false, failure: { code: 'no_session', message: 'No hay sesión.' } };
  }

  const { error } = await supabase.from('profiles').update({ push_token: token }).eq('id', uid);

  if (error) {
    return { ok: false, failure: toAuthFailure(error) };
  }

  return { ok: true, data: undefined };
}
