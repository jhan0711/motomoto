'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, ExternalLink, FileText, LoaderCircle, Trash2, Upload } from 'lucide-react';
import { abrirDocumento, borrarDocumento, listarDocumentos, listarTipos } from './document-actions';
import { ESTILO_ESTADO, ETIQUETA_ESTADO, estadoDe, formatearFecha } from './types';
import type { DocumentOwner, DocumentRow, DocumentType } from './types';
import { UploadDialog } from './upload-dialog';

interface Props {
  owner: DocumentOwner;
  ownerId: string;
  /** Para el texto del dialogo: "los papeles de Ana" o "del motorratón 99". */
  ownerNombre: string;
}

export function DocumentsPanel({ owner, ownerId, ownerNombre }: Props) {
  const [documentos, setDocumentos] = useState<DocumentRow[]>([]);
  const [tipos, setTipos] = useState<DocumentType[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [subiendo, setSubiendo] = useState(false);
  const [trabajando, setTrabajando] = useState(false);

  const consultar = useCallback(async () => {
    const [docs, tps] = await Promise.all([listarDocumentos(owner, ownerId), listarTipos()]);

    if (!docs.ok) {
      setError(docs.mensaje);
      setCargando(false);
      return;
    }
    setDocumentos(docs.documentos);
    // Solo los tipos activos y del dueño correcto: un tipo de vehículo no se le
    // ofrece a un conductor, y el servidor lo rechazaría de todos modos.
    if (tps.ok) setTipos(tps.tipos.filter((t) => t.is_active && t.owner === owner));
    setError(null);
    setCargando(false);
  }, [owner, ownerId]);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  const vencidos = documentos.filter((d) => d.is_expired).length;
  const proximos = documentos.filter((d) => d.expires_soon).length;

  return (
    <section className="rounded-xl border border-border bg-surface p-4">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="flex items-center gap-2 font-medium text-text-primary">
            <FileText size={16} className="text-text-tertiary" />
            Documentos
          </h3>
          {!cargando && (
            <p className="mt-0.5 text-xs text-text-secondary">
              {documentos.length === 0
                ? 'Ninguno todavía'
                : `${documentos.length} ${documentos.length === 1 ? 'documento' : 'documentos'}`}
            </p>
          )}
        </div>

        <button
          type="button"
          disabled={tipos.length === 0}
          title={tipos.length === 0 ? 'No hay tipos de documento activos' : undefined}
          onClick={() => setSubiendo(true)}
          className="btn btn-secundario h-9 gap-1.5 px-3"
        >
          <Upload size={15} />
          Subir documento
        </button>
      </header>

      {/*
       * El aviso de vencidos va arriba y solo cuando hay algo. Es el motivo de
       * que esta pantalla exista: un papel vencido es lo que la empresa
       * necesita ver antes de que se lo diga un policía en la calle.
       */}
      {vencidos > 0 && (
        <div className="mt-3 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle">
          <AlertCircle size={16} className="mt-px shrink-0" />
          <span>
            {vencidos === 1 ? 'Hay un documento vencido.' : `Hay ${vencidos} documentos vencidos.`}
          </span>
        </div>
      )}

      {vencidos === 0 && proximos > 0 && (
        <div className="mt-3 flex items-start gap-2 rounded-lg bg-warning-subtle px-3 py-2 text-sm text-on-warning">
          <AlertCircle size={16} className="mt-px shrink-0" />
          <span>
            {proximos === 1
              ? 'Hay un documento que vence en menos de un mes.'
              : `Hay ${proximos} documentos que vencen en menos de un mes.`}
          </span>
        </div>
      )}

      {error !== null && (
        <p
          role="alert"
          className="mt-3 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
        >
          {error}
        </p>
      )}

      <div className="mt-3 flex flex-col gap-2">
        {cargando && (
          <div className="flex items-center gap-2 py-4 text-sm text-text-secondary">
            <LoaderCircle size={16} className="animate-spin" />
            Consultando los documentos…
          </div>
        )}

        {!cargando && documentos.length === 0 && (
          <p className="py-3 text-sm text-text-secondary">Todavía no hay documentos cargados.</p>
        )}

        {documentos.map((doc) => {
          const estado = estadoDe(doc);
          return (
            <article
              key={doc.document_id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border px-3 py-2.5"
            >
              <div className="min-w-0">
                <p className="flex flex-wrap items-center gap-2 text-sm text-text-primary">
                  {doc.type_name}
                  <span className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[estado]}`}>
                    {ETIQUETA_ESTADO[estado]}
                  </span>
                </p>
                <p className="mt-0.5 text-xs text-text-secondary">
                  {doc.expires_at === null
                    ? 'Sin fecha de vencimiento'
                    : `Vence el ${formatearFecha(doc.expires_at)}`}
                  {doc.uploaded_by_name !== null ? ` · Subido por ${doc.uploaded_by_name}` : ''}
                </p>
              </div>

              <div className="flex shrink-0 gap-2">
                <button
                  type="button"
                  disabled={trabajando}
                  onClick={async () => {
                    setTrabajando(true);
                    const r = await abrirDocumento(doc.file_path);
                    setTrabajando(false);
                    if (!r.ok) setError(r.mensaje ?? 'No pudimos abrir el documento.');
                  }}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  <ExternalLink size={15} />
                  Ver
                </button>

                <button
                  type="button"
                  disabled={trabajando}
                  onClick={async () => {
                    setTrabajando(true);
                    const r = await borrarDocumento(doc.document_id);
                    setTrabajando(false);
                    if (r.ok) void consultar();
                    else setError(r.mensaje ?? 'No pudimos borrar el documento.');
                  }}
                  aria-label={`Borrar ${doc.type_name}`}
                  className="btn btn-secundario size-9 p-0"
                >
                  <Trash2 size={15} />
                </button>
              </div>
            </article>
          );
        })}
      </div>

      {subiendo && (
        <UploadDialog
          owner={owner}
          ownerId={ownerId}
          ownerNombre={ownerNombre}
          tipos={tipos}
          onCerrar={() => setSubiendo(false)}
          onSubido={() => {
            setSubiendo(false);
            void consultar();
          }}
        />
      )}
    </section>
  );
}
