import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

import type { ChosenPoint } from '@/features/destination/types';
import type { CargoItem, ServiceType } from '@/features/fare/types';

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
   *
   * Solo importa cuando `serviceType` es `'passenger'`. En una encomienda el
   * servidor exige cero (D220), y eso lo decide la pantalla al confirmar, no
   * este numero: cambiar de "pasajero" a "encomienda" y volver no debe hacer
   * que el pasajero tenga que volver a elegir cuantos van.
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
  /** Pasajero solo o con carga, contra encomienda sola. Los tres casos no se confunden. */
  serviceType: ServiceType;
  /** Que es la encomienda, en palabras del pasajero. Solo aplica si `serviceType` es `'parcel'`. */
  parcelDescription: string;
  /**
   * Lo que lleva el servicio, sea un pasajero con carga o una encomienda sola.
   *
   * Una lista y no un tipo de carga suelto (D224): la empresa pidio poder
   * anadir mas de una carga, incluso de tipos distintos.
   */
  cargoItems: CargoItem[];
}

interface RideDraftValue extends RideDraft {
  setOrigin: (point: ChosenPoint | null) => void;
  setDestination: (point: ChosenPoint | null) => void;
  setPassengerCount: (count: number) => void;
  setPickupReference: (reference: string) => void;
  setServiceType: (serviceType: ServiceType) => void;
  setParcelDescription: (description: string) => void;
  /**
   * Fija cuantas unidades de un tipo de carga lleva el servicio.
   *
   * Cero quita la linea en vez de dejarla en cero: una carga con cantidad cero
   * no es una carga, y guardarla asi solo trasladaria el problema a quien lea
   * la lista despues. Es la unica forma de tocar `cargoItems`: no hay un
   * "agregar" y un "quitar" por separado, porque los dos son el mismo caso con
   * cantidades distintas.
   */
  setCargoItemQuantity: (cargoTypeId: string, quantity: number) => void;
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
  const [serviceType, setServiceTypeState] = useState<ServiceType>('passenger');
  const [parcelDescription, setParcelDescription] = useState('');
  const [cargoItems, setCargoItems] = useState<CargoItem[]>([]);

  const clear = useCallback(() => {
    setOrigin(null);
    setDestination(null);
    setPassengerCount(1);
    // Se borra con el resto. Una referencia sirve para un punto concreto: si
    // sobreviviera al viaje descartado, el siguiente saldria con un "frente a la
    // tienda" que ya no corresponde a donde esta el pasajero. Es el mismo fallo
    // que tuvo el origen antes de que descartar el viaje lo limpiara entero.
    setPickupReference('');
    setServiceTypeState('passenger');
    setParcelDescription('');
    setCargoItems([]);
  }, []);

  /**
   * Cambiar de tipo de servicio limpia la descripcion de encomienda.
   *
   * Mismo motivo que la referencia al descartar un viaje: una descripcion de
   * "Bulto de café" no significa nada en un viaje de pasajeros, y si
   * sobreviviera al cambio, volver a "encomienda" mas tarde la resucitaria como
   * si el pasajero la hubiera vuelto a escribir. La carga NO se limpia: un
   * pasajero que agrego una bicicleta y cambia de opinion a "encomienda sola"
   * probablemente sigue llevando la misma bicicleta.
   */
  const setServiceType = useCallback((next: ServiceType) => {
    setServiceTypeState(next);
    if (next === 'passenger') {
      setParcelDescription('');
    }
  }, []);

  const setCargoItemQuantity = useCallback((cargoTypeId: string, quantity: number) => {
    setCargoItems((actual) => {
      const sinEse = actual.filter((item) => item.cargoTypeId !== cargoTypeId);
      if (quantity <= 0) {
        return sinEse;
      }
      // El mismo techo de 20 que impone el servidor (`rrc_quantity_range`). Se
      // repite aqui para que el control de mas y menos tenga un limite antes de
      // que la peticion salga, no solo despues de que el servidor la rechace.
      const acotada = Math.min(20, Math.round(quantity));
      return [...sinEse, { cargoTypeId, quantity: acotada }];
    });
  }, []);

  const value = useMemo<RideDraftValue>(
    () => ({
      origin,
      destination,
      passengerCount,
      pickupReference,
      serviceType,
      parcelDescription,
      cargoItems,
      setOrigin,
      setDestination,
      setPassengerCount,
      setPickupReference,
      setServiceType,
      setParcelDescription,
      setCargoItemQuantity,
      clear,
      // Solo el destino. El origen en null es valido y significa la ubicacion
      // actual, que es justo lo que quiere la mayoria. La cantidad siempre tiene
      // un valor valido, asi que tampoco condiciona nada. La descripcion y la
      // carga de la encomienda las exige el servidor y las comprueba la propia
      // pantalla del resumen, que es quien conoce las reglas de cada caso.
      isReady: destination !== null,
    }),
    [
      origin,
      destination,
      passengerCount,
      pickupReference,
      serviceType,
      parcelDescription,
      cargoItems,
      setServiceType,
      setCargoItemQuantity,
      clear,
    ],
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
