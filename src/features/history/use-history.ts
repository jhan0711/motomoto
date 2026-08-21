import { useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';

import { RIDE_ERROR_CODES } from '@/features/ride/errors';

import { HISTORY_PAGE_SIZE, type Result } from './history-service';

/**
 * El historial paginado, sin saber de que es.
 *
 * Sirve para las dos pantallas: la del pasajero y la del conductor. Lo unico
 * que cambia entre ellas es la funcion que trae una pagina, y eso entra por
 * parametro. Escribirlo dos veces habria significado arreglar cada fallo de
 * paginacion dos veces.
 *
 * TRES CARGAS DISTINTAS, y la pantalla las pinta de tres maneras. La primera
 * ocupa la pantalla entera con su esqueleto; el tiron hacia abajo deja la lista
 * puesta y gira arriba; la siguiente tanda gira al final. Un solo `loading`
 * para las tres haria parpadear la lista completa cada vez que se llega al
 * final, que es justo cuando el pasajero esta leyendo.
 */

export interface UseHistoryResult<T> {
  rows: T[];
  /** Primera carga, con la lista todavia vacia. */
  loading: boolean;
  /** Tiron hacia abajo sobre una lista que ya tiene filas. */
  refreshing: boolean;
  /** Pidiendo la siguiente tanda al llegar al final. */
  loadingMore: boolean;
  error: string | null;
  /**
   * Cierto cuando el fallo fue quedarse sin conexion, y no un problema del
   * servidor. La pantalla lo cuenta de otra manera: "sin conexion" se arregla
   * solo en cuanto vuelva la senal, y "algo salio mal" no.
   */
  offline: boolean;
  hasMore: boolean;
  refresh: () => void;
  loadMore: () => void;
  /**
   * Vuelve a intentar la tanda que fallo, sin perder lo que ya se leyo.
   *
   * `refresh` no sirve para esto: empieza por la primera pagina y devuelve al
   * usuario al principio de la lista, que es donde no estaba.
   */
  retryMore: () => void;
}

type FetchPage<T> = (limit: number, offset: number) => Promise<Result<T[]>>;

export function useHistory<T>(fetchPage: FetchPage<T>): UseHistoryResult<T> {
  const [rows, setRows] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  /**
   * Cierra la puerta a dos peticiones a la vez.
   *
   * `onEndReached` de FlatList se dispara varias veces seguidas mientras el
   * dedo sigue moviendose. Sin esto, llegar al final pedia la misma pagina tres
   * veces y las filas salian repetidas.
   */
  const ocupado = useRef(false);

  const cargar = useCallback(
    async (desde: number, modo: 'primera' | 'refresco' | 'mas') => {
      if (ocupado.current) return;
      ocupado.current = true;

      if (modo === 'refresco') setRefreshing(true);
      if (modo === 'mas') setLoadingMore(true);

      const resultado = await fetchPage(HISTORY_PAGE_SIZE, desde);

      if (resultado.ok) {
        const pagina = resultado.data;
        setRows((anteriores) => (desde === 0 ? pagina : [...anteriores, ...pagina]));
        // Una pagina incompleta es el final. Una completa puede serlo tambien,
        // y entonces la siguiente llegara vacia: una peticion de mas a cambio
        // de no tener que preguntar cuantas hay en total.
        setHasMore(pagina.length === HISTORY_PAGE_SIZE);
        setError(null);
        setOffline(false);
      } else {
        setError(resultado.failure.message);
        setOffline(resultado.failure.code === RIDE_ERROR_CODES.network);
      }

      setLoading(false);
      setRefreshing(false);
      setLoadingMore(false);
      ocupado.current = false;
    },
    [fetchPage],
  );

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto, igual que en use-places: el
    // compilador de React rechaza un setState alcanzable sincronamente desde
    // un efecto.
    const id = setTimeout(() => void cargar(0, 'primera'), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  /**
   * Al volver a la lista, releerla. Misma razon que en use-detail: se califica en
   * otra pantalla y la fila tiene que dejar de decir "Sin calificar".
   *
   * Vuelve a la primera pagina. Con una lista de historial es lo honesto: lo que
   * cambia esta arriba, y quien estaba mirando el final rara vez acaba de
   * cambiar algo alli.
   */
  const primeraVez = useRef(true);

  useFocusEffect(
    useCallback(() => {
      if (primeraVez.current) {
        primeraVez.current = false;
        return;
      }

      const tarea = setTimeout(() => {
        setHasMore(true);
        void cargar(0, 'refresco');
      }, 0);
      return () => clearTimeout(tarea);
    }, [cargar]),
  );

  const refresh = useCallback(() => {
    setHasMore(true);
    void cargar(0, 'refresco');
  }, [cargar]);

  const loadMore = useCallback(() => {
    // Con la lista a medio cargar, o sin nada mas que traer, no hay nada que
    // pedir. Y tras un fallo tampoco: seguir tirando repetiria el mismo error
    // hasta el infinito mientras el dedo siga bajando.
    if (loading || refreshing || loadingMore || !hasMore || error !== null) return;
    void cargar(rows.length, 'mas');
  }, [cargar, error, hasMore, loading, loadingMore, refreshing, rows.length]);

  const retryMore = useCallback(() => {
    setError(null);
    setOffline(false);
    void cargar(rows.length, 'mas');
  }, [cargar, rows.length]);

  return {
    rows,
    loading,
    refreshing,
    loadingMore,
    error,
    offline,
    hasMore,
    refresh,
    loadMore,
    retryMore,
  };
}
