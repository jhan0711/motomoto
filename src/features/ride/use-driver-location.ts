import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import { supabase } from '@/lib/supabase';

import { fetchDriverLocation, type DriverLocation } from './ride-service';

/**
 * Donde esta el motorraton que viene a recoger al pasajero.
 *
 * POR QUE TIEMPO REAL Y NO SONDEO. El criterio de aceptacion 4 pide ver moverse
 * al conductor con menos de quince segundos de retraso. El conductor envia cada
 * diez (R9); preguntando cada diez, el peor caso son veinte y el criterio no se
 * cumple. Preguntando cada cinco serian doce consultas por minuto y por pasajero,
 * casi todas para descubrir que no ha cambiado nada.
 *
 * DEL EVENTO SOLO SE USA EL AVISO, igual que en `useRequestRealtime` y en
 * `useDriverOffers`. La fila que llega por el canal trae la posicion en el
 * formato binario de PostGIS, que habria que descifrar en el telefono: es lo
 * mismo que D131 descarto para los lugares. Al recibir el aviso se pregunta por
 * la funcion, que ya devuelve latitud y longitud separadas.
 *
 * EL FILTRO POR CONDUCTOR NO ES LA SEGURIDAD, ES EL AHORRO. Sin el, a este
 * telefono llegarian los eventos de toda la flota para descartarlos aqui. Quien
 * decide que puede ver es `driver_locations_select_active_passenger`, que se
 * aplica tambien en tiempo real.
 *
 * TAMBIEN SE RELEE AL VOLVER DE SEGUNDO PLANO, por lo mismo que D152: con el
 * telefono bloqueado el websocket puede caerse, y al volver el pasajero se
 * encontraria el motorraton donde estaba hace diez minutos.
 */
export function useDriverLocation(driverId: string | null): DriverLocation | null {
  const [location, setLocation] = useState<DriverLocation | null>(null);

  /**
   * Descarta respuestas de un conductor que ya no es el nuestro.
   *
   * Pasa de verdad: el pasajero cancela, vuelve a pedir y le toca otro. Una
   * respuesta lenta del primero llegaria despues y pintaria su motorraton.
   */
  const turno = useRef(0);

  const releer = useCallback(async () => {
    if (driverId === null) return;

    const mio = ++turno.current;
    const resultado = await fetchDriverLocation(driverId);

    if (mio !== turno.current) return;

    // Un fallo de red no borra lo que ya se sabe: la posicion de hace veinte
    // segundos sigue siendo mas util que un mapa sin motorraton, y la antiguedad
    // que se pinta al lado ya avisa de que no es de ahora.
    if (resultado.ok) {
      setLocation(resultado.data);
    }
  }, [driverId]);

  /**
   * Cambiar de conductor borra la posicion del anterior.
   *
   * Se ajusta en el render y no en un efecto, que es la forma que React
   * documenta para corregir estado cuando cambia una entrada, y la unica que no
   * deja un fotograma con el motorraton de otro servicio en el mapa.
   *
   * Pasa de verdad: el pasajero cancela, vuelve a pedir y le toca otro
   * conductor. Sin esto, el marcador del primero seguiria ahi hasta que llegara
   * la primera posicion del segundo.
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
        () => void releer(),
      )
      .subscribe();

    const listener = AppState.addEventListener('change', (siguiente) => {
      if (siguiente === 'active') void releer();
    });

    return () => {
      clearTimeout(primera);
      listener.remove();
      void supabase.removeChannel(canal);
      turno.current += 1;
    };
  }, [driverId, releer]);

  return location;
}
