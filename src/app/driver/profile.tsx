import { Bike, LogOut, Phone, Star } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Header } from '@/components/ui/header';
import { Modal } from '@/components/ui/modal';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * Driver profile.
 *
 * Drivers can see far less than passengers can edit. Their vehicle, their unit
 * number and their approval status are set by the company from the web panel,
 * per the Phase 0 rules, so those fields are read-only here by design.
 */
export default function DriverProfile() {
  const { colors } = useTheme();
  const { user, signOut } = useSession();
  const [confirmingSignOut, setConfirmingSignOut] = useState(false);

  return (
    <Screen scroll header={<Header title="Mi perfil" />}>
      <View style={styles.identity}>
        <View style={[styles.avatar, { backgroundColor: colors.brandSubtle }]}>
          <Bike size={iconSize.xl} color={colors.brandStrong} strokeWidth={iconStrokeWidth} />
        </View>
        <Text variant="heading">{user?.fullName ?? 'Conductor'}</Text>
        <View style={styles.rating}>
          <Star size={iconSize.sm} color={colors.warning} strokeWidth={iconStrokeWidth} />
          <Text variant="caption" color="textSecondary">
            Sin calificaciones todavía
          </Text>
        </View>
      </View>

      <Card variant="outlined" padding="md">
        <Text variant="caption" color="textTertiary">
          MOTORRATÓN ASIGNADO
        </Text>
        <Text variant="title">Motorratón 12</Text>
        <Text variant="caption" color="textSecondary">
          Placa ABC12 · Capacidad 3 pasajeros
        </Text>
      </Card>

      <Card variant="outlined" padding="md">
        <View style={styles.row}>
          <Phone size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.rowCopy}>
            <Text variant="caption" color="textTertiary">
              Teléfono
            </Text>
            <Text variant="body">Sin registrar</Text>
          </View>
        </View>
      </Card>

      <Text variant="caption" color="textTertiary" align="center" style={styles.note}>
        Tu vehículo y tu número de unidad los gestiona la empresa. Si algún dato no es correcto,
        comunícalo a la administración.
      </Text>

      <Button
        label="Cerrar sesión"
        variant="secondary"
        icon={LogOut}
        fullWidth
        onPress={() => setConfirmingSignOut(true)}
      />

      <Modal
        visible={confirmingSignOut}
        onRequestClose={() => setConfirmingSignOut(false)}
        icon={LogOut}
        title="¿Cerrar sesión?"
        description="Dejarás de recibir solicitudes hasta que vuelvas a entrar."
        confirmLabel="Cerrar sesión"
        cancelLabel="Quedarme"
        onConfirm={() => {
          setConfirmingSignOut(false);
          signOut();
        }}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  avatar: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 80,
    justifyContent: 'center',
    width: 80,
  },
  identity: {
    alignItems: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.xl,
  },
  note: {
    marginBottom: spacing.lg,
    marginTop: spacing.md,
  },
  rating: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  rowCopy: {
    flex: 1,
  },
});
