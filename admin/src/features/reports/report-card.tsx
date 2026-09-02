'use client';

import { Clock, Info, MessageSquare, Phone, Route, User } from 'lucide-react';
import { ESTILO_ESTADO, ETIQUETA_ESTADO, formatearEspera, formatearFechaHora } from './types';
import type { Report } from './types';

const ETIQUETA_ROL: Record<string, string> = {
  passenger: 'Pasajero',
  driver: 'Conductor',
  admin: 'Administrador',
};

export function ReportCard({
  reporte,
  onGestionar,
}: {
  reporte: Report;
  onGestionar: (reporte: Report) => void;
}) {
  const sinAtender = reporte.status !== 'resolved';

  return (
    <article className="rounded-xl border border-border bg-surface p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[reporte.status]}`}>
            {ETIQUETA_ESTADO[reporte.status]}
          </span>
          <span className="rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
            {reporte.category}
          </span>
        </div>

        {/*
         * LA ESPERA SE DICE EN CADA FILA, no solo la fecha. Es el dato que
         * ordena la bandeja: un reporte de hace cinco dias sin atender no es lo
         * mismo que uno de esta manana, y con la fecha sola hay que hacer la
         * resta a mano.
         */}
        <span
          className={`flex items-center gap-1.5 rounded-md px-2 py-1 text-xs ${
            sinAtender ? 'bg-warning-subtle text-on-warning' : 'text-text-secondary'
          }`}
        >
          <Clock size={14} />
          {formatearEspera(reporte.created_at)}
        </span>
      </header>

      <p className="mt-3 text-sm whitespace-pre-line text-text-primary">{reporte.description}</p>

      <dl className="mt-4 grid gap-3 border-t border-border pt-3 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-xs text-text-secondary">Lo reportó</dt>
          <dd className="mt-0.5 flex flex-wrap items-center gap-1.5 text-text-primary">
            <User size={13} className="text-text-tertiary" />
            {reporte.reporter_name}
            <span className="text-text-secondary">
              ({ETIQUETA_ROL[reporte.reporter_role] ?? reporte.reporter_role})
            </span>
            <span className="flex items-center gap-1 text-text-secondary">
              <Phone size={12} />
              {reporte.reporter_phone}
            </span>
          </dd>
        </div>

        {/*
         * Sin contraparte no se pinta nada: no todos los problemas son con
         * alguien -"la aplicacion se cerro sola"- y una fila vacia con un guion
         * haria pensar que falta un dato.
         */}
        {reporte.counterpart_name !== null && (
          <div>
            <dt className="text-xs text-text-secondary">Sobre</dt>
            <dd className="mt-0.5 text-text-primary">{reporte.counterpart_name}</dd>
          </div>
        )}

        {reporte.ride_route !== null && (
          <div className="sm:col-span-2">
            <dt className="text-xs text-text-secondary">Servicio</dt>
            <dd className="mt-0.5 flex items-start gap-1.5 text-text-primary">
              <Route size={14} className="mt-0.5 shrink-0 text-text-tertiary" />
              <span>
                {reporte.ride_route}
                {reporte.ride_requested_at !== null && (
                  <span className="text-text-secondary">
                    {' · '}
                    {formatearFechaHora(reporte.ride_requested_at)}
                  </span>
                )}
              </span>
            </dd>

            {/*
             * SE DICE CUANDO QUIEN REPORTA NO IBA EN ESE SERVICIO. Nada lo
             * impide -se puede senalar un servicio que uno vio- pero se lee muy
             * distinto, y callarlo haria pensar que el reporte viene de dentro
             * del viaje. Por eso tampoco se ensena contraparte en ese caso: un
             * nombre de mas ahi senala a la persona equivocada.
             */}
            {reporte.reporter_was_in_ride === false && (
              <dd className="mt-1.5 flex items-start gap-1.5 text-xs text-on-warning">
                <Info size={13} className="mt-px shrink-0" />
                Quien lo reportó no iba en este servicio
              </dd>
            )}
          </div>
        )}

        {reporte.resolution_notes !== null && (
          <div className="sm:col-span-2">
            <dt className="text-xs text-text-secondary">
              Qué se hizo
              {reporte.resolved_by_name !== null && ` · ${reporte.resolved_by_name}`}
              {reporte.resolved_at !== null && ` · ${formatearFechaHora(reporte.resolved_at)}`}
            </dt>
            <dd className="mt-0.5 flex items-start gap-1.5 text-text-primary">
              <MessageSquare size={14} className="mt-0.5 shrink-0 text-text-tertiary" />
              {reporte.resolution_notes}
            </dd>
          </div>
        )}
      </dl>

      <footer className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-border pt-3">
        <span className="text-xs text-text-secondary">
          {formatearFechaHora(reporte.created_at)}
        </span>
        <button
          type="button"
          onClick={() => onGestionar(reporte)}
          className="btn btn-secundario px-3 py-1.5"
        >
          Gestionar
        </button>
      </footer>
    </article>
  );
}
