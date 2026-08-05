import { CircleAlert } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * Error de un formulario completo, no de un campo.
 *
 * Los errores de campo los muestra el propio Input con su `errorText`. Esto es
 * para lo que no pertenece a ningun campo: credenciales incorrectas, falta de
 * conexion, limite de intentos.
 *
 * Se anuncia como alerta para que el lector de pantalla lo lea al aparecer. Un
 * mensaje de error que solo existe visualmente deja fuera a quien no lo ve.
 */
export function FormError({ message }: { message: string | null }) {
  const { colors } = useTheme();

  if (message === null) {
    return null;
  }

  return (
    <View accessibilityRole="alert" style={[styles.box, { backgroundColor: colors.dangerSubtle }]}>
      <CircleAlert size={iconSize.md} color={colors.onDangerSubtle} strokeWidth={iconStrokeWidth} />
      <View style={styles.copy}>
        <Text variant="caption" color="onDangerSubtle">
          {message}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    alignItems: 'flex-start',
    borderRadius: radius.md,
    flexDirection: 'row',
    gap: spacing.sm,
    padding: spacing.md,
  },
  copy: {
    flex: 1,
  },
});
