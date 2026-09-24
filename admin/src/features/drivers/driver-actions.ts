'use client';

import { createClient } from '@/lib/supabase/client';
import type { ApprovalStatus, Driver } from './types';

/**
 * Traduccion de los codigos de error del servidor.
 *
 * El servidor manda un mensaje en espanol y un codigo estable en `hint` (D88).
 * **Se usa el codigo, no el mensaje**: el mensaje puede cambiar de redaccion sin
 * avisar, y comparar cadenas de texto para decidir que ensenar es la forma de
 * que un dia deje de funcionar en silencio.
 */
const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  DRIVER_NOT_FOUND: 'No encontramos a ese conductor.',
  PROFILE_NOT_FOUND: 'No encontramos esa cuenta.',
  NOT_A_DRIVER: 'Esa cuenta no es de un conductor.',
  APPROVAL_UNCHANGED: 'Ese conductor ya está en ese estado.',
  STATUS_UNCHANGED: 'Esa cuenta ya está en ese estado.',
  CONTACT_UNCHANGED: 'No cambiaste nada.',
  NAME_TOO_SHORT: 'El nombre debe tener al menos 3 caracteres.',
  INVALID_PHONE: 'El teléfono debe ser un celular colombiano de 10 dígitos.',
  DRIVER_HAS_ACTIVE_RIDE:
    'Ese conductor tiene un servicio en curso. Resuélvelo antes de retirarle la aprobación.',
  INVALID_EMAIL: 'Ese correo no es válido.',
  EMAIL_TAKEN: 'Ya existe una cuenta con ese correo.',
  VEHICLE_NOT_ACTIVE: 'Ese motocarro no existe o no está activo.',
  CANNOT_CHANGE_OWN_ACCOUNT: 'No puedes cambiar el estado de tu propia cuenta.',
  // Desde el paso 11 el servidor tambien lo exige para los conductores, no
  // solo para los pasajeros: bloquear a alguien que va con un pasajero dentro
  // pide explicacion.
  ACTIVE_RIDE_NEEDS_REASON:
    'Ese conductor tiene un servicio en curso. Escribe el motivo del bloqueo, de al menos 10 caracteres.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  const codigo = error.hint ?? '';
  return MENSAJES[codigo] ?? 'No pudimos completar la operación. Inténtalo de nuevo.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarConductores(): Promise<
  { ok: true; conductores: Driver[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_drivers');

  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, conductores: data ?? [] };
}

export async function cambiarAprobacion(
  driverId: string,
  estado: ApprovalStatus,
  motivo: string | null,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_driver_approval', {
    p_driver_id: driverId,
    p_status: estado,
    // `?? undefined` y no `motivo` a secas: los tipos generados declaran los
    // parametros con valor por defecto como opcionales, no como admisores de
    // nulo, asi que un null explicito no encaja aunque el servidor lo acepte.
    p_reason: motivo ?? undefined,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function cambiarEstadoCuenta(
  userId: string,
  estado: 'active' | 'blocked',
  motivo: string | null,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_account_status', {
    p_user_id: userId,
    p_status: estado,
    // `?? undefined` y no `motivo` a secas: los tipos generados declaran los
    // parametros con valor por defecto como opcionales, no como admisores de
    // nulo, asi que un null explicito no encaja aunque el servidor lo acepte.
    p_reason: motivo ?? undefined,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function editarContacto(
  driverId: string,
  nombre: string,
  telefono: string,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_update_driver_contact', {
    p_driver_id: driverId,
    p_full_name: nombre,
    p_phone: telefono,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

/**
 * Da de alta un conductor. Devuelve la contrasena inicial UNA SOLA VEZ.
 *
 * **Ese valor no se guarda en ningun sitio**: ni en la auditoria, ni en el
 * estado de la pantalla mas alla de lo que dure el dialogo. Si se pierde, hay
 * que restablecerla, que genera otra distinta.
 */
export async function crearConductor(
  correo: string,
  nombre: string,
  telefono: string,
  vehicleId: string | null,
): Promise<{ ok: true; password: string } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_create_driver', {
    p_email: correo,
    p_full_name: nombre,
    p_phone: telefono,
    p_vehicle_id: vehicleId ?? undefined,
  });

  if (error) return { ok: false, mensaje: traducir(error) };

  const fila = data?.[0];
  if (fila === undefined) return { ok: false, mensaje: 'No pudimos crear la cuenta.' };
  return { ok: true, password: fila.initial_password };
}

/** Genera una contrasena nueva para un conductor. Tambien se muestra una vez. */
export async function restablecerContrasena(
  driverId: string,
): Promise<{ ok: true; password: string } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_reset_driver_password', {
    p_driver_id: driverId,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  if (typeof data !== 'string') return { ok: false, mensaje: 'No pudimos generar la contraseña.' };
  return { ok: true, password: data };
}
