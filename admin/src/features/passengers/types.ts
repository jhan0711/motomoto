import type { Database } from '@/lib/supabase/database.types';

export type Passenger = Database['public']['Functions']['admin_list_passengers']['Returns'][number];
export type PassengerRide =
  Database['public']['Functions']['admin_get_passenger_rides']['Returns'][number];

export function formatearPesos(valor: number | null): string {
  if (valor === null) return '—';
  return '$' + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/** Sin `Intl`, por D201: su formato depende del idioma del navegador. */
export function formatearFechaHora(iso: string | null): string {
  if (iso === null) return '—';
  const d = new Date(iso);
  const hora = d.getHours().toString().padStart(2, '0');
  const min = d.getMinutes().toString().padStart(2, '0');
  return `${d.getDate()} ${MESES[d.getMonth()] ?? ''} · ${hora}:${min}`;
}

export const ETIQUETA_ESTADO: Record<string, string> = {
  completed: 'Terminado',
  cancelled: 'Cancelado',
  expired: 'Nadie lo tomó',
  searching: 'Buscando',
  assigned: 'Asignado',
  in_progress: 'En recorrido',
};

export const ESTILO_ESTADO: Record<string, string> = {
  completed: 'bg-success-subtle text-success',
  cancelled: 'bg-danger-subtle text-on-danger-subtle',
  expired: 'bg-warning-subtle text-on-warning',
  searching: 'bg-info-subtle text-info',
  assigned: 'bg-info-subtle text-info',
  in_progress: 'bg-info-subtle text-info',
};

export const ETIQUETA_ACTOR: Record<string, string> = {
  passenger: 'el pasajero',
  driver: 'el conductor',
  admin: 'la empresa',
  system: 'el sistema',
};

/**
 * Cuantas de sus solicitudes acabaron mal.
 *
 * **Se calcula en la pantalla y no en el servidor** porque es una lectura, no un
 * dato: la empresa decide si un 40% de cancelaciones es mucho, y ese criterio va
 * a cambiar con el tiempo. Guardarlo lo convertiria en una regla.
 */
export function porcentajeCancelado(p: Passenger): number | null {
  const total = p.completed_count + p.cancelled_count;
  if (total === 0) return null;
  return Math.round((p.cancelled_count / total) * 100);
}
