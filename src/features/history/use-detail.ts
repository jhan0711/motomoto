import { useCallback, useEffect, useState } from 'react';

import { RIDE_ERROR_CODES } from '@/features/ride/errors';

import type { Result } from './history-service';

/**
 * El detalle de un servicio, cargado una vez al abrir la pantalla.
 *
 * Distingue TRES finales y no dos, porque en pantalla se cuentan distinto:
 *
 *   error     no se pudo preguntar. Se ofrece reintentar
 *   notFound  se pregunto y la respuesta fue que no hay nada. Pasa cuando el
 *             identificador no existe, o cuando es de otra persona, que desde
 *             fuera son indistinguibles a proposito
 *   item      esta
 *
 * Mezclar los dos primeros haria que "no es tuyo" ofreciera un boton de
 * reintentar que nunca va a funcionar.
 */

export interface UseDetailResult<T> {
  item: T | null;
  loading: boolean;
  error: string | null;
  /** Ver el gemelo en use-history: sin conexion se cuenta distinto. */
  offline: boolean;
  notFound: boolean;
  reload: () => void;
}

export function useHistoryDetail<T>(
  fetchOne: (id: string) => Promise<Result<T | null>>,
  id: string,
): UseDetailResult<T> {
  const [item, setItem] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const [notFound, setNotFound] = useState(false);

  const cargar = useCallback(async () => {
    const resultado = await fetchOne(id);

    if (resultado.ok) {
      setItem(resultado.data);
      setNotFound(resultado.data === null);
      setError(null);
      setOffline(false);
    } else {
      setError(resultado.failure.message);
      setOffline(resultado.failure.code === RIDE_ERROR_CODES.network);
    }

    setLoading(false);
  }, [fetchOne, id]);

  useEffect(() => {
    // Diferido, igual que en use-history y en use-places: el compilador de React
    // rechaza un setState alcanzable sincronamente desde un efecto.
    const tarea = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(tarea);
  }, [cargar]);

  const reload = useCallback(() => {
    setLoading(true);
    setError(null);
    setOffline(false);
    void cargar();
  }, [cargar]);

  return { item, loading, error, offline, notFound, reload };
}
