'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, Info, LoaderCircle, Moon, Plus, Sun } from 'lucide-react';
import {
  cargarTodo,
  guardarParametro,
  guardarTarifaUrbana,
  guardarTipoCarga,
} from './config-actions';
import { formatearPesos, metaDe } from './types';
import type { CargoType, Setting, UrbanFare } from './types';
import { EditableValue } from './editable-value';
import { CargoDialog } from './cargo-dialog';

export function ConfigPage() {
  const [tarifas, setTarifas] = useState<UrbanFare[]>([]);
  const [cargas, setCargas] = useState<CargoType[]>([]);
  const [parametros, setParametros] = useState<Setting[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editandoCarga, setEditandoCarga] = useState<CargoType | null>(null);
  const [creandoCarga, setCreandoCarga] = useState(false);

  const consultar = useCallback(async () => {
    const r = await cargarTodo();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setTarifas(r.tarifas);
    setCargas(r.cargas);
    setParametros(r.parametros);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  const dia = tarifas.filter((t) => !t.is_night);
  const noche = tarifas.filter((t) => t.is_night);
  const deTarifas = parametros.filter((p) => metaDe(p.key).grupo === 'tarifas');
  const deOperacion = parametros.filter((p) => metaDe(p.key).grupo === 'operacion');

  if (cargando) {
    return (
      <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
        <LoaderCircle size={18} className="animate-spin" />
        Consultando la configuración…
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-8">
      <header>
        <h2 className="text-lg font-semibold text-text-primary">Tarifas y configuración</h2>
        <p className="mt-0.5 text-sm text-text-secondary">
          Cada cambio se guarda por separado y queda registrado.
        </p>
      </header>

      {error !== null && (
        <div
          role="alert"
          className="flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* ------------------------------------------------ Rejilla urbana */}
      <section>
        <h3 className="font-medium text-text-primary">Viajes dentro del pueblo</h3>
        <p className="mt-0.5 text-sm text-text-secondary">
          {/* D222: la franja nocturna sustituye, no se suma. */}
          De noche se cobra la tarifa nocturna completa, no un recargo aparte.
        </p>

        <div className="mt-3 overflow-x-auto rounded-xl border border-border bg-surface">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-text-secondary">
                <th className="px-4 py-2.5 font-medium">Pasajeros</th>
                <th className="px-4 py-2.5 font-medium">
                  <span className="flex items-center gap-1.5">
                    <Sun size={14} />
                    De día
                  </span>
                </th>
                <th className="px-4 py-2.5 font-medium">
                  <span className="flex items-center gap-1.5">
                    <Moon size={14} />
                    De noche
                  </span>
                </th>
              </tr>
            </thead>
            <tbody>
              {dia.map((t) => {
                const suNoche = noche.find((n) => n.passenger_count === t.passenger_count);
                return (
                  <tr key={t.passenger_count} className="border-b border-border last:border-0">
                    <td className="px-4 py-2 text-text-primary">
                      {t.passenger_count} {t.passenger_count === 1 ? 'pasajero' : 'pasajeros'}
                    </td>
                    <td className="px-2 py-1.5">
                      <EditableValue
                        valor={t.amount.toString()}
                        etiquetaAccesible={`tarifa de día para ${t.passenger_count} pasajeros`}
                        onGuardar={async (v) => {
                          const r = await guardarTarifaUrbana(
                            t.passenger_count,
                            false,
                            Number.parseInt(v, 10),
                          );
                          if (r.ok) void consultar();
                          return r;
                        }}
                      />
                      <span className="ml-1 text-xs text-text-tertiary">
                        {formatearPesos(t.amount)}
                      </span>
                    </td>
                    <td className="px-2 py-1.5">
                      {suNoche !== undefined && (
                        <>
                          <EditableValue
                            valor={suNoche.amount.toString()}
                            etiquetaAccesible={`tarifa de noche para ${t.passenger_count} pasajeros`}
                            onGuardar={async (v) => {
                              const r = await guardarTarifaUrbana(
                                t.passenger_count,
                                true,
                                Number.parseInt(v, 10),
                              );
                              if (r.ok) void consultar();
                              return r;
                            }}
                          />
                          <span className="ml-1 text-xs text-text-tertiary">
                            {formatearPesos(suNoche.amount)}
                          </span>
                        </>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* ------------------------------------------------ Tipos de carga */}
      <section>
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h3 className="font-medium text-text-primary">Tipos de carga</h3>
            <p className="mt-0.5 text-sm text-text-secondary">
              {/* D225: el precio se congela en cada servicio. */}
              Cambiar un precio no afecta a los servicios ya hechos.
            </p>
          </div>
          <button
            type="button"
            onClick={() => setCreandoCarga(true)}
            className="btn btn-secundario h-9 gap-1.5 px-3"
          >
            <Plus size={15} />
            Nuevo tipo
          </button>
        </div>

        <div className="mt-3 flex flex-col gap-2">
          {cargas.map((c) => (
            <article
              key={c.cargo_type_id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-2.5"
            >
              <div>
                <p className="flex items-center gap-2 text-text-primary">
                  {c.name}
                  {!c.is_active && (
                    <span className="rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
                      Oculto
                    </span>
                  )}
                </p>
                <p className="text-xs text-text-secondary">
                  {formatearPesos(c.amount)}
                  {c.usage_count > 0 ? ` · usado en ${c.usage_count} servicios` : ''}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setEditandoCarga(c)}
                className="btn btn-secundario h-9 px-3"
              >
                Editar
              </button>
            </article>
          ))}
        </div>
      </section>

      {/* ------------------------------------------------ Parámetros */}
      {(
        [
          ['tarifas', 'Cómo se calculan las tarifas', deTarifas],
          ['operacion', 'Reglas de operación', deOperacion],
        ] as const
      ).map(([clave, titulo, lista]) => (
        <section key={clave}>
          <h3 className="font-medium text-text-primary">{titulo}</h3>
          {clave === 'operacion' && (
            <p className="mt-0.5 text-sm text-text-secondary">
              Estos valores cambian cómo se reparten y se siguen los servicios. Cámbialos con
              cuidado.
            </p>
          )}

          <div className="mt-3 flex flex-col gap-2">
            {lista.map((p) => {
              const meta = metaDe(p.key);
              return (
                <article
                  key={p.key}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-2.5"
                >
                  <div className="min-w-0">
                    <p className="text-text-primary">{meta.etiqueta}</p>
                    {meta.aviso !== undefined && (
                      <p className="mt-0.5 flex items-start gap-1.5 text-xs text-text-secondary">
                        <Info size={13} className="mt-0.5 shrink-0" />
                        {meta.aviso}
                      </p>
                    )}
                  </div>
                  <EditableValue
                    valor={p.value ?? ''}
                    sufijo={meta.unidad}
                    ancho={p.key.startsWith('fare_center') ? 'w-36' : 'w-28'}
                    etiquetaAccesible={meta.etiqueta}
                    onGuardar={async (v) => {
                      const r = await guardarParametro(p.key, v);
                      if (r.ok) void consultar();
                      return r;
                    }}
                  />
                </article>
              );
            })}
          </div>
        </section>
      ))}

      {(creandoCarga || editandoCarga !== null) && (
        <CargoDialog
          tipo={editandoCarga}
          onCerrar={() => {
            setCreandoCarga(false);
            setEditandoCarga(null);
          }}
          onGuardar={async (nombre, monto, activo, orden) => {
            const r = await guardarTipoCarga(
              editandoCarga?.cargo_type_id ?? null,
              nombre,
              monto,
              activo,
              orden,
            );
            if (r.ok) {
              setCreandoCarga(false);
              setEditandoCarga(null);
              void consultar();
            }
            return r;
          }}
        />
      )}
    </div>
  );
}
