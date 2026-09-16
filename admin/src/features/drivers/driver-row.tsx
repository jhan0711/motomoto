'use client';

import { useState } from 'react';
import {
  Ban,
  Check,
  ChevronDown,
  ChevronRight,
  CircleSlash,
  KeyRound,
  Pencil,
  Star,
  Truck,
  UserCheck,
} from 'lucide-react';
import { BlockDialog } from '@/features/shared/block-dialog';
import type { Driver } from './types';
import { ESTILO_APROBACION, ETIQUETA_APROBACION, ETIQUETA_MOTIVO_NO_DISPONIBLE } from './types';
import {
  cambiarAprobacion,
  cambiarEstadoCuenta,
  editarContacto,
  restablecerContrasena,
} from './driver-actions';
import { EditContactDialog } from './edit-contact-dialog';
import { PasswordNotice } from '@/features/shared/password-notice';
import { DocumentsPanel } from '@/features/documents/documents-panel';

interface Props {
  conductor: Driver;
  onCambio: () => void;
}

export function DriverRow({ conductor, onCambio }: Props) {
  const [trabajando, setTrabajando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editando, setEditando] = useState(false);
  // La contrasena recien generada, solo mientras el dialogo la ensena.
  const [credencial, setCredencial] = useState<string | null>(null);
  const [bloqueando, setBloqueando] = useState(false);

  /*
   * Los documentos van plegados. Cada ficha abierta es una consulta mas y una
   * lista larga de golpe: con veinte conductores en pantalla, abrirlos todos
   * llenaria la pagina de papeles que nadie pidio ver.
   */
  const [verDocumentos, setVerDocumentos] = useState(false);

  const aprobado = conductor.approval_status === 'approved';
  const bloqueada = conductor.account_status === 'blocked';

  async function ejecutar(accion: () => Promise<{ ok: boolean; mensaje?: string }>) {
    setTrabajando(true);
    setError(null);
    const r = await accion();
    setTrabajando(false);

    if (!r.ok) {
      setError(r.mensaje ?? 'No pudimos completar la operación.');
      return;
    }
    onCambio();
  }

  return (
    <article className="rounded-xl border border-border bg-surface p-4">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-medium text-text-primary">{conductor.full_name}</h3>
            <span
              className={`rounded-md px-2 py-0.5 text-xs ${ESTILO_APROBACION[conductor.approval_status]}`}
            >
              {ETIQUETA_APROBACION[conductor.approval_status]}
            </span>
            {/*
             * D270: el motivo de la ultima desconexion. Puede faltar aun
             * estando apagado -si lo apago accept_ride_offer al llenarse el
             * motorraton, o un administrador, ninguno de los dos deja motivo,
             * ver la cabecera de la migracion 20260916004026- y por eso el
             * texto cambia segun haya uno o no, en vez de dar por hecho que
             * siempre lo hay.
             *
             * El generador de tipos declara `unavailable_reason_code` como no
             * nulo -mismo defecto ya documentado del lado del conductor con
             * `distance_m`/`seconds_remaining`, el generador no ve que una
             * funcion `returns table` admite null en una columna-, asi que la
             * comprobacion de aqui abajo es real aunque el tipo diga que
             * nunca hace falta.
             */}
            <span
              className={`rounded-md px-2 py-0.5 text-xs ${
                conductor.is_available
                  ? 'bg-success-subtle text-success'
                  : 'bg-surface-subtle text-text-secondary'
              }`}
            >
              {conductor.is_available
                ? 'Disponible'
                : conductor.unavailable_reason_code === null
                  ? 'No disponible'
                  : `No disponible: ${ETIQUETA_MOTIVO_NO_DISPONIBLE[conductor.unavailable_reason_code]}${
                      conductor.unavailable_reason_code === 'otro' &&
                      conductor.unavailable_reason !== null
                        ? ` (${conductor.unavailable_reason})`
                        : ''
                    }`}
            </span>
            {bloqueada && (
              <span className="rounded-md bg-danger-subtle px-2 py-0.5 text-xs text-on-danger-subtle">
                Cuenta bloqueada
              </span>
            )}
            {/*
             * Que vaya conduciendo no es un estado suyo, es una circunstancia
             * de ahora mismo, y por eso se dice aparte y en otro tono: es lo
             * que explica por que algunos botones no se pueden pulsar.
             */}
            {conductor.has_active_ride && (
              <span className="rounded-md bg-info-subtle px-2 py-0.5 text-xs text-info">
                En servicio ahora
              </span>
            )}
          </div>

          <p className="mt-1 text-sm text-text-secondary">{conductor.phone}</p>
        </div>

        <div className="flex flex-col items-end gap-1 text-sm">
          <span className="flex items-center gap-1.5 text-text-primary">
            <Truck size={15} className="text-text-tertiary" />
            {conductor.unit_number === null
              ? 'Sin motorratón'
              : `Motorratón ${conductor.unit_number}`}
          </span>
          <span className="flex items-center gap-1.5 text-text-secondary">
            <Star size={14} className="text-text-tertiary" />
            {conductor.rating_count === 0
              ? 'Sin calificaciones'
              : `${Number(conductor.rating_average).toFixed(2)} · ${conductor.rating_count}`}
          </span>
        </div>
      </header>

      {error !== null && (
        <p
          role="alert"
          className="mt-3 rounded-lg bg-danger-subtle px-3 py-2 text-sm text-on-danger-subtle"
        >
          {error}
        </p>
      )}

      <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-3">
        {!aprobado ? (
          <button
            type="button"
            disabled={trabajando}
            onClick={() =>
              void ejecutar(() => cambiarAprobacion(conductor.driver_id, 'approved', null))
            }
            className="btn btn-primario h-9 gap-1.5 px-3"
          >
            <Check size={15} />
            Aprobar
          </button>
        ) : (
          <button
            type="button"
            /*
             * Se deshabilita cuando va conduciendo, y ademas el servidor lo
             * rechaza con DRIVER_HAS_ACTIVE_RIDE. Las dos cosas: el boton
             * apagado explica por que no se puede, y la comprobacion del
             * servidor es la que de verdad lo impide, porque el estado de esta
             * pantalla puede tener diez segundos de antiguedad.
             */
            disabled={trabajando || conductor.has_active_ride}
            title={
              conductor.has_active_ride
                ? 'Tiene un servicio en curso. Resuélvelo primero.'
                : undefined
            }
            onClick={() =>
              void ejecutar(() => cambiarAprobacion(conductor.driver_id, 'blocked', null))
            }
            className="btn btn-secundario h-9 gap-1.5 px-3"
          >
            <CircleSlash size={15} />
            Retirar aprobación
          </button>
        )}

        <button
          type="button"
          disabled={trabajando}
          onClick={() => setEditando(true)}
          className="btn btn-secundario h-9 gap-1.5 px-3"
        >
          <Pencil size={15} />
          Editar contacto
        </button>

        <button
          type="button"
          disabled={trabajando}
          onClick={async () => {
            setTrabajando(true);
            setError(null);
            const r = await restablecerContrasena(conductor.driver_id);
            setTrabajando(false);
            if (r.ok) setCredencial(r.password);
            else setError(r.mensaje);
          }}
          className="btn btn-secundario h-9 gap-1.5 px-3"
        >
          <KeyRound size={15} />
          Nueva contraseña
        </button>

        {/*
         * DESBLOQUEAR VA DIRECTO; BLOQUEAR PASA POR EL DIALOGO. Devolver a
         * alguien al trabajo no es la decision delicada, quitarselo si, y desde
         * el paso 11 **el servidor exige motivo si el conductor va con un
         * pasajero dentro**. Antes este boton mandaba siempre `null` y el
         * servidor lo rechazaba con un error que la pantalla no sabia explicar:
         * el usuario veia "no pudimos completar la operacion" y nada mas.
         */}
        <button
          type="button"
          disabled={trabajando}
          onClick={() => {
            if (bloqueada) {
              void ejecutar(() => cambiarEstadoCuenta(conductor.driver_id, 'active', null));
              return;
            }
            setBloqueando(true);
          }}
          className="btn btn-secundario h-9 gap-1.5 px-3"
        >
          {bloqueada ? <UserCheck size={15} /> : <Ban size={15} />}
          {bloqueada ? 'Desbloquear cuenta' : 'Bloquear cuenta'}
        </button>
      </div>

      <button
        type="button"
        onClick={() => setVerDocumentos((v) => !v)}
        aria-expanded={verDocumentos}
        className="btn mt-3 h-9 gap-1.5 px-2 font-normal text-text-secondary hover:bg-surface-pressed"
      >
        {verDocumentos ? <ChevronDown size={15} /> : <ChevronRight size={15} />}
        Documentos
      </button>

      {verDocumentos && (
        <div className="mt-2">
          <DocumentsPanel
            owner="driver"
            ownerId={conductor.driver_id}
            ownerNombre={conductor.full_name}
          />
        </div>
      )}

      {credencial !== null && (
        <PasswordNotice
          titulo="Contraseña nueva"
          nombre={conductor.full_name}
          password={credencial}
          recuperarDesde="esta misma ficha"
          onCerrar={() => setCredencial(null)}
        />
      )}

      {bloqueando && (
        <BlockDialog
          nombre={conductor.full_name}
          conServicioEnCurso={conductor.has_active_ride}
          avisoServicioEnCurso="Va con un pasajero dentro ahora mismo. Ese servicio lo va a terminar: lo que se corta es que tome otros. Escribe por qué lo bloqueas."
          onCerrar={() => setBloqueando(false)}
          onBloquear={async (motivo) => {
            const r = await cambiarEstadoCuenta(conductor.driver_id, 'blocked', motivo);
            if (r.ok) {
              setBloqueando(false);
              onCambio();
            }
            return r;
          }}
        />
      )}

      {editando && (
        <EditContactDialog
          nombreActual={conductor.full_name}
          telefonoActual={conductor.phone}
          onCerrar={() => setEditando(false)}
          onGuardar={async (nombre, telefono) => {
            const r = await editarContacto(conductor.driver_id, nombre, telefono);
            if (r.ok) {
              setEditando(false);
              onCambio();
            }
            return r;
          }}
        />
      )}
    </article>
  );
}
