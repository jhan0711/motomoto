import { Wallet } from 'lucide-react-native';
import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { formatAmount } from '@/features/fare/format-amount';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

import {
  fetchMyBalance,
  fetchMyLedger,
  type DriverBalance,
  type LedgerEntry,
} from './balance-service';

const ETIQUETA: Record<LedgerEntry['kind'], string> = {
  topup: 'Recarga',
  commission: 'Comisión de un servicio',
  adjustment: 'Ajuste de la empresa',
};

/** Con el signo delante: "+$10.000" / "-$200". `formatAmount` no pinta signos. */
function conSigno(valor: number): string {
  return `${valor < 0 ? '-' : '+'}${formatAmount(Math.abs(valor))}`;
}

/**
 * Su saldo y sus ultimos movimientos.
 *
 * No pinta NADA mientras el interruptor de la empresa este apagado (D278): un
 * conductor que ve "Saldo $0" sin que nadie le cobre pensaria que algo esta mal.
 * Tampoco hay boton de recargar todavia: la pasarela va en otra entrega, y un
 * boton que no hace nada es peor que ninguno. Mientras tanto se le dice a quien
 * acudir.
 */
export function BalanceCard() {
  const { colors } = useTheme();
  const [saldo, setSaldo] = useState<DriverBalance | null>(null);
  const [movimientos, setMovimientos] = useState<LedgerEntry[]>([]);

  const cargar = useCallback(async () => {
    const s = await fetchMyBalance();
    if (!s.ok || s.data === null) return;
    setSaldo(s.data);

    if (!s.data.enforced) return;
    const m = await fetchMyLedger(10);
    if (m.ok) setMovimientos(m.data);
  }, []);

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  if (saldo === null || !saldo.enforced) return null;

  return (
    <Card variant="outlined" padding="md">
      <View style={styles.cabecera}>
        <Wallet size={iconSize.md} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <View style={styles.cabeceraTextos}>
          <Text variant="caption" color="textTertiary">
            SALDO
          </Text>
          <Text variant="title" color={saldo.canWork ? 'textPrimary' : 'danger'}>
            {saldo.balance < 0 ? `-${formatAmount(-saldo.balance)}` : formatAmount(saldo.balance)}
          </Text>
        </View>
      </View>

      <Text variant="caption" color="textSecondary">
        {`La empresa descuenta el ${String(saldo.commissionPercent).replace('.', ',')}% de cada servicio terminado.`}
      </Text>

      {!saldo.canWork && (
        <Text variant="caption" color="danger" style={styles.aviso}>
          {`Tu saldo no alcanza para recibir servicios (mínimo ${formatAmount(saldo.minRequired)}). Comunícate con la empresa para recargar: la recarga mínima es de ${formatAmount(saldo.minTopup)}.`}
        </Text>
      )}

      {movimientos.length > 0 && (
        <View style={styles.lista}>
          {movimientos.map((m) => (
            <View key={m.id} style={styles.movimiento}>
              <View style={styles.cabeceraTextos}>
                <Text variant="body">{ETIQUETA[m.kind]}</Text>
                <Text variant="caption" color="textTertiary">
                  {new Date(m.createdAt).toLocaleDateString('es-CO', {
                    day: 'numeric',
                    month: 'short',
                  })}
                  {m.reason !== null ? ` · ${m.reason}` : ''}
                </Text>
              </View>
              <Text variant="bodyStrong" color={m.amount < 0 ? 'textSecondary' : 'brand'}>
                {conSigno(m.amount)}
              </Text>
            </View>
          ))}
        </View>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  aviso: {
    marginTop: spacing.sm,
  },
  cabecera: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    marginBottom: spacing.xs,
  },
  cabeceraTextos: {
    flex: 1,
  },
  lista: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  movimiento: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
});
