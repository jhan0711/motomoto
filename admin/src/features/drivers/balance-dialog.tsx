'use client';

import { useEffect, useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import { formatearPesos } from '@/features/config/types';
import { ajustarSaldo, obtenerMovimientos, type Movimiento } from './driver-actions';

interface Props {
  nombre: string;
  driverId: string;
  saldoActual: number;
  onCerrar: () => void;
  /** Se llama tras un ajuste guardado, para que la lista recargue los saldos. */
  onAjustado: () => void;
}

const ETIQUETA: Record<Movimiento['kind'], string> = {
  topup: 'Recarga',
  commission: 'Comisión',
  adjustment: 'Ajuste',
};

function conSigno(valor: number): string {
  return `${valor < 0 ? '-' : '+'}${formatearPesos(Math.abs(valor))}`;
}

/**
 * El saldo de un conductor, sus movimientos y el formulario de ajuste.
 *
 * **Aqui se toca dinero.** Un ajuste no edita ni borra nada -el libro solo se
 * anade-: si algo se cobro de mas, se corrige con un ajuste a favor y su motivo,
 * y las dos filas quedan a la vista. Por eso el motivo es obligatorio y por eso
 * el signo se elige con dos opciones explicitas y no con un "menos" escrito a
 * mano, que se olvida.
 */
export function BalanceDialog({ nombre, driverId, saldoActual, onCerrar, onAjustado }: Props) {
  const [movimientos, setMovimientos] = useState<Movimiento[] | null>(null);
  const [saldo, setSaldo] = useState(saldoActual);
  const [sentido, setSentido] = useState<'favor' | 'contra'>('favor');
  const [monto, setMonto] = useState('');
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto, como en el resto del panel.
    const id = setTimeout(() => {
      void obtenerMovimientos(driverId).then((r) => {
        if (r.ok) setMovimientos(r.movimientos);
        else setError(r.mensaje);
      });
    }, 0);
    return () => clearTimeout(id);
  }, [driverId]);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const valor = Number(monto.replace(/\D/g, ''));
    if (!Number.isInteger(valor) || valor <= 0) {
      setError('Escribe el valor del ajuste en pesos.');
      return;
    }

    setGuardando(true);
    const r = await ajustarSaldo(driverId, sentido === 'favor' ? valor : -valor, motivo);
    if (!r.ok) {
      setGuardando(false);
      setError(r.mensaje);
      return;
    }

    setSaldo(r.saldo);
    setMonto('');
    setMotivo('');
    const m = await obtenerMovimientos(driverId);
    if (m.ok) setMovimientos(m.movimientos);
    setGuardando(false);
    onAjustado();
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-saldo"
    >
      <div className="my-8 w-full max-w-[560px] rounded-xl border border-border bg-surface p-5">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h3 id="titulo-saldo" className="font-medium text-text-primary">
              Saldo de {nombre}
            </h3>
            <p className="mt-1 text-2xl font-semibold text-text-primary">
              {saldo < 0 ? `-${formatearPesos(-saldo)}` : formatearPesos(saldo)}
            </p>
          </div>
          <button type="button" onClick={onCerrar} className="btn btn-secundario h-9 px-3">
            Cerrar
          </button>
        </div>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-3" noValidate>
          <fieldset className="flex gap-4 text-sm text-text-primary">
            <legend className="sr-only">Sentido del ajuste</legend>
            <label className="flex items-center gap-1.5">
              <input
                type="radio"
                name="sentido"
                checked={sentido === 'favor'}
                onChange={() => setSentido('favor')}
              />
              A favor del conductor (suma)
            </label>
            <label className="flex items-center gap-1.5">
              <input
                type="radio"
                name="sentido"
                checked={sentido === 'contra'}
                onChange={() => setSentido('contra')}
              />
              En contra (resta)
            </label>
          </fieldset>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="monto" className="text-sm font-medium text-text-primary">
              Valor en pesos
            </label>
            <input
              id="monto"
              inputMode="numeric"
              value={monto}
              onChange={(e) => setMonto(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="motivo" className="text-sm font-medium text-text-primary">
              Motivo
            </label>
            <input
              id="motivo"
              value={motivo}
              maxLength={300}
              onChange={(e) => setMotivo(e.target.value)}
              placeholder="Ej. Recarga en efectivo, o Reverso del servicio del 24/09"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">
              Queda en el libro del conductor y en el registro de auditoría. No se puede borrar.
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

          <button type="submit" disabled={guardando} className="btn btn-primario h-10 px-3">
            {guardando && <LoaderCircle size={16} className="animate-spin" />}
            Guardar ajuste
          </button>
        </form>

        <h4 className="mt-6 text-sm font-medium text-text-primary">Movimientos</h4>
        {movimientos === null ? (
          <p className="mt-2 text-sm text-text-secondary">Consultando…</p>
        ) : movimientos.length === 0 ? (
          <p className="mt-2 text-sm text-text-secondary">Todavía no hay movimientos.</p>
        ) : (
          <ul className="mt-2 flex flex-col divide-y divide-border">
            {movimientos.map((m) => (
              <li key={m.id} className="flex items-start justify-between gap-3 py-2 text-sm">
                <div>
                  <p className="text-text-primary">
                    {ETIQUETA[m.kind]}
                    {m.created_by_name !== null ? ` · ${m.created_by_name}` : ''}
                  </p>
                  <p className="text-xs text-text-secondary">
                    {new Date(m.created_at).toLocaleString('es-CO')}
                    {m.reason !== null ? ` · ${m.reason}` : ''}
                  </p>
                </div>
                <span className={m.amount < 0 ? 'text-text-secondary' : 'font-medium text-success'}>
                  {conSigno(m.amount)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
