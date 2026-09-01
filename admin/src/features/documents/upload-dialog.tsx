'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import { subirDocumento } from './document-actions';
import type { DocumentOwner, DocumentType } from './types';

interface Props {
  owner: DocumentOwner;
  ownerId: string;
  ownerNombre: string;
  tipos: DocumentType[];
  onCerrar: () => void;
  onSubido: () => void;
}

/** Los mismos que admite el bucket. Repetirlos aquí solo evita un viaje inútil. */
const TIPOS_ACEPTADOS = 'image/jpeg,image/png,image/webp,application/pdf';
const TAMANO_MAXIMO = 5 * 1024 * 1024;

export function UploadDialog({ owner, ownerId, ownerNombre, tipos, onCerrar, onSubido }: Props) {
  const [tipoId, setTipoId] = useState('');
  const [archivo, setArchivo] = useState<File | null>(null);
  const [expedido, setExpedido] = useState('');
  const [vence, setVence] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [subiendo, setSubiendo] = useState(false);

  const tipoElegido = tipos.find((t) => t.document_type_id === tipoId);
  const exigeVencimiento = tipoElegido?.requires_expiry === true;

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (archivo === null) {
      setError('Elige el archivo del documento.');
      return;
    }

    // Se comprueba aquí para no gastar una subida que el bucket va a rechazar.
    // El límite de verdad lo pone Storage, no esta pantalla.
    if (archivo.size > TAMANO_MAXIMO) {
      setError('El archivo no puede pesar más de 5 MB.');
      return;
    }

    setSubiendo(true);
    const r = await subirDocumento(
      owner,
      ownerId,
      tipoId,
      archivo,
      expedido === '' ? null : expedido,
      vence === '' ? null : vence,
    );
    setSubiendo(false);

    if (r.ok) {
      onSubido();
      return;
    }
    setError(r.mensaje ?? 'No pudimos subir el documento.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-subir"
    >
      <div className="max-h-full w-full max-w-[460px] overflow-y-auto rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-subir" className="font-medium text-text-primary">
          Subir documento
        </h3>
        <p className="mt-1 text-sm text-text-secondary">{ownerNombre}</p>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="tipo-doc" className="text-sm font-medium text-text-primary">
              Tipo de documento
            </label>
            <select
              id="tipo-doc"
              value={tipoId}
              onChange={(e) => setTipoId(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            >
              <option value="">Elige el tipo</option>
              {tipos.map((t) => (
                <option key={t.document_type_id} value={t.document_type_id}>
                  {t.name}
                  {t.requires_expiry ? ' (necesita vencimiento)' : ''}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="archivo-doc" className="text-sm font-medium text-text-primary">
              Archivo
            </label>
            <input
              id="archivo-doc"
              type="file"
              accept={TIPOS_ACEPTADOS}
              onChange={(e) => setArchivo(e.target.files?.[0] ?? null)}
              className="rounded-lg border border-border bg-surface px-3 py-2.5 text-sm text-text-primary file:mr-3 file:rounded-md file:border-0 file:bg-surface-pressed file:px-3 file:py-1.5 file:text-sm file:text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">
              Foto o PDF, hasta 5 MB. Se guarda en privado: solo lo ven la empresa y su dueño.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="expedido-doc" className="text-sm font-medium text-text-primary">
                Expedido el
              </label>
              <input
                id="expedido-doc"
                type="date"
                value={expedido}
                onChange={(e) => setExpedido(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="vence-doc" className="text-sm font-medium text-text-primary">
                Vence el{exigeVencimiento ? '' : ' (opcional)'}
              </label>
              <input
                id="vence-doc"
                type="date"
                value={vence}
                onChange={(e) => setVence(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>
          </div>

          {/*
           * Se avisa en cuanto se elige el tipo, no al fallar el envío: el
           * servidor lo rechaza con EXPIRY_REQUIRED, pero para entonces el
           * archivo ya se subió y hubo que borrarlo.
           */}
          {exigeVencimiento && vence === '' && (
            <p className="rounded-lg bg-warning-subtle px-3 py-2 text-xs text-on-warning">
              Este tipo de documento necesita fecha de vencimiento.
            </p>
          )}

          {error !== null && (
            <p
              role="alert"
              className="rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {error}
            </p>
          )}

          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onCerrar}
              disabled={subiendo}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={subiendo || tipoId === '' || archivo === null}
              className="btn btn-primario h-10 px-4"
            >
              {subiendo && <LoaderCircle size={15} className="animate-spin" />}
              {subiendo ? 'Subiendo…' : 'Subir'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
