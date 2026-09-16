import type { Database } from '@/lib/supabase/database.types';

export type Driver = Database['public']['Functions']['admin_list_drivers']['Returns'][number];

export type ApprovalStatus = Database['public']['Enums']['driver_approval_status'];
export type AccountStatus = Database['public']['Enums']['user_status'];
export type UnavailableReasonCode = Database['public']['Enums']['driver_unavailable_reason_code'];

/** Mismo catalogo que `src/features/driver/unavailable-reason.ts` del lado
 * del conductor (D270). Los dos proyectos generan sus tipos del mismo
 * esquema pero no comparten codigo entre si, asi que la lista vive por
 * duplicado en cada uno -igual que ya pasa con ETIQUETA_APROBACION. */
export const ETIQUETA_MOTIVO_NO_DISPONIBLE: Record<UnavailableReasonCode, string> = {
  almuerzo: 'Almuerzo',
  descanso: 'Descanso',
  combustible: 'Cargando combustible',
  fin_de_turno: 'Fin de turno',
  otro: 'Otro',
};

export const ETIQUETA_APROBACION: Record<ApprovalStatus, string> = {
  pending: 'Pendiente de aprobar',
  approved: 'Aprobado',
  blocked: 'Aprobación retirada',
};

/*
 * El color va siempre con su texto y su icono, nunca solo (D202). Aqui ademas
 * hay un motivo practico: "pendiente" y "retirado" son dos situaciones muy
 * distintas -una espera una decision, la otra ya la tuvo- y distinguirlas solo
 * por el tono seria pedirle al ojo lo que la palabra dice sin esfuerzo.
 */
export const ESTILO_APROBACION: Record<ApprovalStatus, string> = {
  pending: 'bg-warning-subtle text-on-warning',
  approved: 'bg-success-subtle text-success',
  blocked: 'bg-danger-subtle text-on-danger-subtle',
};
