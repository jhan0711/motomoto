import type { Database } from '@/lib/supabase/database.types';

export type DocumentRow =
  Database['public']['Functions']['admin_list_documents']['Returns'][number];
export type DocumentType =
  Database['public']['Functions']['admin_list_document_types']['Returns'][number];
export type DocumentOwner = Database['public']['Enums']['document_owner'];

/** El bucket privado del paso 4c. Las direcciones se firman, no se guardan. */
export const BUCKET = 'documents';

/**
 * Fechas escritas a mano, sin `Intl`, por el mismo motivo que D201: el formato
 * de `Intl` depende del idioma del navegador, y uno en ingles pintaria
 * "August 27, 2026" dentro de una pantalla en espanol.
 */
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

export function formatearFecha(iso: string | null): string {
  if (iso === null) return '—';
  // Se parte la cadena en vez de usar `new Date`: una fecha sin hora se
  // interpreta como UTC y en Colombia se veria el dia anterior.
  const partes = iso.split('-');
  const anio = partes[0];
  const mes = Number.parseInt(partes[1] ?? '1', 10) - 1;
  const dia = Number.parseInt(partes[2] ?? '1', 10);
  return `${dia} de ${MESES[mes] ?? ''} de ${anio}`;
}

/*
 * El estado va con su texto y su color, nunca solo con el color (D202). Y son
 * tres y no dos: "vencido" y "vence pronto" piden acciones distintas -uno hay
 * que resolverlo ya, el otro se puede planificar-.
 */
export type EstadoDocumento = 'vencido' | 'pronto' | 'al-dia' | 'sin-fecha';

export function estadoDe(doc: DocumentRow): EstadoDocumento {
  if (doc.is_expired) return 'vencido';
  if (doc.expires_soon) return 'pronto';
  return doc.expires_at === null ? 'sin-fecha' : 'al-dia';
}

export const ETIQUETA_ESTADO: Record<EstadoDocumento, string> = {
  vencido: 'Vencido',
  pronto: 'Vence pronto',
  'al-dia': 'Al día',
  'sin-fecha': 'Sin vencimiento',
};

export const ESTILO_ESTADO: Record<EstadoDocumento, string> = {
  vencido: 'bg-danger-subtle text-on-danger-subtle',
  pronto: 'bg-warning-subtle text-on-warning',
  'al-dia': 'bg-success-subtle text-success',
  'sin-fecha': 'bg-surface-subtle text-text-secondary',
};
