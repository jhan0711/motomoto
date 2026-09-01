'use client';

import { useCallback, useEffect, useState } from 'react';
import { Box, Circle, LoaderCircle, Phone, Star, X } from 'lucide-react';
import { obtenerDetalle } from './ride-actions';
import {
  ESTILO_ESTADO,
  ESTILO_RESPUESTA,
  ETIQUETA_ACTOR,
  ETIQUETA_ESTADO,
  ETIQUETA_RESPUESTA,
  formatearDistancia,
  formatearDuracion,
  formatearFechaHora,
  formatearHora,
  formatearPesos,
  pasosDe,
} from './types';
import type { RideDetail, RideOffer, RideRating } from './types';

interface Props {
  requestId: string;
  onCerrar: () => void;
}

export function RideDetailDialog({ requestId, onCerrar }: Props) {
  const [detalle, setDetalle] = useState<RideDetail | null>(null);
  const [ofertas, setOfertas] = useState<RideOffer[]>([]);
  const [calificaciones, setCalificaciones] = useState<RideRating[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const consultar = useCallback(async () => {
    const r = await obtenerDetalle(requestId);
    setCargando(false);
    if (!r.ok) {
      setError(r.mensaje);
      return;
    }
    setDetalle(r.detalle);
    setOfertas(r.ofertas);
    setCalificaciones(r.calificaciones);
  }, [requestId]);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-servicio"
    >
      <div className="my-8 w-full max-w-[720px] rounded-xl border border-border bg-surface">
        <header className="flex items-start justify-between gap-3 border-b border-border p-5">
          <div>
            <h3 id="titulo-servicio" className="font-medium text-text-primary">
              Detalle del servicio
            </h3>
            {detalle !== null && (
              <p className="mt-1 flex flex-wrap items-center gap-2 text-sm text-text-secondary">
                <span className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[detalle.status]}`}>
                  {ETIQUETA_ESTADO[detalle.status]}
                </span>
                {formatearFechaHora(detalle.requested_at)}
              </p>
            )}
          </div>
          <button
            type="button"
            onClick={onCerrar}
            aria-label="Cerrar"
            className="btn btn-secundario size-9 shrink-0 p-0"
          >
            <X size={16} />
          </button>
        </header>

        {cargando && (
          <div className="flex items-center justify-center gap-2 py-16 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando el servicio…
          </div>
        )}

        {error !== null && (
          <p
            role="alert"
            className="m-5 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
          >
            {error}
          </p>
        )}

        {detalle !== null && (
          <div className="flex flex-col gap-6 p-5">
            {/* --------------------------------------------------- La ruta */}
            <section>
              <p className="text-text-primary">
                {detalle.origin_label} <span className="text-text-tertiary">→</span>{' '}
                {detalle.destination_label}
              </p>
              {detalle.pickup_reference !== null && (
                <p className="mt-0.5 text-sm text-text-secondary">
                  Recogida: {detalle.pickup_reference}
                </p>
              )}
              <p className="mt-1 flex flex-wrap items-center gap-2 text-sm text-text-secondary">
                {detalle.service_type === 'parcel' ? (
                  <span className="flex items-center gap-1.5">
                    <Box size={14} />
                    Encomienda
                  </span>
                ) : (
                  <span>
                    {detalle.passenger_count}{' '}
                    {detalle.passenger_count === 1 ? 'pasajero' : 'pasajeros'}
                  </span>
                )}
                {detalle.distance_m !== null && (
                  <span>· {formatearDistancia(detalle.distance_m)}</span>
                )}
                {detalle.duration_s !== null && (
                  <span>· {formatearDuracion(detalle.duration_s)}</span>
                )}
              </p>
              {detalle.parcel_description !== null && (
                <p className="mt-1 text-sm text-text-secondary">{detalle.parcel_description}</p>
              )}
            </section>

            {/* ------------------------------------------------ Las partes */}
            <section className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-lg border border-border p-3">
                <p className="text-xs text-text-secondary">Pasajero</p>
                <p className="mt-0.5 text-text-primary">{detalle.passenger_name}</p>
                <p className="mt-0.5 flex items-center gap-1.5 text-sm text-text-secondary">
                  <Phone size={13} />
                  {detalle.contact_phone}
                  {/* El teléfono del perfil puede diferir del de contacto del viaje. */}
                  {detalle.passenger_phone !== detalle.contact_phone && (
                    <span className="text-text-tertiary">(perfil: {detalle.passenger_phone})</span>
                  )}
                </p>
              </div>

              <div className="rounded-lg border border-border p-3">
                <p className="text-xs text-text-secondary">Conductor</p>
                {detalle.driver_name === null ? (
                  <p className="mt-0.5 text-text-secondary">Nadie lo tomó</p>
                ) : (
                  <>
                    <p className="mt-0.5 text-text-primary">
                      {detalle.driver_name}
                      {detalle.unit_number !== null && (
                        <span className="text-text-secondary">
                          {' '}
                          · Motorratón {detalle.unit_number}
                        </span>
                      )}
                    </p>
                    <p className="mt-0.5 flex items-center gap-1.5 text-sm text-text-secondary">
                      <Phone size={13} />
                      {detalle.driver_phone}
                      {detalle.plate !== null && <span>· {detalle.plate}</span>}
                    </p>
                  </>
                )}
              </div>
            </section>

            {/* ---------------------------------------------- El valor */}
            <section>
              <h4 className="text-sm font-medium text-text-primary">Valor</h4>
              <div className="mt-2 rounded-lg border border-border p-3">
                <p className="text-lg font-semibold text-text-primary">
                  {formatearPesos(detalle.fare_amount)}
                </p>
                {detalle.fare_amount !== null && (
                  <p className="mt-0.5 text-sm text-text-secondary">
                    Viaje {formatearPesos(detalle.fare_trip_amount)}
                    {detalle.fare_cargo_amount !== null && detalle.fare_cargo_amount > 0
                      ? ` · Carga ${formatearPesos(detalle.fare_cargo_amount)}`
                      : ''}
                    {detalle.fare_is_night === true ? ' · Tarifa nocturna' : ''}
                    {detalle.fare_reference !== null ? ` · ${detalle.fare_reference}` : ''}
                  </p>
                )}
              </div>
            </section>

            {/* ------------------------------------------- Línea de tiempo */}
            <section>
              <h4 className="text-sm font-medium text-text-primary">Qué pasó</h4>
              <ol className="mt-2 flex flex-col gap-0">
                {pasosDe(detalle).map((paso, i, todos) => {
                  const ocurrio = paso.cuando !== null;
                  return (
                    <li key={paso.etiqueta} className="flex gap-3">
                      <div className="flex flex-col items-center">
                        <Circle
                          size={12}
                          className={ocurrio ? 'text-brand' : 'text-border'}
                          fill={ocurrio ? 'currentColor' : 'none'}
                        />
                        {i < todos.length - 1 && (
                          <div className="h-8 w-px bg-border" aria-hidden="true" />
                        )}
                      </div>
                      <div className="-mt-1 pb-3">
                        {/*
                         * Los pasos que NO ocurrieron se muestran igual, apagados:
                         * ver que un servicio nunca llegó a "el conductor llegó"
                         * dice tanto como ver que sí.
                         */}
                        <p className={ocurrio ? 'text-text-primary' : 'text-text-tertiary'}>
                          {paso.etiqueta}
                        </p>
                        <p className="text-xs text-text-secondary">
                          {ocurrio ? formatearHora(paso.cuando) : 'No llegó a pasar'}
                        </p>
                      </div>
                    </li>
                  );
                })}
              </ol>

              {detalle.cancelled_by !== null && (
                <p className="rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle">
                  Canceló {ETIQUETA_ACTOR[detalle.cancelled_by] ?? detalle.cancelled_by}
                  {detalle.cancellation_reason !== null ? `: ${detalle.cancellation_reason}` : ''}
                </p>
              )}
            </section>

            {/* ---------------------------------------------- Las ofertas */}
            <section>
              <h4 className="text-sm font-medium text-text-primary">
                A quién le llegó ({ofertas.length})
              </h4>
              {ofertas.length === 0 ? (
                <p className="mt-2 rounded-lg bg-warning-subtle px-3 py-2 text-sm text-on-warning">
                  {/*
                   * Distinguir "no le llegó a nadie" de "le llegó y nadie lo tomó"
                   * es justo lo que convierte este dato en algo accionable.
                   */}
                  No se le ofreció a ningún conductor. Puede que no hubiera ninguno disponible con
                  capacidad suficiente.
                </p>
              ) : (
                <div className="mt-2 flex flex-col gap-2">
                  {ofertas.map((o) => (
                    <div
                      key={o.offer_id}
                      className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border px-3 py-2 text-sm"
                    >
                      <span className="text-text-primary">
                        {o.driver_name}
                        {o.unit_number !== null && (
                          <span className="text-text-secondary"> · Motorratón {o.unit_number}</span>
                        )}
                        {o.distance_m !== null && (
                          <span className="text-text-secondary">
                            {' '}
                            · a {formatearDistancia(o.distance_m)}
                          </span>
                        )}
                      </span>
                      <span className="flex items-center gap-2">
                        {o.response_seconds !== null && (
                          <span className="text-xs text-text-secondary">
                            en {o.response_seconds} s
                          </span>
                        )}
                        <span
                          className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_RESPUESTA[o.response] ?? ''}`}
                        >
                          {ETIQUETA_RESPUESTA[o.response] ?? o.response}
                        </span>
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </section>

            {/* ----------------------------------------- Las calificaciones */}
            {calificaciones.length > 0 && (
              <section>
                <h4 className="text-sm font-medium text-text-primary">Cómo se calificaron</h4>
                <div className="mt-2 flex flex-col gap-2">
                  {calificaciones.map((c) => (
                    <div key={c.rating_id} className="rounded-lg border border-border px-3 py-2">
                      <p className="flex items-center gap-2 text-sm text-text-primary">
                        <span className="flex items-center gap-1 text-brand">
                          <Star size={13} fill="currentColor" />
                          {c.stars}
                        </span>
                        {c.rater_name} → {c.rated_name}
                      </p>
                      {c.comment !== null && (
                        <p className="mt-0.5 text-sm text-text-secondary">{c.comment}</p>
                      )}
                    </div>
                  ))}
                </div>
              </section>
            )}

            {/* -------------------------------------------- El recorrido */}
            <section>
              <h4 className="text-sm font-medium text-text-primary">Recorrido registrado</h4>
              {/*
               * Se muestra como datos y no como mapa: hoy la base tiene un punto
               * por viaje, porque el emulador no puede producir movimiento
               * (medido desde la Fase 14). Un mapa con un punto no enseña nada.
               */}
              <p className="mt-2 text-sm text-text-secondary">
                {detalle.track_points === 0
                  ? 'No se registró ningún punto del recorrido.'
                  : `${detalle.track_points} ${detalle.track_points === 1 ? 'punto' : 'puntos'}, de ${formatearHora(detalle.track_first_at)} a ${formatearHora(detalle.track_last_at)}.`}
              </p>
            </section>
          </div>
        )}
      </div>
    </div>
  );
}
