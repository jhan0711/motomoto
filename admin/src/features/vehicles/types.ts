import type { Database } from '@/lib/supabase/database.types';

export type Vehicle = Database['public']['Functions']['admin_list_vehicles']['Returns'][number];
export type VehicleStatus = Database['public']['Enums']['vehicle_status'];

/**
 * Un conductor de los que comparten una unidad (D246, doble turno).
 *
 * La funcion lo devuelve como `jsonb`, y los tipos generados lo tipan como
 * `Json` porque el generador no puede saber que hay dentro. Esta interfaz dice
 * la forma real, y `leerConductores` es el unico sitio que hace la conversion:
 * asi el `as` vive en una linea y no repartido por la pantalla.
 */
export interface VehicleDriver {
  id: string;
  name: string;
  is_available: boolean;
}

export function leerConductores(vehiculo: Vehicle): VehicleDriver[] {
  return Array.isArray(vehiculo.drivers) ? (vehiculo.drivers as unknown as VehicleDriver[]) : [];
}

export const ETIQUETA_ESTADO: Record<VehicleStatus, string> = {
  active: 'Activo',
  maintenance: 'En taller',
  retired: 'Retirado',
};

/*
 * El color va siempre con su texto (D202). "En taller" y "Retirado" se
 * distinguen a proposito con tonos distintos: uno vuelve y el otro no.
 */
export const ESTILO_ESTADO: Record<VehicleStatus, string> = {
  active: 'bg-success-subtle text-success',
  maintenance: 'bg-warning-subtle text-on-warning',
  retired: 'bg-surface-subtle text-text-secondary',
};

export const ESTADOS: VehicleStatus[] = ['active', 'maintenance', 'retired'];
