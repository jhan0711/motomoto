'use client';

import { createClient } from '@/lib/supabase/client';
import type { AssignableDriver } from './types';

/**
 * Los dos pasos de la asignacion manual (D7).
 *
 * EL MENSAJE DE ERROR SALE DEL SERVIDOR, NO DE AQUI. `admin_assign_driver`
 * levanta sus errores con texto en espanol y un codigo estable en `hint`
 * (D88), justamente para que la pantalla no tenga que adivinar que paso: si
 * el conductor se puso a trabajar entre que se abrio la lista y se pulso el
 * boton, quien lo sabe es el servidor.
 */
function traducir(error: { message: string } | null, porDefecto: string): string {
  if (error === null) return porDefecto;
  return error.message.trim() === '' ? porDefecto : error.message;
}

export async function listarAsignables(
  requestId: string,
): Promise<{ ok: true; conductores: AssignableDriver[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_assignable_drivers', {
    p_request_id: requestId,
  });

  if (error) {
    return { ok: false, mensaje: traducir(error, 'No pudimos consultar los conductores.') };
  }
  return { ok: true, conductores: data ?? [] };
}

export async function asignarConductor(
  requestId: string,
  driverId: string,
  motivo: string,
): Promise<{ ok: true } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_assign_driver', {
    p_request_id: requestId,
    p_driver_id: driverId,
    p_reason: motivo.trim() === '' ? undefined : motivo.trim(),
  });

  if (error) {
    return { ok: false, mensaje: traducir(error, 'No pudimos asignar el conductor.') };
  }
  return { ok: true };
}
