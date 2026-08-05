import { zodResolver } from '@hookform/resolvers/zod';
import { Redirect, useRouter } from 'expo-router';
import { Lock, ShieldCheck } from 'lucide-react-native';
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
import { changePassword } from '@/features/auth/auth-service';
import { FormError } from '@/components/ui/form-error';
import { changePasswordSchema, type ChangePasswordValues } from '@/features/auth/schemas';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Cambio de contrasena desde dentro de la aplicacion.
 *
 * Vive en la raiz y no dentro de `passenger/` a proposito: un conductor tambien
 * tiene que poder cambiar la suya. Su cuenta la crea el administrador con una
 * contrasena inicial, asi que querra cambiarla el primer dia.
 *
 * Se pide la contrasena actual. Supabase no la exige, y aceptar eso significaria
 * que un telefono desbloqueado durante un minuto es una cuenta perdida.
 */
export default function ChangePassword() {
  const router = useRouter();
  const { user, isLoading } = useSession();
  const [formError, setFormError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(changePasswordSchema),
    defaultValues: { currentPassword: '', password: '', confirmPassword: '' },
  });

  async function onSubmit(values: ChangePasswordValues) {
    if (user?.email == null) {
      setFormError('No pudimos identificar tu cuenta. Vuelve a iniciar sesión.');
      return;
    }

    setFormError(null);

    const result = await changePassword(user.email, values);

    if (result.ok) {
      setDone(true);
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

  if (done) {
    return (
      <Screen>
        <EmptyState
          icon={ShieldCheck}
          title="Contraseña actualizada"
          description="La próxima vez que inicies sesión usa tu contraseña nueva."
          actionLabel="Volver a mi perfil"
          onAction={() => router.back()}
        />
      </Screen>
    );
  }

  return (
    <Screen scroll header={<Header title="Cambiar contraseña" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <FormError message={formError} />

        <Controller
          control={control}
          name="currentPassword"
          render={({ field, fieldState }) => (
            <Input
              label="Contraseña actual"
              placeholder="La que usas hoy"
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
              label="Repite la contraseña nueva"
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

        <Text variant="caption" color="textTertiary">
          Si olvidaste tu contraseña actual, cierra sesión y usa «Recuperar contraseña» en la
          pantalla de acceso.
        </Text>
      </View>

      <View style={styles.actions}>
        <Button
          label="Guardar contraseña"
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
