'use client';

import { useState } from 'react';
import { Check, Copy, KeyRound, TriangleAlert } from 'lucide-react';

interface Props {
  titulo: string;
  nombre: string;
  password: string;
  /** Donde se genera otra si esta se pierde. Ej: "la ficha del conductor". */
  recuperarDesde: string;
  onCerrar: () => void;
}

/**
 * La contrasena inicial, mostrada UNA SOLA VEZ.
 *
 * **Esta pantalla es el unico momento en que esa contrasena existe legible.** No
 * esta en la auditoria ni en ninguna tabla: solo su cifrado. Si se cierra sin
 * apuntarla, no se puede recuperar, hay que generar otra.
 *
 * Por eso el dialogo **no se cierra tocando fuera ni con Escape**, al reves que
 * los demas del panel: solo con el boton, que dice explicitamente que ya se
 * anoto. Un cierre accidental aqui cuesta una llamada al conductor.
 */
export function PasswordNotice({ titulo, nombre, password, recuperarDesde, onCerrar }: Props) {
  const [copiada, setCopiada] = useState(false);
  const [confirmado, setConfirmado] = useState(false);

  async function copiar() {
    try {
      await navigator.clipboard.writeText(password);
      setCopiada(true);
    } catch {
      // Sin portapapeles -navegador antiguo, o sin permiso- no pasa nada: la
      // contrasena esta a la vista y se puede escribir a mano. No se avisa de
      // un fallo que no impide nada.
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="titulo-password"
    >
      <div className="w-full max-w-[460px] rounded-xl border border-border bg-surface p-5">
        <h3 id="titulo-password" className="flex items-center gap-2 font-medium text-text-primary">
          <KeyRound size={18} className="text-success" />
          {titulo}
        </h3>

        <p className="mt-2 text-sm text-text-secondary">
          Entrégale estos datos a <span className="font-medium">{nombre}</span> para que entre en la
          aplicación.
        </p>

        <div className="mt-4 rounded-lg border border-border bg-surface-subtle p-4 text-center">
          <p className="text-xs text-text-secondary">Contraseña</p>
          <p className="mt-1 font-mono text-2xl font-semibold tracking-wide text-text-primary">
            {password}
          </p>
        </div>

        <button
          type="button"
          onClick={() => void copiar()}
          className="btn btn-secundario mt-3 h-10 w-full px-3"
        >
          {copiada ? <Check size={15} /> : <Copy size={15} />}
          {copiada ? 'Copiada' : 'Copiar la contraseña'}
        </button>

        <div className="mt-4 flex items-start gap-2 rounded-lg bg-warning-subtle px-3 py-2.5 text-sm text-on-warning">
          <TriangleAlert size={18} className="mt-px shrink-0" />
          <span>
            No se vuelve a mostrar. Si la pierdes, tendrás que generar una nueva desde{' '}
            {recuperarDesde}.
          </span>
        </div>

        {/*
         * La casilla obliga a leer el aviso antes de poder cerrar. Es friccion a
         * proposito: sin ella, el reflejo es cerrar el dialogo sin apuntar nada.
         */}
        <label className="mt-4 flex cursor-pointer items-start gap-2 text-sm text-text-primary">
          <input
            type="checkbox"
            checked={confirmado}
            onChange={(e) => setConfirmado(e.target.checked)}
            className="mt-0.5 size-4 accent-(--color-brand)"
          />
          Ya la anoté o se la entregué
        </label>

        <button
          type="button"
          onClick={onCerrar}
          disabled={!confirmado}
          className="btn btn-primario mt-4 h-11 w-full px-4"
        >
          Cerrar
        </button>
      </div>
    </div>
  );
}
