'use client';

import { useCallback, useEffect, useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import { listarVehiculos } from '@/features/vehicles/vehicle-actions';
import type { Vehicle } from '@/features/vehicles/types';

interface Props {
  onCerrar: () => void;
  onCrear: (
    correo: string,
    nombre: string,
    telefono: string,
    vehicleId: string | null,
  ) => Promise<{ ok: boolean; mensaje?: string }>;
}

/**
 * Alta de un conductor.
 *
 * **No hay campo de contraseña**: la genera el sistema (D251) y se muestra
 * después, una sola vez. Tampoco hay campo de aprobación: el conductor nace
 * pendiente, porque dar de alta y autorizar a trabajar son dos decisiones
 * distintas (D245) y la segunda suele depender de unos papeles que aún no están.
 */
export function NewDriverDialog({ onCerrar, onCrear }: Props) {
  const [correo, setCorreo] = useState('');
  const [nombre, setNombre] = useState('');
  const [telefono, setTelefono] = useState('');
  const [vehiculo, setVehiculo] = useState('');
  const [libres, setLibres] = useState<Vehicle[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  const consultar = useCallback(async () => {
    const r = await listarVehiculos();
    if (!r.ok) return;
    // Solo los activos: el servidor rechaza los demás con VEHICLE_NOT_ACTIVE.
    setLibres(r.vehiculos.filter((v) => v.status === 'active'));
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setGuardando(true);
    const r = await onCrear(correo, nombre, telefono, vehiculo === '' ? null : vehiculo);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos crear la cuenta.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-nuevo-conductor"
    >
      <div className="max-h-full w-full max-w-[460px] overflow-y-auto rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-nuevo-conductor" className="font-medium text-text-primary">
          Nuevo conductor
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="nombre-cond" className="text-sm font-medium text-text-primary">
              Nombre completo
            </label>
            <input
              id="nombre-cond"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="correo-cond" className="text-sm font-medium text-text-primary">
              Correo electrónico
            </label>
            <input
              id="correo-cond"
              type="email"
              autoComplete="off"
              value={correo}
              onChange={(e) => setCorreo(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Con este correo entrará en la aplicación.</p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="telefono-cond" className="text-sm font-medium text-text-primary">
              Teléfono
            </label>
            <input
              id="telefono-cond"
              inputMode="numeric"
              value={telefono}
              onChange={(e) => setTelefono(e.target.value)}
              placeholder="3001234567"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Es el número que verá el pasajero.</p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="vehiculo-cond" className="text-sm font-medium text-text-primary">
              Motocarro
            </label>
            <select
              id="vehiculo-cond"
              value={vehiculo}
              onChange={(e) => setVehiculo(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            >
              <option value="">Se lo asigno después</option>
              {libres.map((v) => (
                <option key={v.vehicle_id} value={v.vehicle_id}>
                  {v.unit_number} · {v.plate}
                  {v.driver_count > 0 ? ` (lo comparten ${v.driver_count})` : ''}
                </option>
              ))}
            </select>
          </div>

          {/*
           * Se dice de antemano lo que va a pasar: nace pendiente y la
           * contraseña se muestra una sola vez. Las dos cosas sorprenden si se
           * descubren después.
           */}
          <div className="rounded-lg bg-surface-subtle px-3 py-2.5 text-xs text-text-secondary">
            Se creará <span className="font-medium">pendiente de aprobar</span>: no podrá trabajar
            hasta que lo apruebes. La contraseña la genera el sistema y{' '}
            <span className="font-medium">solo se muestra una vez</span>.
          </div>

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
              Crear conductor
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
