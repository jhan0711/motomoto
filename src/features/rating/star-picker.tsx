import { Star } from 'lucide-react-native';
import { Pressable, StyleSheet, View } from 'react-native';

import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

import { MAX_STARS } from './rating-service';

/**
 * Las estrellas, para elegir o para ensenar.
 *
 * Sin `onChange` es de solo lectura y no reacciona al dedo: es la misma pieza
 * pintando la calificacion que ya se dio, en el historial. Tener dos habria
 * significado que una se quedara con el estilo viejo.
 *
 * CADA ESTRELLA ES UN BOTON DE 48 dp, aunque el dibujo mida 32. Es el minimo de
 * area tactil del sistema de diseno, y aqui importa mas que en otros sitios:
 * cinco objetivos pequenos y pegados son cinco formas de calificar sin querer lo
 * que no se queria.
 *
 * El color va relleno, no solo en el borde. Una estrella hueca y una llena se
 * distinguen sin depender del color, que es lo que hace falta para quien no
 * distingue el amarillo del gris (H14).
 */

export interface StarPickerProps {
  /** Cuantas estrellas estan marcadas. Cero es "sin elegir todavia". */
  value: number;
  /** Omitido, el control es de solo lectura. */
  onChange?: (stars: number) => void;
  size?: number;
}

export function StarPicker({ value, onChange, size = 32 }: StarPickerProps) {
  const { colors } = useTheme();
  const editable = onChange !== undefined;

  return (
    <View
      style={styles.fila}
      accessibilityRole={editable ? 'radiogroup' : 'text'}
      accessibilityLabel={
        editable ? 'Calificación en estrellas' : `Calificación: ${value} de ${MAX_STARS}`
      }
    >
      {Array.from({ length: MAX_STARS }, (_, indice) => {
        const estrella = indice + 1;
        const marcada = estrella <= value;

        const dibujo = (
          <Star
            size={size}
            color={marcada ? colors.warning : colors.textTertiary}
            fill={marcada ? colors.warning : 'transparent'}
            strokeWidth={iconStrokeWidth}
          />
        );

        if (!editable) {
          return (
            <View key={estrella} style={styles.hueco}>
              {dibujo}
            </View>
          );
        }

        return (
          <Pressable
            key={estrella}
            onPress={() => onChange(estrella)}
            accessibilityRole="radio"
            accessibilityState={{ selected: marcada }}
            accessibilityLabel={estrella === 1 ? '1 estrella' : `${estrella} estrellas`}
            style={({ pressed }) => [styles.boton, pressed && styles.pulsado]}
            hitSlop={spacing.xs}
          >
            {dibujo}
          </Pressable>
        );
      })}
    </View>
  );
}

const AREA_TACTIL = 48;

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', gap: spacing.xs },
  boton: {
    alignItems: 'center',
    height: AREA_TACTIL,
    justifyContent: 'center',
    width: AREA_TACTIL,
  },
  pulsado: { opacity: 0.6 },
  hueco: { alignItems: 'center', justifyContent: 'center', paddingRight: iconSize.xs / 2 },
});
