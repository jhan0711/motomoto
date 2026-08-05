import { useRouter } from 'expo-router';
import {
  ChevronRight,
  LogOut,
  Mail,
  Pencil,
  Phone,
  ShieldCheck,
  UserRound,
  type LucideIcon,
} from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Header } from '@/components/ui/header';
import { Modal } from '@/components/ui/modal';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { FormError } from '@/components/ui/form-error';
import { useSession } from '@/features/auth/session';
import { ProfileAvatar } from '@/features/profile/profile-avatar';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

/**
 * Perfil del pasajero.
 *
 * Los datos son reales: salen del perfil cargado en la sesion. Antes eran texto
 * fijo que decia "Sin registrar" incluso cuando el dato existia, que es peor que
 * no mostrarlo.
 *
 * El correo se muestra pero no se edita, y no es un olvido: con la confirmacion
 * de correo desactivada (D91) el cambio seria inmediato y sin verificar. Quien
 * tuviera el telefono desbloqueado un minuto podria apuntar la cuenta a su
 * propio correo y luego usar "recuperar contrasena" para quedarse con ella. Se
 * habilita en la Fase 25, cuando exista verificacion.
 *
 * La edicion de nombre y telefono llega en el paso 7.2, y el cambio de
 * contrasena en el 7.3. Mientras no funcionen, sus filas no aparecen: una fila
 * con flecha que no hace nada al pulsarla es una mentira de interfaz.
 */
export default function PassengerProfile() {
  const router = useRouter();
  const { user, signOut, refreshProfile } = useSession();
  const [confirmingSignOut, setConfirmingSignOut] = useState(false);
  const [avatarError, setAvatarError] = useState<string | null>(null);

  return (
    <Screen scroll header={<Header title="Mi perfil" onBack={() => router.back()} />}>
      <View style={styles.identity}>
        {user !== null && (
          <ProfileAvatar
            userId={user.id}
            avatarPath={user.avatarPath}
            fallbackIcon={UserRound}
            editable
            onChanged={refreshProfile}
            onError={setAvatarError}
          />
        )}
        <Text variant="heading">{user?.fullName ?? 'Pasajero'}</Text>
        <Text variant="caption" color="textSecondary">
          Toca la foto para cambiarla
        </Text>
      </View>

      <FormError message={avatarError} />

      <View style={styles.list}>
        {/* El telefono lleva flecha porque se puede editar; el correo no la lleva
            porque no se puede. La flecha informa, no decora. */}
        <Row
          icon={Phone}
          label="Teléfono"
          value={user?.phone}
          onPress={() => router.push('/passenger/edit-profile')}
        />
        <Row icon={Mail} label="Correo" value={user?.email} />
        <Row
          icon={ShieldCheck}
          label="Seguridad"
          value="Cambiar contraseña"
          onPress={() => router.push('/change-password')}
        />
      </View>

      <View style={styles.actions}>
        <Button
          label="Editar perfil"
          variant="primary"
          icon={Pencil}
          fullWidth
          onPress={() => router.push('/passenger/edit-profile')}
        />
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
  icon: LucideIcon;
  label: string;
  /** Null o vacio se muestra como "Sin registrar", atenuado. */
  value: string | null | undefined;
  /** Omitir para una fila de solo lectura. Sin accion no se dibuja la flecha. */
  onPress?: () => void;
}

function Row({ icon: Icon, label, value, onPress }: RowProps) {
  const { colors } = useTheme();
  const hasValue = value !== null && value !== undefined && value !== '';

  return (
    <Card
      variant="outlined"
      padding="md"
      onPress={onPress}
      accessibilityLabel={onPress === undefined ? undefined : label}
    >
      <View style={styles.row}>
        <Icon size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <View style={styles.rowCopy}>
          <Text variant="caption" color="textTertiary">
            {label}
          </Text>
          <Text variant="body" color={hasValue ? 'textPrimary' : 'textTertiary'}>
            {hasValue ? value : 'Sin registrar'}
          </Text>
        </View>
        {onPress !== undefined && (
          <ChevronRight
            size={iconSize.md}
            color={colors.textTertiary}
            strokeWidth={iconStrokeWidth}
          />
        )}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  actions: {
    marginBottom: spacing.md,
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
