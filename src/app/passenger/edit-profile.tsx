import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Phone, UserRound } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { updateProfile } from '@/features/auth/auth-service';
import { FormError } from '@/components/ui/form-error';
import { editProfileSchema, type EditProfileValues } from '@/features/auth/schemas';
import { useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Edicion del nombre y el telefono del pasajero.
 *
 * El correo no esta aqui: no se edita en el MVP. La razon completa esta en el
 * comentario de `SessionUser.email`.
 *
 * Al guardar se pide a la sesion que vuelva a leer el perfil y se vuelve atras.
 * No se actualiza el estado a mano con los valores del formulario: eso mostraria
 * lo que el usuario escribio y no lo que la base de datos acepto, y las dos cosas
 * pueden no coincidir. El telefono, por ejemplo, se guarda normalizado.
 */
export default function EditProfile() {
  const router = useRouter();
  const { user, refreshProfile } = useSession();
  const [formError, setFormError] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(editProfileSchema),
    defaultValues: {
      fullName: user?.fullName ?? '',
      phone: user?.phone ?? '',
    },
  });

  async function onSubmit(values: EditProfileValues) {
    if (user === null) {
      return;
    }

    setFormError(null);

    const result = await updateProfile(user.id, values);

    if (result.ok) {
      refreshProfile();
      router.back();
    } else {
      setFormError(result.failure.message);
    }
  }

  return (
    <Screen scroll header={<Header title="Editar perfil" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <FormError message={formError} />

        <Controller
          control={control}
          name="fullName"
          render={({ field, fieldState }) => (
            <Input
              label="Nombre completo"
              placeholder="Como te llamas"
              icon={UserRound}
              autoCapitalize="words"
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />

        <Controller
          control={control}
          name="phone"
          render={({ field, fieldState }) => (
            <Input
              label="Teléfono"
              placeholder="300 000 0000"
              icon={Phone}
              keyboardType="phone-pad"
              helperText="Lo usará el conductor para coordinar la recogida"
              value={field.value}
              onChangeText={field.onChange}
              onBlur={field.onBlur}
              errorText={fieldState.error?.message}
            />
          )}
        />

        <Text variant="caption" color="textTertiary">
          Tu correo no se puede cambiar desde la aplicación. Si necesitas cambiarlo, comunícate con
          la empresa.
        </Text>
      </View>

      <View style={styles.actions}>
        <Button
          label="Guardar cambios"
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
