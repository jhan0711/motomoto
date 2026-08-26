import { useCallback, useEffect, useState } from 'react';

import { RIDE_ERROR_CODES } from '@/features/ride/errors';

import { fetchDriverEarnings } from './earnings-service';
import type { EarningsPeriod, EarningsRow } from './types';

export interface UseEarningsResult {
  rows: EarningsRow[];
  period: EarningsPeriod;
  setPeriod: (period: EarningsPeriod) => void;
  /** El total de lo que SI tiene valor. Ver `EarningsRow.fareAmount`. */
  total: number;
  loading: boolean;
  refreshing: boolean;
  error: string | null;
  offline: boolean;
  refresh: () => void;
}

/**
 * El recaudo del conductor: los servicios completados de un periodo y su
 * total.
 *
 * No pagina, al reves que `useHistory`: el periodo mas largo que ofrece la
 * pantalla es una semana, y un conductor de un solo pueblo no completa
 * suficientes servicios en una semana para que haga falta.
 */
export function useEarnings(): UseEarningsResult {
  const [period, setPeriod] = useState<EarningsPeriod>('today');
  const [rows, setRows] = useState<EarningsRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);

  // El periodo anterior, para saber en el render mismo si acaba de cambiar.
  // Mismo patron que `use-fare-quote`: limpiar en el render y no dentro del
  // efecto evita un fotograma con las filas del periodo anterior bajo el
  // rotulo del nuevo.
  const [periodoAnterior, setPeriodoAnterior] = useState(period);
  if (period !== periodoAnterior) {
    setPeriodoAnterior(period);
    setLoading(true);
    setRows([]);
    setError(null);
    setOffline(false);
  }

  const cargar = useCallback(async (p: EarningsPeriod, modo: 'primera' | 'refresco') => {
    if (modo === 'refresco') setRefreshing(true);

    const resultado = await fetchDriverEarnings(p);

    if (resultado.ok) {
      setRows(resultado.data);
      setError(null);
      setOffline(false);
    } else {
      setError(resultado.failure.message);
      setOffline(resultado.failure.code === RIDE_ERROR_CODES.network);
    }

    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto: mismo motivo que en use-history,
    // el compilador de React rechaza un setState alcanzable sincronamente
    // desde aqui.
    const id = setTimeout(() => void cargar(period, 'primera'), 0);
    return () => clearTimeout(id);
  }, [cargar, period]);

  const refresh = useCallback(() => {
    void cargar(period, 'refresco');
  }, [cargar, period]);

  const total = rows.reduce((suma, fila) => suma + (fila.fareAmount ?? 0), 0);

  return { rows, period, setPeriod, total, loading, refreshing, error, offline, refresh };
}
