'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { listarConductores } from '@/features/drivers/driver-actions';

/** Mismo intervalo que `useActiveServices`, por el mismo motivo: todo lo que
 * hay en el tablero se refresca junto. */
const INTERVALO_MS = 10_000;

interface Estado {
  cuantos: number;
  cargando: boolean;
  error: string | null;
}

/**
 * Cuantos conductores tienen el interruptor de disponible encendido ahora
 * mismo (pedido de la empresa, 2026-09-16).
 *
 * SE APOYA EN `listarConductores`, no en una consulta propia: es la misma
 * fuente que ya usa la pantalla de conductores (`admin_list_drivers`), y
 * duplicar la llamada solo arriesgaria que un dia contaran cosas distintas.
 */
export function useAvailableDrivers() {
  const [estado, setEstado] = useState<Estado>({ cuantos: 0, cargando: true, error: null });

  const peticionRef = useRef(0);

  const consultar = useCallback(async () => {
    const miPeticion = ++peticionRef.current;
    const r = await listarConductores();

    if (miPeticion !== peticionRef.current) return;

    if (!r.ok) {
      setEstado((previo) => ({ ...previo, cargando: false, error: r.mensaje }));
      return;
    }

    setEstado({
      cuantos: r.conductores.filter((c) => c.is_available).length,
      cargando: false,
      error: null,
    });
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    const id = setInterval(() => void consultar(), INTERVALO_MS);
    return () => {
      clearTimeout(inicial);
      clearInterval(id);
    };
  }, [consultar]);

  return estado;
}
