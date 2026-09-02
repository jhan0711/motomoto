import type { Database } from '@/lib/supabase/database.types';

/**
 * Una fila de la bandeja y una calificacion del listado, derivadas del esquema
 * real y no escritas a mano (D89).
 */
export type Report = Database['public']['Functions']['admin_list_reports']['Returns'][number];
export type Rating = Database['public']['Functions']['admin_list_ratings']['Returns'][number];
export type ReportStatus = Database['public']['Enums']['report_status'];

export const ETIQUETA_ESTADO: Record<ReportStatus, string> = {
  open: 'Sin atender',
  in_review: 'En revisión',
  resolved: 'Resuelto',
};

/*
 * El estado va siempre con texto propio ademas del color (D202): los pares de
 * color no llegan al contraste minimo (H14) y una bandeja que solo distingue
 * por color no la puede leer quien no distingue esos colores.
 */
export const ESTILO_ESTADO: Record<ReportStatus, string> = {
  open: 'bg-danger-subtle text-on-danger-subtle',
  in_review: 'bg-warning-subtle text-on-warning',
  resolved: 'bg-surface-subtle text-text-secondary',
};

/** Pesos y fechas se escriben a mano, no con `Intl` (D201). */
const MESES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

export function formatearFechaHora(iso: string): string {
  const d = new Date(iso);
  const hh = d.getHours().toString().padStart(2, '0');
  const mm = d.getMinutes().toString().padStart(2, '0');
  return `${d.getDate()} de ${MESES[d.getMonth()]}, ${hh}:${mm}`;
}

/**
 * Cuanto lleva esperando respuesta.
 *
 * **Es el dato que ordena la bandeja**, asi que se dice en cada fila: un
 * reporte de hace cinco dias sin atender no es lo mismo que uno de esta manana,
 * y la fecha sola obliga a hacer la resta mentalmente.
 */
export function formatearEspera(iso: string): string {
  const dias = Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
  if (dias >= 1) return dias === 1 ? 'hace 1 día' : `hace ${dias} días`;

  const horas = Math.floor((Date.now() - new Date(iso).getTime()) / 3_600_000);
  if (horas >= 1) return horas === 1 ? 'hace 1 hora' : `hace ${horas} horas`;
  return 'hace menos de una hora';
}
