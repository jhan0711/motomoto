import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Lock, LinkIcon } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { updatePassword } from '@/features/auth/auth-service';
import { FormError } from '@/components/ui/form-error';
import { resetPasswordSchema, type ResetPasswordValues } from '@/features/auth/schemas';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Contrasena nueva, al final del enlace del correo.
 *
 * Se llega aqui unicamente desde el enlace: la sesion ya esta abierta cuando
 * esta pantalla aparece. Por eso no se pide la contrasena anterior, que es
 * justamente la que el usuario no recuerda; lo que demuestra que la cuenta es
 * suya es haber podido abrir el correo.
 *
 * Al guardar no se navega a ninguna parte. Se retira la marca de recuperacion y
 * las guardias llevan al usuario a su zona, igual que en un inicio de sesion
 * normal.
 */
export default function ResetPassword() {
  const router = useRouter();
  const { user, recoveryError, endPasswordRecovery, signOut } = useSession();
  const [formError, setFormError] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(resetPasswordSchema),
    defaultValues: { password: '', confirmPassword: '' },
  });

  async function onSubmit(values: ResetPasswordValues) {
    setFormError(null);

    const result = await updatePassword(values.password);

    if (result.ok) {
      endPasswordRecovery();
    } else {
      setFormError(result.failure.message);
    }
  }

  // Enlace caducado, ya usado o manipulado. Es el caso mas frecuente de todos:
  // la gente abre el correo al dia siguiente.
  if (recoveryError !== null) {
    return (
      <Screen>
        <EmptyState
          icon={LinkIcon}
          title="El enlace ya no sirve"
          description={recoveryError}
          actionLabel="Pedir un enlace nuevo"
          onAction={() => router.replace('/forgot-password')}
        />
      </Screen>
    );
  }

  // La sesion del enlace tarda un instante en abrirse. Sin esta espera se veria
  // el formulario antes de tiempo, y guardar fallaria sin motivo aparente.
  if (user === null) {
    return (
      <Screen>
        <Spinner size="large" centered label="Validando el enlace" />
      </Screen>
    );
  }

  return (
    <Screen scroll header={<Header title="Nueva contraseña" />}>
      <View style={styles.form}>
        <Text variant="body" color="textSecondary">
          Escribe tu contraseña nueva. La necesitarás la próxima vez que inicies sesión.
        </Text>

        <FormError message={formError} />

        <Controller
          control={control}
          name="password"
          render={({ field, fieldState }) => (
            <Input
              label="Contraseña nueva"
              placeholder="Mínimo 8 caracteres"
              icon={Lock}
              secureTextEntry
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />

        <Controller
          control={control}
          name="confirmPassword"
          render={({ field, fieldState }) => (
            <Input
              label="Repite la contraseña"
              placeholder="Escríbela otra vez"
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
          label="Guardar contraseña"
          variant="primary"
          fullWidth
          loading={formState.isSubmitting}
          onPress={() => void handleSubmit(onSubmit)()}
        />
        <Button
          label="Cancelar"
          variant="ghost"
          fullWidth
          onPress={() => {
            signOut();
            endPasswordRecovery();
          }}
        />
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
