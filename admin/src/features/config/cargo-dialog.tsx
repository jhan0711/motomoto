'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import type { Resultado } from './config-actions';
import type { CargoType } from './types';

interface Props {
  /** Nulo al crear uno nuevo. */
  tipo: CargoType | null;
  onCerrar: () => void;
  onGuardar: (nombre: string, monto: number, activo: boolean, orden: number) => Promise<Resultado>;
}

export function CargoDialog({ tipo, onCerrar, onGuardar }: Props) {
  const editando = tipo !== null;

  const [nombre, setNombre] = useState(tipo?.name ?? '');
  const [monto, setMonto] = useState(tipo?.amount?.toString() ?? '');
  const [activo, setActivo] = useState(tipo?.is_active ?? true);
  const [orden, setOrden] = useState(tipo?.sort_order?.toString() ?? '0');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const nMonto = Number.parseInt(monto, 10);
    if (Number.isNaN(nMonto)) {
      setError('El precio tiene que ser un número en pesos, sin puntos.');
      return;
    }

    setGuardando(true);
    const r = await onGuardar(nombre, nMonto, activo, Number.parseInt(orden, 10) || 0);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos guardar los cambios.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-carga"
    >
      <div className="w-full max-w-[420px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-carga" className="font-medium text-text-primary">
          {editando ? `Editar ${tipo.name}` : 'Nuevo tipo de carga'}
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="nombre-carga" className="text-sm font-medium text-text-primary">
              Nombre
            </label>
            <input
              id="nombre-carga"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              placeholder="Bulto de café"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Como lo verá el pasajero al elegir carga.</p>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="monto-carga" className="text-sm font-medium text-text-primary">
                Precio
              </label>
              <input
                id="monto-carga"
                inputMode="numeric"
                value={monto}
                onChange={(e) => setMonto(e.target.value)}
                placeholder="4900"
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="orden-carga" className="text-sm font-medium text-text-primary">
                Orden
              </label>
              <input
                id="orden-carga"
                inputMode="numeric"
                value={orden}
                onChange={(e) => setOrden(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>
          </div>

          {editando && (
            <label className="flex cursor-pointer items-center gap-2 text-sm text-text-primary">
              <input
                type="checkbox"
                checked={activo}
                onChange={(e) => setActivo(e.target.checked)}
                className="size-4 accent-(--color-brand)"
              />
              Disponible para los pasajeros
            </label>
          )}

          {editando && tipo.usage_count > 0 && (
            /*
             * D225: el precio se congela en cada servicio, asi que subirlo no
             * reescribe lo que costo un viaje de la semana pasada. Se dice
             * porque desde fuera es exactamente lo que uno teme al tocarlo.
             */
            <p className="rounded-lg bg-surface-subtle px-3 py-2 text-xs text-text-secondary">
              Se ha usado en {tipo.usage_count} servicios. Cambiar el precio no altera lo que
              costaron: cada servicio guarda el suyo.
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
              disabled={guardando}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button type="submit" disabled={guardando} className="btn btn-primario h-10 px-4">
              {guardando && <LoaderCircle size={15} className="animate-spin" />}
              {editando ? 'Guardar' : 'Crear'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
