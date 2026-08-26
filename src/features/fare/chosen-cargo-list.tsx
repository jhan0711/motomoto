import { Package, Plus, X } from 'lucide-react-native';
import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import { formatAmount } from './format-amount';
import type { CargoItem, CargoType } from './types';

export interface ChosenCargoListProps {
  cargoTypes: CargoType[];
  items: CargoItem[];
  onOpenPicker: () => void;
  onRemove: (cargoTypeId: string) => void;
  /**
   * Cambia el texto del boton y el estado vacio: en un viaje de pasajeros la
   * carga es opcional ("Agregar carga"), y en una encomienda es lo unico que
   * hay que decidir ("Agregar la carga").
   */
  required: boolean;
}

/**
 * Lo que ya se eligio, mas el boton para agregar mas.
 *
 * Vive fuera del selector: mientras el pasajero decide, quiere ver de un
 * vistazo que ha puesto en la lista sin tener que reabrir el dialogo cada vez.
 */
export function ChosenCargoList({
  cargoTypes,
  items,
  onOpenPicker,
  onRemove,
  required,
}: ChosenCargoListProps) {
  const { colors } = useTheme();

  const porNombre = new Map(cargoTypes.map((tipo) => [tipo.id, tipo]));

  return (
    <View style={styles.contenedor}>
      {items.length === 0 ? (
        <Text variant="caption" color="textSecondary">
          {required ? 'Todavía no agregaste ninguna carga.' : 'Sin carga adicional.'}
        </Text>
      ) : (
        items.map((item) => {
          const tipo = porNombre.get(item.cargoTypeId);
          if (tipo === undefined) return null;

          return (
            <View key={item.cargoTypeId} style={styles.fila}>
              <Package
                size={iconSize.sm}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />

              <Text variant="body" style={styles.nombre}>
                {tipo.name}
                {item.quantity > 1 ? ` ×${item.quantity}` : ''}
              </Text>

              <Text variant="caption" color="textSecondary">
                {formatAmount(tipo.amount * item.quantity)}
              </Text>

              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`Quitar ${tipo.name}`}
                onPress={() => onRemove(item.cargoTypeId)}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                style={({ pressed }) => [
                  styles.quitar,
                  { backgroundColor: pressed ? colors.surfacePressed : 'transparent' },
                ]}
              >
                <X size={iconSize.sm} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
              </Pressable>
            </View>
          );
        })
      )}

      <Pressable
        accessibilityRole="button"
        onPress={onOpenPicker}
        style={({ pressed }) => [
          styles.agregar,
          { backgroundColor: pressed ? colors.surfacePressed : 'transparent' },
        ]}
      >
        <Plus size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <Text variant="bodyStrong" color="brand">
          {items.length === 0 ? 'Agregar carga' : 'Agregar otra carga'}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  agregar: {
    alignItems: 'center',
    borderRadius: radius.sm,
    flexDirection: 'row',
    gap: spacing.xs,
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.xxs,
  },
  contenedor: {
    gap: spacing.xs,
  },
  fila: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  nombre: {
    flex: 1,
  },
  quitar: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
});
