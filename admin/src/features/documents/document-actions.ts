'use client';

import { createClient } from '@/lib/supabase/client';
import { BUCKET } from './types';
import type { DocumentOwner, DocumentRow, DocumentType } from './types';

const MENSAJES: Record<string, string> = {
  NOT_AN_ADMIN: 'Tu cuenta ya no tiene permiso para hacer esto. Vuelve a entrar.',
  DOCUMENT_TYPE_NOT_FOUND: 'No encontramos ese tipo de documento.',
  DOCUMENT_TYPE_INACTIVE: 'Ese tipo de documento está desactivado.',
  DOCUMENT_TYPE_IN_USE: 'Ese tipo ya tiene documentos: no se puede cambiar de dueño.',
  DOCUMENT_CODE_TAKEN: 'Ya existe un tipo de documento con ese código.',
  DOCUMENT_NOT_FOUND: 'No encontramos ese documento.',
  INVALID_DOCUMENT_CODE:
    'El código solo admite minúsculas, números y guion bajo, de 2 a 40 caracteres.',
  INVALID_DOCUMENT_NAME: 'El nombre debe tener al menos 2 caracteres.',
  MISSING_FILE_PATH: 'Falta el archivo.',
  EXPIRY_REQUIRED: 'Ese tipo de documento necesita fecha de vencimiento.',
  INVALID_EXPIRY_DATES: 'El vencimiento tiene que ser posterior a la fecha de expedición.',
  DRIVER_NOT_FOUND: 'No encontramos a ese conductor.',
  VEHICLE_NOT_FOUND: 'No encontramos ese motorratón.',
};

function traducir(error: { hint?: string | null; message: string }): string {
  return MENSAJES[error.hint?.trim() ?? ''] ?? 'No pudimos completar la operación.';
}

export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

export async function listarTipos(): Promise<
  { ok: true; tipos: DocumentType[] } | { ok: false; mensaje: string }
> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_document_types');
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, tipos: data ?? [] };
}

export async function listarDocumentos(
  owner: DocumentOwner,
  ownerId: string,
): Promise<{ ok: true; documentos: DocumentRow[] } | { ok: false; mensaje: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_list_documents', {
    p_owner: owner,
    p_owner_id: ownerId,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true, documentos: data ?? [] };
}

/**
 * Sube el archivo y despues registra la fila.
 *
 * **EL ORDEN IMPORTA Y ESTA ELEGIDO** (ver la migracion del paso 4c): un archivo
 * sin fila es basura recuperable; una fila sin archivo es un documento que la
 * empresa cree tener y no tiene. Por eso se sube primero, y **si el registro
 * falla se borra el archivo recien subido**, para no dejar el bucket lleno de
 * huerfanos.
 */
export async function subirDocumento(
  owner: DocumentOwner,
  ownerId: string,
  documentTypeId: string,
  archivo: File,
  expedidoEl: string | null,
  venceEl: string | null,
): Promise<Resultado> {
  const supabase = createClient();

  const extension = archivo.name.split('.').pop()?.toLowerCase() ?? 'bin';
  // La ruta lleva el dueno en las dos primeras carpetas: es lo que usan las
  // politicas del bucket para decidir de quien es cada archivo.
  const ruta = `${owner}/${ownerId}/${crypto.randomUUID()}.${extension}`;

  const subida = await supabase.storage.from(BUCKET).upload(ruta, archivo, {
    contentType: archivo.type,
    upsert: false,
  });

  if (subida.error) {
    return { ok: false, mensaje: 'No pudimos subir el archivo. Inténtalo de nuevo.' };
  }

  const { error } = await supabase.rpc('admin_register_document', {
    p_document_type_id: documentTypeId,
    p_owner_id: ownerId,
    p_file_path: ruta,
    p_issued_at: expedidoEl ?? undefined,
    p_expires_at: venceEl ?? undefined,
  });

  if (error) {
    // Limpieza. Si tambien falla no se avisa aparte: el usuario ya tiene un
    // error que resolver, y el huerfano no le afecta.
    await supabase.storage.from(BUCKET).remove([ruta]);
    return { ok: false, mensaje: traducir(error) };
  }

  return { ok: true };
}

/**
 * Borra el documento y su archivo.
 *
 * La funcion devuelve la ruta justamente para esto: si solo se borrara la fila,
 * el bucket acumularia cedulas de gente que ya no trabaja en la empresa.
 */
export async function borrarDocumento(documentId: string): Promise<Resultado> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc('admin_delete_document', {
    p_document_id: documentId,
  });

  if (error) return { ok: false, mensaje: traducir(error) };

  if (typeof data === 'string' && data !== '') {
    await supabase.storage.from(BUCKET).remove([data]);
  }
  return { ok: true };
}

/**
 * Abre el documento en una pestana nueva.
 *
 * El bucket es privado, asi que la direccion **se firma y caduca**. Por eso no
 * se puede guardar en la base de datos ni poner en un enlace fijo: se pide una
 * cada vez que alguien quiere mirar el papel.
 */
export async function abrirDocumento(rutaArchivo: string): Promise<Resultado> {
  const supabase = createClient();
  // Un minuto basta para abrirlo; pasado ese rato, el enlace ya no sirve.
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(rutaArchivo, 60);

  if (error || data === null) {
    return { ok: false, mensaje: 'No pudimos abrir el documento.' };
  }

  window.open(data.signedUrl, '_blank', 'noopener,noreferrer');
  return { ok: true };
}

export async function guardarTipoDocumento(
  id: string | null,
  codigo: string,
  nombre: string,
  owner: DocumentOwner,
  exigeVencimiento: boolean,
  activo: boolean,
  orden: number,
): Promise<Resultado> {
  const supabase = createClient();
  const { error } = await supabase.rpc('admin_upsert_document_type', {
    p_document_type_id: id as string,
    p_code: codigo,
    p_name: nombre,
    p_owner: owner,
    p_requires_expiry: exigeVencimiento,
    p_is_active: activo,
    p_sort_order: orden,
  });
  if (error) return { ok: false, mensaje: traducir(error) };
  return { ok: true };
}
