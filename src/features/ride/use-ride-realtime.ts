import { useEffect } from 'react';

import { supabase } from '@/lib/supabase';

/**
 * Avisa cuando el viaje asignado cambia de estado.
 *
 * POR QUE NO SIRVE `useRequestRealtime`, que ya existe. Aquel escucha
 * `ride_requests`, y de las cuatro transiciones del conductor solo dos llegan a
 * esa tabla: iniciar el recorrido y finalizarlo. Salir hacia el punto de recogida
 * y **anunciar la llegada** se quedan en `rides`, asi que por aquel canal no
 * suena nada. Se comprobo en pantalla: el conductor salia y el pasajero seguia
 * leyendo "un motocarro tomó tu servicio".
 *
 * Y de las dos que se perdian, la de la llegada es la que mas importa: es el
 * aviso que hace que el pasajero salga a la calle.
 *
 * SON DOS HOOKS Y NO UNO PORQUE SON DOS TABLAS con dos filtros distintos. Este
 * filtra por el identificador del viaje, que el pasajero conoce en cuanto alguien
 * acepta; el otro no puede filtrar por nada equivalente. Unificarlos obligaria a
 * pasarles tabla y filtro por parametro, que es un hook generico de suscripcion
 * disfrazado y esconde justo lo que aqui hay que explicar.
 *
 * Del evento solo se usa el aviso, como en los demas: la fila que llega no trae
 * al conductor ni al vehiculo, asi que al recibirla se vuelve a preguntar por
 * `get_active_request`, que lo trae todo junto.
 */
export function useRideRealtime(rideId: string | null, onChange: () => void): void {
  useEffect(() => {
    if (rideId === null) return;

    const canal = supabase
      .channel(`pasajero-viaje-${rideId}`)
      .on(
        'postgres_changes',
        // UPDATE y no '*': la fila la crea el conductor al aceptar, y de eso el
        // pasajero ya se entera por el cambio de estado de su solicitud.
        { event: 'UPDATE', schema: 'public', table: 'rides', filter: `id=eq.${rideId}` },
        () => onChange(),
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(canal);
    };
  }, [rideId, onChange]);
}
