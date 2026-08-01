import { useCallback, useEffect, useState } from 'react';

import { supabase } from '@/lib/supabase';

/**
 * Parametros operativos que la empresa configura, leidos desde `app_settings`.
 *
 * El maximo de pasajeros no se escribe en el codigo (R11). Hoy los motorratones
 * llevan tres, pero eso es un dato de la flota, no una verdad del software: el
 * dia que entre un vehiculo de cuatro plazas la empresa cambia un numero en el
 * panel y la aplicacion se entera sola.
 */

/**
 * Lo que se usa si la lectura falla.
 *
 * Quedarse sin poder pedir un servicio porque no se pudo leer un parametro seria
 * desproporcionado, asi que se sigue con el valor conocido de la flota actual.
 * No es peligroso: la cantidad la valida `request_ride` en el servidor, que es
 * quien manda (D83). Como mucho el pasajero elige un numero que el servidor
 * rechaza, y eso se le explica en la Fase 11.
 */
const MAX_PASSENGERS_FALLBACK = 3;

const KEY = 'max_passengers_per_request';

let cache: number | null = null;

/** La usa la Fase 20 cuando el panel cambie los parametros. */
export function invalidateSettingsCache(): void {
  cache = null;
}

async function fetchMaxPassengers(): Promise<number> {
  const { data, error } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', KEY)
    .maybeSingle();

  if (error || data === null) return MAX_PASSENGERS_FALLBACK;

  // La columna es jsonb, asi que el valor llega como numero o como texto segun
  // como se guardara. Se acepta lo uno y lo otro en lugar de confiar en que
  // siempre venga bien: un parametro mal escrito desde el panel no debe dejar la
  // aplicacion sin selector.
  const raw = data.value;
  const parsed = typeof raw === 'number' ? raw : Number(raw);

  if (!Number.isInteger(parsed) || parsed < 1) return MAX_PASSENGERS_FALLBACK;
  return parsed;
}

/**
 * El maximo de pasajeros por solicitud.
 *
 * Devuelve el valor de reserva desde el primer render y lo sustituye cuando
 * llega el real. Asi el selector aparece completo desde el principio en lugar de
 * parpadear, y en el caso normal, que es que el maximo siga siendo tres, el
 * pasajero no nota nada.
 */
export function useMaxPassengers(): number {
  const [max, setMax] = useState(cache ?? MAX_PASSENGERS_FALLBACK);

  const cargar = useCallback(async () => {
    const value = await fetchMaxPassengers();
    cache = value;
    setMax(value);
  }, []);

  useEffect(() => {
    if (cache !== null) return;

    // Diferido fuera del cuerpo del efecto, por la misma razon que en
    // use-location y use-places: el compilador de React rechaza un setState
    // alcanzable sincronamente desde un efecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  return max;
}
