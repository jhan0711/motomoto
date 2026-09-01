import type { Database } from '@/lib/supabase/database.types';

export type Ride = Database['public']['Functions']['admin_list_rides']['Returns'][number];
export type RideDetail =
  Database['public']['Functions']['admin_get_ride_detail']['Returns'][number];
export type RideOffer = Database['public']['Functions']['admin_get_ride_offers']['Returns'][number];
export type RideRating =
  Database['public']['Functions']['admin_get_ride_ratings']['Returns'][number];
export type RequestStatus = Database['public']['Enums']['ride_request_status'];

export const ETIQUETA_ESTADO: Record<RequestStatus, string> = {
  searching: 'Buscando',
  assigned: 'Asignado',
  in_progress: 'En recorrido',
  completed: 'Terminado',
  cancelled: 'Cancelado',
  expired: 'Nadie lo tomó',
};

export const ESTILO_ESTADO: Record<RequestStatus, string> = {
  searching: 'bg-info-subtle text-info',
  assigned: 'bg-info-subtle text-info',
  in_progress: 'bg-info-subtle text-info',
  completed: 'bg-success-subtle text-success',
  cancelled: 'bg-danger-subtle text-on-danger-subtle',
  expired: 'bg-warning-subtle text-on-warning',
};

export const ESTADOS: RequestStatus[] = [
  'searching',
  'assigned',
  'in_progress',
  'completed',
  'cancelled',
  'expired',
];

export const ETIQUETA_ACTOR: Record<string, string> = {
  passenger: 'el pasajero',
  driver: 'el conductor',
  admin: 'la empresa',
  system: 'el sistema',
};

export const ETIQUETA_RESPUESTA: Record<string, string> = {
  pending: 'Sin responder',
  accepted: 'Aceptó',
  rejected: 'Rechazó',
  expired: 'Dejó pasar el tiempo',
};

export const ESTILO_RESPUESTA: Record<string, string> = {
  pending: 'bg-surface-subtle text-text-secondary',
  accepted: 'bg-success-subtle text-success',
  rejected: 'bg-danger-subtle text-on-danger-subtle',
  expired: 'bg-warning-subtle text-on-warning',
};

export function formatearPesos(valor: number | null): string {
  if (valor === null) return 'Sin valor';
  return '$' + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/** A mano y sin `Intl`, por D201. */
export function formatearFechaHora(iso: string | null): string {
  if (iso === null) return '—';
  const d = new Date(iso);
  const hh = d.getHours().toString().padStart(2, '0');
  const mm = d.getMinutes().toString().padStart(2, '0');
  return `${d.getDate()} ${MESES[d.getMonth()] ?? ''} ${d.getFullYear()} · ${hh}:${mm}`;
}

export function formatearHora(iso: string | null): string {
  if (iso === null) return '—';
  const d = new Date(iso);
  return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
}

export function formatearDistancia(metros: number | null): string {
  if (metros === null) return '—';
  if (metros < 1000) return `${metros} m`;
  return `${(metros / 1000).toFixed(1).replace('.', ',')} km`;
}

export function formatearDuracion(segundos: number | null): string {
  if (segundos === null) return '—';
  const min = Math.round(segundos / 60);
  if (min < 60) return `${min} min`;
  return `${Math.floor(min / 60)} h ${min % 60} min`;
}

/**
 * Un paso de la linea de tiempo.
 *
 * Se arma en la pantalla a partir de las fechas sueltas del detalle, y **los
 * pasos que no ocurrieron se muestran igual, apagados**: ver que un servicio
 * nunca llego a "el conductor llego" dice tanto como ver que si.
 */
export interface Paso {
  etiqueta: string;
  cuando: string | null;
}

export function pasosDe(d: RideDetail): Paso[] {
  const pasos: Paso[] = [
    { etiqueta: 'El pasajero lo pidió', cuando: d.requested_at },
    { etiqueta: 'Un conductor aceptó', cuando: d.accepted_at },
    { etiqueta: 'El conductor llegó', cuando: d.driver_arrived_at },
    { etiqueta: 'Empezó el recorrido', cuando: d.started_at },
    { etiqueta: 'Terminó', cuando: d.completed_at },
  ];

  // La cancelacion sustituye al final, no se suma: un servicio cancelado no
  // termino.
  if (d.cancelled_at !== null) {
    return [...pasos.slice(0, 4), { etiqueta: 'Se canceló', cuando: d.cancelled_at }];
  }
  return pasos;
}
