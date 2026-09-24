import { Minus, Plus, Users } from 'lucide-react-native';
import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

export interface PassengerCountProps {
  value: number;
  onChange: (value: number) => void;
  /** Techo configurado por la empresa. Viene de `app_settings`, no del codigo. */
  max: number;
}

/**
 * Cuantos viajan.
 *
 * Un control de menos y mas, y no tres botones fijos con los numeros. Los
 * botones fijos serian un toque mas rapido con el maximo actual de tres, y
 * dejarian de servir el dia que la empresa suba el limite: el maximo es un dato
 * de la flota (R11), no una constante del programa.
 *
 * El aviso de que hay que pedir dos servicios aparece solo cuando el pasajero
 * intenta pasarse del limite. Tenerlo siempre en pantalla ocuparia sitio
 * permanentemente para advertir de algo que casi nunca ocurre: la mayoria de los
 * viajes son de una persona.
 */
export function PassengerCount({ value, onChange, max }: PassengerCountProps) {
  const { colors } = useTheme();
  const [avisoLimite, setAvisoLimite] = useState(false);

  const bajar = useCallback(() => {
    if (value <= 1) return;
    setAvisoLimite(false);
    onChange(value - 1);
  }, [value, onChange]);

  const subir = useCallback(() => {
    if (value >= max) {
      // No es un error del pasajero: es una limitacion del vehiculo, y se le
      // dice que puede hacer en lugar de solo que no puede.
      setAvisoLimite(true);
      return;
    }
    setAvisoLimite(false);
    onChange(value + 1);
  }, [value, max, onChange]);

  return (
    <View style={styles.contenedor}>
      <View style={styles.fila}>
        <Users size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />

        <View style={styles.textos}>
          <Text variant="bodyStrong">Pasajeros</Text>
          <Text variant="caption" color="textSecondary">
            {value === 1 ? 'Vas solo' : `Van ${value} personas`}
          </Text>
        </View>

        <View style={[styles.control, { borderColor: colors.border }]}>
          <BotonPaso
            icon={Minus}
            etiqueta="Quitar un pasajero"
            deshabilitado={value <= 1}
            onPress={bajar}
          />

          <Text variant="subheading" align="center" style={styles.numero}>
            {value}
          </Text>

          <BotonPaso
            icon={Plus}
            etiqueta="Añadir un pasajero"
            // Nunca deshabilitado: pulsarlo en el maximo es lo que muestra la
            // explicacion. Un boton apagado no explica nada.
            deshabilitado={false}
            atenuado={value >= max}
            onPress={subir}
          />
        </View>
      </View>

      {avisoLimite && (
        <Text variant="caption" color="textSecondary">
          Un motocarro lleva hasta {max} pasajeros. Si van más, pide dos servicios por separado.
        </Text>
      )}
    </View>
  );
}

interface BotonPasoProps {
  icon: typeof Plus;
  etiqueta: string;
  deshabilitado: boolean;
  /** Se ve apagado pero sigue respondiendo, para poder explicar el limite. */
  atenuado?: boolean;
  onPress: () => void;
}

function BotonPaso({
  icon: Icon,
  etiqueta,
  deshabilitado,
  atenuado = false,
  onPress,
}: BotonPasoProps) {
  const { colors } = useTheme();
  const apagado = deshabilitado || atenuado;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={etiqueta}
      accessibilityState={{ disabled: deshabilitado }}
      disabled={deshabilitado}
      onPress={onPress}
      // El control mide 40 dp de alto para no dominar la hoja. El area tactil
      // llega a los 48 dp que exige D48 gracias a este margen invisible.
      hitSlop={{ top: 4, bottom: 4, left: 4, right: 4 }}
      style={({ pressed }) => [
        styles.boton,
        { backgroundColor: pressed && !apagado ? colors.surfacePressed : 'transparent' },
      ]}
    >
      <Icon
        size={iconSize.md}
        color={apagado ? colors.textTertiary : colors.textPrimary}
        strokeWidth={iconStrokeWidth}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  boton: {
    alignItems: 'center',
    borderRadius: radius.md,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  contenedor: {
    gap: spacing.sm,
  },
  control: {
    alignItems: 'center',
    borderRadius: radius.full,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
  },
  fila: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: MIN_TOUCH_TARGET,
  },
  numero: {
    minWidth: 28,
  },
  textos: {
    flex: 1,
    gap: spacing.xxs,
  },
});
