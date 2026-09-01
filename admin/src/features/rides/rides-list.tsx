'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, Inbox, LoaderCircle, Search } from 'lucide-react';
import { listarServicios } from './ride-actions';
import type { Filtros } from './ride-actions';
import {
  ESTADOS,
  ESTILO_ESTADO,
  ETIQUETA_ACTOR,
  ETIQUETA_ESTADO,
  formatearFechaHora,
  formatearPesos,
} from './types';
import type { Ride, RequestStatus } from './types';
import { RideDetailDialog } from './ride-detail-dialog';

const POR_PAGINA = 30;

export function RidesList() {
  const [servicios, setServicios] = useState<Ride[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pagina, setPagina] = useState(0);
  const [abierto, setAbierto] = useState<string | null>(null);

  const [filtros, setFiltros] = useState<Filtros>({
    estado: null,
    desde: null,
    hasta: null,
    busqueda: '',
  });

  // Lo que se envia de verdad al servidor. Se separa del texto que se escribe
  // para no consultar en cada tecla: la lista puede tener cientos de filas.
  const [buscado, setBuscado] = useState('');

  const consultar = useCallback(async () => {
    const r = await listarServicios(
      { ...filtros, busqueda: buscado },
      POR_PAGINA,
      pagina * POR_PAGINA,
    );
    setCargando(false);
    if (!r.ok) {
      setError(r.mensaje);
      return;
    }
    setServicios(r.servicios);
    setError(null);
  }, [filtros, buscado, pagina]);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  // El total viene en cada fila, calculado por el servidor sobre lo filtrado.
  const total = servicios[0]?.total_count ?? 0;
  const paginas = Math.ceil(Number(total) / POR_PAGINA);

  function cambiarFiltro(cambio: Partial<Filtros>) {
    // Volver a la primera pagina al filtrar: quedarse en la cuarta de un
    // resultado que ahora tiene dos es la forma de ver una lista vacia y creer
    // que no hay nada.
    setPagina(0);
    setCargando(true);
    setFiltros((f) => ({ ...f, ...cambio }));
  }

  return (
    <section>
      <header>
        <h2 className="text-lg font-semibold text-text-primary">Servicios</h2>
        <p className="mt-0.5 text-sm text-text-secondary">
          {cargando ? 'Consultando…' : `${total} ${Number(total) === 1 ? 'servicio' : 'servicios'}`}
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

      <div className="mt-4 flex flex-wrap items-end gap-2">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setPagina(0);
            setCargando(true);
            setBuscado(filtros.busqueda);
          }}
          className="relative flex-1 sm:max-w-xs"
        >
          <Search
            size={16}
            className="absolute top-1/2 left-3 -translate-y-1/2 text-text-tertiary"
          />
          <input
            value={filtros.busqueda}
            onChange={(e) => setFiltros((f) => ({ ...f, busqueda: e.target.value }))}
            placeholder="Pasajero, conductor, origen o destino"
            aria-label="Buscar un servicio"
            className="h-10 w-full rounded-lg border border-border bg-surface pr-3 pl-9 text-sm text-text-primary outline-none focus:border-brand"
          />
        </form>

        <div className="flex flex-col gap-1">
          <label htmlFor="filtro-estado" className="text-xs text-text-secondary">
            Estado
          </label>
          <select
            id="filtro-estado"
            value={filtros.estado ?? ''}
            onChange={(e) =>
              cambiarFiltro({
                estado: e.target.value === '' ? null : (e.target.value as RequestStatus),
              })
            }
            className="h-10 rounded-lg border border-border bg-surface px-3 text-sm text-text-primary outline-none focus:border-brand"
          >
            <option value="">Todos</option>
            {ESTADOS.map((s) => (
              <option key={s} value={s}>
                {ETIQUETA_ESTADO[s]}
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label htmlFor="filtro-desde" className="text-xs text-text-secondary">
            Desde
          </label>
          <input
            id="filtro-desde"
            type="date"
            value={filtros.desde ?? ''}
            onChange={(e) =>
              cambiarFiltro({ desde: e.target.value === '' ? null : e.target.value })
            }
            className="h-10 rounded-lg border border-border bg-surface px-3 text-sm text-text-primary outline-none focus:border-brand"
          />
        </div>

        <div className="flex flex-col gap-1">
          <label htmlFor="filtro-hasta" className="text-xs text-text-secondary">
            Hasta
          </label>
          <input
            id="filtro-hasta"
            type="date"
            value={filtros.hasta ?? ''}
            onChange={(e) =>
              cambiarFiltro({ hasta: e.target.value === '' ? null : e.target.value })
            }
            className="h-10 rounded-lg border border-border bg-surface px-3 text-sm text-text-primary outline-none focus:border-brand"
          />
        </div>
      </div>

      <div className="mt-4 flex flex-col gap-2">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los servicios…
          </div>
        )}

        {!cargando && servicios.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">Ningún servicio coincide</p>
            <p className="max-w-sm text-sm text-text-secondary">Prueba con otros filtros.</p>
          </div>
        )}

        {!cargando &&
          servicios.map((s) => (
            <button
              key={s.request_id}
              type="button"
              onClick={() => setAbierto(s.request_id)}
              className="btn w-full flex-col items-stretch gap-1 rounded-xl border border-border bg-surface p-4 text-left font-normal hover:bg-surface-subtle"
            >
              <span className="flex flex-wrap items-center justify-between gap-2">
                <span className="flex flex-wrap items-center gap-2">
                  <span className="text-text-primary">
                    {s.origin_label} <span className="text-text-tertiary">→</span>{' '}
                    {s.destination_label}
                  </span>
                  <span className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[s.status]}`}>
                    {ETIQUETA_ESTADO[s.status]}
                  </span>
                </span>
                <span className="text-sm text-text-secondary">{formatearPesos(s.fare_amount)}</span>
              </span>

              <span className="text-xs text-text-secondary">
                {formatearFechaHora(s.requested_at)} · {s.passenger_name}
                {s.driver_name !== null ? ` · ${s.driver_name}` : ' · sin conductor'}
                {s.unit_number !== null ? ` (${s.unit_number})` : ''}
                {s.duration_minutes !== null ? ` · ${s.duration_minutes} min` : ''}
                {s.cancelled_by !== null
                  ? ` · canceló ${ETIQUETA_ACTOR[s.cancelled_by] ?? s.cancelled_by}`
                  : ''}
              </span>
            </button>
          ))}
      </div>

      {paginas > 1 && (
        <nav className="mt-4 flex items-center justify-between gap-3" aria-label="Paginación">
          <button
            type="button"
            disabled={pagina === 0}
            onClick={() => {
              setCargando(true);
              setPagina((p) => p - 1);
            }}
            className="btn btn-secundario h-10 px-3"
          >
            Anterior
          </button>
          <span className="text-sm text-text-secondary">
            Página {pagina + 1} de {paginas}
          </span>
          <button
            type="button"
            disabled={pagina + 1 >= paginas}
            onClick={() => {
              setCargando(true);
              setPagina((p) => p + 1);
            }}
            className="btn btn-secundario h-10 px-3"
          >
            Siguiente
          </button>
        </nav>
      )}

      {abierto !== null && (
        <RideDetailDialog requestId={abierto} onCerrar={() => setAbierto(null)} />
      )}
    </section>
  );
}
