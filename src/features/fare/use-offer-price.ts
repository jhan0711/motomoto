import { useCallback, useEffect, useState } from 'react';

import { fetchMinOfferAmount } from './fare-service';
import { parseOfferAmount, sanitizeOfferText } from './offer-amount';

/**
 * El valor que el pasajero ofrece por el servicio (D277).
 *
 * Nace con la tarifa sugerida y el pasajero puede escribir otra. La edicion se
 * guarda junto con la tarifa sobre la que se hizo: si esa tarifa cambia -otro
 * numero de pasajeros, otro destino, una carga mas-, lo escrito ya no responde a
 * este viaje y el campo vuelve a la sugerida. Se decide al leer, sin efecto: un
 * efecto dejaria un fotograma con la oferta vieja bajo la tarifa nueva.
 */
export function useOfferPrice(suggested: number | null) {
  const [editada, setEditada] = useState<{ texto: string; sobre: number } | null>(null);
  const [minimo, setMinimo] = useState<number | null>(null);

  // Una sola lectura. El piso solo cambia si la empresa toca la tabla de
  // tarifas, y aun asi el servidor lo vuelve a exigir: esto es para avisar sin
  // esperar el rechazo, no para decidir.
  useEffect(() => {
    let vigente = true;
    void fetchMinOfferAmount().then((valor) => {
      if (vigente && valor !== null) setMinimo(valor);
    });
    return () => {
      vigente = false;
    };
  }, []);

  const vigenteEditada = editada !== null && editada.sobre === suggested ? editada : null;
  const texto = vigenteEditada?.texto ?? (suggested === null ? '' : String(suggested));
  const amount = parseOfferAmount(texto);

  let error: string | null = null;
  if (suggested !== null) {
    if (amount === null) {
      error = 'Escribe el valor que ofreces.';
    } else if (minimo !== null && amount < minimo) {
      error = 'Es menos que la tarifa mínima.';
    }
  }

  const setText = useCallback(
    (nuevo: string) => {
      if (suggested === null) return;
      setEditada({ texto: sanitizeOfferText(nuevo), sobre: suggested });
    },
    [suggested],
  );

  // Estable a proposito: `confirmar` la lleva entre sus dependencias.
  const reset = useCallback(() => setEditada(null), []);

  return { text: texto, amount, error, minimum: minimo, setText, reset };
}
