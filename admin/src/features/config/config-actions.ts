'use client';

import { createClient } from '@/lib/supabase/client';
import type { CargoType, Setting, UrbanFare } from './types';

const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  INVALID_FARE_AMOUNT: 'El valor debe estar entre 1 y 1.000.000 de pesos.',
  URBAN_FARE_NOT_FOUND: 'Esa casilla de la rejilla no existe.',
  FARE_UNCHANGED: 'No cambiaste nada.',
  INVALID_CARGO_NAME: 'El nombre debe tener al menos 2 caracteres.',
  CARGO_NAME_TAKEN: 'Ya existe un tipo de carga con ese nombre.',
  CARGO_TYPE_NOT_FOUND: 'No encontramos ese tipo de carga.',
  SETTING_NOT_FOUND: 'Ese parámetro no existe.',
  SETTING_UNCHANGED: 'No cambiaste nada.',
  SETTING_MUST_BE_NUMBER: 'Ese parámetro tiene que ser un número.',
  SETTING_MUST_BE_POSITIVE: 'Ese parámetro no puede ser negativo.',
  INVALID_TIMEZONE: 'Esa zona horaria no existe.',
  INVALID_HOUR: 'La hora debe ser un número entero entre 0 y 23.',
  INVALID_PASSENGER_MAX: 'El máximo de pasajeros debe estar entre 1 y 10.',
  INVALID_OFFER_WINDOW: 'La ventana de oferta debe estar entre 5 y 300 segundos.',
  INVALID_EXPIRY: 'La caducidad debe estar entre 60 y 3600 segundos.',
  INVALID_COORDINATE: 'Esa coordenada no es válida.',
  INVALID_RADIUS: 'El radio debe estar entre 0 y 50 kilómetros.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  return MENSAJES[error.hint?.trim() ?? ''] ?? 'No pudimos completar la operación.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function cargarTodo(): Promise<
  | { ok: true; tarifas: UrbanFare[]; cargas: CargoType[]; parametros: Setting[] }
  | { ok: false; mensaje: string }
> {
  const supabase = createClient();

  // Las tres en paralelo: son independientes y la pantalla las necesita juntas.
  const [tarifas, cargas, parametros] = await Promise.all([
    supabase.rpc('admin_list_urban_fares'),
    supabase.rpc('admin_list_cargo_types'),
    supabase.rpc('admin_list_settings'),
  ]);

  const fallo = tarifas.error ?? cargas.error ?? parametros.error;
  if (fallo) return { ok: false, mensaje: traducir(fallo) };

  return {
    ok: true,
    tarifas: tarifas.data ?? [],
    cargas: cargas.data ?? [],
    parametros: parametros.data ?? [],
  };
}

export async function guardarTarifaUrbana(
  pasajeros: number,
  esNoche: boolean,
  monto: number,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_urban_fare', {
    p_passenger_count: pasajeros,
    p_is_night: esNoche,
    p_amount: monto,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function guardarTipoCarga(
  id: string | null,
  nombre: string,
  monto: number,
  activo: boolean,
  orden: number,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_upsert_cargo_type', {
    // El nulo crea uno nuevo. El generador lo tipa como obligatorio porque el
    // parametro no lleva DEFAULT, igual que en `admin_set_rural_fare`.
    p_cargo_type_id: id as string,
    p_name: nombre,
    p_amount: monto,
    p_is_active: activo,
    p_sort_order: orden,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function guardarParametro(clave: string, valor: string): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_setting', { p_key: clave, p_value: valor });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}
