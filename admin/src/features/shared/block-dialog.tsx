'use client';

import { useState } from 'react';
import { LoaderCircle, TriangleAlert } from 'lucide-react';
/**
 * El resultado de cualquiera de las dos acciones de bloqueo. Se declara aqui y
 * no se importa de un modulo concreto: **este dialogo lo usan pasajeros y
 * conductores**, y depender de uno de los dos lo ataria al que llego primero.
 */
export interface Resultado {
  ok: boolean;
  mensaje?: string;
}

interface Props {
  nombre: string;
  /** Cierto cuando tiene un servicio vivo ahora mismo. */
  conServicioEnCurso: boolean;
  /**
   * Que se le dice a quien bloquea cuando hay un servicio en curso. **Cambia
   * segun a quien se bloquea**: al pasajero se le queda sin poder ver donde va;
   * al conductor se le corta el trabajo nuevo pero **termina el que lleva**
   * (D262), y eso hay que decirlo o parece que se deja al pasajero tirado.
   */
  avisoServicioEnCurso: string;
  onCerrar: () => void;
  onBloquear: (motivo: string | null) => Promise<Resultado>;
}

/**
 * Confirmar el bloqueo de una cuenta, de pasajero o de conductor.
 *
 * **El motivo solo es obligatorio si tiene un servicio en curso** (D253). Esa es
 * la regla del servidor y aqui se refleja tal cual: pedirlo siempre convertiria
 * en tramite algo que casi siempre es rutina, y no pedirlo nunca dejaria sin
 * explicacion el unico caso en que hace falta.
 */
export function BlockDialog({
  nombre,
  conServicioEnCurso,
  avisoServicioEnCurso,
  onCerrar,
  onBloquear,
}: Props) {
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [trabajando, setTrabajando] = useState(false);

  const motivoCorto = conServicioEnCurso && motivo.trim().length < 10;

  async function enviar(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setTrabajando(true);
    const r = await onBloquear(motivo.trim() === '' ? null : motivo.trim());
    setTrabajando(false);
    if (!r.ok) setError(r.mensaje ?? 'No pudimos bloquear la cuenta.');
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-bloqueo"
    >
      <div className="w-full max-w-[460px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-bloqueo" className="font-medium text-text-primary">
          Bloquear a {nombre}
        </h3>
        <p className="mt-2 text-sm text-text-secondary">
          No podrá entrar en la aplicación. Su historial se conserva y puedes desbloquearlo cuando
          quieras.
        </p>

        {conServicioEnCurso && (
          <div className="mt-3 flex items-start gap-2 rounded-lg bg-warning-subtle px-3 py-2.5 text-sm text-on-warning">
            <TriangleAlert size={18} className="mt-px shrink-0" />
            <span>{avisoServicioEnCurso}</span>
          </div>
        )}

        <form onSubmit={enviar} className="mt-4 flex flex-col gap-4" noValidate>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="motivo-bloqueo" className="text-sm font-medium text-text-primary">
              Motivo{conServicioEnCurso ? '' : ' (opcional)'}
            </label>
            <textarea
              id="motivo-bloqueo"
              rows={3}
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
              placeholder={
                conServicioEnCurso
                  ? 'Qué pasó, con detalle suficiente para entenderlo dentro de seis meses'
                  : 'Opcional'
              }
              className="rounded-lg border border-border bg-surface px-3 py-2 text-text-primary outline-none focus:border-brand"
            />
            <p className="text-xs text-text-secondary">Queda registrado con tu nombre y la hora.</p>
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
              disabled={trabajando}
              className="btn btn-secundario h-10 px-3"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={trabajando || motivoCorto}
              className="btn btn-primario h-10 px-4"
            >
              {trabajando && <LoaderCircle size={15} className="animate-spin" />}
              Bloquear
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
