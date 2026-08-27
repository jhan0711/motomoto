'use client';

import { createClient } from '@/lib/supabase/client';
import type { Place } from './types';

const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  PLACE_NOT_FOUND: 'No encontramos ese lugar.',
  INVALID_PLACE_NAME: 'El nombre debe tener entre 2 y 120 caracteres.',
  PLACE_NAME_TAKEN: 'Ya existe un lugar con ese nombre.',
  PLACE_NEEDS_LOCATION: 'El lugar necesita una coordenada.',
  PLACE_OUTSIDE_SERVICE_AREA: 'Ese punto está fuera del área de servicio del municipio.',
  INVALID_FARE_AMOUNT: 'La tarifa debe estar entre 1 y 1.000.000 de pesos.',
  NO_RURAL_FARE: 'Ese lugar no tiene tarifa propia que quitar.',
  FARE_UNCHANGED: 'No cambiaste nada.',
};

/*
 * `DISTANT_PLACE_NEEDS_FARE` NO esta en el mapa a proposito.
 *
 * Es el mensaje de D229, y el servidor lo manda con la distancia dentro: "Ese
 * lugar esta a 10,4 km del centro. Necesita una tarifa rural...". **Ese numero
 * es lo que permite decidir** si hay que ponerle precio o si se movio mal la
 * chincheta, y no se puede calcular aqui sin repetir la formula del servidor.
 *
 * Es el mismo criterio que D247 con el companero de turno: se usa el texto del
 * servidor cuando lleva un dato que el cliente no tiene. Sigue decidiendo el
 * `hint`; el texto solo se muestra.
 */
const USAN_TEXTO_DEL_SERVIDOR = new Set(['DISTANT_PLACE_NEEDS_FARE']);

function traducir(error: { hint?: string | null; message: string }): string {
  const codigo = error.hint?.trim() ?? '';
  if (USAN_TEXTO_DEL_SERVIDOR.has(codigo) && error.message.trim() !== '') return error.message;
  return MENSAJES[codigo] ?? 'No pudimos completar la operación. Inténtalo de nuevo.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarLugares(): Promise<
  { ok: true; lugares: Place[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_places');
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, lugares: data ?? [] };
}

export async function crearLugar(
  nombre: string,
  lng: number,
  lat: number,
  descripcion: string,
  tarifaRural: number | null,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_create_place', {
    p_name: nombre,
    p_lng: lng,
    p_lat: lat,
    p_description: descripcion.trim() === '' ? undefined : descripcion,
    p_rural_amount: tarifaRural ?? undefined,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

export async function editarLugar(
  placeId: string,
  nombre: string,
  descripcion: string,
  activo: boolean,
  orden: number,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_update_place', {
    p_place_id: placeId,
    p_name: nombre,
    p_description: descripcion,
    p_is_active: activo,
    p_sort_order: orden,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}

/**
 * Nulo apaga la tarifa; un numero la pone o la cambia.
 *
 * El `as number` no esconde nada: el generador de tipos declara `p_amount` como
 * obligatorio y no nulo porque **en la funcion no lleva DEFAULT**, y no tiene
 * forma de saber que el nulo es un valor con significado -"apagar"-. En el
 * servidor si lo tiene, y ahi esta la comprobacion que decide.
 *
 * Se prefirio esto a darle un DEFAULT en la base de datos solo para contentar al
 * generador: eso haria que llamarla sin monto apagara la tarifa por descuido, y
 * apagar un precio tiene que ser siempre una decision escrita.
 */
export async function ponerTarifaRural(placeId: string, monto: number | null): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_rural_fare', {
    p_place_id: placeId,
    p_amount: monto as number,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}
