'use client';

import { AlertCircle, Inbox, LoaderCircle, RefreshCw } from 'lucide-react';
import { useActiveServices } from './use-active-services';
import { ServiceCard } from './service-card';
import { ESTADOS_VIVOS, ETIQUETA_ESTADO } from './types';

export function Dashboard() {
  const { servicios, cargando, error, actualizadoEn, recargar } = useActiveServices();

  // El recuento por estado se deriva del listado en el render. No hay un estado
  // aparte que mantener sincronizado, que es de donde salen las pantallas que
  // dicen "3 en curso" mientras muestran cuatro tarjetas.
  const porEstado = ESTADOS_VIVOS.map((estado) => ({
    estado,
    cuantos: servicios.filter((s) => s.status === estado).length,
  }));

  return (
    <section>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-text-primary">Servicios en curso</h2>
          <p className="mt-0.5 text-sm text-text-secondary">
            {actualizadoEn === null
              ? 'Consultando…'
              : `Actualizado a las ${actualizadoEn.getHours().toString().padStart(2, '0')}:${actualizadoEn.getMinutes().toString().padStart(2, '0')}:${actualizadoEn.getSeconds().toString().padStart(2, '0')}`}
          </p>
        </div>

        <button
          type="button"
          onClick={() => void recargar()}
          className="flex h-10 items-center gap-2 rounded-lg border border-border px-3 text-sm font-medium text-text-primary"
        >
          <RefreshCw size={15} />
          Actualizar
        </button>
      </header>

      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        {porEstado.map(({ estado, cuantos }) => (
          <div key={estado} className="rounded-xl border border-border bg-surface px-4 py-3">
            <p className="text-2xl font-semibold text-text-primary">{cuantos}</p>
            <p className="mt-0.5 text-sm text-text-secondary">{ETIQUETA_ESTADO[estado]}</p>
          </div>
        ))}
      </div>

      {error !== null && (
        <div
          role="alert"
          className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>No pudimos actualizar el tablero. Se muestra la última información conocida.</span>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-3">
        {cargando && servicios.length === 0 && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los servicios en curso…
          </div>
        )}

        {/*
         * Un tablero vacio es la buena noticia de que no hay nada atascado, no
         * un error. Se dice asi, y no con una pantalla de fallo.
         */}
        {!cargando && servicios.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">No hay servicios en curso</p>
            <p className="max-w-sm text-sm text-text-secondary">
              Aquí aparecerán las solicitudes en cuanto un pasajero pida un motorratón.
            </p>
          </div>
        )}

        {servicios.map((servicio) => (
          <ServiceCard key={servicio.request_id} servicio={servicio} />
        ))}
      </div>
    </section>
  );
}
