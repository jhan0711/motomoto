'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  AlertCircle,
  ChevronDown,
  ChevronRight,
  Inbox,
  LoaderCircle,
  Pencil,
  Plus,
  User,
  UserMinus,
} from 'lucide-react';
import {
  asignarVehiculo,
  crearVehiculo,
  editarVehiculo,
  listarVehiculos,
  quitarVehiculo,
} from './vehicle-actions';
import { ESTILO_ESTADO, ETIQUETA_ESTADO, leerConductores } from './types';
import type { Vehicle } from './types';
import { VehicleDialog } from './vehicle-dialog';
import { AssignDialog } from './assign-dialog';
import { DocumentsPanel } from '@/features/documents/documents-panel';

export function VehiclesList() {
  const [vehiculos, setVehiculos] = useState<Vehicle[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [editando, setEditando] = useState<Vehicle | null>(null);
  const [creando, setCreando] = useState(false);
  const [asignando, setAsignando] = useState<Vehicle | null>(null);
  const [trabajando, setTrabajando] = useState(false);
  // Plegados, por lo mismo que en la ficha del conductor.
  const [conDocumentos, setConDocumentos] = useState<string | null>(null);

  const consultar = useCallback(async () => {
    const r = await listarVehiculos();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setVehiculos(r.vehiculos);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  const activos = vehiculos.filter((v) => v.status === 'active').length;
  const sinConductor = vehiculos.filter(
    (v) => v.status === 'active' && v.driver_count === 0,
  ).length;

  return (
    <section>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-text-primary">Motocarros</h2>
          <p className="mt-0.5 text-sm text-text-secondary">
            {cargando
              ? 'Consultando…'
              : `${vehiculos.length} en total · ${activos} activos${
                  sinConductor === 0 ? '' : ` · ${sinConductor} sin conductor`
                }`}
          </p>
        </div>

        <button
          type="button"
          onClick={() => setCreando(true)}
          className="btn btn-primario h-10 px-3"
        >
          <Plus size={16} />
          Nuevo motocarro
        </button>
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

      <div className="mt-4 flex flex-col gap-3">
        {cargando && (
          <div className="flex items-center justify-center gap-2 rounded-xl border border-border bg-surface py-12 text-text-secondary">
            <LoaderCircle size={18} className="animate-spin" />
            Consultando los motocarros…
          </div>
        )}

        {!cargando && vehiculos.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-xl border border-border bg-surface py-12 text-center">
            <Inbox size={28} className="text-text-tertiary" />
            <p className="font-medium text-text-primary">Todavía no hay motocarros</p>
            <p className="max-w-sm text-sm text-text-secondary">
              Da de alta el primero con el botón de arriba.
            </p>
          </div>
        )}

        {vehiculos.map((vehiculo) => (
          <article
            key={vehiculo.vehicle_id}
            className="rounded-xl border border-border bg-surface p-4"
          >
            <header className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  {/* El numero, destacado: es como se identifica a distancia (D55). */}
                  <h3 className="text-lg font-semibold text-text-primary">
                    {vehiculo.unit_number}
                  </h3>
                  <span className="text-sm text-text-secondary">{vehiculo.plate}</span>
                  <span
                    className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_ESTADO[vehiculo.status]}`}
                  >
                    {ETIQUETA_ESTADO[vehiculo.status]}
                  </span>
                  {vehiculo.has_active_ride && (
                    <span className="rounded-md bg-info-subtle px-2 py-0.5 text-xs text-info">
                      En servicio ahora
                    </span>
                  )}
                </div>

                <p className="mt-1 text-sm text-text-secondary">
                  {vehiculo.model ?? 'Sin modelo'} · {vehiculo.max_passengers} pasajeros
                </p>
                {vehiculo.notes !== null && (
                  <p className="mt-1 text-sm text-text-tertiary">{vehiculo.notes}</p>
                )}
              </div>

              {/*
               * DOBLE TURNO (D246). Una unidad puede tener varios conductores, y
               * aqui se dicen las dos cosas por separado porque responden a
               * preguntas distintas: quienes la comparten -que es plantilla- y
               * quien la lleva ahora mismo -que es operacion-.
               */}
              <div className="text-right text-sm">
                <p className="flex items-center justify-end gap-1.5 text-text-primary">
                  <User size={15} className="shrink-0 text-text-tertiary" />
                  {vehiculo.driver_count === 0 ? 'Sin conductores' : vehiculo.drivers_label}
                </p>

                {vehiculo.driver_count > 1 && (
                  <p className="mt-0.5 text-xs text-text-secondary">
                    {vehiculo.driver_count} conductores por turnos
                  </p>
                )}

                {vehiculo.driver_count > 0 && (
                  <p className="mt-1 text-xs">
                    {vehiculo.active_driver_name === null ? (
                      <span className="text-text-tertiary">Nadie conectado</span>
                    ) : (
                      <span className="text-success">
                        Al volante: {vehiculo.active_driver_name}
                      </span>
                    )}
                  </p>
                )}
              </div>
            </header>

            <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-3">
              <button
                type="button"
                disabled={trabajando}
                onClick={() => setEditando(vehiculo)}
                className="btn btn-secundario h-9 gap-1.5 px-3"
              >
                <Pencil size={15} />
                Editar
              </button>

              {/*
               * Con el doble turno (D246) ya no hay "el conductor" de la unidad,
               * asi que "Asignar" pasa a ser "Anadir al turno" en cuanto hay
               * uno. Mismo criterio que "Agregar otra carga" en la pantalla del
               * pasajero: el boton dice lo que va a hacer ahora, no lo que hizo
               * la primera vez.
               */}
              <button
                type="button"
                disabled={trabajando || vehiculo.status !== 'active'}
                title={
                  vehiculo.status !== 'active'
                    ? 'Solo se pueden asignar motocarros activos.'
                    : undefined
                }
                onClick={() => setAsignando(vehiculo)}
                className="btn btn-secundario h-9 gap-1.5 px-3"
              >
                <User size={15} />
                {vehiculo.driver_count === 0 ? 'Asignar conductor' : 'Añadir al turno'}
              </button>

              {/*
               * Un boton de quitar POR CADA conductor, en vez de uno solo: con
               * varios compartiendo unidad, "Quitar conductor" a secas no diria
               * a cual. Cada uno lleva su nombre, que es lo unico que evita
               * quitar al equivocado.
               */}
              {leerConductores(vehiculo).map((conductor) => (
                <button
                  key={conductor.id}
                  type="button"
                  disabled={trabajando || vehiculo.has_active_ride}
                  title={
                    vehiculo.has_active_ride
                      ? 'Hay un servicio en curso con esta unidad. Resuélvelo primero.'
                      : undefined
                  }
                  onClick={async () => {
                    setTrabajando(true);
                    const r = await quitarVehiculo(conductor.id);
                    setTrabajando(false);
                    if (r.ok) void consultar();
                    else setError(r.mensaje ?? 'No pudimos quitar el motocarro.');
                  }}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  <UserMinus size={15} />
                  Quitar a {conductor.name.split(' ')[0]}
                </button>
              ))}
            </div>

            <button
              type="button"
              onClick={() =>
                setConDocumentos((actual) =>
                  actual === vehiculo.vehicle_id ? null : vehiculo.vehicle_id,
                )
              }
              aria-expanded={conDocumentos === vehiculo.vehicle_id}
              className="btn mt-3 h-9 gap-1.5 px-2 font-normal text-text-secondary hover:bg-surface-pressed"
            >
              {conDocumentos === vehiculo.vehicle_id ? (
                <ChevronDown size={15} />
              ) : (
                <ChevronRight size={15} />
              )}
              Documentos
            </button>

            {conDocumentos === vehiculo.vehicle_id && (
              <div className="mt-2">
                <DocumentsPanel
                  owner="vehicle"
                  ownerId={vehiculo.vehicle_id}
                  ownerNombre={`Motocarro ${vehiculo.unit_number} · ${vehiculo.plate}`}
                />
              </div>
            )}
          </article>
        ))}
      </div>

      {creando && (
        <VehicleDialog
          vehiculo={null}
          onCerrar={() => setCreando(false)}
          onGuardar={async (numero, placa, modelo, capacidad) => {
            const r = await crearVehiculo(numero, placa, modelo, capacidad);
            if (r.ok) {
              setCreando(false);
              void consultar();
            }
            return r;
          }}
        />
      )}

      {editando !== null && (
        <VehicleDialog
          vehiculo={editando}
          onCerrar={() => setEditando(null)}
          onGuardar={async (numero, placa, modelo, capacidad, estado, notas) => {
            const r = await editarVehiculo(
              editando.vehicle_id,
              numero,
              placa,
              modelo,
              capacidad,
              estado,
              notas,
            );
            if (r.ok) {
              setEditando(null);
              void consultar();
            }
            return r;
          }}
        />
      )}

      {asignando !== null && (
        <AssignDialog
          vehiculo={asignando}
          onCerrar={() => setAsignando(null)}
          onAsignar={async (driverId) => {
            const r = await asignarVehiculo(driverId, asignando.vehicle_id);
            if (r.ok) {
              setAsignando(null);
              void consultar();
            }
            return r;
          }}
        />
      )}
    </section>
  );
}
