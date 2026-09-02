'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  AlertCircle,
  Ban,
  Inbox,
  KeyRound,
  LoaderCircle,
  Plus,
  ShieldCheck,
  UserCheck,
} from 'lucide-react';
import {
  cambiarEstadoAdministrador,
  crearAdministrador,
  listarAdministradores,
  restablecerContrasena,
} from './admin-actions';
import { ESTILO_ESTADO, ETIQUETA_ESTADO } from './types';
import type { Admin } from './types';
import { NewAdminDialog } from './new-admin-dialog';
import { PasswordNotice } from '@/features/shared/password-notice';

interface Props {
  /** El id de quien esta mirando: su propia fila no lleva acciones. */
  miId: string;
}

export function AdminsList({ miId }: Props) {
  const [administradores, setAdministradores] = useState<Admin[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creando, setCreando] = useState(false);
  const [trabajando, setTrabajando] = useState<string | null>(null);
  const [confirmandoBloqueo, setConfirmandoBloqueo] = useState<Admin | null>(null);

  // La contrasena recien generada, solo mientras el dialogo la ensena. No se
  // guarda, no viaja a la auditoria, desaparece al cerrar.
  const [credencial, setCredencial] = useState<{ nombre: string; password: string } | null>(null);

  const consultar = useCallback(async () => {
    const r = await listarAdministradores();
    if (!r.ok) {
      setError(r.mensaje);
      setCargando(false);
      return;
    }
    setAdministradores(r.administradores);
    setError(null);
    setCargando(false);
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    return () => clearTimeout(inicial);
  }, [consultar]);

  async function ejecutar(id: string, accion: () => Promise<{ ok: boolean; mensaje?: string }>) {
    setTrabajando(id);
    setError(null);
    const r = await accion();
    setTrabajando(null);
    if (!r.ok) {
      setError(r.mensaje ?? 'No pudimos completar la operación.');
      return false;
    }
    await consultar();
    return true;
  }

  const bloqueados = administradores.filter((a) => a.account_status === 'blocked').length;

  return (
    <section>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-text-primary">Administradores</h2>
          <p className="mt-0.5 text-sm text-text-secondary">
            {cargando
              ? 'Consultando…'
              : `${administradores.length} en total${bloqueados > 0 ? ` · ${bloqueados} ${bloqueados === 1 ? 'bloqueada' : 'bloqueadas'}` : ''}`}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setCreando(true)}
          className="btn btn-primario h-10 px-4"
        >
          <Plus size={16} />
          Nuevo administrador
        </button>
      </header>

      {error !== null && (
        <p
          role="alert"
          className="mt-4 flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          {error}
        </p>
      )}

      <div className="mt-4 flex flex-col gap-2">
        {cargando && (
          <div className="flex items-center gap-2 rounded-lg border border-border bg-surface px-4 py-6 text-sm text-text-secondary">
            <LoaderCircle size={16} className="animate-spin" />
            Cargando…
          </div>
        )}

        {!cargando && administradores.length === 0 && (
          <div className="flex flex-col items-center gap-2 rounded-lg border border-border bg-surface px-4 py-10 text-center text-sm text-text-secondary">
            <Inbox size={22} />
            No hay administradores.
          </div>
        )}

        {administradores.map((a) => {
          const esYo = a.admin_id === miId;
          const ocupado = trabajando === a.admin_id;
          const bloqueada = a.account_status === 'blocked';
          return (
            <div
              key={a.admin_id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-surface px-4 py-3"
            >
              <div className="min-w-0">
                <p className="flex items-center gap-2 font-medium text-text-primary">
                  {a.full_name}
                  {a.is_super_admin && (
                    <span className="inline-flex items-center gap-1 rounded-md bg-brand-subtle px-1.5 py-0.5 text-xs font-medium text-brand-strong">
                      <ShieldCheck size={12} />
                      Super admin
                    </span>
                  )}
                  {esYo && <span className="text-xs font-normal text-text-secondary">(tú)</span>}
                </p>
                <p className="truncate text-sm text-text-secondary">
                  {a.email} · {a.phone}
                </p>
              </div>

              <div className="flex items-center gap-2">
                <span
                  className={`rounded-md px-2 py-0.5 text-xs font-medium ${ESTILO_ESTADO[a.account_status]}`}
                >
                  {ETIQUETA_ESTADO[a.account_status]}
                </span>

                {/* La fila propia y la del super admin no llevan acciones: uno no
                    se bloquea a si mismo, y al super admin no lo gestiona nadie. */}
                {!esYo && !a.is_super_admin && (
                  <>
                    <button
                      type="button"
                      disabled={ocupado}
                      onClick={() =>
                        void ejecutar(a.admin_id, async () => {
                          const r = await restablecerContrasena(a.admin_id);
                          if (r.ok) setCredencial({ nombre: a.full_name, password: r.password });
                          return r;
                        })
                      }
                      className="btn btn-secundario h-9 px-2.5 text-sm"
                    >
                      <KeyRound size={14} />
                      Contraseña
                    </button>

                    <button
                      type="button"
                      disabled={ocupado}
                      onClick={() => {
                        if (bloqueada) {
                          void ejecutar(a.admin_id, () =>
                            cambiarEstadoAdministrador(a.admin_id, 'active'),
                          );
                        } else {
                          setConfirmandoBloqueo(a);
                        }
                      }}
                      className="btn btn-secundario h-9 px-2.5 text-sm"
                    >
                      {ocupado ? (
                        <LoaderCircle size={14} className="animate-spin" />
                      ) : bloqueada ? (
                        <UserCheck size={14} />
                      ) : (
                        <Ban size={14} />
                      )}
                      {bloqueada ? 'Desbloquear' : 'Bloquear'}
                    </button>
                  </>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {creando && (
        <NewAdminDialog
          onCerrar={() => setCreando(false)}
          onCrear={async (correo, nombre, telefono) => {
            const r = await crearAdministrador(correo, nombre, telefono);
            if (r.ok) {
              setCreando(false);
              // El dialogo de la contrasena se abre ANTES de recargar: la lista
              // puede tardar y esa contrasena no se puede perder por el camino.
              setCredencial({ nombre, password: r.password });
              void consultar();
            }
            return r;
          }}
        />
      )}

      {credencial !== null && (
        <PasswordNotice
          titulo="Administrador listo"
          nombre={credencial.nombre}
          password={credencial.password}
          recuperarDesde="esta pantalla, con el botón «Contraseña»"
          onCerrar={() => setCredencial(null)}
        />
      )}

      {confirmandoBloqueo !== null && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
          role="dialog"
          aria-modal="true"
          aria-labelledby="titulo-bloquear-admin"
        >
          <div className="w-full max-w-[420px] rounded-xl border border-border bg-surface p-5">
            <h3
              id="titulo-bloquear-admin"
              className="flex items-center gap-2 font-medium text-text-primary"
            >
              <Ban size={18} className="text-on-danger-subtle" />
              Bloquear a {confirmandoBloqueo.full_name}
            </h3>
            <p className="mt-2 text-sm text-text-secondary">
              No podrá entrar al panel hasta que lo desbloquees. Sus acciones anteriores quedan como
              están.
            </p>
            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setConfirmandoBloqueo(null)}
                className="btn btn-secundario h-10 px-3"
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={() => {
                  const objetivo = confirmandoBloqueo;
                  setConfirmandoBloqueo(null);
                  void ejecutar(objetivo.admin_id, () =>
                    cambiarEstadoAdministrador(objetivo.admin_id, 'blocked'),
                  );
                }}
                className="btn btn-primario h-10 px-4"
              >
                Bloquear
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
