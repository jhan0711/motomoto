import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Mail } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { sendPasswordReset } from '@/features/auth/auth-service';
import { FormError } from '@/features/auth/form-error';
import { forgotPasswordSchema, type ForgotPasswordValues } from '@/features/auth/schemas';
import { spacing } from '@/theme';

/**
 * Solicitud de recuperacion de contrasena.
 *
 * La confirmacion no dice si esa direccion tiene cuenta (D74). Una pantalla que
 * responda "ese correo no está registrado" le regala a cualquiera una forma de
 * averiguar quien usa la plataforma probando direcciones, y aqui hay telefonos e
 * historiales de viaje.
 *
 * Los unicos errores que si se muestran son los que el usuario puede entender y
 * remediar: sin conexion, o demasiados intentos seguidos. Callarlos lo dejaria
 * esperando un correo que nunca se envio.
 */
export default function ForgotPassword() {
  const router = useRouter();
  const [sent, setSent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(forgotPasswordSchema),
    defaultValues: { email: '' },
  });

  async function onSubmit(values: ForgotPasswordValues) {
    setFormError(null);

    const result = await sendPasswordReset(values);

    if (result.ok) {
      setSent(true);
    } else {
      setFormError(result.failure.message);
    }
  }

  if (sent) {
    return (
      <Screen header={<Header onBack={() => router.back()} />}>
        <EmptyState
          icon={Mail}
          title="Revisa tu correo"
          description="Si esa dirección tiene una cuenta, te enviamos un enlace para crear una contraseña nueva. El enlace caduca en una hora."
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

        <Button
          label="Enviar enlace"
          variant="primary"
          fullWidth
          loading={formState.isSubmitting}
          onPress={() => void handleSubmit(onSubmit)()}
        />
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
