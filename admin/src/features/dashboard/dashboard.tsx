'use client';

import { useState } from 'react';
import { AlertCircle, Inbox, LoaderCircle, RefreshCw, SignalZero, Users } from 'lucide-react';
import { useActiveServices } from './use-active-services';
import { useAvailableDrivers } from './use-available-drivers';
import { useDriverLocations } from './use-driver-locations';
import { ServiceCard } from './service-card';
import { AssignDialog } from './assign-dialog';
import { FleetMap } from './fleet-map';
import { ESTADOS_VIVOS, ETIQUETA_ESTADO } from './types';
import type { ActiveService } from './types';

export function Dashboard() {
  const { servicios, cargando, error, actualizadoEn, recargar } = useActiveServices();
  const disponibles = useAvailableDrivers();
  const { ubicaciones } = useDriverLocations();

  /*
   * Se guarda el servicio entero y no solo su identificador. El tablero se
   * refresca sola cada diez segundos, y el servicio asignado **desaparece de la
   * lista de los que buscan en cuanto se asigna**: con solo el identificador, el
   * dialogo se quedaria sin datos que ensenar justo mientras esta abierto.
   */
  const [asignando, setAsignando] = useState<ActiveService | null>(null);

  // El recuento por estado se deriva del listado en el render. No hay un estado
  // aparte que mantener sincronizado, que es de donde salen las pantallas que
  // dicen "3 en curso" mientras muestran cuatro tarjetas.
  const porEstado = ESTADOS_VIVOS.map((estado) => ({
    estado,
    cuantos: servicios.filter((s) => s.status === estado).length,
  }));

  // R10: cuantos servicios en curso llevan sin dar senal. Lo decide el servidor
  // con el umbral de los parametros; aqui solo se cuentan.
  const sinSenal = servicios.filter((s) => s.signal_lost === true).length;

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
          className="btn btn-secundario h-10 px-3"
        >
          <RefreshCw size={15} />
          Actualizar
        </button>
      </header>

      <div className="mt-4 grid gap-3 sm:grid-cols-4">
        {porEstado.map(({ estado, cuantos }) => (
          <div key={estado} className="rounded-xl border border-border bg-surface px-4 py-3">
            <p className="text-2xl font-semibold text-text-primary">{cuantos}</p>
            <p className="mt-0.5 text-sm text-text-secondary">{ETIQUETA_ESTADO[estado]}</p>
          </div>
        ))}

        {/*
         * Aparte de los estados de un servicio: esto cuenta conductores, no
         * servicios, y mezclarlo en `porEstado` habria hecho pasar por lo
         * mismo dos cosas que no lo son -un conductor disponible puede no
         * tener ningun servicio esperandolo-.
         */}
        <div className="rounded-xl border border-border bg-surface px-4 py-3">
          <p className="flex items-center gap-1.5 text-2xl font-semibold text-text-primary">
            <Users size={18} className="text-text-tertiary" />
            {disponibles.cargando ? '…' : disponibles.cuantos}
          </p>
          <p className="mt-0.5 text-sm text-text-secondary">Conductores disponibles</p>
        </div>
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

      {/*
       * R10 ARRIBA DEL TODO, y separado de los recuentos por estado. Un servicio
       * cuyo conductor lleva minutos sin dar senal **no se distingue de los
       * demas mirando la lista**: hay que bajar hasta su tarjeta para verlo. Este
       * aviso dice cuantos hay antes de mirar ninguna.
       */}
      {sinSenal > 0 && (
        <div
          role="alert"
          className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <SignalZero size={18} className="mt-px shrink-0" />
          <span>
            {sinSenal === 1
              ? 'Un servicio en curso lleva rato sin recibir la posición del conductor.'
              : `${sinSenal} servicios en curso llevan rato sin recibir la posición del conductor.`}{' '}
            Conviene llamar para saber si todo va bien.
          </span>
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
              Aquí aparecerán las solicitudes en cuanto un pasajero pida un motocarro.
            </p>
          </div>
        )}

        {servicios.map((servicio) => (
          <ServiceCard key={servicio.request_id} servicio={servicio} onAsignar={setAsignando} />
        ))}
      </div>

      {asignando !== null && (
        <AssignDialog
          servicio={asignando}
          onCerrar={() => setAsignando(null)}
          onAsignado={() => {
            setAsignando(null);
            // Sin esperar a los diez segundos del temporizador: quien acaba de
            // asignar quiere ver el servicio ya con su conductor.
            void recargar();
          }}
        />
      )}

      <h2 className="mt-8 text-lg font-semibold text-text-primary">Mapa de la flota</h2>
      <FleetMap ubicaciones={ubicaciones} />
    </section>
  );
}
