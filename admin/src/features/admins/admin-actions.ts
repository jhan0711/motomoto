'use client';

import { createClient } from '@/lib/supabase/client';
import type { Admin } from './types';

/**
 * Traduccion de los codigos de error del servidor (D88). Se usa el codigo del
 * `hint`, no el mensaje, que puede cambiar de redaccion sin avisar.
 */
const MENSAJES: Record<string, string> = {
  NEEDS_SUPER_ADMIN: 'Solo el super administrador puede hacer esto.',
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  PROFILE_NOT_FOUND: 'No encontramos esa cuenta.',
  NOT_AN_ADMIN_ACCOUNT: 'Esa cuenta no es de un administrador.',
  STATUS_UNCHANGED: 'Esa cuenta ya está en ese estado.',
  CANNOT_CHANGE_OWN_ACCOUNT: 'No puedes cambiar el estado de tu propia cuenta.',
  INVALID_EMAIL: 'Ese correo no es válido.',
  EMAIL_TAKEN: 'Ya existe una cuenta con ese correo.',
  NAME_TOO_SHORT: 'El nombre debe tener al menos 3 caracteres.',
  INVALID_PHONE: 'El teléfono debe ser un celular colombiano de 10 dígitos.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  return (
    MENSAJES[error.hint?.trim() ?? ''] ?? 'No pudimos completar la operación. Inténtalo de nuevo.'
  );
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarAdministradores(): Promise<
  { ok: true; administradores: Admin[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_admins');
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, administradores: data ?? [] };
}

/**
 * Da de alta un administrador. Devuelve la contrasena inicial UNA SOLA VEZ.
 * Ese valor no se guarda en ningun sitio: ni en la auditoria, ni en el estado
 * mas alla de lo que dure el dialogo.
 */
export async function crearAdministrador(
  correo: string,
  nombre: string,
  telefono: string,
): Promise<{ ok: true; password: string } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_create_admin', {
    p_email: correo,
    p_full_name: nombre,
    p_phone: telefono,
  });

  if (error) return { ok: false, mensaje: traducir(error) };

  const fila = data?.[0];
  if (fila === undefined) return { ok: false, mensaje: 'No pudimos crear la cuenta.' };
  return { ok: true, password: fila.initial_password };
}

/** Genera una contrasena nueva para un administrador. Tambien se muestra una vez. */
export async function restablecerContrasena(
  adminId: string,
): Promise<{ ok: true; password: string } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_reset_admin_password', {
    p_admin_id: adminId,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  if (typeof data !== 'string') return { ok: false, mensaje: 'No pudimos generar la contraseña.' };
  return { ok: true, password: data };
}

export async function cambiarEstadoAdministrador(
  userId: string,
  estado: 'active' | 'blocked',
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_account_status', {
    p_user_id: userId,
    p_status: estado,
  });

  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}
