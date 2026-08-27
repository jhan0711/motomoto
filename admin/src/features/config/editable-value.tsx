'use client';

import { useState } from 'react';
import { Check, LoaderCircle, X } from 'lucide-react';
import type { Resultado } from './config-actions';

interface Props {
  valor: string;
  sufijo?: string;
  ancho?: string;
  etiquetaAccesible: string;
  onGuardar: (nuevo: string) => Promise<Resultado>;
}

/**
 * Un valor que se edita en su sitio.
 *
 * Se eligio esto y no un formulario con "Guardar" al final por lo que se cambia
 * aqui: **precios y parametros sueltos**. Un formulario con veinte campos y un
 * boton invita a tocar cuatro cosas y guardarlas juntas; si una falla la
 * validacion, el usuario no sabe cual. Cambiando de uno en uno, cada cambio
 * lleva su propia respuesta y su propia linea en la auditoria.
 *
 * Escape cancela y Enter guarda: son las dos teclas que cualquiera prueba.
 */
export function EditableValue({ valor, sufijo, ancho, etiquetaAccesible, onGuardar }: Props) {
  const [editando, setEditando] = useState(false);
  const [borrador, setBorrador] = useState(valor);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function guardar() {
    if (borrador === valor) {
      setEditando(false);
      setError(null);
      return;
    }
    setGuardando(true);
    const r = await onGuardar(borrador);
    setGuardando(false);
    if (r.ok) {
      setEditando(false);
      setError(null);
      return;
    }
    setError(r.mensaje ?? 'No pudimos guardar.');
  }

  function cancelar() {
    setBorrador(valor);
    setEditando(false);
    setError(null);
  }

  if (!editando) {
    return (
      <button
        type="button"
        onClick={() => {
          setBorrador(valor);
          setEditando(true);
        }}
        aria-label={`Editar ${etiquetaAccesible}`}
        className="btn h-9 px-2 font-normal text-text-primary hover:bg-surface-pressed"
      >
        {valor}
        {sufijo !== undefined ? ` ${sufijo}` : ''}
      </button>
    );
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex items-center gap-1">
        <input
          autoFocus
          value={borrador}
          onChange={(e) => setBorrador(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') void guardar();
            if (e.key === 'Escape') cancelar();
          }}
          aria-label={etiquetaAccesible}
          className={`h-9 rounded-lg border border-brand bg-surface px-2 text-right text-text-primary outline-none ${ancho ?? 'w-28'}`}
        />
        <button
          type="button"
          onClick={() => void guardar()}
          disabled={guardando}
          aria-label="Guardar"
          className="btn btn-primario size-9 p-0"
        >
          {guardando ? <LoaderCircle size={15} className="animate-spin" /> : <Check size={15} />}
        </button>
        <button
          type="button"
          onClick={cancelar}
          disabled={guardando}
          aria-label="Cancelar"
          className="btn btn-secundario size-9 p-0"
        >
          <X size={15} />
        </button>
      </div>

      {error !== null && (
        <p role="alert" className="max-w-xs text-right text-xs text-on-danger-subtle">
          {error}
        </p>
      )}
    </div>
  );
}
