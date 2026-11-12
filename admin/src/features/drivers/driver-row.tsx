'use client';

import { useState } from 'react';
import {
  Archive,
  ArchiveRestore,
  Ban,
  Check,
  ChevronDown,
  ChevronRight,
  CircleSlash,
  KeyRound,
  MailX,
  Pencil,
  Star,
  Trash2,
  Truck,
  UserCheck,
  Wallet,
} from 'lucide-react';
import { BlockDialog } from '@/features/shared/block-dialog';
import { RemoveDialog } from '@/features/shared/remove-dialog';
import type { Driver } from './types';
import { ESTILO_APROBACION, ETIQUETA_APROBACION } from './types';
import {
  archivarConductor,
  cambiarAprobacion,
  cambiarEstadoCuenta,
  editarContacto,
  eliminarConductor,
  liberarCorreoConductor,
  restablecerContrasena,
  restaurarConductor,
  type SaldoConductor,
} from './driver-actions';
import { BalanceDialog } from './balance-dialog';
import { formatearPesos } from '@/features/config/types';
import { EditContactDialog } from './edit-contact-dialog';
import { PasswordNotice } from '@/features/shared/password-notice';
import { DocumentsPanel } from '@/features/documents/documents-panel';

interface Props {
  conductor: Driver;
  /** Nulo mientras no llega, o si la consulta de saldos falló. */
  saldo: SaldoConductor | null;
  /** Decide si el dialogo de saldo trae el formulario de ajuste (D278). */
  esSuperAdmin: boolean;
  /** Se esta viendo la lista de archivados: solo se puede restaurar (D306). */
  archivado: boolean;
  onCambio: () => void;
}

export function DriverRow({ conductor, saldo, esSuperAdmin, archivado, onCambio }: Props) {
  const [verSaldo, setVerSaldo] = useState(false);
  const [trabajando, setTrabajando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editando, setEditando] = useState(false);
  // La contrasena recien generada, solo mientras el dialogo la ensena.
  const [credencial, setCredencial] = useState<string | null>(null);
  const [bloqueando, setBloqueando] = useState(false);
  // D306. Que se esta confirmando: archivar (reversible) o eliminar (definitivo).
  const [quitando, setQuitando] = useState<'archivar' | 'eliminar' | 'liberar' | null>(null);

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
            <span
              className={`rounded-md px-2 py-0.5 text-xs ${
                conductor.is_available
                  ? 'bg-success-subtle text-success'
                  : 'bg-surface-subtle text-text-secondary'
              }`}
            >
              {conductor.is_available ? 'Disponible' : 'No disponible'}
            </span>
            {bloqueada && (
              <span className="rounded-md bg-danger-subtle px-2 py-0.5 text-xs text-on-danger-subtle">
                Cuenta bloqueada
              </span>
            )}
            {archivado && (
              <span className="rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
                Archivado
              </span>
            )}
            {archivado && conductor.email_released && (
              <span className="rounded-md bg-surface-subtle px-2 py-0.5 text-xs text-text-secondary">
                Correo liberado
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
              ? 'Sin motocarro'
              : `Motocarro ${conductor.unit_number}`}
          </span>
          {saldo !== null && (
            <span
              className={`flex items-center gap-1.5 ${
                saldo.can_work ? 'text-text-secondary' : 'text-on-danger-subtle'
              }`}
              title={saldo.can_work ? undefined : 'El saldo no alcanza para recibir servicios.'}
            >
              <Wallet size={14} className="text-text-tertiary" />
              Saldo {saldo.balance < 0 ? '-' : ''}
              {formatearPesos(Math.abs(saldo.balance))}
            </span>
          )}
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

      {archivado ? (
        <div className="mt-4 flex flex-col gap-2 border-t border-border pt-3">
          {conductor.email_released ? (
            <p className="text-sm text-text-secondary">
              Su correo ya quedó libre: puede registrarse de nuevo como pasajero con el mismo
              correo. Esta ficha ya no se puede restaurar.
            </p>
          ) : (
            <>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={trabajando}
                  onClick={() => void ejecutar(() => restaurarConductor(conductor.driver_id))}
                  className="btn btn-primario h-9 gap-1.5 px-3"
                >
                  <ArchiveRestore size={15} />
                  Restaurar
                </button>
                <button
                  type="button"
                  disabled={trabajando}
                  onClick={() => setQuitando('liberar')}
                  className="btn btn-secundario h-9 gap-1.5 px-3"
                >
                  <MailX size={15} />
                  Liberar su correo
                </button>
              </div>
              <p className="text-xs text-text-secondary">
                Al restaurarlo vuelve a la lista, pero su cuenta sigue bloqueada hasta que la
                desbloquees. «Liberar su correo» es para quien se va de la empresa y quiere usar la
                app como pasajero: ya no se podrá restaurar.
              </p>
            </>
          )}
        </div>
      ) : (
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
            onClick={() => setVerSaldo(true)}
            className="btn btn-secundario h-9 gap-1.5 px-3"
          >
            <Wallet size={15} />
            Saldo
          </button>

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

          {/*
           * D306. UN SOLO BOTON, Y LA FICHA DECIDE CUAL. Con historial (viajes,
           * saldo, calificaciones) solo se puede archivar: la base de datos no deja
           * borrarlo, y aunque dejara, se perderia el registro. Sin historial se
           * puede eliminar de verdad. El servidor lo vuelve a comprobar al ejecutar.
           */}
          <button
            type="button"
            disabled={trabajando || conductor.has_active_ride}
            title={
              conductor.has_active_ride
                ? 'Tiene un servicio en curso. Resuélvelo primero.'
                : undefined
            }
            onClick={() => setQuitando(conductor.has_history ? 'archivar' : 'eliminar')}
            className="btn btn-secundario h-9 gap-1.5 px-3"
          >
            {conductor.has_history ? <Archive size={15} /> : <Trash2 size={15} />}
            {conductor.has_history ? 'Archivar' : 'Eliminar'}
          </button>
        </div>
      )}

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

      {quitando === 'archivar' && (
        <RemoveDialog
          titulo={`Archivar a ${conductor.full_name}`}
          descripcion="Se oculta de la lista, su cuenta queda bloqueada y se le quita el motocarro. Su historial se conserva y puedes restaurarlo desde «Ver archivados»."
          aviso={
            conductor.is_available ? 'Ahora figura como disponible: se desconectará.' : undefined
          }
          etiquetaConfirmar="Archivar"
          peligroso={false}
          opcion={{
            etiqueta: 'Liberar su correo para que pueda registrarse como pasajero',
            ayuda:
              'Úsalo si se va de la empresa. Podrá crear una cuenta nueva con el mismo correo (con contraseña nueva) y no verá su historial de conductor. Después ya no se podrá restaurar esta ficha.',
          }}
          onCerrar={() => setQuitando(null)}
          onConfirmar={async (liberarCorreo) => {
            const r = await archivarConductor(conductor.driver_id, liberarCorreo);
            if (r.ok) {
              setQuitando(null);
              onCambio();
            }
            return r;
          }}
        />
      )}

      {quitando === 'liberar' && (
        <RemoveDialog
          titulo={`Liberar el correo de ${conductor.full_name}`}
          descripcion="Su correo queda libre para que esa persona (u otra) se registre de nuevo, por ejemplo como pasajero. Su cuenta de conductor sigue archivada y su historial se conserva, pero esta ficha ya no se podrá restaurar."
          escribirParaConfirmar={conductor.full_name}
          queEscribir="su nombre"
          etiquetaConfirmar="Liberar su correo"
          peligroso
          onCerrar={() => setQuitando(null)}
          onConfirmar={async () => {
            const r = await liberarCorreoConductor(conductor.driver_id);
            if (r.ok) {
              setQuitando(null);
              onCambio();
            }
            return r;
          }}
        />
      )}

      {quitando === 'eliminar' && (
        <RemoveDialog
          titulo={`Eliminar a ${conductor.full_name}`}
          descripcion="No tiene viajes, saldo ni calificaciones. Se borran su cuenta y sus documentos para siempre. Esto no se puede deshacer."
          escribirParaConfirmar={conductor.full_name}
          queEscribir="su nombre"
          etiquetaConfirmar="Eliminar para siempre"
          peligroso
          onCerrar={() => setQuitando(null)}
          onConfirmar={async () => {
            const r = await eliminarConductor(conductor.driver_id);
            if (r.ok) {
              setQuitando(null);
              onCambio();
            }
            return r;
          }}
        />
      )}

      {verSaldo && (
        <BalanceDialog
          nombre={conductor.full_name}
          driverId={conductor.driver_id}
          saldoActual={saldo?.balance ?? 0}
          esSuperAdmin={esSuperAdmin}
          onCerrar={() => setVerSaldo(false)}
          onAjustado={onCambio}
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
