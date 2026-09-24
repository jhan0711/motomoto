'use client';

import { createClient } from '@/lib/supabase/client';
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
};

function traducir(error: { hint?: string | null; message: string }): string {
  return MENSAJES[error.hint ?? ''] ?? 'No pudimos completar la operación. Inténtalo de nuevo.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarVehiculos(): Promise<
  { ok: true; vehiculos: Vehicle[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_vehicles');
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
