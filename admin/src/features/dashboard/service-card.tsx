import {
  Ban,
  Box,
  Clock,
  MapPin,
  Phone,
  Search,
  Signal,
  SignalZero,
  User,
  UserPlus,
} from 'lucide-react';
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

export function ServiceCard({
  servicio,
  onAsignar,
}: {
  servicio: ActiveService;
  onAsignar: (servicio: ActiveService) => void;
}) {
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
            <dd className="mt-0.5 flex flex-wrap items-center justify-between gap-2 text-text-primary">
              <span className="flex items-center gap-1.5">
                <Search size={14} className="text-text-tertiary" />
                {servicio.pending_offers === 0
                  ? 'Ningún conductor la tiene ahora mismo'
                  : `${servicio.pending_offers} ${servicio.pending_offers === 1 ? 'conductor la tiene' : 'conductores la tienen'}`}
              </span>

              {/*
               * EL BOTON VIVE AQUI Y NO EN UNA PANTALLA APARTE, y es a
               * proposito: la asignacion manual no se decide en abstracto sino
               * mirando una solicitud concreta que lleva rato sin que nadie la
               * coja. Al lado de la espera y de las ofertas vivas, que son los
               * dos numeros que hacen tomar la decision.
               */}
              <button
                type="button"
                onClick={() => onAsignar(servicio)}
                className="btn btn-secundario px-3 py-1.5"
              >
                <UserPlus size={14} />
                Asignar a mano
              </button>
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
                {/*
                 * Que el conductor este bloqueado se dice AQUI, pegado a su
                 * nombre. Antes no se veia por ningun lado: la empresa bloqueaba
                 * a alguien y el servicio seguia en el tablero igual que los
                 * demas, sin nada que dijera que ese es el ultimo que va a hacer.
                 * Termina el viaje que lleva (D262), y por eso sigue en la lista.
                 */}
                {servicio.driver_blocked === true && (
                  <span className="mt-1 flex items-center gap-1.5 text-xs text-on-danger-subtle">
                    <Ban size={12} />
                    Cuenta bloqueada · termina este servicio y no toma más
                  </span>
                )}
              </dd>
            </div>

            <div>
              <dt className="text-xs text-text-secondary">Última posición</dt>
              {/*
               * R10. La alerta va DENTRO del dato que la provoca, no en un aviso
               * aparte: quien mira la fila tiene que ver a la vez cuanto hace que
               * no se sabe nada y que eso ya pasa de la cuenta. El umbral lo pone
               * la empresa en los parametros; aqui solo se pinta lo que dice el
               * servidor.
               */}
              <dd
                className={`mt-0.5 flex items-center gap-1.5 ${
                  servicio.signal_lost === true
                    ? 'rounded-md bg-danger-subtle px-2 py-1 text-on-danger-subtle'
                    : 'text-text-primary'
                }`}
              >
                {servicio.signal_lost === true ? (
                  <SignalZero size={14} />
                ) : (
                  <Signal size={14} className="text-text-tertiary" />
                )}
                {formatearAntiguedadPosicion(servicio.driver_location_age_seconds)}
                {servicio.signal_lost === true && <span>· sin señal</span>}
              </dd>
            </div>
          </>
        )}
      </dl>
    </article>
  );
}
