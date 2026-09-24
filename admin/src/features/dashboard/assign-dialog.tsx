'use client';

import { useCallback, useEffect, useState } from 'react';
import { Ban, LoaderCircle, Phone, Signal, Star, X } from 'lucide-react';
import { asignarConductor, listarAsignables } from './assign-actions';
import { formatearAntiguedadPosicion } from './format';
import type { ActiveService, AssignableDriver } from './types';

interface Props {
  servicio: ActiveService;
  onCerrar: () => void;
  onAsignado: () => void;
}

function formatearDistancia(metros: number | null): string {
  if (metros === null) return 'Sin posición conocida';
  if (metros < 1000) return `a ${metros} m`;
  return `a ${(metros / 1000).toFixed(1).replace('.', ',')} km`;
}

/**
 * La asignacion manual, D7: la empresa le pone conductor a una solicitud que
 * nadie ha tomado.
 *
 * POR QUE LA LISTA ENSENA TAMBIEN A LOS QUE NO SE PUEDEN ASIGNAR. Esconderlos
 * dejaria al despachador mirando una lista corta sin saber por que: "¿donde
 * esta Juan, que lo acabo de ver?". Salen todos; los que no se pueden salen
 * apagados y **con el motivo escrito** -ocupado, sin aprobar, sin turno, no le
 * caben los pasajeros-. Quien decide si se puede es el servidor, en
 * `can_assign`; esta pantalla solo lo pinta.
 *
 * EL ORDEN LO DA EL SERVIDOR y no se reordena aqui: los asignables primero y,
 * entre ellos, el mas cercano arriba. Reordenar en la pantalla haria que dos
 * despachadores mirando lo mismo vieran cosas distintas.
 */
export function AssignDialog({ servicio, onCerrar, onAsignado }: Props) {
  const [conductores, setConductores] = useState<AssignableDriver[]>([]);
  const [cargando, setCargando] = useState(true);

  /*
   * DOS ERRORES SEPARADOS, Y NO ES DE MAS. Con uno solo, el aviso de la
   * asignacion fallida **se borraba solo**: al fallar se refresca la lista, y el
   * refresco que sale bien limpiaba el error. El usuario lo vio el 2026-09-01
   * como un mensaje que aparecia y desaparecia sin darle tiempo a leerlo. Son
   * dos cosas distintas -no poder consultar y no poder asignar- y ninguna debe
   * tapar a la otra.
   */
  const [errorLista, setErrorLista] = useState<string | null>(null);
  const [errorAccion, setErrorAccion] = useState<string | null>(null);
  const [elegido, setElegido] = useState<string | null>(null);
  const [motivo, setMotivo] = useState('');
  const [asignando, setAsignando] = useState(false);

  const consultar = useCallback(async () => {
    const r = await listarAsignables(servicio.request_id);
    setCargando(false);
    if (!r.ok) {
      setErrorLista(r.mensaje);
      return;
    }
    setConductores(r.conductores);
    setErrorLista(null);
  }, [servicio.request_id]);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  async function confirmar() {
    if (elegido === null) return;
    setErrorAccion(null);
    setAsignando(true);
    const r = await asignarConductor(servicio.request_id, elegido, motivo);
    setAsignando(false);

    if (!r.ok) {
      /*
       * NO SE CIERRA EL DIALOGO NI SE VACIA LO ESCRITO. El fallo mas probable
       * aqui es que el conductor dejo de estar libre entre que se abrio la
       * lista y se pulso el boton, y en ese caso lo que quiere el despachador
       * es elegir otro sin volver a empezar. Se refresca la lista para que el
       * motivo real quede a la vista.
       */
      setErrorAccion(r.mensaje);
      setElegido(null);
      void consultar();
      return;
    }
    onAsignado();
  }

  const puedeAlguno = conductores.some((c) => c.can_assign);

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-asignar"
    >
      <div className="my-8 w-full max-w-[620px] rounded-xl border border-border bg-surface">
        <header className="flex items-start justify-between gap-3 border-b border-border p-5">
          <div>
            <h3 id="titulo-asignar" className="font-medium text-text-primary">
              Asignar un motocarro
            </h3>
            <p className="mt-1 text-sm text-text-secondary">
              {servicio.origin_label}
              <span className="text-text-tertiary"> → </span>
              {servicio.destination_label}
            </p>
          </div>
          <button
            type="button"
            onClick={onCerrar}
            className="btn btn-secundario size-8 shrink-0 p-0"
            aria-label="Cerrar"
          >
            <X size={16} />
          </button>
        </header>

        <div className="p-5">
          {/*
           * El de la asignacion va primero: es la respuesta a lo ultimo que
           * hizo quien esta mirando.
           */}
          {errorAccion !== null && (
            <p
              role="alert"
              className="mb-4 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {errorAccion}
            </p>
          )}

          {errorLista !== null && (
            <p
              role="alert"
              className="mb-4 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {errorLista}
            </p>
          )}

          {cargando ? (
            <p className="flex items-center gap-2 py-6 text-sm text-text-secondary">
              <LoaderCircle size={16} className="animate-spin" />
              Consultando conductores…
            </p>
          ) : conductores.length === 0 ? (
            <p className="py-6 text-sm text-text-secondary">
              No hay ningún conductor registrado para mostrar.
            </p>
          ) : (
            <>
              {!puedeAlguno && (
                <p className="mb-4 rounded-lg bg-warning-subtle px-3 py-2 text-sm text-on-warning">
                  Ahora mismo ninguno se puede asignar. Al lado de cada uno dice por qué.
                </p>
              )}

              <ul className="flex flex-col gap-2">
                {conductores.map((c) => {
                  const seleccionado = elegido === c.driver_id;
                  return (
                    <li key={c.driver_id}>
                      <button
                        type="button"
                        disabled={!c.can_assign}
                        onClick={() => setElegido(c.driver_id)}
                        aria-pressed={seleccionado}
                        className={`btn w-full flex-col items-stretch gap-1 border p-3 text-left ${
                          seleccionado
                            ? 'border-(--color-brand) bg-surface-subtle'
                            : 'border-border bg-surface hover:border-border-strong hover:bg-surface-pressed'
                        } ${c.can_assign ? '' : 'opacity-60'}`}
                      >
                        <span className="flex flex-wrap items-center justify-between gap-2">
                          <span className="font-medium text-text-primary">
                            {c.full_name}
                            {c.unit_number !== null && (
                              <span className="font-normal text-text-secondary">
                                {' '}
                                · Motocarro {c.unit_number}
                              </span>
                            )}
                          </span>
                          <span className="flex items-center gap-1 text-xs font-normal text-text-secondary">
                            <Phone size={12} />
                            {c.phone}
                          </span>
                        </span>

                        <span className="flex flex-wrap items-center gap-3 text-xs font-normal text-text-secondary">
                          <span>{formatearDistancia(c.distance_m)}</span>
                          <span className="flex items-center gap-1">
                            <Signal size={12} className="text-text-tertiary" />
                            {formatearAntiguedadPosicion(c.location_age_seconds)}
                          </span>
                          {c.rating_average !== null && (
                            <span className="flex items-center gap-1">
                              <Star size={12} className="text-text-tertiary" />
                              {c.rating_average.toFixed(1).replace('.', ',')}
                            </span>
                          )}
                          {c.max_passengers !== null && <span>Caben {c.max_passengers}</span>}
                        </span>

                        {/*
                         * El motivo del bloqueo lo escribe el servidor y se
                         * ensena tal cual: si manana se anade una regla nueva,
                         * su explicacion llega sola.
                         */}
                        {!c.can_assign && c.blocked_reason !== null && (
                          <span className="flex items-center gap-1.5 text-xs font-normal text-on-danger-subtle">
                            <Ban size={12} />
                            {c.blocked_reason}
                          </span>
                        )}
                      </button>
                    </li>
                  );
                })}
              </ul>

              {/*
               * EL MOTIVO NO ES OBLIGATORIO PERO SE PIDE. Queda en la auditoria
               * junto a quien asigno y a quien: dentro de un mes, "nadie la tomo
               * y el pasajero llevaba veinte minutos" es la diferencia entre una
               * decision explicada y uno preguntandose por que.
               */}
              <label className="mt-5 block">
                <span className="text-sm text-text-secondary">
                  Por qué se asigna a mano (queda registrado)
                </span>
                <input
                  type="text"
                  value={motivo}
                  onChange={(e) => setMotivo(e.target.value)}
                  maxLength={200}
                  placeholder="Nadie la tomó y el pasajero espera"
                  className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-(--color-brand)"
                />
              </label>
            </>
          )}
        </div>

        <footer className="flex justify-end gap-2 border-t border-border p-5">
          <button type="button" onClick={onCerrar} className="btn btn-secundario px-4 py-2">
            Cancelar
          </button>
          <button
            type="button"
            disabled={elegido === null || asignando}
            onClick={() => void confirmar()}
            className="btn btn-primario px-4 py-2"
          >
            {asignando && <LoaderCircle size={16} className="animate-spin" />}
            Asignar
          </button>
        </footer>
      </div>
    </div>
  );
}
