'use client';

import { useState } from 'react';
import { LoaderCircle, X } from 'lucide-react';
import { cambiarEstado } from './report-actions';
import { ETIQUETA_ESTADO } from './types';
import type { Report, ReportStatus } from './types';

const ESTADOS: ReportStatus[] = ['open', 'in_review', 'resolved'];

const EXPLICACION: Record<ReportStatus, string> = {
  open: 'Vuelve a la bandeja como pendiente. Se le quita la fecha de cierre.',
  in_review: 'Queda marcado como que alguien lo está atendiendo. No se avisa a nadie todavía.',
  resolved: 'Se cierra y se le avisa a quien lo reportó de que ya lo revisaron.',
};

export function ManageDialog({
  reporte,
  onCerrar,
  onGuardado,
}: {
  reporte: Report;
  onCerrar: () => void;
  onGuardado: () => void;
}) {
  const [estado, setEstado] = useState<ReportStatus>(reporte.status);
  const [notas, setNotas] = useState(reporte.resolution_notes ?? '');
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const cambio = estado !== reporte.status;

  async function guardar() {
    setError(null);
    setGuardando(true);
    const r = await cambiarEstado(reporte.report_id, estado, notas);
    setGuardando(false);
    if (!r.ok) {
      setError(r.mensaje);
      return;
    }
    onGuardado();
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-gestion"
    >
      <div className="my-8 w-full max-w-[560px] rounded-xl border border-border bg-surface">
        <header className="flex items-start justify-between gap-3 border-b border-border p-5">
          <div>
            <h3 id="titulo-gestion" className="font-medium text-text-primary">
              Gestionar el reporte
            </h3>
            <p className="mt-1 text-sm text-text-secondary">
              {reporte.category} · {reporte.reporter_name}
            </p>
          </div>
          <button
            type="button"
            onClick={onCerrar}
            className="btn btn-secundario size-8 shrink-0 p-0"
            aria-label="Cerrar"
          >
            <X size={16} />
          </button>
        </header>

        <div className="p-5">
          {error !== null && (
            <p
              role="alert"
              className="mb-4 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {error}
            </p>
          )}

          <p className="rounded-lg bg-surface-subtle px-3 py-2 text-sm whitespace-pre-line text-text-secondary">
            {reporte.description}
          </p>

          <fieldset className="mt-5">
            <legend className="text-sm text-text-secondary">En qué estado queda</legend>
            <div className="mt-2 flex flex-col gap-2">
              {ESTADOS.map((e) => (
                <label
                  key={e}
                  className={`flex cursor-pointer gap-3 rounded-lg border p-3 transition-colors duration-100 ${
                    estado === e
                      ? 'border-(--color-brand) bg-surface-subtle'
                      : 'border-border hover:border-border-strong hover:bg-surface-pressed'
                  }`}
                >
                  <input
                    type="radio"
                    name="estado"
                    value={e}
                    checked={estado === e}
                    onChange={() => setEstado(e)}
                    className="mt-0.5"
                  />
                  <span>
                    <span className="block text-sm font-medium text-text-primary">
                      {ETIQUETA_ESTADO[e]}
                      {e === reporte.status && (
                        <span className="font-normal text-text-secondary">
                          {' '}
                          · el que tiene ahora
                        </span>
                      )}
                    </span>
                    {/*
                     * Cada opcion dice que pasa al elegirla, y no es relleno:
                     * "resuelto" **le manda un aviso a quien se quejo**, que es
                     * una accion hacia fuera y no puede ser una sorpresa.
                     */}
                    <span className="mt-0.5 block text-xs text-text-secondary">
                      {EXPLICACION[e]}
                    </span>
                  </span>
                </label>
              ))}
            </div>
          </fieldset>

          {/*
           * La nota solo se pide al cerrar, que es cuando el servidor la exige.
           * Ensenarla siempre haria pensar que hace falta para todo.
           */}
          {estado === 'resolved' && (
            <label className="mt-5 block">
              <span className="text-sm text-text-secondary">
                Qué se hizo (hace falta para poder cerrarlo)
              </span>
              <textarea
                value={notas}
                onChange={(ev) => setNotas(ev.target.value)}
                rows={3}
                maxLength={1000}
                placeholder="Se habló con el conductor y se le devolvió la diferencia al pasajero"
                className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-(--color-brand)"
              />
            </label>
          )}
        </div>

        <footer className="flex justify-end gap-2 border-t border-border p-5">
          <button type="button" onClick={onCerrar} className="btn btn-secundario px-4 py-2">
            Cancelar
          </button>
          <button
            type="button"
            disabled={!cambio || guardando}
            onClick={() => void guardar()}
            className="btn btn-primario px-4 py-2"
          >
            {guardando && <LoaderCircle size={16} className="animate-spin" />}
            Guardar
          </button>
        </footer>
      </div>
    </div>
  );
}
