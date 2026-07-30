import { Inbox } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, Switch, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { radius, spacing, useTheme } from '@/theme';

/**
 * Driver home.
 *
 * The availability switch is the single most important control in the driver
 * app: it decides whether this driver receives ride offers at all.
 *
 * Three deliberate decisions about how it looks:
 *
 *   - The state is the largest text on the screen, larger than the vehicle. The
 *     vehicle is reference data the driver never touches; the state is what they
 *     act on. Before, the vehicle number was drawn bigger than the state, which
 *     inverted the hierarchy and made both cards read as one indistinct block.
 *   - The whole card takes the brand colour when available, not just the switch.
 *     A driver checks this at a glance, outdoors, in sunlight, sometimes moving,
 *     and should recognise their state without reading a single word.
 *   - The vehicle card is deliberately quieter. One card is a control that
 *     changes something and the other is information that is never touched;
 *     dressing them the same is what made them look glued together.
 *
 * Receiving real requests is Phase 12, and location reporting is Phase 14. The
 * vehicle shown here is still placeholder data.
 */
export default function DriverHome() {
  const { colors } = useTheme();
  const { user } = useSession();
  const [available, setAvailable] = useState(false);

  return (
    <Screen scroll header={<Header title={`Hola, ${user?.fullName ?? 'conductor'}`} />}>
      <View style={styles.panels}>
        <Card
          variant="elevated"
          style={
            available
              ? { backgroundColor: colors.brandSubtle, borderColor: colors.brand, borderWidth: 1 }
              : undefined
          }
        >
          <View style={styles.statusRow}>
            <View style={styles.statusCopy}>
              <Text variant="title">{available ? 'Disponible' : 'No disponible'}</Text>
              <Text variant="caption" color="textSecondary">
                {available
                  ? 'Estás recibiendo solicitudes de servicio.'
                  : 'No recibirás solicitudes mientras estés en este estado.'}
              </Text>
            </View>
            <Switch
              value={available}
              onValueChange={setAvailable}
              accessibilityLabel="Cambiar disponibilidad"
              trackColor={{ false: colors.border, true: colors.brand }}
              thumbColor={colors.surface}
            />
          </View>
        </Card>

        <Card variant="outlined" padding="md" style={styles.vehicle}>
          <Text variant="caption" color="textTertiary">
            MOTORRATÓN ASIGNADO
          </Text>
          <Text variant="subheading">Motorratón 12</Text>
          <Text variant="caption" color="textSecondary">
            Placa ABC12 · Capacidad 3 pasajeros
          </Text>
        </Card>
      </View>

      <View style={styles.feed}>
        {available ? (
          <Spinner label="Esperando solicitudes cercanas" />
        ) : (
          <EmptyState
            icon={Inbox}
            title="Sin solicitudes"
            description="Cambia tu estado a disponible para empezar a recibir servicios."
          />
        )}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  feed: {
    marginTop: spacing.xl,
  },
  // Las dos tarjetas estaban pegadas: eran hermanas sin separacion, y Screen
  // solo aporta margen horizontal. Lo que parecia un hueco era la sombra.
  panels: {
    gap: spacing.md,
  },
  statusCopy: {
    flex: 1,
    gap: spacing.xxs,
  },
  statusRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  vehicle: {
    borderRadius: radius.md,
  },
});
