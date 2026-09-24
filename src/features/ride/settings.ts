import { useCallback, useEffect, useState } from 'react';

import { supabase } from '@/lib/supabase';

/**
 * Parametros operativos que la empresa configura, leidos desde `app_settings`.
 *
 * El maximo de pasajeros no se escribe en el codigo (R11). Hoy los motocarros
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

/**
 * Cada parametro se lee una vez por sesion de aplicacion.
 *
 * Un Map y no una variable suelta porque desde la Fase 12 hay mas de un
 * parametro que leer: el maximo de pasajeros del pasajero y el intervalo de
 * envio de posicion del conductor.
 */
const cache = new Map<string, number>();

/** La usa la Fase 20 cuando el panel cambie los parametros. */
export function invalidateSettingsCache(): void {
  cache.clear();
}

async function fetchNumericSetting(key: string, fallback: number): Promise<number> {
  const { data, error } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', key)
    .maybeSingle();

  if (error || data === null) return fallback;

  // La columna es jsonb, asi que el valor llega como numero o como texto segun
  // como se guardara. Se acepta lo uno y lo otro en lugar de confiar en que
  // siempre venga bien: un parametro mal escrito desde el panel no debe dejar la
  // aplicacion sin selector.
  const raw = data.value;
  const parsed = typeof raw === 'number' ? raw : Number(raw);

  if (!Number.isInteger(parsed) || parsed < 1) return fallback;
  return parsed;
}

/**
 * Un parametro numerico de la empresa, con un valor de reserva.
 *
 * Devuelve el valor de reserva desde el primer render y lo sustituye cuando
 * llega el real. Asi la pantalla aparece completa desde el principio en lugar de
 * parpadear, y en el caso normal, que es que el parametro siga en su valor
 * habitual, no se nota nada.
 */
export function useNumericSetting(key: string, fallback: number, enabled = true): number {
  const [value, setValue] = useState(cache.get(key) ?? fallback);

  const cargar = useCallback(async () => {
    const leido = await fetchNumericSetting(key, fallback);
    cache.set(key, leido);
    setValue(leido);
  }, [key, fallback]);

  useEffect(() => {
    // `enabled` en falso: el parametro no hace falta todavia. Se evita una
    // llamada de red que competiria con las del primer pintado. En cuanto haga
    // falta -y `enabled` pase a cierto- se lee, una sola vez por sesion.
    if (!enabled || cache.has(key)) return;

    // Diferido fuera del cuerpo del efecto, por la misma razon que en
    // use-location y use-places: el compilador de React rechaza un setState
    // alcanzable sincronamente desde un efecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar, key, enabled]);

  return value;
}

/** El maximo de pasajeros por solicitud (R11). */
export function useMaxPassengers(): number {
  return useNumericSetting('max_passengers_per_request', MAX_PASSENGERS_FALLBACK);
}
