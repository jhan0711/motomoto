import type { Database } from '@/lib/supabase/database.types';

export type Driver = Database['public']['Functions']['admin_list_drivers']['Returns'][number];

export type ApprovalStatus = Database['public']['Enums']['driver_approval_status'];
export type AccountStatus = Database['public']['Enums']['user_status'];

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
