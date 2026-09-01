'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertCircle,
  Ban,
  ChevronDown,
  ChevronRight,
  Inbox,
  LoaderCircle,
  Search,
  Star,
  UserCheck,
} from 'lucide-react';
import { cambiarEstadoPasajero, listarPasajeros, listarServiciosDe } from './passenger-actions';
import {
  ESTILO_ESTADO,
  ETIQUETA_ACTOR,
  ETIQUETA_ESTADO,
  formatearFechaHora,
  formatearPesos,
  porcentajeCancelado,
} from './types';
import type { Passenger, PassengerRide } from './types';
import { BlockDialog } from './block-dialog';

export function PassengersList() {
  const [pasajeros, setPasajeros] = useState<Passenger[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busqueda, setBusqueda] = useState('');
  const [trabajando, setTrabajando] = useState(false);
  const [bloqueando, setBloqueando] = useState<Passenger | null>(null);

  // Los servicios de cada pasajero se piden solo al desplegar su ficha: son
  // hasta veinte filas por persona, y con veinte pasajeros serian cuatrocientas
  // que nadie pidio ver.
  const [abierto, setAbierto] = useState<string | null>(null);
  const [servicios, setServicios] = useState<PassengerRide[]>([]);
  const [cargandoServicios, setCargandoServicios] = useState(false);

  const consultar = useCallback(async () => {
    const r = await listarPasajeros();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setPasajeros(r.pasajeros);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  async function abrirFicha(p: Passenger) {
    if (abierto === p.passenger_id) {
      setAbierto(null);
      return;
    }
    setAbierto(p.passenger_id);
    setCargandoServicios(true);
    const r = await listarServiciosDe(p.passenger_id);
    setCargandoServicios(false);
    setServicios(r.ok ? r.servicios : []);
  }

  const visibles = useMemo(() => {
    const texto = busqueda.trim().toLowerCase();
    if (texto === '') return pasajeros;
    return pasajeros.filter(
      (p) => p.full_name.toLowerCase().includes(texto) || p.phone.includes(texto),
    );
  }, [pasajeros, busqueda]);

  const bloqueados = pasajeros.filter((p) => p.status === 'blocked').length;

  return (
    <section>
      <header>
        <h2 className="text-lg font-semibold text-text-primary">Pasajeros</h2>
        <p className="mt-0.5 text-sm text-text-secondary">
          {cargando
            ? 'Consultando…'
            : `${pasajeros.length} en total${bloqueados > 0 ? ` · ${bloqueados} bloqueados` : ''}`}
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

      <div className="relative mt-4 sm:max-w-xs">
        <Search size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-text-tertiary" />
        <input
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
          placeholder="Buscar por nombre o teléfono"
          aria-label="Buscar un pasajero"
          className="h-10 w-full rounded-lg border border-border bg-surface pr-3 pl-9 text-sm text-text-primary outline-none focus:border-brand"
        />
      </div>

      <div className="mt-4 flex flex-col gap-3">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los pasajeros…
          </div>
        )}

        {!cargando && visibles.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">
              {pasajeros.length === 0 ? 'Todavía no hay pasajeros' : 'Ninguno coincide'}
            </p>
          </div>
        )}

        {visibles.map((p) => {
          const bloqueado = p.status === 'blocked';
          const cancelado = porcentajeCancelado(p);
          return (
            <article
              key={p.passenger_id}
              className="rounded-xl border border-border bg-surface p-4"
            >
              <header className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="font-medium text-text-primary">{p.full_name}</h3>
                    {bloqueado && (
                      <span className="rounded-md bg-danger-subtle px-2 py-0.5 text-xs text-on-danger-subtle">
                        Bloqueado
                      </span>
                    )}
                    {p.has_active_request && (
                      <span className="rounded-md bg-info-subtle px-2 py-0.5 text-xs text-info">
                        Con servicio en curso
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-sm text-text-secondary">
                    {p.phone}
                    {p.last_request_at !== null
                      ? ` · Último servicio el ${formatearFechaHora(p.last_request_at)}`
                      : ' · Nunca ha pedido un servicio'}
                  </p>
                </div>

                <div className="flex flex-col items-end gap-1 text-sm">
                  <span className="flex items-center gap-1.5 text-text-secondary">
                    <Star size={14} className="text-text-tertiary" />
                    {p.rating_count === 0
                      ? 'Sin calificaciones'
                      : `${Number(p.rating_average).toFixed(2)} · ${p.rating_count}`}
                  </span>
                  <span className="text-xs text-text-secondary">
                    {p.completed_count} terminados · {p.cancelled_count} cancelados
                    {/*
                     * El porcentaje solo se muestra cuando dice algo: con dos
                     * servicios, un 50% no significa nada, y ensenarlo invita a
                     * decidir sobre ruido.
                     */}
                    {cancelado !== null && p.completed_count + p.cancelled_count >= 5 && (
                      <span
                        className={cancelado >= 40 ? 'text-on-danger-subtle' : 'text-text-tertiary'}
                      >
                        {' '}
                        ({cancelado}% cancelados)
                      </span>
                    )}
                  </span>
                </div>
              </header>

              <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-3">
                <button
                  type="button"
                  disabled={trabajando}
                  onClick={async () => {
                    if (bloqueado) {
                      setTrabajando(true);
                      const r = await cambiarEstadoPasajero(p.passenger_id, 'active', null);
                      setTrabajando(false);
                      if (r.ok) void consultar();
                      else setError(r.mensaje ?? 'No pudimos desbloquear la cuenta.');
                      return;
                    }
                    // Bloquear siempre pasa por el dialogo: aunque el motivo sea
                    // opcional, quitarle el acceso a alguien no debería ser un
                    // clic suelto.
                    setBloqueando(p);
                  }}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  {bloqueado ? <UserCheck size={15} /> : <Ban size={15} />}
                  {bloqueado ? 'Desbloquear' : 'Bloquear'}
                </button>

                <button
                  type="button"
                  onClick={() => void abrirFicha(p)}
                  aria-expanded={abierto === p.passenger_id}
                  className="btn h-9 gap-1.5 px-2 font-normal text-text-secondary hover:bg-surface-pressed"
                >
                  {abierto === p.passenger_id ? (
                    <ChevronDown size={15} />
                  ) : (
                    <ChevronRight size={15} />
                  )}
                  Sus servicios
                </button>
              </div>

              {abierto === p.passenger_id && (
                <div className="mt-3 flex flex-col gap-2">
                  {cargandoServicios && (
                    <div className="flex items-center gap-2 py-3 text-sm text-text-secondary">
                      <LoaderCircle size={16} className="animate-spin" />
                      Consultando…
                    </div>
                  )}

                  {!cargandoServicios && servicios.length === 0 && (
                    <p className="py-3 text-sm text-text-secondary">
                      No ha pedido ningún servicio.
                    </p>
                  )}

                  {!cargandoServicios &&
                    servicios.map((s) => (
                      <div
                        key={s.request_id}
                        className="rounded-lg border border-border px-3 py-2.5 text-sm"
                      >
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <span className="flex items-center gap-2 text-text-primary">
                            {s.origin_label} → {s.destination_label}
                            <span
                              className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[s.status] ?? ''}`}
                            >
                              {ETIQUETA_ESTADO[s.status] ?? s.status}
                            </span>
                          </span>
                          <span className="text-text-secondary">
                            {formatearPesos(s.fare_amount)}
                          </span>
                        </div>
                        <p className="mt-0.5 text-xs text-text-secondary">
                          {formatearFechaHora(s.requested_at)}
                          {s.driver_name !== null ? ` · ${s.driver_name}` : ''}
                          {/* Quién canceló es la mitad que explica el número. */}
                          {s.cancelled_by !== null
                            ? ` · Canceló ${ETIQUETA_ACTOR[s.cancelled_by] ?? s.cancelled_by}`
                            : ''}
                          {s.cancellation_reason !== null ? `: ${s.cancellation_reason}` : ''}
                        </p>
                      </div>
                    ))}
                </div>
              )}
            </article>
          );
        })}
      </div>

      {bloqueando !== null && (
        <BlockDialog
          nombre={bloqueando.full_name}
          conServicioEnCurso={bloqueando.has_active_request}
          onCerrar={() => setBloqueando(null)}
          onBloquear={async (motivo) => {
            const r = await cambiarEstadoPasajero(bloqueando.passenger_id, 'blocked', motivo);
            if (r.ok) {
              setBloqueando(null);
              void consultar();
            }
            return r;
          }}
        />
      )}
    </section>
  );
}
