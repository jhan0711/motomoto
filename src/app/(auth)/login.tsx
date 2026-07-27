import { useRouter } from 'expo-router';
import { Lock, Mail } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Sign-in screen.
 *
 * The form is real but not wired: there is no backend until Phase 6. Pressing
 * the button signs in as a passenger so the flow can be walked end to end.
 * Validation, error handling and loading states arrive with the real
 * implementation.
 */
export default function Login() {
  const router = useRouter();
  const { signInAs } = useSession();

  return (
    <Screen scroll header={<Header title="Iniciar sesión" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <Input
          label="Correo"
          placeholder="correo@ejemplo.com"
          icon={Mail}
          keyboardType="email-address"
          autoCapitalize="none"
          autoComplete="email"
        />
        <Input
          label="Contraseña"
          placeholder="Tu contraseña"
          icon={Lock}
          secureTextEntry
          autoComplete="password"
        />

        <Button
          label="Recuperar contraseña"
          variant="ghost"
          size="sm"
          onPress={() => router.push('/forgot-password')}
        />
      </View>

      <View style={styles.actions}>
        <Button label="Entrar" variant="primary" fullWidth onPress={() => signInAs('passenger')} />
        <View style={styles.footer}>
          <Text variant="caption" color="textSecondary">
            ¿No tienes cuenta?
          </Text>
          <Button
            label="Crear una"
            variant="ghost"
            size="sm"
            onPress={() => router.replace('/register')}
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
