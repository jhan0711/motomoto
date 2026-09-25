import { toRideFailure } from '@/features/ride/errors';
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
