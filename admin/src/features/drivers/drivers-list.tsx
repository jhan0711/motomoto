'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, Inbox, LoaderCircle } from 'lucide-react';
import { listarConductores } from './driver-actions';
import { DriverRow } from './driver-row';
import type { Driver } from './types';

export function DriversList() {
  const [conductores, setConductores] = useState<Driver[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const consultar = useCallback(async () => {
    const r = await listarConductores();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setConductores(r.conductores);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    // La primera consulta se programa en vez de llamarse en el cuerpo del
    // efecto, por lo mismo que en `useActiveServices`: el compilador de React
    // prohibe poner estado durante el efecto y la regla no se silencia.
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  // Aqui NO hay temporizador, al reves que en el tablero. La lista de
  // conductores no cambia sola: cambia cuando alguien de la empresa la cambia,
  // y quien la cambia es quien esta mirando esta pantalla. Refrescarla cada diez
  // segundos solo serviria para mover el listado bajo el raton de quien esta a
  // punto de pulsar un boton.
  const pendientes = conductores.filter((c) => c.approval_status === 'pending').length;

  return (
    <section>
      <header>
        <h2 className="text-lg font-semibold text-text-primary">Conductores</h2>
        <p className="mt-0.5 text-sm text-text-secondary">
          {cargando
            ? 'Consultando…'
            : pendientes === 0
              ? `${conductores.length} en total`
              : `${conductores.length} en total · ${pendientes} ${pendientes === 1 ? 'espera' : 'esperan'} aprobación`}
        </p>
      </header>

      {error !== null && (
        <div
          role="alert"
          className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-3">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los conductores…
          </div>
        )}

        {!cargando && conductores.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">Todavía no hay conductores</p>
            <p className="max-w-sm text-sm text-text-secondary">
              Las altas de conductores se construyen en el paso siguiente del panel.
            </p>
          </div>
        )}

        {conductores.map((conductor) => (
          <DriverRow
            key={conductor.driver_id}
            conductor={conductor}
            onCambio={() => void consultar()}
          />
        ))}
      </div>
    </section>
  );
}
