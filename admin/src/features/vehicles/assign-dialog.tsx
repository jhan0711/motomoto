'use client';

import { useCallback, useEffect, useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import { listarConductores } from '@/features/drivers/driver-actions';
import type { Driver } from '@/features/drivers/types';
import type { Resultado } from './vehicle-actions';
import type { Vehicle } from './types';

interface Props {
  vehiculo: Vehicle;
  onCerrar: () => void;
  onAsignar: (driverId: string) => Promise<Resultado>;
}

/**
 * Elegir a quien se le entrega una unidad.
 *
 * **Solo salen los conductores aprobados**: entregarle un motocarro a alguien
 * que la empresa todavia no ha aprobado seria dejar salir a trabajar a quien no
 * puede. El servidor no lo comprueba -asignar a un pendiente es legitimo si la
 * empresa quiere prepararlo antes de aprobarlo-, pero el camino normal de la
 * pantalla no deberia invitarlo.
 */
export function AssignDialog({ vehiculo, onCerrar, onAsignar }: Props) {
  const [conductores, setConductores] = useState<Driver[]>([]);
  const [cargando, setCargando] = useState(true);
  const [elegido, setElegido] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  const consultar = useCallback(async () => {
    const r = await listarConductores();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setConductores(r.conductores.filter((c) => c.approval_status === 'approved'));
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (elegido === '') return;

    setError(null);
    setGuardando(true);
    const r = await onAsignar(elegido);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos asignar el motocarro.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-asignar"
    >
      <div className="w-full max-w-[460px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-asignar" className="font-medium text-text-primary">
          Asignar el motocarro {vehiculo.unit_number}
        </h3>

        {cargando ? (
          <div className="mt-6 flex items-center justify-center gap-2 py-6 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los conductores…
          </div>
        ) : (
          <form onSubmit={enviar} className="mt-4 flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="conductor" className="text-sm font-medium text-text-primary">
                Conductor
              </label>
              <select
                id="conductor"
                value={elegido}
                onChange={(e) => setElegido(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              >
                <option value="">Elige un conductor</option>
                {conductores.map((c) => (
                  <option key={c.driver_id} value={c.driver_id}>
                    {c.full_name}
                    {c.unit_number === null ? '' : ` (lleva la ${c.unit_number})`}
                  </option>
                ))}
              </select>
              {/*
               * Se avisa antes de pulsar, no despues de fallar: si el elegido ya
               * lleva otra unidad, la anterior se cierra sola en la misma
               * transaccion, y eso conviene que se sepa de antemano.
               */}
              <p className="text-xs text-text-secondary">
                Si el conductor ya lleva otro motocarro, esa asignación se cierra automáticamente.
              </p>
            </div>

            {conductores.length === 0 && (
              <p className="rounded-lg bg-warning-subtle px-3 py-2 text-sm text-on-warning">
                No hay conductores aprobados. Apruébalos primero en la pestaña Conductores.
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
              <button
                type="submit"
                disabled={guardando || elegido === ''}
                className="btn btn-primario h-10 px-4"
              >
                {guardando && <LoaderCircle size={15} className="animate-spin" />}
                Asignar
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
