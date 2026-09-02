'use client';

import { createClient } from '@/lib/supabase/client';
import type { Rating, Report, ReportStatus } from './types';

/**
 * El mensaje de error sale del servidor cuando lo trae (D88): `admin_set_report_status`
 * levanta los suyos en espanol -"para cerrar un reporte hay que escribir que se
 * hizo"- y repetirlos aqui seria tener el mismo texto en dos sitios que se
 * separan con el tiempo.
 */
function traducir(error: { message: string } | null, porDefecto: string): string {
  if (error === null) return porDefecto;
  return error.message.trim() === '' ? porDefecto : error.message;
}

export interface FiltrosReportes {
  estado: ReportStatus | null;
  busqueda: string;
}

export async function listarReportes(
  f: FiltrosReportes,
  limite: number,
  desplazamiento: number,
): Promise<{ ok: true; reportes: Report[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_reports', {
    p_status: f.estado ?? undefined,
    p_search: f.busqueda.trim() === '' ? undefined : f.busqueda,
    p_limit: limite,
    p_offset: desplazamiento,
  });

  if (error) return { ok: false, mensaje: traducir(error, 'No pudimos consultar los reportes.') };
  return { ok: true, reportes: data ?? [] };
}

export async function cambiarEstado(
  reportId: string,
  estado: ReportStatus,
  notas: string,
): Promise<{ ok: true } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_set_report_status', {
    p_report_id: reportId,
    p_status: estado,
    p_notes: notas.trim() === '' ? undefined : notas.trim(),
  });

  if (error) return { ok: false, mensaje: traducir(error, 'No pudimos cambiar el estado.') };
  return { ok: true };
}

export interface FiltrosCalificaciones {
  soloMalas: boolean;
  soloConComentario: boolean;
}

export async function listarCalificaciones(
  f: FiltrosCalificaciones,
  limite: number,
  desplazamiento: number,
): Promise<{ ok: true; calificaciones: Rating[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_ratings', {
    // Dos estrellas o menos es lo que la empresa llama "mala": el corte vive
    // aqui y no en el servidor porque es un criterio suyo, no una regla.
    p_max_stars: f.soloMalas ? 2 : undefined,
    p_only_with_comment: f.soloConComentario,
    p_limit: limite,
    p_offset: desplazamiento,
  });

  if (error) {
    return { ok: false, mensaje: traducir(error, 'No pudimos consultar las calificaciones.') };
  }
  return { ok: true, calificaciones: data ?? [] };
}
