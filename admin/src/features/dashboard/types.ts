import type { Database } from '@/lib/supabase/database.types';

/**
 * Una fila del tablero, tal como la devuelve `admin_list_active_services`.
 *
 * Se deriva del tipo generado desde el esquema real y no se escribe a mano
 * (D89). Si manana la funcion gana una columna, esto la trae sola.
 */
export type ActiveService =
  Database['public']['Functions']['admin_list_active_services']['Returns'][number];

export type RequestStatus = Database['public']['Enums']['ride_request_status'];

/**
 * Un conductor candidato para la asignacion manual, tal como lo devuelve
 * `admin_list_assignable_drivers`. Trae `can_assign` y `blocked_reason` ya
 * resueltos por el servidor: **la pantalla no decide quien puede, solo lo
 * ensena**.
 */
export type AssignableDriver =
  Database['public']['Functions']['admin_list_assignable_drivers']['Returns'][number];

/**
 * Los tres estados que el tablero muestra, en el orden en que se leen: primero
 * lo que aun no tiene conductor, que es lo que puede irse al traste.
 */
export const ESTADOS_VIVOS = ['searching', 'assigned', 'in_progress'] as const;

export const ETIQUETA_ESTADO: Record<string, string> = {
  searching: 'Buscando motocarro',
  assigned: 'Conductor asignado',
  in_progress: 'En recorrido',
};
