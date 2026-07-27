import { useRouter } from 'expo-router';
import { Lock, Mail, Phone, UserRound } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Passenger sign-up.
 *
 * Only passengers register here. Drivers never self-register: an administrator
 * creates their account from the web panel, per the Phase 0 rules. That is why
 * there is no role selector on this screen.
 *
 * Not wired to a backend until Phase 6.
 */
export default function Register() {
  const router = useRouter();
  const { signInAs } = useSession();

  return (
    <Screen scroll header={<Header title="Crear cuenta" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <Input label="Nombre completo" placeholder="Como te llamas" icon={UserRound} />
        <Input
          label="Teléfono"
          placeholder="300 000 0000"
          icon={Phone}
          keyboardType="phone-pad"
          helperText="Lo usará el conductor para coordinar la recogida"
        />
        <Input
          label="Correo"
          placeholder="correo@ejemplo.com"
          icon={Mail}
          keyboardType="email-address"
          autoCapitalize="none"
        />
        <Input label="Contraseña" placeholder="Mínimo 8 caracteres" icon={Lock} secureTextEntry />
      </View>

      <View style={styles.actions}>
        <Button
          label="Crear cuenta"
          variant="primary"
          fullWidth
          onPress={() => signInAs('passenger')}
        />
        <View style={styles.footer}>
          <Text variant="caption" color="textSecondary">
            ¿Ya tienes cuenta?
          </Text>
          <Button
            label="Iniciar sesión"
            variant="ghost"
            size="sm"
            onPress={() => router.replace('/login')}
          />
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: spacing.sm,
    marginTop: spacing.xl,
  },
  footer: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
    justifyContent: 'center',
  },
  form: {
    gap: spacing.lg,
    marginTop: spacing.lg,
  },
});
