import { useCallback, useEffect, useState } from 'react';

import { supabase } from '@/lib/supabase';

import { fetchOffers, type DriverOffer } from './driver-service';

/**
 * Las solicitudes que le han ofrecido al conductor, en tiempo real (D158).
 *
 * El aviso llega empujado por el servidor. La alternativa era preguntar cada
 * pocos segundos, y con veinte segundos para responder (R2) eso se come la mitad
 * del tiempo del conductor: sondeando cada diez, la oferta le aparece cuando ya
 * le quedan diez. Medido en la prueba: por tiempo real llega en poco mas de un
 * segundo desde que el pasajero confirma.
 *
 * Del evento solo se usa el aviso, no su contenido. La fila de `ride_offers` no
 * trae ni el destino ni las etiquetas ni la distancia, asi que al recibirlo se
 * vuelve a pedir la lista completa. Una llamada de mas cada vez que suena, a
 * cambio de que la tarjeta tenga todo lo que el conductor necesita para decidir.
 *
 * LIMITE CONOCIDO DE ESTA FASE: si otro conductor acepta primero, esta lista no
 * se entera. La oferta se queda en pantalla hasta que caduca, y si el conductor
 * la toca recibe "otro motorratón tomó este servicio", que es un mensaje claro y
 * no un error. Enterarse en el momento exige publicar tambien `ride_requests`, y
 * eso es de la Fase 13.
 */

export interface UseDriverOffersResult {
  offers: DriverOffer[];
  error: string | null;
  /** La retira de la lista sin tocar el servidor. Para cuando su tiempo se agota. */
  removeOffer: (offerId: string) => void;
  refresh: () => void;
}

export function useDriverOffers(active: boolean): UseDriverOffersResult {
  const [offers, setOffers] = useState<DriverOffer[]>([]);
  const [error, setError] = useState<string | null>(null);

  const cargar = useCallback(async () => {
    const resultado = await fetchOffers();

    if (resultado.ok) {
      setOffers(resultado.data);
      setError(null);
    } else {
      setError(resultado.failure.message);
    }
  }, []);

  const removeOffer = useCallback((offerId: string) => {
    setOffers((actuales) => actuales.filter((o) => o.offerId !== offerId));
  }, []);

  const refresh = useCallback(() => {
    void cargar();
  }, [cargar]);

  /**
   * Al dejar de estar disponible se vacia la lista. Dejar tarjetas en pantalla
   * mientras el interruptor dice "no disponible" seria contradecirse a la vista.
   *
   * Se ajusta en el render y no dentro del efecto. La lista vacia es estado
   * derivado de `active`, no una tarea asincrona, y es la cuarta vez en el
   * proyecto que aparece esta regla: diferirla con un temporizador funcionaria,
   * pero dejaria un fotograma con las tarjetas viejas bajo un interruptor ya
   * apagado.
   */
  const [activoAnterior, setActivoAnterior] = useState(active);

  if (active !== activoAnterior) {
    setActivoAnterior(active);
    if (!active) {
      setOffers([]);
      setError(null);
    }
  }

  useEffect(() => {
    if (!active) return;

    const canal = supabase
      .channel('ofertas-del-conductor')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'ride_offers' },
        // Cada suscriptor recibe solo sus propias filas: las politicas de
        // seguridad se aplican tambien en tiempo real. Comprobado con dos
        // sesiones, una de conductor y otra de pasajero.
        () => void cargar(),
      )
      .subscribe();

    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto.
    const primera = setTimeout(() => void cargar(), 0);

    return () => {
      clearTimeout(primera);
      void supabase.removeChannel(canal);
    };
  }, [active, cargar]);

  return { offers, error, removeOffer, refresh };
}
