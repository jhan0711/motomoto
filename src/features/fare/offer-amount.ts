import { formatAmount } from './format-amount';

/**
 * Lo que el pasajero escribe en el campo de su oferta, convertido en pesos.
 *
 * Solo digitos: el teclado numerico ya lo pide, pero pegar "4.500" o "$ 4500"
 * tambien pasa, y en espanol de Colombia el punto separa miles -nunca decimales-,
 * asi que quitarlo es leer bien el numero y no perder precision.
 *
 * Devuelve `null` cuando no hay un numero entero positivo. El campo vacio no es
 * un cero: es alguien que todavia no escribio nada, y la pantalla lo trata como
 * "sin oferta valida", no como "ofrece cero pesos".
 */
export function parseOfferAmount(texto: string): number | null {
  const digitos = texto.replace(/\D/g, '');
  if (digitos === '') return null;

  const valor = Number(digitos);
  // Un tope de digitos para que un pegado absurdo no llegue a `Infinity`; el tope
  // real -relativo a la tarifa de ese viaje- lo pone el servidor.
  if (!Number.isSafeInteger(valor) || valor <= 0) return null;

  return valor;
}

/** El texto del campo tras una edicion: solo digitos, sin ceros a la izquierda. */
export function sanitizeOfferText(texto: string): string {
  return texto.replace(/\D/g, '').replace(/^0+/, '').slice(0, 9);
}

/**
 * El texto de un campo de pesos tal como se ve mientras se escribe: "$12.500".
 *
 * Se guarda solo lo digitado (`sanitizeOfferText`) y esto solo lo pinta, asi que
 * el signo y los puntos nunca se cuelan en el valor. Vacio si no hay digitos: un
 * "$0" sobre un campo sin escribir taparia el marcador de posicion.
 */
export function formatAmountInput(texto: string): string {
  const digitos = sanitizeOfferText(texto);
  return digitos === '' ? '' : formatAmount(Number(digitos));
}
