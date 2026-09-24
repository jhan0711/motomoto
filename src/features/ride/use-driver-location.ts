import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import { supabase } from '@/lib/supabase';

import { fetchDriverLocation, type DriverLocation } from './ride-service';

/** Cada cuanto el telefono recalcula la antiguedad de la ultima posicion. */
const TICK_MS = 5000;

/**
 * Segundos entre una marca de tiempo ISO y ahora, contados por el telefono.
 *
 * Exportada para la prueba: es la cuenta que decide si se enciende "perdimos la
 * senal" cuando los eventos de tiempo real dejan de llegar.
 */
export function edadDesde(updatedAt: string): number {
  const at = Date.parse(updatedAt);
  if (Number.isNaN(at)) return 0;
  return Math.max(0, Math.round((Date.now() - at) / 1000));
}

/**
 * Donde esta el motocarro que viene a recoger al pasajero.
 *
 * POR QUE TIEMPO REAL Y NO SONDEO. El criterio de aceptacion 4 pide ver moverse
 * al conductor con menos de quince segundos de retraso. El conductor envia cada
 * 7-10 s (R9); sondeando cada diez, el peor caso son veinte y el criterio no se
 * cumple.
 *
 * LA POSICION VIENE EN EL PROPIO EVENTO. Desde la Fase 22 (paso 7),
 * `driver_locations` guarda `lat` y `lng` sueltas ademas de la geografia, y el
 * evento de tiempo real las trae. El pasajero pinta el punto en cuanto llega el
 * aviso, sin la consulta extra que antes anadia 2-4 s.
 *
 * SE SIGUE LLAMANDO A LA FUNCION en dos momentos: el primer pintado -antes de
 * que llegue ningun evento- y al volver de segundo plano -con el telefono
 * bloqueado el websocket puede caerse y al volver el pasajero se encontraria el
 * motocarro donde estaba hace diez minutos, D152-. En esos dos casos la
 * antiguedad la cuenta el servidor; entre eventos la cuenta el telefono a partir
 * de la marca de tiempo, con un temporizador, para que "perdimos la senal" se
 * encienda aunque los eventos dejen de llegar.
 *
 * EL FILTRO POR CONDUCTOR NO ES LA SEGURIDAD, ES EL AHORRO. Sin el, a este
 * telefono llegarian los eventos de toda la flota para descartarlos aqui. Quien
 * decide que puede ver es `driver_locations_select_active_passenger`, que se
 * aplica tambien en tiempo real.
 */
export function useDriverLocation(driverId: string | null): DriverLocation | null {
  const [location, setLocation] = useState<DriverLocation | null>(null);

  /**
   * Descarta respuestas de un conductor que ya no es el nuestro.
   *
   * Pasa de verdad: el pasajero cancela, vuelve a pedir y le toca otro. Una
   * respuesta lenta del primero llegaria despues y pintaria su motocarro.
   */
  const turno = useRef(0);

  const aplicar = useCallback(
    (lat: number, lng: number, heading: number | null, updatedAt: string, ageServidor?: number) => {
      setLocation({
        latitude: lat,
        longitude: lng,
        heading,
        ageSeconds: ageServidor ?? edadDesde(updatedAt),
        updatedAt,
      });
    },
    [],
  );

  const releer = useCallback(async () => {
    if (driverId === null) return;

    const mio = ++turno.current;
    const resultado = await fetchDriverLocation(driverId);

    if (mio !== turno.current) return;

    // Un fallo de red no borra lo que ya se sabe: la posicion de hace veinte
    // segundos sigue siendo mas util que un mapa sin motocarro, y la antiguedad
    // que se pinta al lado ya avisa de que no es de ahora.
    if (resultado.ok && resultado.data !== null) {
      const d = resultado.data;
      aplicar(d.latitude, d.longitude, d.heading, d.updatedAt, d.ageSeconds);
    }
  }, [driverId, aplicar]);

  /**
   * Cambiar de conductor borra la posicion del anterior.
   *
   * Se ajusta en el render y no en un efecto, que es la forma que React
   * documenta para corregir estado cuando cambia una entrada, y la unica que no
   * deja un fotograma con el motocarro de otro servicio en el mapa.
   */
  const [driverIdAnterior, setDriverIdAnterior] = useState(driverId);

  if (driverId !== driverIdAnterior) {
    setDriverIdAnterior(driverId);
    setLocation(null);
  }

  useEffect(() => {
    if (driverId === null) return;

    // Diferido, como en el resto del proyecto: el compilador de React rechaza un
    // setState alcanzable desde el cuerpo de un efecto.
    const primera = setTimeout(() => void releer(), 0);

    const canal = supabase
      .channel(`pasajero-posicion-${driverId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'driver_locations',
          filter: `driver_id=eq.${driverId}`,
        },
        (payload) => {
          const fila = payload.new as {
            lat: number | null;
            lng: number | null;
            heading: number | null;
            updated_at: string;
          };
          // Si por lo que sea la fila no trae las coordenadas sueltas, se
          // pregunta como antes. No deberia pasar tras la migracion del paso 7.
          if (fila.lat === null || fila.lng === null) {
            void releer();
            return;
          }
          aplicar(fila.lat, fila.lng, fila.heading, fila.updated_at);
        },
      )
      .subscribe();

    const listener = AppState.addEventListener('change', (siguiente) => {
      if (siguiente === 'active') void releer();
    });

    // El telefono cuenta la antiguedad entre eventos: sin esto, si el conductor
    // se queda sin cobertura la posicion se quedaria "fresca" para siempre y
    // "perdimos la senal" no llegaria a encenderse. La marca de tiempo vive en
    // el propio estado (`updatedAt`), asi que no hace falta guardarla aparte.
    const tic = setInterval(() => {
      setLocation((prev) =>
        prev === null ? prev : { ...prev, ageSeconds: edadDesde(prev.updatedAt) },
      );
    }, TICK_MS);

    return () => {
      clearTimeout(primera);
      clearInterval(tic);
      listener.remove();
      void supabase.removeChannel(canal);
      turno.current += 1;
    };
  }, [driverId, releer, aplicar]);

  return location;
}
