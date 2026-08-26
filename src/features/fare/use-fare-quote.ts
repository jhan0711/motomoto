import { useEffect, useState } from 'react';

import { quoteFare } from './fare-service';
import type { CargoItem, FareQuote, ServiceType } from './types';

export interface UseFareQuoteInput {
  serviceType: ServiceType;
  passengerCount: number;
  originLatitude: number | null;
  originLongitude: number | null;
  originPlaceId: string | null;
  destinationLatitude: number | null;
  destinationLongitude: number | null;
  destinationPlaceId: string | null;
  cargo: CargoItem[];
}

/** Por que todavia no hay cotizacion, cuando no la hay por un motivo normal. */
export type FareQuotePending = 'origin' | 'cargo';

export interface UseFareQuoteResult {
  quote: FareQuote | null;
  loading: boolean;
  /** Nulo cuando no hay nada que reportar, incluidas las esperas normales de `pending`. */
  error: string | null;
  /** El codigo del error del servidor, para que la pantalla decida si ofrece "elige de la lista" u otra cosa. */
  errorCode: string | null;
  /**
   * Por que no hay cotizacion todavia, cuando el motivo es normal y no un
   * error: falta saber de donde sale (D233, sin esto no se puede saber si el
   * origen es una vereda) o es una encomienda a la que aun no se le agrego
   * nada. Nulo en cualquier otro caso, incluido mientras `loading` es true.
   */
  pending: FareQuotePending | null;
}

/**
 * La cotizacion en vivo del servicio, mientras el pasajero decide.
 *
 * Mismo patron que el efecto de la ruta en `passenger/index.tsx`: se limpia el
 * resultado en el render en cuanto cambia cualquier entrada, para no dejar un
 * fotograma con el precio del destino anterior bajo el destino nuevo, y la
 * peticion se difiere con un `setTimeout(...,0)` porque el compilador de React
 * rechaza un setState alcanzable sincronamente desde un efecto.
 *
 * NO SE PREGUNTA SI FALTA EL ORIGEN O EL DESTINO, Y NO SE PREGUNTA SI ES
 * ENCOMIENDA SIN CARGA TODAVIA. Lo primero porque no hay nada que cotizar: D233
 * necesita los dos extremos para saber si alguno es una vereda, y sin
 * ubicacion conocida -D137, "Continuar sin ubicacion"- el origen puede faltar
 * aun con destino elegido. Lo segundo porque el servidor responderia
 * PARCEL_NEEDS_CARGO en cuanto el pasajero toca "Encomienda" y antes de que
 * haya tenido ocasion de agregar nada, y eso se veria como un error rojo por
 * elegir una opcion valida. La pantalla trata las dos esperas como lo que son,
 * no como fallos.
 */
export function useFareQuote(input: UseFareQuoteInput): UseFareQuoteResult {
  const [quote, setQuote] = useState<FareQuote | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errorCode, setErrorCode] = useState<string | null>(null);

  const cargaClave = [...input.cargo]
    .map((c) => `${c.cargoTypeId}:${c.quantity}`)
    .sort()
    .join(',');

  const clave = [
    input.serviceType,
    input.passengerCount,
    input.originLatitude,
    input.originLongitude,
    input.originPlaceId,
    input.destinationLatitude,
    input.destinationLongitude,
    input.destinationPlaceId,
    cargaClave,
  ].join('|');

  // El resultado caduca en cuanto cambia cualquiera de las entradas. Se limpia
  // en el render y no dentro del efecto, mismo motivo que la ruta: sin esto se
  // ve un fotograma con el precio del destino anterior bajo el destino nuevo.
  const [claveAnterior, setClaveAnterior] = useState(clave);
  if (clave !== claveAnterior) {
    setClaveAnterior(clave);
    setQuote(null);
    setError(null);
    setErrorCode(null);
  }

  const hayOrigen = input.originLatitude !== null && input.originLongitude !== null;
  const hayDestino = input.destinationLatitude !== null && input.destinationLongitude !== null;
  const hayCarga = input.serviceType === 'passenger' || input.cargo.length > 0;

  const pending: FareQuotePending | null = !hayOrigen ? 'origin' : !hayCarga ? 'cargo' : null;

  const hayAlgoQueCotizar = hayOrigen && hayDestino && hayCarga;

  useEffect(() => {
    if (!hayAlgoQueCotizar) return;

    let vigente = true;

    // Diferido fuera del cuerpo del efecto, mismo motivo que en el efecto de la
    // ruta: el compilador de React rechaza un setState alcanzable
    // sincronamente desde aqui.
    const id = setTimeout(() => {
      void (async () => {
        setLoading(true);
        const resultado = await quoteFare({
          serviceType: input.serviceType,
          passengerCount: input.passengerCount,
          // Los `as number` son seguros: `hayAlgoQueCotizar` ya comprobo
          // `hayOrigen` y `hayDestino`.
          originLatitude: input.originLatitude as number,
          originLongitude: input.originLongitude as number,
          originPlaceId: input.originPlaceId,
          destinationLatitude: input.destinationLatitude as number,
          destinationLongitude: input.destinationLongitude as number,
          destinationPlaceId: input.destinationPlaceId,
          cargo: input.cargo,
        });
        if (!vigente) return;

        if (resultado.ok) {
          setQuote(resultado.data);
          setError(null);
          setErrorCode(null);
        } else {
          setQuote(null);
          setError(resultado.failure.message);
          setErrorCode(resultado.failure.code);
        }
        setLoading(false);
      })();
    }, 0);

    return () => {
      vigente = false;
      clearTimeout(id);
    };
    // clave resume todas las entradas que importan; usarla como dependencia
    // unica evita que un CargoItem[] recien creado en cada render dispare la
    // peticion cuando su contenido no cambio.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [clave, hayAlgoQueCotizar]);

  return { quote, loading, error, errorCode, pending };
}
