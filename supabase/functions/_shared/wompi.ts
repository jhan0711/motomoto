/**
 * Piezas puras de la integracion con Wompi (D279): la firma del cobro y la
 * verificacion de los avisos.
 *
 * Viven aparte de las Edge Functions, y sin ninguna API de Deno, por una razon:
 * son las dos cuentas que deciden si se acredita dinero, y asi se pueden probar
 * con jest como cualquier otro codigo, sin levantar un servidor de funciones.
 *
 * Solo usan `crypto.subtle` y `TextEncoder`, que existen igual en Deno (donde
 * corre en produccion) y en Node (donde corren las pruebas).
 */

async function sha256Hex(texto: string): Promise<string> {
  const bytes = new TextEncoder().encode(texto);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Comparacion en tiempo constante.
 *
 * Un `===` corta en el primer caracter distinto, y eso deja medir por fuera
 * cuantos caracteres de una firma falsa iban bien. Con un checksum de 64
 * caracteres es poco practico, pero costar nada evitarlo.
 */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let diferencia = 0;
  for (let i = 0; i < a.length; i++) {
    diferencia |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diferencia === 0;
}

/**
 * La firma de integridad del cobro: SHA256(referencia + monto en centavos +
 * moneda + secreto de integridad).
 *
 * Se calcula SIEMPRE en el servidor. Si el secreto viajara en la app, cualquiera
 * podria fabricar un cobro por el monto que quisiera.
 */
export async function integritySignature(
  reference: string,
  amountInCents: number,
  currency: string,
  integritySecret: string,
): Promise<string> {
  return sha256Hex(`${reference}${amountInCents}${currency}${integritySecret}`);
}

export interface CheckoutParams {
  publicKey: string;
  reference: string;
  /** En pesos. Wompi pide centavos: se convierte aqui y en ningun otro sitio. */
  amountPesos: number;
  integritySecret: string;
  redirectUrl: string;
}

/** La URL del Web Checkout de Wompi, ya firmada. */
export async function buildCheckoutUrl(p: CheckoutParams): Promise<string> {
  const amountInCents = Math.round(p.amountPesos * 100);
  const signature = await integritySignature(p.reference, amountInCents, 'COP', p.integritySecret);

  const url = new URL('https://checkout.wompi.co/p/');
  url.searchParams.set('public-key', p.publicKey);
  url.searchParams.set('currency', 'COP');
  url.searchParams.set('amount-in-cents', String(amountInCents));
  url.searchParams.set('reference', p.reference);
  url.searchParams.set('signature:integrity', signature);
  url.searchParams.set('redirect-url', p.redirectUrl);
  return url.toString();
}

/** Lo que trae un aviso de Wompi que nos importa. Todo lo demas se ignora. */
export interface WompiEvent {
  event: string;
  data: Record<string, unknown>;
  timestamp: number;
  signature: {
    properties: string[];
    checksum: string;
  };
}

/** Un valor por su ruta con puntos, "transaction.id", dentro de `data`. */
function valueAtPath(data: Record<string, unknown>, path: string): unknown {
  let actual: unknown = data;

  for (const parte of path.split('.')) {
    if (typeof actual !== 'object' || actual === null) return undefined;
    actual = (actual as Record<string, unknown>)[parte];
  }
  return actual;
}

/** Lo minimo para dejar pasar un cuerpo como aviso; el resto se comprueba al firmar. */
export function parseWompiEvent(cuerpo: unknown): WompiEvent | null {
  if (typeof cuerpo !== 'object' || cuerpo === null) return null;
  const e = cuerpo as Record<string, unknown>;

  const signature = e.signature as Record<string, unknown> | undefined;

  if (
    typeof e.event !== 'string' ||
    typeof e.data !== 'object' ||
    e.data === null ||
    typeof e.timestamp !== 'number' ||
    typeof signature !== 'object' ||
    signature === null ||
    !Array.isArray(signature.properties) ||
    !signature.properties.every((p) => typeof p === 'string') ||
    typeof signature.checksum !== 'string'
  ) {
    return null;
  }

  return {
    event: e.event,
    data: e.data as Record<string, unknown>,
    timestamp: e.timestamp,
    signature: {
      properties: signature.properties as string[],
      checksum: signature.checksum,
    },
  };
}

/**
 * Verifica que un aviso lo firmo Wompi.
 *
 * El algoritmo es el de su documentacion: concatenar los valores de las
 * propiedades que el propio aviso lista en `signature.properties`, anadir el
 * `timestamp` y el secreto de eventos, aplicar SHA256 y comparar con el
 * `checksum`. **La lista de propiedades se lee del aviso y no se fija aqui**: cambia
 * segun el evento, y fijarla es la forma de que un dia deje de verificar bien
 * sin que nada avise.
 *
 * Si falta alguna de las propiedades que el aviso dice usar, se rechaza: una
 * propiedad ausente concatenaria una cadena vacia y firmaria un valor que nadie
 * calculo.
 */
export async function verifyEventChecksum(
  event: WompiEvent,
  eventsSecret: string,
  headerChecksum?: string | null,
): Promise<boolean> {
  if (eventsSecret === '') return false;

  let concatenado = '';

  for (const propiedad of event.signature.properties) {
    const valor = valueAtPath(event.data, propiedad);

    if (typeof valor !== 'string' && typeof valor !== 'number' && typeof valor !== 'boolean') {
      return false;
    }
    concatenado += String(valor);
  }

  const esperado = await sha256Hex(`${concatenado}${event.timestamp}${eventsSecret}`);
  const recibido = event.signature.checksum.toLowerCase();

  if (!timingSafeEqual(esperado, recibido)) return false;

  // La cabecera repite el checksum. Si llega y no coincide con el del cuerpo, algo
  // manipulo uno de los dos.
  if (headerChecksum != null && headerChecksum !== '') {
    return timingSafeEqual(esperado, headerChecksum.toLowerCase());
  }

  return true;
}

/** La transaccion que trae un aviso, con lo que necesitamos de ella. */
export interface WompiTransactionRef {
  id: string;
  reference: string;
}

export function transactionRefOf(event: WompiEvent): WompiTransactionRef | null {
  const t = event.data.transaction;
  if (typeof t !== 'object' || t === null) return null;

  const { id, reference } = t as Record<string, unknown>;
  if (typeof id !== 'string' || typeof reference !== 'string') return null;

  return { id, reference };
}
