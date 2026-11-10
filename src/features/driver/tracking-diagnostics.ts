import { Platform } from 'react-native';

import { supabase } from '@/lib/supabase';

/**
 * Diario tecnico del seguimiento de ubicacion (fase A, 2026-11-10).
 *
 * Existe para poder responder, con una consulta y no con suposiciones, POR QUE
 * un conductor "disponible" deja de aparecer al minimizar la aplicacion: si la
 * tarea en segundo plano ni se ejecuta, si se ejecuta y el envio falla, o si el
 * permiso cambio. Ver `supabase/migrations/20261110200000_driver_tracking_
 * events.sql`.
 *
 * REGLAS DE ESTE ARCHIVO.
 * - NUNCA lanza ni bloquea: un fallo de diagnostico no puede romper el
 *   seguimiento que intenta diagnosticar. Todo error se traga.
 * - Sin coordenadas ni datos personales en `detail`.
 * - La tarea en segundo plano se llama muchas veces: `task_fired` va limitado a
 *   una fila por minuto. Los fallos y los cambios de estado NO se limitan.
 */

export type TrackingEventSource = 'task' | 'app';

/** Cada cuanto como maximo se anota que la tarea se ejecuto bien. */
const MIN_MS_BETWEEN_TASK_FIRED = 60_000;

let lastTaskFiredAt = 0;

export async function logTrackingEvent(
  driverId: string | null,
  source: TrackingEventSource,
  kind: string,
  detail: Record<string, unknown> = {},
): Promise<void> {
  if (driverId === null) return;

  try {
    await supabase.from('driver_tracking_events').insert({
      driver_id: driverId,
      source,
      kind,
      platform: Platform.OS === 'ios' ? 'ios' : 'android',
      detail: detail as never,
    });
  } catch {
    // Diagnostico: se ignora a proposito.
  }
}

/** Como `logTrackingEvent`, pero solo una vez por minuto. Para `task_fired`. */
export async function logTaskFiredThrottled(
  driverId: string | null,
  detail: Record<string, unknown>,
): Promise<void> {
  const now = Date.now();
  if (now - lastTaskFiredAt < MIN_MS_BETWEEN_TASK_FIRED) return;
  lastTaskFiredAt = now;
  await logTrackingEvent(driverId, 'task', 'task_fired', detail);
}
