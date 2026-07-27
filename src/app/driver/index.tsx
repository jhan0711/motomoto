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
import { spacing, useTheme } from '@/theme';

/**
 * Driver home.
 *
 * The availability switch is the single most important control in the driver
 * app: it decides whether this driver receives ride offers at all. It sits at
 * the top, is large, and states the consequence in plain words rather than just
 * saying on or off.
 *
 * Receiving real requests is Phase 12, and location reporting is Phase 14.
 */
export default function DriverHome() {
  const { colors } = useTheme();
  const { user } = useSession();
  const [available, setAvailable] = useState(false);

  return (
    <Screen scroll header={<Header title={`Hola, ${user?.fullName ?? 'conductor'}`} />}>
      <Card variant="elevated">
        <View style={styles.statusRow}>
          <View style={styles.statusCopy}>
            <Text variant="subheading">{available ? 'Disponible' : 'No disponible'}</Text>
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

      <Card variant="outlined" padding="md">
        <Text variant="caption" color="textTertiary">
          MOTORRATÓN ASIGNADO
        </Text>
        <Text variant="title">Motorratón 12</Text>
        <Text variant="caption" color="textSecondary">
          Placa ABC12 · Capacidad 3 pasajeros
        </Text>
      </Card>

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
  statusCopy: {
    flex: 1,
    gap: spacing.xxs,
  },
  statusRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
});
