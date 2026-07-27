import { useRouter } from 'expo-router';
import { ChevronRight, LogOut, Mail, Phone, ShieldCheck, UserRound } from 'lucide-react-native';
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
 * Passenger profile.
 *
 * Read-only for now. Editing arrives in Phase 7. Signing out is real: it clears
 * the session, and the root guard sends the user back to the public zone.
 */
export default function PassengerProfile() {
  const { colors } = useTheme();
  const router = useRouter();
  const { user, signOut } = useSession();
  const [confirmingSignOut, setConfirmingSignOut] = useState(false);

  return (
    <Screen scroll header={<Header title="Mi perfil" onBack={() => router.back()} />}>
      <View style={styles.identity}>
        <View style={[styles.avatar, { backgroundColor: colors.brandSubtle }]}>
          <UserRound size={iconSize.xl} color={colors.brandStrong} strokeWidth={iconStrokeWidth} />
        </View>
        <Text variant="heading">{user?.fullName ?? 'Pasajero'}</Text>
        <Text variant="caption" color="textSecondary">
          Pasajero
        </Text>
      </View>

      <View style={styles.list}>
        <Row icon={Phone} label="Teléfono" value="Sin registrar" />
        <Row icon={Mail} label="Correo" value="Sin registrar" />
        <Row icon={ShieldCheck} label="Seguridad" value="Cambiar contraseña" />
      </View>

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
        description="Tendrás que volver a entrar con tu correo y contraseña."
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

interface RowProps {
  icon: typeof Phone;
  label: string;
  value: string;
}

function Row({ icon: Icon, label, value }: RowProps) {
  const { colors } = useTheme();

  return (
    <Card variant="outlined" padding="md" onPress={() => {}} accessibilityLabel={label}>
      <View style={styles.row}>
        <Icon size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <View style={styles.rowCopy}>
          <Text variant="caption" color="textTertiary">
            {label}
          </Text>
          <Text variant="body">{value}</Text>
        </View>
        <ChevronRight
          size={iconSize.md}
          color={colors.textTertiary}
          strokeWidth={iconStrokeWidth}
        />
      </View>
    </Card>
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
  list: {
    gap: spacing.sm,
    marginBottom: spacing.xl,
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
