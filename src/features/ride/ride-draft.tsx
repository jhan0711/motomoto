import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

import type { ChosenPoint } from '@/features/destination/types';

/**
 * La solicitud a medio hacer.
 *
 * Elegir un viaje ocupa varias pantallas: el destino en una, el punto en el mapa
 * en otra, la confirmacion en la de inicio. Sin un sitio comun donde dejar lo ya
 * elegido, cada vuelta atras lo perderia y habria que empezar de nuevo.
 *
 * En memoria y no en disco, a proposito. Esto es un formulario a medio llenar,
 * no un viaje en curso. Si la aplicacion se cierra del todo, empezar otra vez es
 * razonable y ademas honesto: la ubicacion habra cambiado. Restaurar un VIAJE
 * ACTIVO tras cerrar la aplicacion es otra cosa, y es de la Fase 15.
 */

export interface RideDraft {
  /**
   * De donde sale. En null significa "mi ubicacion actual", que es el caso
   * normal y por eso es el valor inicial: el pasajero no deberia tener que
   * decir donde esta si el telefono ya lo sabe.
   */
  origin: ChosenPoint | null;
  destination: ChosenPoint | null;
  /**
   * Cuantos viajan. Empieza en 1, que es el caso mayoritario: quien va solo no
   * deberia tener que tocar nada.
   */
  passengerCount: number;
  /**
   * Como encontrar al pasajero en el punto de recogida. Vacio casi siempre.
   *
   * Cadena y no `string | null` porque es lo que un campo de texto tiene dentro,
   * y el vacio ya significa "no escribio nada". Traducirlo a nulo es cosa del
   * servicio, que es quien habla con el servidor.
   */
  pickupReference: string;
}

interface RideDraftValue extends RideDraft {
  setOrigin: (point: ChosenPoint | null) => void;
  setDestination: (point: ChosenPoint | null) => void;
  setPassengerCount: (count: number) => void;
  setPickupReference: (reference: string) => void;
  clear: () => void;
  /** Hay lo suficiente para pasar al siguiente paso. */
  isReady: boolean;
}

const RideDraftContext = createContext<RideDraftValue | null>(null);

export function RideDraftProvider({ children }: { children: ReactNode }) {
  const [origin, setOrigin] = useState<ChosenPoint | null>(null);
  const [destination, setDestination] = useState<ChosenPoint | null>(null);
  const [passengerCount, setPassengerCount] = useState(1);
  const [pickupReference, setPickupReference] = useState('');

  const clear = useCallback(() => {
    setOrigin(null);
    setDestination(null);
    setPassengerCount(1);
    // Se borra con el resto. Una referencia sirve para un punto concreto: si
    // sobreviviera al viaje descartado, el siguiente saldria con un "frente a la
    // tienda" que ya no corresponde a donde esta el pasajero. Es el mismo fallo
    // que tuvo el origen antes de que descartar el viaje lo limpiara entero.
    setPickupReference('');
  }, []);

  const value = useMemo<RideDraftValue>(
    () => ({
      origin,
      destination,
      passengerCount,
      pickupReference,
      setOrigin,
      setDestination,
      setPassengerCount,
      setPickupReference,
      clear,
      // Solo el destino. El origen en null es valido y significa la ubicacion
      // actual, que es justo lo que quiere la mayoria. La cantidad siempre tiene
      // un valor valido, asi que tampoco condiciona nada.
      isReady: destination !== null,
    }),
    [origin, destination, passengerCount, pickupReference, clear],
  );

  return <RideDraftContext.Provider value={value}>{children}</RideDraftContext.Provider>;
}

/**
 * Lanza excepcion fuera del proveedor, mismo criterio que `useSession` (D75).
 * Devolver un borrador vacio se confundiria con "todavia no ha elegido nada" y
 * el fallo aparecerian tres pantallas mas adelante, sin rastro de la causa.
 */
export function useRideDraft(): RideDraftValue {
  const value = useContext(RideDraftContext);
  if (value === null) {
    throw new Error('useRideDraft se usó fuera de RideDraftProvider');
  }
  return value;
}
