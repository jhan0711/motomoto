import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, radius, spacing, useTheme } from '@/theme';

import type { EarningsPeriod } from './types';

export interface PeriodToggleProps {
  value: EarningsPeriod;
  onChange: (value: EarningsPeriod) => void;
}

const OPCIONES: readonly { valor: EarningsPeriod; etiqueta: string }[] = [
  { valor: 'today', etiqueta: 'Hoy' },
  { valor: 'week', etiqueta: 'Esta semana' },
];

/** Que periodo de recaudo se esta mirando. Mismo patron que ServiceTypeToggle. */
export function PeriodToggle({ value, onChange }: PeriodToggleProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.contenedor, { borderColor: colors.border }]}>
      {OPCIONES.map((opcion) => {
        const activo = value === opcion.valor;
        return (
          <Pressable
            key={opcion.valor}
            accessibilityRole="button"
            accessibilityState={{ selected: activo }}
            onPress={() => onChange(opcion.valor)}
            style={({ pressed }) => [
              styles.opcion,
              {
                backgroundColor: activo
                  ? colors.brandSubtle
                  : pressed
                    ? colors.surfacePressed
                    : 'transparent',
              },
            ]}
          >
            <Text variant="bodyStrong" color={activo ? 'brand' : 'textSecondary'}>
              {opcion.etiqueta}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  contenedor: {
    borderRadius: radius.md,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.xxs,
    padding: spacing.xxs,
  },
  opcion: {
    alignItems: 'center',
    borderRadius: radius.sm,
    flex: 1,
    justifyContent: 'center',
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.sm,
  },
});
