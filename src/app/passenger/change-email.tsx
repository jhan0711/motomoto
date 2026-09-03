import { zodResolver } from '@hookform/resolvers/zod';
import { Redirect, useRouter } from 'expo-router';
import { Lock, Mail, MailCheck } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { FormError } from '@/components/ui/form-error';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { changeEmail } from '@/features/auth/auth-service';
import { changeEmailSchema, type ChangeEmailValues } from '@/features/auth/schemas';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Cambio de correo del pasajero (Fase 25 paso 7c, D101).
 *
 * Solo pasajeros: los datos del conductor los gestiona la empresa, y su correo
 * es la referencia con la que el administrador lo identifica. Por eso vive bajo
 * `passenger/`, igual que la edicion de perfil, y no en la raiz como el cambio
 * de contrasena.
 *
 * Se pide la contrasena actual (D102). El cambio no surte efecto hasta que el
 * usuario abre el enlace que Supabase manda al correo nuevo -y, con el cambio
 * seguro, tambien al actual-.
 */
export default function ChangeEmail() {
  const router = useRouter();
  const { user, isLoading } = useSession();
  const [formError, setFormError] = useState<string | null>(null);
  const [enviado, setEnviado] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(changeEmailSchema),
    defaultValues: { email: '', currentPassword: '' },
  });

  async function onSubmit(values: ChangeEmailValues) {
    if (user?.email == null) {
      setFormError('No pudimos identificar tu cuenta. Vuelve a iniciar sesión.');
      return;
    }

    setFormError(null);

    const result = await changeEmail(user.email, values);

    if (result.ok) {
      setEnviado(values.email);
    } else {
      setFormError(result.failure.message);
    }
  }

  if (isLoading) {
    return (
      <Screen>
        <Spinner size="large" centered label="Cargando" />
      </Screen>
    );
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  if (enviado !== null) {
    return (
      <Screen>
        <EmptyState
          icon={MailCheck}
          title="Confirma el cambio"
          description={`Te enviamos un enlace a ${enviado} y otro a tu correo actual. Ábrelos desde este teléfono para que el cambio surta efecto.`}
          actionLabel="Volver a mi perfil"
          onAction={() => router.back()}
        />
      </Screen>
    );
  }

  return (
    <Screen scroll header={<Header title="Cambiar correo" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <FormError message={formError} />

        <Text variant="caption" color="textTertiary">
          Tu correo actual es {user.email}. Escribe el nuevo y tu contraseña.
        </Text>

        <Controller
          control={control}
          name="email"
          render={({ field, fieldState }) => (
            <Input
              label="Correo nuevo"
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
          name="currentPassword"
          render={({ field, fieldState }) => (
            <Input
              label="Contraseña"
              placeholder="La que usas para entrar"
              icon={Lock}
              secureTextEntry
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />
      </View>

      <View style={styles.actions}>
        <Button
          label="Enviar enlace de confirmación"
          variant="primary"
          fullWidth
          loading={formState.isSubmitting}
          onPress={() => void handleSubmit(onSubmit)()}
        />
        <Button label="Cancelar" variant="ghost" fullWidth onPress={() => router.back()} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: spacing.sm,
    marginTop: spacing.xl,
  },
  form: {
    gap: spacing.lg,
    marginTop: spacing.lg,
  },
});
