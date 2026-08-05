import { Circle, MapPin, Phone, Users } from 'lucide-react-native';
import { Linking, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

import type { DriverRide } from './driver-service';

/**
 * Un servicio aceptado, con quien hay que recoger.
 *
 * El telefono es un boton y no un texto. El conductor va a usarlo con una mano,
 * a veces en movimiento, y copiar diez digitos a la aplicacion de llamadas es
 * justo el tipo de friccion que hace que la gente termine llamando por otro
 * canal y deje de usar la aplicacion.
 *
 * Las transiciones del servicio, que son "voy en camino", "llegue", "iniciar" y
 * "finalizar", son de la Fase 15. Esta tarjeta enseña a quien recoger y donde;
 * moverlo por sus estados es otra cosa.
 */

export interface ActiveRideCardProps {
  ride: DriverRide;
}

export function ActiveRideCard({ ride }: ActiveRideCardProps) {
  const { colors } = useTheme();

  return (
    <Card variant="elevated" style={{ borderColor: colors.brand, borderWidth: 1 }}>
      <Text variant="caption" color="textTertiary">
        SERVICIO ACEPTADO
      </Text>
      <Text variant="subheading">{ride.passengerName}</Text>

      <View style={[styles.separador, { backgroundColor: colors.border }]} />

      <View style={styles.fila}>
        <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <View style={styles.filaTextos}>
          <Text variant="caption" color="textTertiary">
            RECOGER EN
          </Text>
          <Text variant="body" numberOfLines={2}>
            {ride.origin.label}
          </Text>
        </View>
      </View>

      <View style={styles.fila}>
        <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <View style={styles.filaTextos}>
          <Text variant="caption" color="textTertiary">
            LLEVAR A
          </Text>
          <Text variant="body" numberOfLines={2}>
            {ride.destination.label}
          </Text>
        </View>
      </View>

      <View style={styles.fila}>
        <Users size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" style={styles.filaTextos}>
          {ride.passengerCount === 1 ? 'Un pasajero' : `${ride.passengerCount} pasajeros`}
        </Text>
      </View>

      <Button
        label={`Llamar a ${primerNombre(ride.passengerName)}`}
        variant="secondary"
        icon={Phone}
        fullWidth
        style={styles.llamar}
        onPress={() => void Linking.openURL(`tel:${ride.passengerPhone}`)}
      />
    </Card>
  );
}

/**
 * Solo el primer nombre en el boton de llamar.
 *
 * "Llamar a Jhan" cabe en una linea; "Llamar a Jhan Roldan Restrepo" se corta o
 * encoge la letra. El nombre completo ya esta arriba, en grande.
 */
function primerNombre(nombre: string): string {
  const partes = nombre.trim().split(/\s+/);
  return partes[0] ?? nombre;
}

const styles = StyleSheet.create({
  fila: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 40,
    paddingVertical: spacing.xs,
  },
  filaTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  llamar: {
    marginTop: spacing.md,
  },
  separador: {
    height: StyleSheet.hairlineWidth,
    marginVertical: spacing.sm,
  },
});
