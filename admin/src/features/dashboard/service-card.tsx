import { Box, Clock, MapPin, Phone, Search, Signal, User } from 'lucide-react';
import type { ActiveService } from './types';
import { ETIQUETA_ESTADO } from './types';
import {
  formatearAntiguedadPosicion,
  formatearEspera,
  formatearPesos,
  nivelDeEspera,
} from './format';

/*
 * El color del estado va SIEMPRE acompanado de texto y de un icono propio, y
 * nunca es la unica senal. Es D202 de la aplicacion movil aplicado aqui, y por
 * el mismo motivo: los pares de color de estado no llegan al contraste minimo
 * (hallazgo H14), y ademas un tablero que solo distingue por color no lo puede
 * leer quien no distingue esos colores.
 */
const ESTILO_ESPERA = {
  normal: 'bg-surface-subtle text-text-secondary',
  atencion: 'bg-warning-subtle text-on-warning',
  alerta: 'bg-danger-subtle text-on-danger-subtle',
} as const;

export function ServiceCard({ servicio }: { servicio: ActiveService }) {
  const espera = nivelDeEspera(servicio.waiting_seconds);
  const esEncomienda = servicio.service_type === 'parcel';

  return (
    <article className="rounded-xl border border-border bg-surface p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          {esEncomienda ? (
            <Box size={18} className="text-text-secondary" />
          ) : (
            <User size={18} className="text-text-secondary" />
          )}
          <span className="font-medium text-text-primary">
            {esEncomienda
              ? 'Encomienda'
              : `${servicio.passenger_count} ${servicio.passenger_count === 1 ? 'pasajero' : 'pasajeros'}`}
          </span>
          <span className="rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
            {ETIQUETA_ESTADO[servicio.status] ?? servicio.status}
          </span>
        </div>

        <div
          className={`flex items-center gap-1.5 rounded-md px-2 py-1 text-xs ${ESTILO_ESPERA[espera]}`}
        >
          <Clock size={14} />
          {formatearEspera(servicio.waiting_seconds)}
        </div>
      </header>

      <div className="mt-3 flex items-start gap-2 text-sm">
        <MapPin size={16} className="mt-0.5 shrink-0 text-text-tertiary" />
        <p className="text-text-primary">
          {servicio.origin_label}
          <span className="text-text-tertiary"> → </span>
          {servicio.destination_label}
        </p>
      </div>

      {servicio.pickup_reference !== null && (
        <p className="mt-1 pl-6 text-sm text-text-secondary">{servicio.pickup_reference}</p>
      )}

      {esEncomienda && servicio.parcel_description !== null && (
        <p className="mt-1 pl-6 text-sm text-text-secondary">{servicio.parcel_description}</p>
      )}

      <dl className="mt-4 grid gap-3 border-t border-border pt-3 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-xs text-text-secondary">Pasajero</dt>
          <dd className="mt-0.5 flex items-center gap-1.5 text-text-primary">
            {servicio.passenger_name}
            <span className="flex items-center gap-1 text-text-secondary">
              <Phone size={12} />
              {servicio.passenger_phone}
            </span>
          </dd>
        </div>

        <div>
          <dt className="text-xs text-text-secondary">Valor</dt>
          <dd className="mt-0.5 text-text-primary">
            {formatearPesos(servicio.fare_amount)}
            {servicio.fare_reference !== null && (
              <span className="text-text-secondary"> · {servicio.fare_reference}</span>
            )}
          </dd>
        </div>

        {/*
         * Mientras nadie ha aceptado, lo util es cuantos conductores tienen la
         * oferta delante: distingue "no hay nadie cerca" de "hay cinco y
         * ninguno la coge", que son dos problemas distintos.
         */}
        {servicio.status === 'searching' ? (
          <div className="sm:col-span-2">
            <dt className="text-xs text-text-secondary">Ofertas en curso</dt>
            <dd className="mt-0.5 flex items-center gap-1.5 text-text-primary">
              <Search size={14} className="text-text-tertiary" />
              {servicio.pending_offers === 0
                ? 'Ningún conductor la tiene ahora mismo'
                : `${servicio.pending_offers} ${servicio.pending_offers === 1 ? 'conductor la tiene' : 'conductores la tienen'}`}
            </dd>
          </div>
        ) : (
          <>
            <div>
              <dt className="text-xs text-text-secondary">Conductor</dt>
              <dd className="mt-0.5 text-text-primary">
                {servicio.driver_name}
                {servicio.unit_number !== null && (
                  <span className="text-text-secondary"> · Motorratón {servicio.unit_number}</span>
                )}
              </dd>
            </div>

            <div>
              <dt className="text-xs text-text-secondary">Última posición</dt>
              <dd className="mt-0.5 flex items-center gap-1.5 text-text-primary">
                <Signal size={14} className="text-text-tertiary" />
                {formatearAntiguedadPosicion(servicio.driver_location_age_seconds)}
              </dd>
            </div>
          </>
        )}
      </dl>
    </article>
  );
}
