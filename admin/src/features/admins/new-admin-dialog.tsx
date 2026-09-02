'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';

interface Props {
  onCerrar: () => void;
  onCrear: (
    correo: string,
    nombre: string,
    telefono: string,
  ) => Promise<{ ok: boolean; mensaje?: string }>;
}

/**
 * Alta de un administrador.
 *
 * **No hay campo de contraseña**: la genera el sistema (D251) y se muestra
 * después, una sola vez. El administrador nace activo: a diferencia del
 * conductor, no hay nada que aprobarle.
 */
export function NewAdminDialog({ onCerrar, onCrear }: Props) {
  const [correo, setCorreo] = useState('');
  const [nombre, setNombre] = useState('');
  const [telefono, setTelefono] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setGuardando(true);
    const r = await onCrear(correo.trim(), nombre.trim(), telefono.trim());
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos crear la cuenta.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-nuevo-admin"
    >
      <div className="max-h-full w-full max-w-[460px] overflow-y-auto rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-nuevo-admin" className="font-medium text-text-primary">
          Nuevo administrador
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="nombre-admin" className="text-sm font-medium text-text-primary">
              Nombre completo
            </label>
            <input
              id="nombre-admin"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="correo-admin" className="text-sm font-medium text-text-primary">
              Correo electrónico
            </label>
            <input
              id="correo-admin"
              type="email"
              autoComplete="off"
              value={correo}
              onChange={(e) => setCorreo(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Con este correo entrará en el panel.</p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="telefono-admin" className="text-sm font-medium text-text-primary">
              Teléfono
            </label>
            <input
              id="telefono-admin"
              inputMode="numeric"
              value={telefono}
              onChange={(e) => setTelefono(e.target.value)}
              placeholder="3001234567"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          <div className="rounded-lg bg-surface-subtle px-3 py-2.5 text-xs text-text-secondary">
            La contraseña la genera el sistema y{' '}
            <span className="font-medium">solo se muestra una vez</span>. Podrá cambiarla desde el
            panel cuando entre.
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
              Crear administrador
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
