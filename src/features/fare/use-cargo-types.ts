import { useCallback, useEffect, useState } from 'react';

import { fetchCargoTypes } from './cargo-types-service';
import type { CargoType } from './types';

/**
 * El catalogo de tipos de carga, cargado una vez por sesion de aplicacion.
 *
 * Mismo criterio que `usePlaces`: la lista la administra la empresa y cambia
 * poco, asi que una cache a nivel de modulo evita pedirla otra vez cada vez que
 * el pasajero abre el selector de carga.
 */

let cache: CargoType[] | null = null;

/** La usa la Fase 20 cuando el panel modifique el catalogo. */
export function invalidateCargoTypesCache(): void {
  cache = null;
}

export interface UseCargoTypesResult {
  cargoTypes: CargoType[];
  loading: boolean;
  error: string | null;
}

export function useCargoTypes(): UseCargoTypesResult {
  const [cargoTypes, setCargoTypes] = useState<CargoType[]>(cache ?? []);
  const [loading, setLoading] = useState(cache === null);
  const [error, setError] = useState<string | null>(null);

  const cargar = useCallback(async () => {
    const resultado = await fetchCargoTypes();
    if (resultado.ok) {
      cache = resultado.data;
      setCargoTypes(resultado.data);
      setError(null);
    } else {
      setError(resultado.failure.message);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (cache !== null) return;

    // Diferido fuera del cuerpo del efecto, mismo motivo que en use-places: el
    // compilador de React rechaza un setState alcanzable sincronamente desde un
    // efecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  return { cargoTypes, loading, error };
}
