'use client';

import { createClient } from '@/lib/supabase/client';
import type { RequestStatus, Ride, RideDetail, RideOffer, RideRating } from './types';

function traducir(): string {
  return 'No pudimos consultar los servicios. Inténtalo de nuevo.';
}

export interface Filtros {
  estado: RequestStatus | null;
  desde: string | null;
  hasta: string | null;
  busqueda: string;
}

export async function listarServicios(
  f: Filtros,
  limite: number,
  desplazamiento: number,
): Promise<{ ok: true; servicios: Ride[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_rides', {
    p_status: f.estado ?? undefined,
    p_from: f.desde ?? undefined,
    // El filtro del servidor es `< p_to`, asi que para incluir el dia entero se
    // manda el dia siguiente a medianoche. Si no, "hasta el 27" dejaria fuera
    // todo lo que paso el 27 despues de las 00:00.
    p_to: f.hasta === null ? undefined : `${f.hasta}T23:59:59`,
    p_search: f.busqueda.trim() === '' ? undefined : f.busqueda,
    p_limit: limite,
    p_offset: desplazamiento,
  });

  if (error) return { ok: false, mensaje: traducir() };
  return { ok: true, servicios: data ?? [] };
}

export async function obtenerDetalle(
  requestId: string,
): Promise<
  | { ok: true; detalle: RideDetail; ofertas: RideOffer[]; calificaciones: RideRating[] }
  | { ok: false; mensaje: string }
> {
  const supabase = createClient();

  // Las tres a la vez: la pantalla las necesita juntas y son independientes.
  const [det, ofe, cal] = await Promise.all([
    supabase.rpc('admin_get_ride_detail', { p_request_id: requestId }),
    supabase.rpc('admin_get_ride_offers', { p_request_id: requestId }),
    supabase.rpc('admin_get_ride_ratings', { p_request_id: requestId }),
  ]);

  if (det.error ?? ofe.error ?? cal.error) return { ok: false, mensaje: traducir() };

  const detalle = det.data?.[0];
  if (detalle === undefined) {
    return { ok: false, mensaje: 'No encontramos ese servicio.' };
  }

  return { ok: true, detalle, ofertas: ofe.data ?? [], calificaciones: cal.data ?? [] };
}
