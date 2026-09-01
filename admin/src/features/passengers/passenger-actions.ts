'use client';

import { createClient } from '@/lib/supabase/client';
import type { Passenger, PassengerRide } from './types';

const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  PROFILE_NOT_FOUND: 'No encontramos esa cuenta.',
  STATUS_UNCHANGED: 'Esa cuenta ya está en ese estado.',
  CANNOT_CHANGE_OWN_ACCOUNT: 'No puedes cambiar el estado de tu propia cuenta.',
  ACTIVE_RIDE_NEEDS_REASON:
    'Esa persona tiene un servicio en curso. Escribe el motivo del bloqueo, de al menos 10 caracteres.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  return MENSAJES[error.hint?.trim() ?? ''] ?? 'No pudimos completar la operación.';
}

export interface Resultado {
  ok: boolean;
  /** El codigo del servidor, para que la pantalla sepa pedir un motivo. */
  codigo?: string;
  mensaje?: string;
}

export async function listarPasajeros(): Promise<
  { ok: true; pasajeros: Passenger[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_passengers');
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, pasajeros: data ?? [] };
}

export async function listarServiciosDe(
  passengerId: string,
): Promise<{ ok: true; servicios: PassengerRide[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_get_passenger_rides', {
    p_passenger_id: passengerId,
    p_limit: 20,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, servicios: data ?? [] };
}

export async function cambiarEstadoPasajero(
  userId: string,
  estado: 'active' | 'blocked',
  motivo: string | null,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_account_status', {
    p_user_id: userId,
    p_status: estado,
    p_reason: motivo ?? undefined,
  });

  if (error) {
    /*
     * El codigo se devuelve ademas del mensaje. Es lo que permite a la pantalla
     * **abrir el cuadro del motivo** cuando el servidor responde
     * ACTIVE_RIDE_NEEDS_REASON, en vez de limitarse a ensenar un error que el
     * usuario no sabe como resolver.
     */
    return { ok: false, codigo: error.hint?.trim() ?? '', mensaje: traducir(error) };
  }
  return { ok: true };
}
