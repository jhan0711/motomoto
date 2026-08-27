'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import type { Resultado } from './driver-actions';

interface Props {
  nombreActual: string;
  telefonoActual: string;
  onCerrar: () => void;
  onGuardar: (nombre: string, telefono: string) => Promise<Resultado>;
}

/**
 * Dialogo para corregir el contacto de un conductor.
 *
 * **El telefono que se edita aqui es el que la aplicacion le ensena al pasajero
 * para llamar a su conductor.** Por eso el cambio pasa por una funcion que deja
 * registro (D240) y no por un UPDATE directo.
 */
export function EditContactDialog({ nombreActual, telefonoActual, onCerrar, onGuardar }: Props) {
  const [nombre, setNombre] = useState(nombreActual);
  const [telefono, setTelefono] = useState(telefonoActual);
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setGuardando(true);
    const r = await onGuardar(nombre, telefono);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos guardar los cambios.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-editar-contacto"
    >
      <div className="w-full max-w-[420px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-editar-contacto" className="font-medium text-text-primary">
          Editar contacto del conductor
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="nombre" className="text-sm font-medium text-text-primary">
              Nombre completo
            </label>
            <input
              id="nombre"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="telefono" className="text-sm font-medium text-text-primary">
              Teléfono
            </label>
            <input
              id="telefono"
              inputMode="numeric"
              value={telefono}
              onChange={(e) => setTelefono(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">
              Es el número que la aplicación le muestra al pasajero.
            </p>
          </div>

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
              disabled={guardando}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button type="submit" disabled={guardando} className="btn btn-primario h-10 px-4">
              {guardando && <LoaderCircle size={15} className="animate-spin" />}
              Guardar
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
