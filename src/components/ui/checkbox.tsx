import { Check } from 'lucide-react-native';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { MIN_TOUCH_TARGET, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

export interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  /**
   * La etiqueta. Puede llevar `<Text onPress>` dentro para enlaces (como en la
   * casilla de "acepto los términos"): al tocar un enlace, React Native entrega
   * el toque al `Text` y no al `Pressable` de la fila.
   */
  children: ReactNode;
  /** Pinta el recuadro en rojo. El mensaje lo pone el formulario, no esto. */
  error?: boolean;
  disabled?: boolean;
  /** Para lectores de pantalla, ya que la etiqueta puede ser un nodo. */
  accessibilityLabel: string;
}

const BOX = 22;

/**
 * Casilla de verificación.
 *
 * No existía hasta la Fase 26: la usa la casilla de aceptación de los términos
 * en el registro, y es el único sitio del MVP donde hace falta una. El recuadro
 * es de 22 dp pero el área tocable llega a 48 con `hitSlop`, igual que el botón.
 */
export function Checkbox({
  checked,
  onChange,
  children,
  error = false,
  disabled = false,
  accessibilityLabel,
}: CheckboxProps) {
  const { colors } = useTheme();
  const slop = Math.max(0, (MIN_TOUCH_TARGET - BOX) / 2);

  const borderColor = error ? colors.danger : checked ? colors.brand : colors.border;

  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ checked, disabled }}
      accessibilityLabel={accessibilityLabel}
      disabled={disabled}
      hitSlop={{ top: slop, bottom: slop, left: slop, right: slop }}
      onPress={() => onChange(!checked)}
      style={styles.row}
    >
      <View
        style={[
          styles.box,
          {
            borderColor,
            backgroundColor: checked ? colors.brand : 'transparent',
            opacity: disabled ? 0.5 : 1,
          },
        ]}
      >
        {checked && <Check size={16} color={colors.onBrand} strokeWidth={iconStrokeWidth + 0.5} />}
      </View>
      <View style={styles.label}>{children}</View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  box: {
    alignItems: 'center',
    borderRadius: radius.sm,
    borderWidth: 2,
    height: BOX,
    justifyContent: 'center',
    marginTop: 1,
    width: BOX,
  },
  label: {
    flex: 1,
  },
  row: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.sm,
  },
});
