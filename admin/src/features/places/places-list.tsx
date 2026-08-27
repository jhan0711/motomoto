'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertCircle,
  CircleDollarSign,
  EyeOff,
  Inbox,
  LoaderCircle,
  Pencil,
  Plus,
  Search,
} from 'lucide-react';
import { crearLugar, editarLugar, listarLugares, ponerTarifaRural } from './place-actions';
import { claseDe, ESTILO_CLASE, ETIQUETA_CLASE, formatearDistancia, formatearPesos } from './types';
import type { Place } from './types';
import { PlaceDialog } from './place-dialog';
import { FareDialog } from './fare-dialog';

type Filtro = 'todos' | 'rural' | 'sin-tarifa' | 'ocultos';

const FILTROS: { valor: Filtro; etiqueta: string }[] = [
  { valor: 'todos', etiqueta: 'Todos' },
  { valor: 'rural', etiqueta: 'Con tarifa propia' },
  { valor: 'sin-tarifa', etiqueta: 'Sin tarifa' },
  { valor: 'ocultos', etiqueta: 'Ocultos' },
];

export function PlacesList() {
  const [lugares, setLugares] = useState<Place[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [busqueda, setBusqueda] = useState('');
  const [filtro, setFiltro] = useState<Filtro>('todos');

  const [editando, setEditando] = useState<Place | null>(null);
  const [creando, setCreando] = useState(false);
  const [tarifando, setTarifando] = useState<Place | null>(null);

  const consultar = useCallback(async () => {
    const r = await listarLugares();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setLugares(r.lugares);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  /*
   * Con 63 lugares, una lista sin buscador obliga a recorrerla entera cada vez.
   * El filtrado se hace aqui y no en el servidor: son sesenta filas, ya estan
   * cargadas, y pedirlas de nuevo por cada letra seria mas lento que buscarlas.
   */
  const visibles = useMemo(() => {
    const texto = busqueda.trim().toLowerCase();
    return lugares.filter((l) => {
      if (texto !== '' && !l.name.toLowerCase().includes(texto)) return false;
      if (filtro === 'rural') return l.rural_is_active === true;
      if (filtro === 'sin-tarifa') return l.needs_fare;
      if (filtro === 'ocultos') return !l.is_active;
      return true;
    });
  }, [lugares, busqueda, filtro]);

  const sinTarifa = lugares.filter((l) => l.needs_fare).length;
  const conTarifa = lugares.filter((l) => l.rural_is_active === true).length;

  return (
    <section>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-text-primary">Lugares y tarifas</h2>
          <p className="mt-0.5 text-sm text-text-secondary">
            {cargando
              ? 'Consultando…'
              : `${lugares.length} lugares · ${conTarifa} con tarifa propia`}
          </p>
        </div>

        <button
          type="button"
          onClick={() => setCreando(true)}
          className="btn btn-primario h-10 px-3"
        >
          <Plus size={16} />
          Nuevo lugar
        </button>
      </header>

      {/*
       * EL AVISO DE D229, ARRIBA DEL TODO Y SOLO CUANDO HAY ALGO QUE ARREGLAR.
       * Un destino activo, lejos y sin precio sale en la lista del pasajero y
       * rebota al elegirlo: es un fallo que solo se ve desde aqui.
       */}
      {sinTarifa > 0 && (
        <div className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle">
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>
            {sinTarifa === 1
              ? 'Hay un lugar lejos del pueblo sin tarifa. La aplicación no deja pedir viajes hasta allí.'
              : `Hay ${sinTarifa} lugares lejos del pueblo sin tarifa. La aplicación no deja pedir viajes hasta allí.`}{' '}
            <button
              type="button"
              onClick={() => setFiltro('sin-tarifa')}
              className="underline underline-offset-2"
            >
              Verlos
            </button>
          </span>
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

      <div className="mt-4 flex flex-wrap items-center gap-2">
        <div className="relative flex-1 sm:max-w-xs">
          <Search
            size={16}
            className="absolute top-1/2 left-3 -translate-y-1/2 text-text-tertiary"
          />
          <input
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            placeholder="Buscar un lugar"
            aria-label="Buscar un lugar"
            className="h-10 w-full rounded-lg border border-border bg-surface pr-3 pl-9 text-sm text-text-primary outline-none focus:border-brand"
          />
        </div>

        <div className="flex flex-wrap gap-1">
          {FILTROS.map(({ valor, etiqueta }) => (
            <button
              key={valor}
              type="button"
              onClick={() => setFiltro(valor)}
              aria-pressed={filtro === valor}
              className={`btn h-10 px-3 ${
                filtro === valor
                  ? 'bg-surface-pressed text-text-primary'
                  : 'text-text-secondary hover:bg-surface-subtle'
              }`}
            >
              {etiqueta}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 flex flex-col gap-2">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los lugares…
          </div>
        )}

        {!cargando && visibles.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">
              {lugares.length === 0 ? 'Todavía no hay lugares' : 'Ningún lugar coincide'}
            </p>
          </div>
        )}

        {visibles.map((lugar) => {
          const clase = claseDe(lugar);
          return (
            <article
              key={lugar.place_id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-3"
            >
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="font-medium text-text-primary">{lugar.name}</h3>
                  <span className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_CLASE[clase]}`}>
                    {ETIQUETA_CLASE[clase]}
                    {clase === 'rural' ? ` · ${formatearPesos(lugar.rural_amount)}` : ''}
                  </span>
                  {!lugar.is_active && (
                    <span className="flex items-center gap-1 rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
                      <EyeOff size={12} />
                      Oculto
                    </span>
                  )}
                </div>
                <p className="mt-0.5 text-xs text-text-secondary">
                  A {formatearDistancia(lugar.distance_from_center_m)} del centro
                  {lugar.usage_count > 0 ? ` · ${lugar.usage_count} viajes` : ''}
                  {lugar.description !== null ? ` · ${lugar.description}` : ''}
                </p>
              </div>

              <div className="flex shrink-0 gap-2">
                <button
                  type="button"
                  onClick={() => setTarifando(lugar)}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  <CircleDollarSign size={15} />
                  Tarifa
                </button>
                <button
                  type="button"
                  onClick={() => setEditando(lugar)}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  <Pencil size={15} />
                  Editar
                </button>
              </div>
            </article>
          );
        })}
      </div>

      {(creando || editando !== null) && (
        <PlaceDialog
          lugar={editando}
          onCerrar={() => {
            setCreando(false);
            setEditando(null);
          }}
          onCrear={async (nombre, lng, lat, descripcion, tarifa) => {
            const r = await crearLugar(nombre, lng, lat, descripcion, tarifa);
            if (r.ok) {
              setCreando(false);
              void consultar();
            }
            return r;
          }}
          onEditar={async (nombre, descripcion, activo, orden) => {
            const r = await editarLugar(editando!.place_id, nombre, descripcion, activo, orden);
            if (r.ok) {
              setEditando(null);
              void consultar();
            }
            return r;
          }}
        />
      )}

      {tarifando !== null && (
        <FareDialog
          lugar={tarifando}
          onCerrar={() => setTarifando(null)}
          onGuardar={async (monto) => {
            const r = await ponerTarifaRural(tarifando.place_id, monto);
            if (r.ok) {
              setTarifando(null);
              void consultar();
            }
            return r;
          }}
        />
      )}
    </section>
  );
}
