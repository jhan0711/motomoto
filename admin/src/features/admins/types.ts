import type { Database } from '@/lib/supabase/database.types';

export type Admin = Database['public']['Functions']['admin_list_admins']['Returns'][number];

export type AccountStatus = Database['public']['Enums']['user_status'];

export const ETIQUETA_ESTADO: Record<AccountStatus, string> = {
  active: 'Activa',
  blocked: 'Bloqueada',
};

// El color va siempre con su texto, nunca solo (D202).
export const ESTILO_ESTADO: Record<AccountStatus, string> = {
  active: 'bg-success-subtle text-success',
  blocked: 'bg-danger-subtle text-on-danger-subtle',
};
