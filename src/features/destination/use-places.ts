import { useCallback, useEffect, useState } from 'react';

import { fetchPlaces } from './places-service';
import type { Place } from './types';

/**
 * Los lugares del municipio, cargados una vez por sesion de aplicacion.
 *
 * La cache vive en el modulo y no en el componente. Tres pantallas necesitan
 * esta lista (el inicio, el buscador y el punto en el mapa), y sin cache cada
 * navegacion la volveria a pedir: un parpadeo de carga, ida y vuelta a la red, y
 * en Amalfi eso puede ser un par de segundos.
 *
 * Treinta y seis filas que cambian cuando la empresa las cambia. Guardarlas es
 * seguro y hace que elegir destino siga funcionando si la conexion se cae a
 * mitad del flujo.
 */

let cache: Place[] | null = null;

/** La usa la Fase 20 cuando el panel modifique la lista. */
export function invalidatePlacesCache(): void {
  cache = null;
}

export interface UsePlacesResult {
  places: Place[];
  loading: boolean;
  error: string | null;
  reload: () => void;
}

export function usePlaces(): UsePlacesResult {
  const [places, setPlaces] = useState<Place[]>(cache ?? []);
  const [loading, setLoading] = useState(cache === null);
  const [error, setError] = useState<string | null>(null);

  const cargar = useCallback(async () => {
    const resultado = await fetchPlaces();
    if (resultado.ok) {
      cache = resultado.data;
      setPlaces(resultado.data);
      setError(null);
    } else {
      setError(resultado.failure.message);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (cache !== null) return;

    // Diferido fuera del cuerpo del efecto, por la misma razon que en
    // use-location: el compilador de React rechaza un setState alcanzable
    // sincronamente desde un efecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  const reload = useCallback(() => {
    cache = null;
    setLoading(true);
    void cargar();
  }, [cargar]);

  return { places, loading, error, reload };
}
