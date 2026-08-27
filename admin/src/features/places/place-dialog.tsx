'use client';

import { useState } from 'react';
import { LoaderCircle } from 'lucide-react';
import type { Resultado } from './place-actions';
import type { Place } from './types';

interface Props {
  /** Nulo al crear uno nuevo. */
  lugar: Place | null;
  onCerrar: () => void;
  onCrear: (
    nombre: string,
    lng: number,
    lat: number,
    descripcion: string,
    tarifa: number | null,
  ) => Promise<Resultado>;
  onEditar: (
    nombre: string,
    descripcion: string,
    activo: boolean,
    orden: number,
  ) => Promise<Resultado>;
}

export function PlaceDialog({ lugar, onCerrar, onCrear, onEditar }: Props) {
  const editando = lugar !== null;

  const [nombre, setNombre] = useState(lugar?.name ?? '');
  const [descripcion, setDescripcion] = useState(lugar?.description ?? '');
  const [lng, setLng] = useState(lugar?.lng?.toString() ?? '');
  const [lat, setLat] = useState(lugar?.lat?.toString() ?? '');
  const [activo, setActivo] = useState(lugar?.is_active ?? true);
  const [orden, setOrden] = useState(lugar?.sort_order?.toString() ?? '0');
  const [tarifa, setTarifa] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (editando) {
      setGuardando(true);
      const r = await onEditar(nombre, descripcion, activo, Number.parseInt(orden, 10) || 0);
      setGuardando(false);
      if (!r.ok) setError(r.mensaje ?? 'No pudimos guardar los cambios.');
      return;
    }

    const nLng = Number.parseFloat(lng);
    const nLat = Number.parseFloat(lat);
    if (Number.isNaN(nLng) || Number.isNaN(nLat)) {
      setError('La longitud y la latitud tienen que ser números, con punto decimal.');
      return;
    }

    const nTarifa = tarifa.trim() === '' ? null : Number.parseInt(tarifa, 10);
    if (nTarifa !== null && Number.isNaN(nTarifa)) {
      setError('La tarifa tiene que ser un número en pesos, sin puntos.');
      return;
    }

    setGuardando(true);
    const r = await onCrear(nombre, nLng, nLat, descripcion, nTarifa);
    setGuardando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos crear el lugar.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-lugar"
    >
      <div className="max-h-full w-full max-w-[460px] overflow-y-auto rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-lugar" className="font-medium text-text-primary">
          {editando ? `Editar ${lugar.name}` : 'Nuevo lugar'}
        </h3>

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="nombre" className="text-sm font-medium text-text-primary">
              Nombre
            </label>
            <input
              id="nombre"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Como lo verá el pasajero en su lista.</p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label htmlFor="descripcion" className="text-sm font-medium text-text-primary">
              Descripción
            </label>
            <input
              id="descripcion"
              value={descripcion}
              onChange={(e) => setDescripcion(e.target.value)}
              placeholder="Opcional"
              className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
            />
          </div>

          {!editando ? (
            <>
              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1.5">
                  <label htmlFor="lng" className="text-sm font-medium text-text-primary">
                    Longitud
                  </label>
                  <input
                    id="lng"
                    value={lng}
                    onChange={(e) => setLng(e.target.value)}
                    placeholder="-75.074987"
                    className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
                  />
                </div>
                <div className="flex flex-col gap-1.5">
                  <label htmlFor="lat" className="text-sm font-medium text-text-primary">
                    Latitud
                  </label>
                  <input
                    id="lat"
                    value={lat}
                    onChange={(e) => setLat(e.target.value)}
                    placeholder="6.907392"
                    className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
                  />
                </div>
              </div>

              <div className="flex flex-col gap-1.5">
                <label htmlFor="tarifa" className="text-sm font-medium text-text-primary">
                  Tarifa propia
                </label>
                <input
                  id="tarifa"
                  inputMode="numeric"
                  value={tarifa}
                  onChange={(e) => setTarifa(e.target.value)}
                  placeholder="Déjalo vacío si cobra tarifa urbana"
                  className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
                />
                {/*
                 * D229. El servidor lo exige si el lugar cae fuera del radio, y
                 * el mensaje que devuelve trae la distancia. Aquí se avisa antes
                 * de intentarlo, pero quien decide es el servidor: esta pantalla
                 * no sabe dónde cayó la coordenada.
                 */}
                <p className="text-xs text-text-secondary">
                  Si el lugar queda lejos del pueblo, la tarifa es obligatoria: sin ella la
                  aplicación no dejará pedir viajes hasta allí.
                </p>
              </div>
            </>
          ) : (
            <>
              {/*
               * La coordenada no se edita, y se dice por qué: moverla cambia la
               * distancia al centro, y con ella si el lugar necesita tarifa
               * (D229) y a qué destino se pega un punto suelto (D230).
               */}
              <div className="rounded-lg bg-surface-subtle px-3 py-2 text-xs text-text-secondary">
                La ubicación no se puede cambiar: mover un lugar cambia lo que cuesta llegar a él y
                a qué destino se acercan los puntos del mapa. Si está mal situado, desactívalo y
                crea uno nuevo.
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col gap-1.5">
                  <label htmlFor="orden" className="text-sm font-medium text-text-primary">
                    Orden en la lista
                  </label>
                  <input
                    id="orden"
                    inputMode="numeric"
                    value={orden}
                    onChange={(e) => setOrden(e.target.value)}
                    className="h-11 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
                  />
                </div>

                <div className="flex flex-col gap-1.5">
                  <span className="text-sm font-medium text-text-primary">Visible</span>
                  <label className="flex h-11 cursor-pointer items-center gap-2 text-sm text-text-primary">
                    <input
                      type="checkbox"
                      checked={activo}
                      onChange={(e) => setActivo(e.target.checked)}
                      className="size-4 accent-(--color-brand)"
                    />
                    Aparece en la aplicación
                  </label>
                </div>
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
