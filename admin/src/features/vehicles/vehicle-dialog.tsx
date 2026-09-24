'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import type { Resultado } from './vehicle-actions';
import type { Vehicle, VehicleStatus } from './types';
import { ESTADOS, ETIQUETA_ESTADO } from './types';

interface Props {
  /** Nulo al dar de alta uno nuevo. */
  vehiculo: Vehicle | null;
  onCerrar: () => void;
  onGuardar: (
    numero: number,
    placa: string,
    modelo: string,
    capacidad: number,
    estado: VehicleStatus,
    notas: string,
  ) => Promise<Resultado>;
}

/**
 * Alta y edicion de un motocarro, en el mismo dialogo.
 *
 * **El estado no se puede elegir al dar de alta**, y por eso ese campo solo
 * aparece al editar: una unidad nace activa. Crearla directamente "retirada"
 * seria crear algo que no sirve para nada, y crearla "en taller" es un caso tan
 * raro que no compensa el campo de mas en el formulario del dia a dia.
 */
export function VehicleDialog({ vehiculo, onCerrar, onGuardar }: Props) {
  const editando = vehiculo !== null;

  const [numero, setNumero] = useState(vehiculo?.unit_number?.toString() ?? '');
  const [placa, setPlaca] = useState(vehiculo?.plate ?? '');
  const [modelo, setModelo] = useState(vehiculo?.model ?? '');
  const [capacidad, setCapacidad] = useState(vehiculo?.max_passengers?.toString() ?? '3');
  const [estado, setEstado] = useState<VehicleStatus>(vehiculo?.status ?? 'active');
  const [notas, setNotas] = useState(vehiculo?.notes ?? '');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    // Se comprueba aqui para dar el mensaje al instante, pero el servidor lo
    // vuelve a comprobar: esta pantalla no es la que protege el dato.
    const numeroEntero = Number.parseInt(numero, 10);
    if (Number.isNaN(numeroEntero)) {
      setError('El número de motocarro debe ser un número.');
      return;
    }

    setGuardando(true);
    const r = await onGuardar(
      numeroEntero,
      placa,
      modelo,
      Number.parseInt(capacidad, 10),
      estado,
      notas,
    );
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos guardar los cambios.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-vehiculo"
    >
      <div className="max-h-full w-full max-w-[460px] overflow-y-auto rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-vehiculo" className="font-medium text-text-primary">
          {editando ? `Editar motocarro ${vehiculo.unit_number}` : 'Nuevo motocarro'}
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="numero" className="text-sm font-medium text-text-primary">
                Número
              </label>
              <input
                id="numero"
                inputMode="numeric"
                value={numero}
                onChange={(e) => setNumero(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
              {/* D55: es como la gente identifica las unidades a distancia. */}
              <p className="text-xs text-text-secondary">El que va pintado en el motocarro.</p>
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="placa" className="text-sm font-medium text-text-primary">
                Placa
              </label>
              <input
                id="placa"
                value={placa}
                onChange={(e) => setPlaca(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary uppercase outline-none focus:border-brand"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="modelo" className="text-sm font-medium text-text-primary">
                Modelo
              </label>
              <input
                id="modelo"
                value={modelo}
                onChange={(e) => setModelo(e.target.value)}
                placeholder="Opcional"
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label htmlFor="capacidad" className="text-sm font-medium text-text-primary">
                Pasajeros
              </label>
              <select
                id="capacidad"
                value={capacidad}
                onChange={(e) => setCapacidad(e.target.value)}
                className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
              >
                {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
              </select>
              <p className="text-xs text-text-secondary">Sin contar al conductor.</p>
            </div>
          </div>

          {editando && (
            <>
              <div className="flex flex-col gap-1.5">
                <label htmlFor="estado" className="text-sm font-medium text-text-primary">
                  Estado
                </label>
                <select
                  id="estado"
                  value={estado}
                  onChange={(e) => setEstado(e.target.value as VehicleStatus)}
                  className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
                >
                  {ESTADOS.map((s) => (
                    <option key={s} value={s}>
                      {ETIQUETA_ESTADO[s]}
                    </option>
                  ))}
                </select>
                {vehiculo.has_active_ride && estado !== 'active' && (
                  <p className="text-xs text-on-danger-subtle">
                    Este motocarro tiene un servicio en curso. El servidor no permitirá el cambio
                    hasta que se resuelva.
                  </p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <label htmlFor="notas" className="text-sm font-medium text-text-primary">
                  Notas
                </label>
                <textarea
                  id="notas"
                  rows={2}
                  value={notas}
                  onChange={(e) => setNotas(e.target.value)}
                  placeholder="Opcional"
                  className="rounded-lg border border-border bg-surface px-3 py-2 text-text-primary outline-none focus:border-brand"
                />
              </div>
            </>
          )}

          {error !== null && (
            <p
              role="alert"
              className="rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
            >
              {error}
            </p>
          )}

          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onCerrar}
              disabled={guardando}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button type="submit" disabled={guardando} className="btn btn-primario h-10 px-4">
              {guardando && <LoaderCircle size={15} className="animate-spin" />}
              {editando ? 'Guardar' : 'Crear'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
