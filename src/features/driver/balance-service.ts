import { messageForCode, toRideFailure } from '@/features/ride/errors';
import { supabase } from '@/lib/supabase';

import type { Result } from './driver-service';

/**
 * El saldo prepagado del conductor (D278).
 *
 * `enforced` es el interruptor de la empresa: mientras este apagado no se cobra
 * comision ni se bloquea a nadie, y la pantalla no muestra nada de esto. Se lee
 * del servidor y no se decide aqui, porque encenderlo es una decision de negocio
 * que no debe depender de que el conductor tenga la ultima version de la app.
 */
export interface DriverBalance {
  /** En pesos. Puede ser negativo: una comision mayor que el saldo lo deja en deuda. */
  balance: number;
  /** Lo minimo para trabajar: el porcentaje de comision sobre el viaje mas barato. */
  minRequired: number;
  enforced: boolean;
  commissionPercent: number;
  minTopup: number;
  /** Falso solo cuando el cobro esta encendido y el saldo no alcanza. */
  canWork: boolean;
}

export type LedgerKind = 'topup' | 'commission' | 'adjustment';

export interface LedgerEntry {
  id: string;
  kind: LedgerKind;
  /** Con signo: recargas y ajustes a favor suman, comisiones restan. */
  amount: number;
  reason: string | null;
  createdAt: string;
}

/** Nulo si la cuenta no es de un conductor: el servidor no devuelve fila. */
export async function fetchMyBalance(): Promise<Result<DriverBalance | null>> {
  const { data, error } = await supabase.rpc('get_my_balance');

  if (error) {
    return { ok: false, failure: toRideFailure(error) };
  }

  const fila = (data ?? [])[0];

  if (fila === undefined) {
    return { ok: true, data: null };
  }

  return {
    ok: true,
    data: {
      balance: fila.balance,
      minRequired: fila.min_required,
      enforced: fila.enforced,
      commissionPercent: Number(fila.commission_percent),
      minTopup: fila.min_topup,
      canWork: fila.can_work,
    },
  };
}

/**
 * Pide a la Edge Function `create-topup` un cobro de Wompi ya firmado.
 *
 * La firma del cobro se calcula en el servidor con un secreto que la app no
 * tiene: por eso el telefono no arma la URL, solo la abre. Y solo se abre una URL
 * del checkout de Wompi -defensa barata contra que una respuesta rara mande al
 * conductor a cualquier otro sitio-.
 *
 * Que la funcion conteste bien NO significa que el conductor haya pagado: el
 * saldo sube cuando Wompi avisa al servidor, y la pantalla lo relee despues.
 */
export async function createTopup(
  amount: number,
): Promise<Result<{ url: string; reference: string }>> {
  const { data, error } = await supabase.functions.invoke('create-topup', { body: { amount } });

  if (error) {
    // Un error HTTP de la funcion trae el cuerpo con `{ error: CODIGO }` dentro de
    // `context`. Se lee aqui y se traduce por el codigo, nunca por el texto.
    let codigo = '';
    try {
      const cuerpo = await (error as { context?: Response }).context?.json();
      codigo = typeof cuerpo?.error === 'string' ? cuerpo.error : '';
    } catch {
      // Sin cuerpo legible: cae en el mensaje generico de abajo.
    }

    return {
      ok: false,
      failure: { code: codigo || 'TOPUP_FAILED', message: messageForCode(codigo) },
    };
  }

  const url = typeof data?.url === 'string' ? data.url : '';
  const reference = typeof data?.reference === 'string' ? data.reference : '';

  if (!url.startsWith('https://checkout.wompi.co/') || reference === '') {
    return { ok: false, failure: toRideFailure(new Error('respuesta de create-topup invalida')) };
  }

  return { ok: true, data: { url, reference } };
}

export async function fetchMyLedger(limit = 20): Promise<Result<LedgerEntry[]>> {
  const { data, error } = await supabase.rpc('list_my_ledger', { p_limit: limit });

  if (error) {
    return { ok: false, failure: toRideFailure(error) };
  }

  return {
    ok: true,
    data: (data ?? []).map((fila) => ({
      id: fila.id,
      kind: fila.kind,
      amount: fila.amount,
      reason: fila.reason,
      createdAt: fila.created_at,
    })),
  };
}
