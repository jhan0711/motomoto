'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import type { ActiveService } from './types';

/** Cada cuanto se vuelve a preguntar al servidor. */
const INTERVALO_MS = 10_000;

interface Estado {
  servicios: ActiveService[];
  cargando: boolean;
  error: string | null;
  actualizadoEn: Date | null;
}

/**
 * El tablero, refrescandose solo.
 *
 * POR QUE UNA CONSULTA CADA DIEZ SEGUNDOS Y NO TIEMPO REAL. La Fase 13 publico
 * `ride_requests` y `rides` en realtime, asi que suscribirse era posible. Se
 * eligio preguntar por dos motivos: el tablero muestra una lista agregada y no
 * un marcador moviendose, asi que diez segundos de retraso no cambian ninguna
 * decision de un despachador; y varios de los datos que muestra -la espera, la
 * antiguedad de la posicion, las ofertas vivas- **cambian con el paso del
 * tiempo aunque no cambie ninguna fila**, asi que una suscripcion tampoco
 * evitaria tener que refrescar. Si mas adelante hace falta inmediatez, se
 * anade encima sin tirar esto.
 */
export function useActiveServices() {
  const [estado, setEstado] = useState<Estado>({
    servicios: [],
    cargando: true,
    error: null,
    actualizadoEn: null,
  });

  // Evita que una respuesta lenta pise a otra mas reciente.
  const peticionRef = useRef(0);

  const consultar = useCallback(async () => {
    const miPeticion = ++peticionRef.current;
    const supabase = createClient();
    const { data, error } = await supabase.rpc('admin_list_active_services');

    if (miPeticion !== peticionRef.current) return;

    if (error) {
      // El listado anterior se conserva a proposito: un corte de red no tiene
      // por que vaciar la pantalla que el despachador esta mirando. Se avisa
      // del fallo y se sigue mostrando lo ultimo que se supo.
      setEstado((previo) => ({ ...previo, cargando: false, error: error.message }));
      return;
    }

    setEstado({
      servicios: data ?? [],
      cargando: false,
      error: null,
      actualizadoEn: new Date(),
    });
  }, []);

  useEffect(() => {
    /*
     * LA PRIMERA CONSULTA SE PROGRAMA, NO SE LLAMA AQUI MISMO. Llamarla en el
     * cuerpo del efecto pone estado durante el efecto, que es lo que prohibe el
     * compilador de React -`react-hooks/set-state-in-effect`, el mismo aviso que
     * ya salio en `useEarnings` y en el formulario de acceso-. La solucion no es
     * silenciar la regla (regla 6 de las aprendidas): asi la primera consulta
     * entra por el mismo camino que las demas, desde un temporizador, y el
     * cuerpo del efecto solo programa.
     */
    const inicial = setTimeout(() => void consultar(), 0);
    const id = setInterval(() => void consultar(), INTERVALO_MS);
    return () => {
      clearTimeout(inicial);
      clearInterval(id);
    };
  }, [consultar]);

  return { ...estado, recargar: consultar };
}
