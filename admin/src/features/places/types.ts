import type { Database } from '@/lib/supabase/database.types';

export type Place = Database['public']['Functions']['admin_list_places']['Returns'][number];

/**
 * Como se clasifica un lugar en la pantalla.
 *
 * **Lo que hace rural a un destino es tener tarifa, no estar lejos** (D218), asi
 * que esto no se deduce de la distancia: se deduce de si tiene precio propio.
 */
export type Clase = 'urbano' | 'rural' | 'sin-tarifa';

export function claseDe(lugar: Place): Clase {
  if (lugar.needs_fare) return 'sin-tarifa';
  return lugar.rural_is_active === true ? 'rural' : 'urbano';
}

export const ETIQUETA_CLASE: Record<Clase, string> = {
  urbano: 'Tarifa urbana',
  rural: 'Tarifa propia',
  'sin-tarifa': 'Sin tarifa',
};

export const ESTILO_CLASE: Record<Clase, string> = {
  urbano: 'bg-surface-subtle text-text-secondary',
  rural: 'bg-info-subtle text-info',
  'sin-tarifa': 'bg-danger-subtle text-on-danger-subtle',
};

/** Pesos sin decimales, como en el resto del proyecto (D225). */
export function formatearPesos(valor: number | null): string {
  if (valor === null) return '—';
  return '$' + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

export function formatearDistancia(metros: number): string {
  if (metros < 1000) return `${metros} m`;
  return `${(metros / 1000).toFixed(1).replace('.', ',')} km`;
}
