import { PowerOff } from 'lucide-react-native';
import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, radius, spacing, useTheme } from '@/theme';

import type { UnavailableReason, UnavailableReasonCode } from './driver-service';
import { UNAVAILABLE_REASON_CODES, UNAVAILABLE_REASON_LABELS } from './unavailable-reason';

export interface UnavailableReasonModalProps {
  visible: boolean;
  onCancel: () => void;
  onConfirm: (reason: UnavailableReason) => void;
  /** Bloquea las opciones mientras setAvailability esta en vuelo. */
  confirming: boolean;
}

const DETALLE_MAX = 140;

/**
 * Que motivo elige el conductor antes de apagar el interruptor (D270).
 *
 * Elegir una opcion YA ES confirmar, salvo "Otro": esa abre un campo de texto
 * porque el detalle es lo que le da sentido a la opcion, y solo entonces hay
 * algo mas que confirmar. Las otras cuatro no necesitan un segundo toque: son
 * lo bastante concretas por si solas, y esto pasa varias veces al dia.
 */
export function UnavailableReasonModal({
  visible,
  onCancel,
  onConfirm,
  confirming,
}: UnavailableReasonModalProps) {
  const { colors } = useTheme();
  // Se reinicia al cerrar y no al elegir "otro", para que reabrir el modal
  // nunca herede el detalle de una vez anterior que el conductor no confirmo.
  const [otroElegido, setOtroElegido] = useState(false);
  const [detalle, setDetalle] = useState('');

  function cerrar() {
    setOtroElegido(false);
    setDetalle('');
    onCancel();
  }

  function elegir(code: UnavailableReasonCode) {
    if (code === 'otro') {
      setOtroElegido(true);
      return;
    }
    onConfirm({ code });
  }

  return (
    <Modal
      visible={visible}
      onRequestClose={cerrar}
      title="¿Por qué te desconectas?"
      description="La empresa lo usa para revisar los motivos más comunes."
      icon={PowerOff}
      cancelLabel="Cancelar"
    >
      <View style={styles.opciones}>
        {UNAVAILABLE_REASON_CODES.map((code) => (
          <Pressable
            key={code}
            accessibilityRole="button"
            accessibilityLabel={UNAVAILABLE_REASON_LABELS[code]}
            disabled={confirming}
            onPress={() => elegir(code)}
            style={({ pressed }) => [
              styles.opcion,
              {
                borderColor: colors.border,
                backgroundColor: pressed ? colors.surfacePressed : 'transparent',
              },
            ]}
          >
            <Text variant="body">{UNAVAILABLE_REASON_LABELS[code]}</Text>
          </Pressable>
        ))}
      </View>

      {otroElegido && (
        <View style={styles.detalle}>
          <Input
            value={detalle}
            onChangeText={setDetalle}
            placeholder="Cuéntanos qué pasó (opcional)"
            maxLength={DETALLE_MAX}
            autoCapitalize="sentences"
            autoCorrect={false}
            returnKeyType="done"
          />
          <Button
            label="Desconectarme"
            variant="primary"
            fullWidth
            loading={confirming}
            onPress={() => onConfirm({ code: 'otro', detail: detalle })}
          />
        </View>
      )}
    </Modal>
  );
}

const styles = StyleSheet.create({
  detalle: {
    gap: spacing.md,
    marginTop: spacing.md,
    width: '100%',
  },
  opcion: {
    borderRadius: radius.lg,
    borderWidth: StyleSheet.hairlineWidth,
    justifyContent: 'center',
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.lg,
  },
  opciones: {
    gap: spacing.sm,
    width: '100%',
  },
});
