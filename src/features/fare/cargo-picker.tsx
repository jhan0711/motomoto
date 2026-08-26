import { Minus, PackagePlus, Plus } from 'lucide-react-native';
import { useCallback } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { Modal } from '@/components/ui/modal';
import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import { formatAmount } from './format-amount';
import type { CargoItem, CargoType } from './types';

export interface CargoPickerProps {
  visible: boolean;
  onRequestClose: () => void;
  cargoTypes: CargoType[];
  items: CargoItem[];
  onChangeQuantity: (cargoTypeId: string, quantity: number) => void;
}

/**
 * Elegir que carga lleva el servicio, con cuanto de cada tipo.
 *
 * Un solo control por tipo, de menos y mas, en lugar de un boton de "agregar"
 * que crea filas repetidas: el servidor guarda una linea por tipo con su
 * cantidad (`rrc_one_line_per_type`), asi que dos bicicletas son un tipo con
 * cantidad dos, no dos filas iguales. El control refleja exactamente eso.
 *
 * "Agregar otra carga", que es lo que pidio la empresa, es simplemente subir el
 * numero de un tipo o poner otro tipo en uno: no hace falta un boton aparte.
 */
export function CargoPicker({
  visible,
  onRequestClose,
  cargoTypes,
  items,
  onChangeQuantity,
}: CargoPickerProps) {
  const cantidadDe = useCallback(
    (cargoTypeId: string) => items.find((item) => item.cargoTypeId === cargoTypeId)?.quantity ?? 0,
    [items],
  );

  return (
    <Modal
      visible={visible}
      onRequestClose={onRequestClose}
      title="Qué llevas"
      icon={PackagePlus}
      cancelLabel="Listo"
    >
      <ScrollView style={styles.lista} contentContainerStyle={styles.listaContenido}>
        {cargoTypes.map((tipo) => (
          <FilaTipoDeCarga
            key={tipo.id}
            tipo={tipo}
            cantidad={cantidadDe(tipo.id)}
            onChange={(cantidad) => onChangeQuantity(tipo.id, cantidad)}
          />
        ))}
      </ScrollView>
    </Modal>
  );
}

function FilaTipoDeCarga({
  tipo,
  cantidad,
  onChange,
}: {
  tipo: CargoType;
  cantidad: number;
  onChange: (cantidad: number) => void;
}) {
  const { colors } = useTheme();

  return (
    <View style={styles.fila}>
      <View style={styles.textos}>
        <Text variant="bodyStrong">{tipo.name}</Text>
        <Text variant="caption" color="textSecondary">
          {formatAmount(tipo.amount)} c/u
        </Text>
      </View>

      <View style={[styles.control, { borderColor: colors.border }]}>
        <BotonPaso
          icon={Minus}
          etiqueta={`Quitar ${tipo.name}`}
          deshabilitado={cantidad <= 0}
          onPress={() => onChange(cantidad - 1)}
        />

        <Text variant="subheading" align="center" style={styles.numero}>
          {cantidad}
        </Text>

        <BotonPaso
          icon={Plus}
          etiqueta={`Añadir ${tipo.name}`}
          deshabilitado={cantidad >= 20}
          onPress={() => onChange(cantidad + 1)}
        />
      </View>
    </View>
  );
}

function BotonPaso({
  icon: Icon,
  etiqueta,
  deshabilitado,
  onPress,
}: {
  icon: typeof Plus;
  etiqueta: string;
  deshabilitado: boolean;
  onPress: () => void;
}) {
  const { colors } = useTheme();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={etiqueta}
      accessibilityState={{ disabled: deshabilitado }}
      disabled={deshabilitado}
      onPress={onPress}
      hitSlop={{ top: 4, bottom: 4, left: 4, right: 4 }}
      style={({ pressed }) => [
        styles.boton,
        { backgroundColor: pressed && !deshabilitado ? colors.surfacePressed : 'transparent' },
      ]}
    >
      <Icon
        size={iconSize.md}
        color={deshabilitado ? colors.textTertiary : colors.textPrimary}
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
  lista: {
    maxHeight: 360,
    width: '100%',
  },
  listaContenido: {
    gap: spacing.sm,
  },
  numero: {
    minWidth: 24,
  },
  textos: {
    flex: 1,
    gap: spacing.xxs,
  },
});
