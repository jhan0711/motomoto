import { StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { radius, spacing, useTheme } from '@/theme';

import { formatTime } from './format-when';

/**
 * La linea de tiempo de un servicio.
 *
 * SOLO SE PINTAN LOS PASOS QUE OCURRIERON. Un servicio que se cancelo antes de
 * que el conductor llegara no tiene hora de llegada, y ensenar el paso vacio
 * sugeriria que falta un dato cuando lo que falta es el hecho.
 *
 * Las horas van sin fecha porque todo pasa el mismo dia salvo casos rarisimos, y
 * la fecha ya esta arriba en la cabecera. Repetirla en cada linea llenaria la
 * pantalla de ruido.
 */

export interface TimelineStep {
  label: string;
  /** Nulo si ese paso no llego a ocurrir. La linea no lo pinta. */
  at: string | null;
}

export function Timeline({ steps }: { steps: TimelineStep[] }) {
  const { colors } = useTheme();
  const ocurridos = steps.filter((paso): paso is { label: string; at: string } => paso.at !== null);

  if (ocurridos.length === 0) {
    return null;
  }

  return (
    <View>
      {ocurridos.map((paso, indice) => {
        const ultimo = indice === ocurridos.length - 1;

        return (
          <View key={paso.label} style={styles.fila}>
            <View style={styles.carril}>
              <View style={[styles.punto, { backgroundColor: colors.brand }]} />
              {!ultimo && <View style={[styles.hilo, { backgroundColor: colors.border }]} />}
            </View>

            <View style={[styles.textos, ultimo ? null : styles.textosConHueco]}>
              <Text variant="body">{paso.label}</Text>
              <Text variant="caption" color="textSecondary">
                {formatTime(new Date(paso.at))}
              </Text>
            </View>
          </View>
        );
      })}
    </View>
  );
}

const PUNTO = 10;

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', gap: spacing.md },
  carril: { alignItems: 'center', width: PUNTO },
  punto: { borderRadius: radius.full, height: PUNTO, marginTop: spacing.xs, width: PUNTO },
  // El hilo crece hasta el siguiente punto en lugar de medir una altura fija:
  // asi no se descuelga cuando una etiqueta ocupa dos lineas.
  hilo: { flex: 1, marginVertical: spacing.xxs, width: 1 },
  textos: { flex: 1, flexDirection: 'row', justifyContent: 'space-between' },
  textosConHueco: { paddingBottom: spacing.md },
});
