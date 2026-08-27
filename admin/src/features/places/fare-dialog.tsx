'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import type { Resultado } from './place-actions';
import { formatearDistancia, formatearPesos } from './types';
import type { Place } from './types';

interface Props {
  lugar: Place;
  onCerrar: () => void;
  onGuardar: (monto: number | null) => Promise<Resultado>;
}

/**
 * Poner, cambiar o quitar la tarifa propia de un lugar.
 *
 * **Quitar la tarifa no borra nada**: el precio se conserva apagado por si el
 * destino vuelve a atenderse. Se dice en la pantalla porque desde fuera "quitar"
 * suena a perder el dato.
 */
export function FareDialog({ lugar, onCerrar, onGuardar }: Props) {
  const [monto, setMonto] = useState(lugar.rural_amount?.toString() ?? '');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  const tieneTarifa = lugar.rural_is_active === true;

  async function enviar(nuevo: number | null) {
    setError(null);
    setGuardando(true);
    const r = await onGuardar(nuevo);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos guardar la tarifa.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-tarifa"
    >
      <div className="w-full max-w-[440px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-tarifa" className="font-medium text-text-primary">
          Tarifa de {lugar.name}
        </h3>
        <p className="mt-1 text-sm text-text-secondary">
          A {formatearDistancia(lugar.distance_from_center_m)} del centro.
        </p>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            const n = Number.parseInt(monto, 10);
            if (Number.isNaN(n)) {
              setError('Escribe el valor en pesos, sin puntos.');
              return;
            }
            void enviar(n);
          }}
          className="mt-4 flex flex-col gap-4"
          noValidate
        >
          <div className="flex flex-col gap-1.5">
            <label htmlFor="monto" className="text-sm font-medium text-text-primary">
              Valor del viaje hasta aquí
            </label>
            <input
              id="monto"
              inputMode="numeric"
              value={monto}
              onChange={(e) => setMonto(e.target.value)}
              placeholder="12000"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">
              {/* D221: la tarifa rural es plana, no depende de cuántos van. */}
              Se cobra igual vayan una, dos o tres personas
              {monto.trim() !== '' && !Number.isNaN(Number.parseInt(monto, 10))
                ? `: ${formatearPesos(Number.parseInt(monto, 10))}`
                : '.'}
            </p>
          </div>

          {/* D222: los destinos con tarifa propia cuestan lo mismo a cualquier hora. */}
          <p className="rounded-lg bg-surface-subtle px-3 py-2 text-xs text-text-secondary">
            Los lugares con tarifa propia cuestan lo mismo de día y de noche. El recargo nocturno
            solo se aplica a los viajes urbanos.
          </p>

          {error !== null && (
            <p
              role="alert"
              className="rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {error}
            </p>
          )}

          <div className="flex flex-wrap justify-end gap-2">
            {tieneTarifa && (
              <button
                type="button"
                disabled={guardando}
                onClick={() => void enviar(null)}
                className="btn btn-secundario mr-auto h-10 px-3"
                title="El valor se conserva por si vuelve a atenderse"
              >
                Quitar la tarifa
              </button>
            )}
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
