'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, Inbox, LoaderCircle, Search, Star } from 'lucide-react';
import { listarCalificaciones, listarReportes } from './report-actions';
import { ReportCard } from './report-card';
import { ManageDialog } from './manage-dialog';
import { formatearFechaHora } from './types';
import type { Rating, Report, ReportStatus } from './types';

const POR_PAGINA = 25;

const PESTANAS = [
  { id: 'reportes', etiqueta: 'Reportes' },
  { id: 'calificaciones', etiqueta: 'Calificaciones' },
] as const;

type Pestana = (typeof PESTANAS)[number]['id'];

const FILTROS_ESTADO: { valor: ReportStatus | null; etiqueta: string }[] = [
  { valor: null, etiqueta: 'Todos' },
  { valor: 'open', etiqueta: 'Sin atender' },
  { valor: 'in_review', etiqueta: 'En revisión' },
  { valor: 'resolved', etiqueta: 'Resueltos' },
];

/**
 * Reportes y calificaciones, en una sola pantalla con dos pestanas.
 *
 * POR QUE JUNTAS Y NO EN DOS SECCIONES DEL MENU. Son la misma tarea -mirar de
 * que se queja la gente- y quien entra aqui viene a eso. Separarlas obligaria a
 * recordar en cual de las dos estaba lo que busca, y la barra de arriba crece
 * sin que ninguna de las dos lo necesite.
 *
 * **LAS CALIFICACIONES NO REPITEN LAS DEL PASO 8.** Alli se miran desde un
 * servicio -"que paso en este"-; aqui se mira al reves, **donde estan las
 * malas**, que es la pregunta que hace falta para actuar.
 */
export function ReportsPage() {
  const [pestana, setPestana] = useState<Pestana>('reportes');

  const [reportes, setReportes] = useState<Report[]>([]);
  const [estado, setEstado] = useState<ReportStatus | null>(null);
  const [busqueda, setBusqueda] = useState('');
  const [pagina, setPagina] = useState(0);

  const [calificaciones, setCalificaciones] = useState<Rating[]>([]);
  const [soloMalas, setSoloMalas] = useState(false);
  const [soloConComentario, setSoloConComentario] = useState(false);

  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [gestionando, setGestionando] = useState<Report | null>(null);

  const consultar = useCallback(async () => {
    setCargando(true);
    if (pestana === 'reportes') {
      const r = await listarReportes({ estado, busqueda }, POR_PAGINA, pagina * POR_PAGINA);
      setCargando(false);
      if (!r.ok) {
        setError(r.mensaje);
        return;
      }
      setReportes(r.reportes);
      setError(null);
      return;
    }

    const r = await listarCalificaciones(
      { soloMalas, soloConComentario },
      POR_PAGINA,
      pagina * POR_PAGINA,
    );
    setCargando(false);
    if (!r.ok) {
      setError(r.mensaje);
      return;
    }
    setCalificaciones(r.calificaciones);
    setError(null);
  }, [pestana, estado, busqueda, pagina, soloMalas, soloConComentario]);

  useEffect(() => {
    // Se programa, no se llama en el cuerpo del efecto: poner estado durante el
    // efecto es lo que prohibe `react-hooks/set-state-in-effect`.
    const t = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(t);
  }, [consultar]);

  const total =
    pestana === 'reportes'
      ? (reportes[0]?.total_count ?? 0)
      : (calificaciones[0]?.total_count ?? 0);
  const sinAtender = reportes.filter((r) => r.status !== 'resolved').length;

  return (
    <section>
      <header>
        <h2 className="text-lg font-semibold text-text-primary">Reportes y calificaciones</h2>
        <p className="mt-0.5 text-sm text-text-secondary">
          Lo que los pasajeros y los conductores cuentan que salió mal.
        </p>
      </header>

      <div className="mt-4 flex gap-1 border-b border-border">
        {PESTANAS.map((p) => {
          const activa = pestana === p.id;
          return (
            <button
              key={p.id}
              type="button"
              onClick={() => {
                setPestana(p.id);
                setPagina(0);
              }}
              aria-current={activa ? 'page' : undefined}
              className={`-mb-px cursor-pointer border-b-2 px-3 py-2.5 text-sm font-medium transition-colors duration-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-(--color-brand) ${
                activa
                  ? 'border-brand text-brand-strong'
                  : 'border-transparent text-text-secondary hover:border-border-strong hover:text-text-primary'
              }`}
            >
              {p.etiqueta}
            </button>
          );
        })}
      </div>

      {pestana === 'reportes' ? (
        <div className="mt-4 flex flex-wrap items-center gap-2">
          {FILTROS_ESTADO.map((f) => (
            <button
              key={f.etiqueta}
              type="button"
              onClick={() => {
                setEstado(f.valor);
                setPagina(0);
              }}
              aria-pressed={estado === f.valor}
              className={`btn px-3 py-1.5 ${
                estado === f.valor ? 'btn-primario' : 'btn-secundario'
              }`}
            >
              {f.etiqueta}
            </button>
          ))}

          <label className="relative ml-auto">
            <Search
              size={15}
              className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-text-tertiary"
            />
            <input
              type="search"
              value={busqueda}
              onChange={(e) => {
                setBusqueda(e.target.value);
                setPagina(0);
              }}
              placeholder="Buscar en los reportes"
              className="w-56 rounded-lg border border-border bg-surface py-2 pr-3 pl-9 text-sm text-text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-(--color-brand)"
            />
          </label>
        </div>
      ) : (
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => {
              setSoloMalas((v) => !v);
              setPagina(0);
            }}
            aria-pressed={soloMalas}
            className={`btn px-3 py-1.5 ${soloMalas ? 'btn-primario' : 'btn-secundario'}`}
          >
            Solo las malas
          </button>
          <button
            type="button"
            onClick={() => {
              setSoloConComentario((v) => !v);
              setPagina(0);
            }}
            aria-pressed={soloConComentario}
            className={`btn px-3 py-1.5 ${soloConComentario ? 'btn-primario' : 'btn-secundario'}`}
          >
            Solo con comentario
          </button>
        </div>
      )}

      {error !== null && (
        <div
          role="alert"
          className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {pestana === 'reportes' && !cargando && reportes.length > 0 && (
        <p className="mt-4 text-sm text-text-secondary">
          {total} {total === 1 ? 'reporte' : 'reportes'}
          {sinAtender > 0 && (
            <span className="text-text-primary">
              {' · '}
              {sinAtender} sin atender en esta página
            </span>
          )}
        </p>
      )}

      <div className="mt-4 flex flex-col gap-3">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando…
          </div>
        )}

        {/*
         * Una bandeja vacia es una buena noticia -nadie se ha quejado-, no un
         * error, y se dice asi. Mismo criterio que el tablero sin servicios.
         */}
        {!cargando && pestana === 'reportes' && reportes.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">No hay reportes</p>
            <p className="max-w-md text-sm text-text-secondary">
              Aquí llegarán los problemas que los pasajeros y los conductores reporten desde la
              aplicación.
            </p>
          </div>
        )}

        {!cargando &&
          pestana === 'reportes' &&
          reportes.map((r) => (
            <ReportCard key={r.report_id} reporte={r} onGestionar={setGestionando} />
          ))}

        {!cargando && pestana === 'calificaciones' && calificaciones.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Star size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">No hay calificaciones que mostrar</p>
          </div>
        )}

        {!cargando &&
          pestana === 'calificaciones' &&
          calificaciones.map((c) => (
            <article key={c.rating_id} className="rounded-xl border border-border bg-surface p-4">
              <header className="flex flex-wrap items-center justify-between gap-3">
                <span className="flex items-center gap-1.5">
                  {/*
                   * Las estrellas van con su numero al lado: contar dibujitos
                   * para saber si son dos o tres es trabajo que no hace falta.
                   */}
                  <Star size={15} className="text-text-tertiary" />
                  <span className="font-medium text-text-primary">{c.stars} de 5</span>
                </span>
                <span className="text-xs text-text-secondary">
                  {formatearFechaHora(c.created_at)}
                </span>
              </header>

              {c.comment !== null && c.comment.trim() !== '' && (
                <p className="mt-2 text-sm text-text-primary">{c.comment}</p>
              )}

              <p className="mt-3 border-t border-border pt-3 text-sm text-text-secondary">
                <span className="text-text-primary">{c.rater_name}</span> calificó a{' '}
                <span className="text-text-primary">{c.rated_name}</span>
                {c.ride_route !== null && ` · ${c.ride_route}`}
              </p>
            </article>
          ))}
      </div>

      {!cargando && total > POR_PAGINA && (
        <div className="mt-4 flex items-center justify-between gap-3">
          <button
            type="button"
            disabled={pagina === 0}
            onClick={() => setPagina((p) => Math.max(0, p - 1))}
            className="btn btn-secundario px-4 py-2"
          >
            Anterior
          </button>
          <span className="text-sm text-text-secondary">
            Página {pagina + 1} de {Math.ceil(Number(total) / POR_PAGINA)}
          </span>
          <button
            type="button"
            disabled={(pagina + 1) * POR_PAGINA >= Number(total)}
            onClick={() => setPagina((p) => p + 1)}
            className="btn btn-secundario px-4 py-2"
          >
            Siguiente
          </button>
        </div>
      )}

      {gestionando !== null && (
        <ManageDialog
          reporte={gestionando}
          onCerrar={() => setGestionando(null)}
          onGuardado={() => {
            setGestionando(null);
            void consultar();
          }}
        />
      )}
    </section>
  );
}
