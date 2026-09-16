import { Minus, PackagePlus, Plus } from 'lucide-react-native';
import { useCallback } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ErrorState } from '@/components/ui/error-state';
import { Modal } from '@/components/ui/modal';
import { Spinner } from '@/components/ui/spinner';
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
  /**
   * El catalogo (`cargoTypes`) se pide perezosamente y en la primera vez de la
   * sesion puede no haber llegado todavia cuando el pasajero abre este dialogo
   * justo despues de tocar "Encomienda". Sin esto la lista se veia vacia y sin
   * explicacion -parecia rota- hasta que, ya en cache, la segunda vez aparecia
   * de golpe. Mismo `Spinner` que ya usa `usePlaces` para este mismo tipo de
   * catalogo perezoso en `passenger/destination.tsx`, no un `Skeleton`: es una
   * espera corta de un puñado de filas, no una lista paginada cuya forma valga
   * la pena anticipar.
   */
  loading: boolean;
  error: string | null;
  onRetry: () => void;
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
  loading,
  error,
  onRetry,
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
      {loading ? (
        <Spinner centered label="Cargando tipos de carga" />
      ) : error !== null ? (
        // Sin `offline`: un catalogo que no carga no es necesariamente por falta
        // de datos moviles, y el mensaje generico de ErrorState no lo supone.
        <ErrorState description={error} onRetry={onRetry} />
      ) : (
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
      )}
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
