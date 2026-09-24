import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import { distanceInMeters } from '@/features/destination/geo';
import type { Coordinates } from '@/features/map/region';
import { useNumericSetting } from '@/features/ride/settings';

import { reportLocation } from './driver-service';

/**
 * El conductor dice donde esta (D159, regla R9).
 *
 * Por que esto existe y no se dejo para la Fase 14. `find_available_drivers`
 * descarta a cualquier conductor cuya ubicacion tenga mas de dos minutos, asi
 * que sin este envio un conductor real no aparece nunca en una busqueda por muy
 * bien que funcione todo lo demas.
 *
 * LA FASE 14 LE ANADIO LAS DOS MITADES QUE LE FALTABAN.
 *
 * La primera es la cadencia. La regla R9 pide dos ritmos y no uno: treinta
 * segundos mientras solo esta disponible, y diez segundos o cincuenta metros
 * mientras lleva a alguien. La diferencia no es capricho: en el primer caso la
 * posicion sirve para decidir a quien se le ofrece un viaje, y treinta segundos
 * de desfase no cambian esa decision; en el segundo hay un pasajero mirando el
 * mapa para saber si el motocarro ya viene, y ahi treinta segundos son una
 * eternidad. Los dos valores viven en `app_settings`, no aqui.
 *
 * "Diez segundos O cincuenta metros" es literal: manda el que llegue antes. El
 * temporizador sostiene la marca de tiempo aunque el motocarro este parado en
 * un semaforo, que es lo que evita que caduque su posicion y desaparezca de las
 * busquedas; y el desplazamiento adelanta el envio cuando avanza deprisa, que es
 * cuando el marcador del pasajero se quedaria mas atras.
 *
 * La segunda es CUANDO se envia, y era un fallo de verdad. Antes solo se enviaba
 * con el interruptor encendido. Pero desde D164 aceptar una oferta puede apagar
 * la disponibilidad, porque el motocarro se lleno: el conductor se quedaba sin
 * enviar posicion justo mientras iba a recoger a tres personas, y el pasajero
 * habria visto su motocarro congelado en el sitio donde estaba al aceptar. Un
 * conductor con un servicio encima envia siempre, tenga el interruptor como lo
 * tenga.
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
 *
 * ESTO SIGUE SIENDO CIERTO TAL CUAL PARA "EN VIAJE". Para "disponible sin
 * viaje" ya no es toda la historia desde el pedido de la empresa del
 * 2026-09-15 (validado con el dueno del producto): `useBackgroundLocation`,
 * en `use-background-location.ts`, cubre ese caso por su cuenta, con su
 * propia tarea en segundo plano. Este hook no sabe nada de eso ni tenia que
 * saberlo -sigue enviando en primer plano exactamente igual que siempre,
 * disponible o en viaje-, y las dos pantallas de aviso al conductor viven
 * juntas en `app/driver/(tabs)/index.tsx`, no aqui.
 */

/** Valores de reserva si no se puede leer el parametro. Son los de la regla R9. */
const INTERVALO_DISPONIBLE = 30;
const INTERVALO_EN_VIAJE = 10;
const DISTANCIA_MINIMA_M = 50;

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
  /** El interruptor de disponible. */
  available: boolean;
  /**
   * Lleva al menos un servicio encima.
   *
   * Va aparte del interruptor y no mezclado con el, porque las dos cosas pueden
   * ser distintas: un motocarro lleno esta ocupado y no disponible, y es
   * exactamente cuando mas falta hace que se le vea moverse.
   */
  riding: boolean;
}

export function useLocationReporting({
  driverId,
  coords,
  available,
  riding,
}: UseLocationReportingParams): LocationReporting {
  const intervaloDisponible = useNumericSetting(
    'location_interval_available_seconds',
    INTERVALO_DISPONIBLE,
  );
  const intervaloEnViaje = useNumericSetting(
    'location_interval_in_ride_seconds',
    INTERVALO_EN_VIAJE,
  );
  const distanciaMinima = useNumericSetting('location_min_distance_m', DISTANCIA_MINIMA_M);

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

  /** La ultima posicion que se llego a enviar, para medir cuanto se ha movido. */
  const ultimaEnviadaRef = useRef<Coordinates | null>(null);

  /** Si la aplicacion esta a la vista. Fuera de ella no se envia (D116). */
  const enPrimerPlanoRef = useRef(AppState.currentState === 'active');

  const activo = (available || riding) && driverId !== null;
  const intervaloSegundos = riding ? intervaloEnViaje : intervaloDisponible;

  const enviar = useCallback(async () => {
    if (driverId === null || !enPrimerPlanoRef.current) return;

    const posicion = coordsRef.current;
    if (posicion === null) return;

    const resultado = await reportLocation(driverId, posicion);

    if (resultado.ok) {
      // Se apunta lo que de verdad salio, no lo ultimo que dijo el GPS: si el
      // envio fallo, la distancia hay que medirla desde el ultimo punto que el
      // servidor conoce, no desde uno que nunca llego.
      ultimaEnviadaRef.current = posicion;
      setLastSentAt(Date.now());
      setError(null);
    } else {
      setError(resultado.failure.message);
    }
  }, [driverId]);

  useEffect(() => {
    coordsRef.current = coords;
  }, [coords]);

  /**
   * La mitad de los cincuenta metros.
   *
   * Solo durante un viaje. Mientras el conductor unicamente esta disponible, su
   * posicion sirve para elegir a quien ofrecerle un servicio, y adelantar envios
   * por cada calle que recorre seria gastar bateria y datos en afinar una
   * decision que no cambia.
   */
  useEffect(() => {
    if (!activo || !riding || coords === null) return;

    const ultima = ultimaEnviadaRef.current;

    // Sin un punto anterior no hay distancia que medir. Del primer envio ya se
    // encarga el temporizador, que arranca sin esperar.
    if (ultima === null) return;
    if (distanceInMeters(ultima, coords) < distanciaMinima) return;

    // Diferido, como en el resto del proyecto: el compilador de React rechaza un
    // setState alcanzable desde el cuerpo de un efecto.
    const id = setTimeout(() => void enviar(), 0);
    return () => clearTimeout(id);
  }, [activo, riding, coords, distanciaMinima, enviar]);

  useEffect(() => {
    if (!activo) {
      return;
    }

    let vigente = true;

    const enviarSiVigente = () => {
      if (!vigente) return;
      void enviar();
    };

    const listener = AppState.addEventListener('change', (siguiente) => {
      enPrimerPlanoRef.current = siguiente === 'active';
      // Al volver de segundo plano se manda enseguida, sin esperar al siguiente
      // turno: el conductor lleva un rato invisible y lo que quiere es volver a
      // estar disponible ya.
      if (enPrimerPlanoRef.current) enviarSiVigente();
    });

    // El primer envio no espera al intervalo. Encender el interruptor y tardar
    // treinta segundos en existir para el sistema seria una espera que el
    // conductor no entiende, y ademas justo la que decide si recibe la solicitud
    // que esta entrando en este momento.
    //
    // Diferido con un temporizador de cero, como en el resto del proyecto: el
    // compilador de React rechaza un setState alcanzable desde el cuerpo de un
    // efecto.
    const primero = setTimeout(enviarSiVigente, 0);
    const repeticion = setInterval(enviarSiVigente, intervaloSegundos * 1000);

    return () => {
      vigente = false;
      clearTimeout(primero);
      clearInterval(repeticion);
      listener.remove();
    };
  }, [activo, intervaloSegundos, enviar]);

  return { lastSentAt, error };
}
