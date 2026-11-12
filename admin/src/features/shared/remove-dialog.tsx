'use client';

import { useState } from 'react';
import { LoaderCircle, TriangleAlert } from 'lucide-react';

/**
 * El resultado de la accion. Se declara aqui y no se importa de un modulo
 * concreto, por lo mismo que en `block-dialog.tsx`: este dialogo lo usan
 * conductores y motocarros.
 */
export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

interface Props {
  titulo: string;
  descripcion: string;
  /** Una linea aparte, en ambar, para lo que conviene saber antes de confirmar. */
  aviso?: string;
  /**
   * Si se pasa, el boton solo se activa cuando quien confirma escribe EXACTAMENTE
   * esto (sin importar mayusculas ni espacios de los extremos). Es lo que separa
   * "eliminar" de un clic distraido: no se escribe un nombre sin mirarlo.
   */
  escribirParaConfirmar?: string;
  /** Lo que se le pide escribir, tal como se le dice: "el nombre", "el número". */
  queEscribir?: string;
  etiquetaConfirmar: string;
  /** Rojo y definitivo (eliminar) frente a normal y reversible (archivar). */
  peligroso: boolean;
  /**
   * Una casilla opcional (empieza sin marcar). Su valor llega a `onConfirmar`.
   * D307: "liberar el correo" al archivar a un conductor.
   */
  opcion?: { etiqueta: string; ayuda?: string };
  onCerrar: () => void;
  onConfirmar: (opcion: boolean) => Promise<Resultado>;
}

export function RemoveDialog({
  titulo,
  descripcion,
  aviso,
  escribirParaConfirmar,
  queEscribir,
  etiquetaConfirmar,
  peligroso,
  opcion,
  onCerrar,
  onConfirmar,
}: Props) {
  const [escrito, setEscrito] = useState('');
  const [opcionMarcada, setOpcionMarcada] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [trabajando, setTrabajando] = useState(false);

  const coincide =
    escribirParaConfirmar === undefined ||
    escrito.trim().toLowerCase() === escribirParaConfirmar.trim().toLowerCase();

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!coincide) return;
    setError(null);
    setTrabajando(true);
    const r = await onConfirmar(opcionMarcada);
    setTrabajando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos completar la operación.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-quitar"
    >
      <div className="w-full max-w-[460px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-quitar" className="font-medium text-text-primary">
          {titulo}
        </h3>
        <p className="mt-2 text-sm text-text-secondary">{descripcion}</p>

        {aviso !== undefined && (
          <div className="mt-3 flex items-start gap-2 rounded-lg bg-warning-subtle px-3 py-2.5 text-sm text-on-warning">
            <TriangleAlert size={18} className="mt-px shrink-0" />
            <span>{aviso}</span>
          </div>
        )}

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          {escribirParaConfirmar !== undefined && (
            <div className="flex flex-col gap-1.5">
              <label htmlFor="confirmar-quitar" className="text-sm font-medium text-text-primary">
                Para confirmar, escribe {queEscribir ?? 'el nombre'}:{' '}
                <span className="font-semibold">{escribirParaConfirmar}</span>
              </label>
              <input
                id="confirmar-quitar"
                type="text"
                autoComplete="off"
                value={escrito}
                onChange={(e) => setEscrito(e.target.value)}
                className="h-10 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>
          )}

          {opcion !== undefined && (
            <label className="flex cursor-pointer items-start gap-2.5 rounded-lg border border-border px-3 py-2.5">
              <input
                type="checkbox"
                checked={opcionMarcada}
                onChange={(e) => setOpcionMarcada(e.target.checked)}
                className="mt-0.5 h-4 w-4 shrink-0 accent-[var(--color-brand)]"
              />
              <span className="text-sm">
                <span className="font-medium text-text-primary">{opcion.etiqueta}</span>
                {opcion.ayuda !== undefined && (
                  <span className="mt-0.5 block text-text-secondary">{opcion.ayuda}</span>
                )}
              </span>
            </label>
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
              disabled={trabajando}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={trabajando || !coincide}
              className={`btn h-10 px-4 ${peligroso ? 'btn-peligro' : 'btn-primario'}`}
            >
              {trabajando && <LoaderCircle size={15} className="animate-spin" />}
              {etiquetaConfirmar}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
