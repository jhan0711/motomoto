import { Package, UserRound } from 'lucide-react-native';
import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import type { ServiceType } from './types';

export interface ServiceTypeToggleProps {
  value: ServiceType;
  onChange: (value: ServiceType) => void;
}

/**
 * Pasajero contra encomienda. Los tres casos del encargo no se confunden entre
 * si: "pasajero solo" y "pasajero con carga" son el mismo boton, `'passenger'`,
 * y lo que los distingue es si hay algo en la lista de carga de mas abajo
 * (D224). Este control solo decide si va alguien a bordo o no.
 *
 * Dos botones grandes y no un selector desplegable: son solo dos opciones, y la
 * mayoria de los servicios van a ser "pasajero", asi que tiene que ser el toque
 * mas rapido de la pantalla, no uno que exija abrir nada.
 */
export function ServiceTypeToggle({ value, onChange }: ServiceTypeToggleProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.contenedor, { borderColor: colors.border }]}>
      <Opcion
        etiqueta="Pasajero"
        icon={UserRound}
        activo={value === 'passenger'}
        onPress={() => onChange('passenger')}
      />
      <Opcion
        etiqueta="Encomienda"
        icon={Package}
        activo={value === 'parcel'}
        onPress={() => onChange('parcel')}
      />
    </View>
  );
}

function Opcion({
  etiqueta,
  icon: Icon,
  activo,
  onPress,
}: {
  etiqueta: string;
  icon: typeof UserRound;
  activo: boolean;
  onPress: () => void;
}) {
  const { colors } = useTheme();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: activo }}
      onPress={onPress}
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
      <Icon
        size={iconSize.md}
        color={activo ? colors.brand : colors.textSecondary}
        strokeWidth={iconStrokeWidth}
      />
      <Text variant="bodyStrong" color={activo ? 'brand' : 'textSecondary'}>
        {etiqueta}
      </Text>
    </Pressable>
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
    flexDirection: 'row',
    gap: spacing.xs,
    justifyContent: 'center',
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.sm,
  },
});
