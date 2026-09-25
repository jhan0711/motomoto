/**
 * @jest-environment node
 */
import { createHash } from 'node:crypto';

import {
  buildCheckoutUrl,
  integritySignature,
  parseWompiEvent,
  timingSafeEqual,
  transactionRefOf,
  verifyEventChecksum,
  type WompiEvent,
} from '../wompi';

// Llaves INVENTADAS: ninguna es de Wompi. Las pruebas no tocan ninguna cuenta.
const SECRETO_EVENTOS = 'test_events_inventado_para_pruebas';
const SECRETO_INTEGRIDAD = 'test_integrity_inventado_para_pruebas';

function sha256(texto: string): string {
  return createHash('sha256').update(texto).digest('hex');
}

/** Un aviso firmado como lo firma Wompi, calculado aparte con `node:crypto`. */
function avisoFirmado(
  transaction: Record<string, unknown>,
  propiedades = ['transaction.id', 'transaction.status', 'transaction.amount_in_cents'],
  timestamp = 1530291411,
  secreto = SECRETO_EVENTOS,
): WompiEvent {
  const valores = propiedades.map((p) =>
    String((transaction as Record<string, unknown>)[p.split('.')[1] ?? '']),
  );
  return {
    event: 'transaction.updated',
    data: { transaction },
    timestamp,
    signature: {
      properties: propiedades,
      checksum: sha256(`${valores.join('')}${timestamp}${secreto}`),
    },
  };
}

const TX = {
  id: '1234-1610641025-49201',
  reference: 'AGA-0123456789abcdef0123456789abcdef',
  status: 'APPROVED',
  amount_in_cents: 2000000,
};

describe('integritySignature', () => {
  it('es SHA256 de referencia + centavos + moneda + secreto, en ese orden', async () => {
    const esperado = sha256(`ref-1${2000000}COP${SECRETO_INTEGRIDAD}`);
    await expect(integritySignature('ref-1', 2000000, 'COP', SECRETO_INTEGRIDAD)).resolves.toBe(
      esperado,
    );
  });

  it('cambia si cambia el monto', async () => {
    const a = await integritySignature('ref-1', 2000000, 'COP', SECRETO_INTEGRIDAD);
    const b = await integritySignature('ref-1', 2000001, 'COP', SECRETO_INTEGRIDAD);
    expect(a).not.toBe(b);
  });
});

describe('buildCheckoutUrl', () => {
  it('convierte pesos a centavos y firma con el monto en centavos', async () => {
    const url = new URL(
      await buildCheckoutUrl({
        publicKey: 'pub_test_inventada',
        reference: TX.reference,
        amountPesos: 20000,
        integritySecret: SECRETO_INTEGRIDAD,
        redirectUrl: 'https://amalfigo.app/recarga',
      }),
    );

    expect(url.origin + url.pathname).toBe('https://checkout.wompi.co/p/');
    expect(url.searchParams.get('amount-in-cents')).toBe('2000000');
    expect(url.searchParams.get('currency')).toBe('COP');
    expect(url.searchParams.get('reference')).toBe(TX.reference);
    expect(url.searchParams.get('signature:integrity')).toBe(
      sha256(`${TX.reference}2000000COP${SECRETO_INTEGRIDAD}`),
    );
  });

  it('no deja el secreto de integridad en la URL', async () => {
    const url = await buildCheckoutUrl({
      publicKey: 'pub_test_inventada',
      reference: TX.reference,
      amountPesos: 10000,
      integritySecret: SECRETO_INTEGRIDAD,
      redirectUrl: 'https://amalfigo.app/recarga',
    });
    expect(url).not.toContain(SECRETO_INTEGRIDAD);
  });
});

describe('verifyEventChecksum', () => {
  it('acepta un aviso bien firmado', async () => {
    await expect(verifyEventChecksum(avisoFirmado(TX), SECRETO_EVENTOS)).resolves.toBe(true);
  });

  it('rechaza un aviso firmado con otro secreto', async () => {
    const falso = avisoFirmado(TX, undefined, undefined, 'otro_secreto');
    await expect(verifyEventChecksum(falso, SECRETO_EVENTOS)).resolves.toBe(false);
  });

  it('rechaza un aviso al que le cambiaron el monto despues de firmarlo', async () => {
    const aviso = avisoFirmado(TX);
    (aviso.data.transaction as Record<string, unknown>).amount_in_cents = 9999999;
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(false);
  });

  it('rechaza un aviso al que le cambiaron el estado despues de firmarlo', async () => {
    const aviso = avisoFirmado({ ...TX, status: 'DECLINED' });
    (aviso.data.transaction as Record<string, unknown>).status = 'APPROVED';
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(false);
  });

  it('rechaza si cambia el timestamp', async () => {
    const aviso = avisoFirmado(TX);
    aviso.timestamp += 1;
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(false);
  });

  it('usa la lista de propiedades del aviso, no una fija', async () => {
    const aviso = avisoFirmado(TX, ['transaction.id', 'transaction.status']);
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(true);
  });

  it('rechaza si el aviso lista una propiedad que no trae', async () => {
    const aviso = avisoFirmado(TX);
    aviso.signature.properties = [...aviso.signature.properties, 'transaction.no_existe'];
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(false);
  });

  it('rechaza cuando el secreto configurado esta vacio', async () => {
    await expect(verifyEventChecksum(avisoFirmado(TX, undefined, undefined, ''), '')).resolves.toBe(
      false,
    );
  });

  it('acepta el checksum en mayusculas', async () => {
    const aviso = avisoFirmado(TX);
    aviso.signature.checksum = aviso.signature.checksum.toUpperCase();
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS)).resolves.toBe(true);
  });

  it('con cabecera: acepta si coincide y rechaza si no', async () => {
    const aviso = avisoFirmado(TX);
    await expect(
      verifyEventChecksum(aviso, SECRETO_EVENTOS, aviso.signature.checksum),
    ).resolves.toBe(true);
    await expect(verifyEventChecksum(aviso, SECRETO_EVENTOS, 'deadbeef')).resolves.toBe(false);
  });
});

describe('parseWompiEvent', () => {
  it('lee un aviso completo', () => {
    expect(parseWompiEvent(avisoFirmado(TX))).not.toBeNull();
  });

  it('descarta cuerpos que no son avisos', () => {
    expect(parseWompiEvent(null)).toBeNull();
    expect(parseWompiEvent('hola')).toBeNull();
    expect(parseWompiEvent({ event: 'transaction.updated' })).toBeNull();
    expect(
      parseWompiEvent({ ...avisoFirmado(TX), signature: { properties: [1], checksum: 'x' } }),
    ).toBeNull();
  });
});

describe('transactionRefOf', () => {
  it('saca id y referencia', () => {
    expect(transactionRefOf(avisoFirmado(TX))).toEqual({ id: TX.id, reference: TX.reference });
  });

  it('devuelve nulo si no hay transaccion', () => {
    const aviso = avisoFirmado(TX);
    aviso.data = {};
    expect(transactionRefOf(aviso)).toBeNull();
  });
});

describe('timingSafeEqual', () => {
  it('compara cadenas', () => {
    expect(timingSafeEqual('abc', 'abc')).toBe(true);
    expect(timingSafeEqual('abc', 'abd')).toBe(false);
    expect(timingSafeEqual('abc', 'abcd')).toBe(false);
  });
});
