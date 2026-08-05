import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Lock, Mail } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { signIn } from '@/features/auth/auth-service';
import { FormError } from '@/components/ui/form-error';
import { loginSchema, type LoginValues } from '@/features/auth/schemas';
import { spacing } from '@/theme';

/**
 * Inicio de sesion. Sirve igual para pasajero y para conductor: el rol se lee
 * del perfil despues de entrar, no se elige aqui.
 *
 * Al entrar correctamente esta pantalla no navega a ninguna parte, y es
 * deliberado: la guardia de (auth)/_layout ve que ya hay sesion y redirige
 * sola. Navegar tambien desde aqui produciria dos navegaciones a la vez.
 */
export default function Login() {
  const router = useRouter();
  const [formError, setFormError] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  async function onSubmit(values: LoginValues) {
    setFormError(null);

    const result = await signIn(values);

    if (!result.ok) {
      setFormError(result.failure.message);
    }
  }

  return (
    <Screen scroll header={<Header title="Iniciar sesión" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <FormError message={formError} />

        <Controller
          control={control}
          name="email"
          render={({ field, fieldState }) => (
            <Input
              label="Correo"
              placeholder="correo@ejemplo.com"
              icon={Mail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoComplete="email"
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />

        <Controller
          control={control}
          name="password"
          render={({ field, fieldState }) => (
            <Input
              label="Contraseña"
              placeholder="Tu contraseña"
              icon={Lock}
              secureTextEntry
              autoComplete="password"
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />

        <Button
          label="Recuperar contraseña"
          variant="ghost"
          size="sm"
          onPress={() => router.push('/forgot-password')}
        />
      </View>

      <View style={styles.actions}>
        <Button
          label="Entrar"
          variant="primary"
          fullWidth
          loading={formState.isSubmitting}
          onPress={() => void handleSubmit(onSubmit)()}
        />
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
