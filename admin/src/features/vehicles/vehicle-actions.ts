'use client';

import { createClient } from '@/lib/supabase/client';
import { BUCKET } from '@/features/documents/types';
import type { Vehicle, VehicleStatus } from './types';

/**
 * Los errores se traducen por su codigo `hint`, nunca por el texto del mensaje
 * (D88). Mismo criterio que en el modulo de conductores.
 */
const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  VEHICLE_NOT_FOUND: 'No encontramos ese motocarro.',
  DRIVER_NOT_FOUND: 'No encontramos a ese conductor.',
  INVALID_UNIT_NUMBER: 'El número de motocarro debe ser mayor que cero.',
  INVALID_PLATE: 'La placa debe tener entre 5 y 10 caracteres.',
  INVALID_CAPACITY: 'La capacidad debe estar entre 1 y 10 pasajeros.',
  UNIT_NUMBER_TAKEN: 'Ya existe un motocarro con ese número.',
  PLATE_TAKEN: 'Ya existe un motocarro con esa placa.',
  VEHICLE_NOT_ACTIVE: 'Ese motocarro no está activo, así que no se puede asignar.',
  VEHICLE_HAS_ACTIVE_RIDE:
    'Ese motocarro tiene un servicio en curso. Resuélvelo antes de cambiarle el estado.',
  CAPACITY_BELOW_CURRENT_LOAD:
    'Ese motocarro lleva más pasajeros ahora mismo de los que quieres dejarle.',
  ASSIGNMENT_HAS_ACTIVE_RIDE:
    'Hay un servicio en curso con ese conductor o ese motocarro. Resuélvelo primero.',
  ASSIGNMENT_UNCHANGED: 'Ese conductor ya lleva ese motocarro.',
  NO_ASSIGNMENT: 'Ese conductor no tiene ningún motocarro asignado.',
  // D306: archivar, restaurar y eliminar.
  ALREADY_ARCHIVED: 'Ese motocarro ya está archivado.',
  NOT_ARCHIVED: 'Ese motocarro no está archivado.',
  VEHICLE_HAS_HISTORY:
    'Ese motocarro tiene viajes o conductores que lo llevaron: no se puede eliminar, solo archivar.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  return MENSAJES[error.hint ?? ''] ?? 'No pudimos completar la operación. Inténtalo de nuevo.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarVehiculos(
  archivados = false,
): Promise<{ ok: true; vehiculos: Vehicle[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_vehicles', { p_archived: archivados });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, vehiculos: data ?? [] };
}

export async function crearVehiculo(
  numero: number,
  placa: string,
  modelo: string,
  capacidad: number,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_create_vehicle', {
    p_unit_number: numero,
    p_plate: placa,
    p_model: modelo.trim() === '' ? undefined : modelo,
    p_max_passengers: capacidad,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function editarVehiculo(
  vehicleId: string,
  numero: number,
  placa: string,
  modelo: string,
  capacidad: number,
  estado: VehicleStatus,
  notas: string,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_update_vehicle', {
    p_vehicle_id: vehicleId,
    p_unit_number: numero,
    p_plate: placa,
    p_model: modelo,
    p_max_passengers: capacidad,
    p_status: estado,
    p_notes: notas,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function asignarVehiculo(driverId: string, vehicleId: string): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_assign_vehicle', {
    p_driver_id: driverId,
    p_vehicle_id: vehicleId,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function quitarVehiculo(driverId: string): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_unassign_vehicle', { p_driver_id: driverId });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

/** D306. Lo oculta de la lista, lo deja "Retirado" y le quita los conductores. */
export async function archivarVehiculo(vehicleId: string): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_archive_vehicle', { p_vehicle_id: vehicleId });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

/** D306. Lo devuelve a la lista como "Activo". */
export async function restaurarVehiculo(vehicleId: string): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_restore_vehicle', { p_vehicle_id: vehicleId });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

/** D306. Elimina para siempre un motocarro SIN historial (y quita sus documentos). */
export async function eliminarVehiculo(vehicleId: string): Promise<Resultado> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_delete_vehicle', { p_vehicle_id: vehicleId });
  if (error) return { ok: false, mensaje: traducir(error) };

  const rutas = data ?? [];
  if (rutas.length > 0) await supabase.storage.from(BUCKET).remove(rutas);
  return { ok: true };
}
