import { Circle, CircleAlert, Package, Route as RouteIcon } from 'lucide-react-native';
import { ActivityIndicator, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

import { formatAmount } from './format-amount';
import type { FareQuotePending } from './use-fare-quote';
import type { FareQuote } from './types';

export interface FareRowProps {
  quote: FareQuote | null;
  loading: boolean;
  error: string | null;
  /**
   * Por que todavia no hay cotizacion, cuando el motivo es normal: falta el
   * origen (D233, sin el no se sabe si sale de una vereda) o es una encomienda
   * sin carga todavia. Ninguno de los dos es un error -no va a resolverse
   * solo mostrando un giro, como si fuera una espera de red-, asi que se dice
   * que falta en vez de fingir que se esta calculando.
   */
  pending?: FareQuotePending | null;
}

const TEXTO_PENDIENTE: Record<FareQuotePending, string> = {
  origin: 'Necesitamos saber de dónde sales para ver el valor',
  cargo: 'Agrega una carga para ver el valor',
};

/**
 * El valor del servicio, antes de confirmar (D217).
 *
 * Igual criterio que la fila de distancia y tiempo que ya existia (D149): si no
 * hay dato no se pinta un numero fabricado, se pinta que se esta calculando o
 * el motivo por el que no se pudo.
 *
 * "Tarifa de Montañita" y no solo "$15.000" cuando el destino es rural (D228):
 * el pasajero ve de donde sale el numero antes de pagarlo, no despues.
 */
export function FareRow({ quote, loading, error, pending = null }: FareRowProps) {
  const { colors } = useTheme();

  if (pending !== null) {
    const Icon = pending === 'origin' ? Circle : Package;
    return (
      <View style={styles.fila}>
        <Icon size={iconSize.sm} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
        <Text variant="caption" color="textTertiary">
          {TEXTO_PENDIENTE[pending]}
        </Text>
      </View>
    );
  }

  if (error !== null) {
    return (
      <View style={styles.fila}>
        <CircleAlert
          size={iconSize.sm}
          color={colors.onDangerSubtle}
          strokeWidth={iconStrokeWidth}
        />
        <Text variant="caption" color="onDangerSubtle" style={styles.texto}>
          {error}
        </Text>
      </View>
    );
  }

  if (loading || quote === null) {
    return (
      <View style={styles.fila}>
        <ActivityIndicator size="small" color={colors.textTertiary} />
        <Text variant="caption" color="textTertiary">
          Calculando el valor
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.fila}>
      <RouteIcon size={iconSize.sm} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
      <Text variant="bodyStrong" style={styles.texto}>
        {formatAmount(quote.totalAmount)}
      </Text>
      {quote.reference !== null && (
        <Text variant="caption" color="textSecondary">
          Tarifa de {quote.reference}
        </Text>
      )}
      {quote.reference === null && quote.isNight && (
        <Text variant="caption" color="textSecondary">
          Tarifa nocturna
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  fila: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  texto: {
    flexShrink: 1,
  },
});
