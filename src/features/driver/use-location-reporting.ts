import { useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import type { Coordinates } from '@/features/map/region';
import { useNumericSetting } from '@/features/ride/settings';

import { reportLocation } from './driver-service';

/**
 * El conductor dice donde esta mientras esta disponible (D159, regla R9).
 *
 * Por que esto existe y no se dejo para la Fase 14. `find_available_drivers`
 * descarta a cualquier conductor cuya ubicacion tenga mas de dos minutos, asi
 * que sin este envio un conductor real no aparece nunca en una busqueda por muy
 * bien que funcione todo lo demas. La Fase 14 es otra cosa: el seguimiento fino
 * durante el viaje, que el pasajero ve moverse.
 *
 * SOLO EN PRIMER PLANO, por D116. Cuando la aplicacion pasa a segundo plano se
 * deja de enviar a proposito, y esa decision merece explicarse: lo comodo seria
 * seguir mandando la ultima posicion conocida, pero eso pondria al conductor en
 * el mapa, fresco, en un sitio donde ya no esta. Es preferible que desaparezca
 * de las busquedas a que aparezca en el lugar equivocado.
 *
 * Consecuencia que la pantalla tiene que contar: con la aplicacion en segundo
 * plano deja de recibir solicitudes a los dos minutos, aunque su interruptor
 * siga diciendo "disponible".
 */

/** Valor de reserva si no se puede leer el parametro. Es el de la regla R9. */
const INTERVALO_RESERVA = 30;

export interface LocationReporting {
  /** Momento del ultimo envio correcto, o null si todavia no hubo ninguno. */
  lastSentAt: number | null;
  /** Mensaje del ultimo fallo, o null si el ultimo envio salio bien. */
  error: string | null;
}

export interface UseLocationReportingParams {
  driverId: string | null;
  /** La ultima posicion conocida. Null mientras no haya ninguna. */
  coords: Coordinates | null;
  /** Solo se envia cuando esta disponible. */
  active: boolean;
}

export function useLocationReporting({
  driverId,
  coords,
  active,
}: UseLocationReportingParams): LocationReporting {
  const intervaloSegundos = useNumericSetting(
    'location_interval_available_seconds',
    INTERVALO_RESERVA,
  );

  const [lastSentAt, setLastSentAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  /**
   * La posicion vive en una referencia y no en las dependencias del efecto.
   *
   * Si estuviera en las dependencias, cada lectura del GPS reiniciaria el
   * temporizador y el envio no ocurriria nunca: siempre faltarian treinta
   * segundos para el siguiente.
   */
  const coordsRef = useRef<Coordinates | null>(coords);

  useEffect(() => {
    coordsRef.current = coords;
  }, [coords]);

  useEffect(() => {
    if (!active || driverId === null) {
      return;
    }

    let vigente = true;
    let enPrimerPlano = AppState.currentState === 'active';

    const enviar = async () => {
      if (!vigente || !enPrimerPlano) return;

      const posicion = coordsRef.current;
      if (posicion === null) return;

      const resultado = await reportLocation(driverId, posicion);
      if (!vigente) return;

      if (resultado.ok) {
        setLastSentAt(Date.now());
        setError(null);
      } else {
        setError(resultado.failure.message);
      }
    };

    const listener = AppState.addEventListener('change', (siguiente) => {
      enPrimerPlano = siguiente === 'active';
      // Al volver de segundo plano se manda enseguida, sin esperar al siguiente
      // turno: el conductor lleva un rato invisible y lo que quiere es volver a
      // estar disponible ya.
      if (enPrimerPlano) void enviar();
    });

    // El primer envio no espera al intervalo. Encender el interruptor y tardar
    // treinta segundos en existir para el sistema seria una espera que el
    // conductor no entiende, y ademas justo la que decide si recibe la solicitud
    // que esta entrando en este momento.
    //
    // Diferido con un temporizador de cero, como en el resto del proyecto: el
    // compilador de React rechaza un setState alcanzable desde el cuerpo de un
    // efecto.
    const primero = setTimeout(() => void enviar(), 0);
    const repeticion = setInterval(() => void enviar(), intervaloSegundos * 1000);

    return () => {
      vigente = false;
      clearTimeout(primero);
      clearInterval(repeticion);
      listener.remove();
    };
  }, [active, driverId, intervaloSegundos]);

  return { lastSentAt, error };
}
