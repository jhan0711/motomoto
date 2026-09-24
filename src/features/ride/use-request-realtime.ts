import { useEffect } from 'react';

import { supabase } from '@/lib/supabase';

/**
 * Avisa cuando una solicitud cambia, sin que nadie tenga que hacer nada.
 *
 * **LO USAN LOS DOS LADOS, Y ESO NO ES UN ATAJO.** El pasajero quiere saber que
 * alguien acepto su servicio; el conductor, que la solicitud que tiene delante ya
 * se la llevo otro o que el pasajero la cancelo. Es la misma tabla y el mismo
 * evento, y **quien ve que no lo decide este codigo sino las politicas**, que se
 * aplican tambien en tiempo real: al pasajero le llegan las suyas por
 * `ride_requests_select_own`, y al conductor las que le ofrecieron por
 * `ride_requests_select_offered_driver`. Escribir dos hooks casi iguales seria
 * duplicar para acabar dependiendo igualmente de las mismas dos politicas.
 *
 * Mismo criterio que `useDriverOffers`: **del evento solo se usa el aviso, no su
 * contenido**. La fila que llega por el canal no trae ni el conductor ni el
 * motocarro, asi que al recibirla se vuelve a preguntar. Una lectura de mas cada
 * vez que suena, a cambio de tener todo lo que hay que ensenar.
 *
 * QUE RESUELVE. Hasta la Fase 13 el pasajero solo se enteraba de algo al abrir la
 * aplicacion o al volver de segundo plano (D152). Un conductor aceptaba su
 * servicio a los diez segundos y el seguia leyendo "buscando motocarro" con el
 * motocarro ya en camino. Bastaba con no tocar el telefono para no enterarse.
 *
 * ESTO NO SUSTITUYE A D152, SE SUMA. La relectura al volver de segundo plano
 * sigue haciendo falta: con el telefono bloqueado el websocket puede caerse, y al
 * volver hay que preguntar por lo que haya pasado mientras tanto. El tiempo real
 * cubre a quien mira la pantalla; la relectura, a quien vuelve a ella.
 *
 * El nombre del canal lo pone quien llama. Dos pantallas distintas no pueden
 * compartirlo: Supabase identifica la suscripcion por ese nombre.
 */
export function useRequestRealtime(
  active: boolean,
  onChange: () => void,
  channelName: string,
): void {
  useEffect(() => {
    if (!active) return;

    const canal = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        // UPDATE y no '*': la solicitud la crea el propio pasajero, asi que el
        // INSERT es la unica novedad de la que ya esta enterado. Lo que no puede
        // saber por su cuenta es lo que le hacen despues, y eso siempre llega
        // como una actualizacion del estado.
        { event: 'UPDATE', schema: 'public', table: 'ride_requests' },
        () => onChange(),
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(canal);
    };
  }, [active, onChange, channelName]);
}
