import { useRouter } from 'expo-router';
import { Mail } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { spacing } from '@/theme';

/**
 * Password recovery request.
 *
 * The confirmation deliberately does not say whether the address exists. Any
 * screen that answers "that email is not registered" hands an attacker a way to
 * enumerate accounts, and this app stores phone numbers and trip histories.
 *
 * Not wired to a backend until Phase 6, which also depends on configuring a
 * real mail server. Supabase's built-in sender has limits too low for
 * production.
 */
export default function ForgotPassword() {
  const router = useRouter();
  const [sent, setSent] = useState(false);

  if (sent) {
    return (
      <Screen header={<Header onBack={() => router.back()} />}>
        <EmptyState
          icon={Mail}
          title="Revisa tu correo"
          description="Si esa dirección tiene una cuenta, te enviamos un enlace para crear una contraseña nueva."
          actionLabel="Volver a iniciar sesión"
          onAction={() => router.replace('/login')}
        />
      </Screen>
    );
  }

  return (
    <Screen header={<Header title="Recuperar contraseña" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <Text variant="body" color="textSecondary">
          Escribe el correo con el que te registraste y te enviaremos un enlace para restablecer tu
          contraseña.
        </Text>

        <Input
          label="Correo"
          placeholder="correo@ejemplo.com"
          icon={Mail}
          keyboardType="email-address"
          autoCapitalize="none"
        />

        <Button label="Enviar enlace" variant="primary" fullWidth onPress={() => setSent(true)} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  form: {
    gap: spacing.lg,
    marginTop: spacing.lg,
  },
});
