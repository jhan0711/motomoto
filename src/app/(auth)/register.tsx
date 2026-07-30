import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Lock, Mail, Phone, UserRound } from 'lucide-react-native';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { signUp } from '@/features/auth/auth-service';
import { FormError } from '@/features/auth/form-error';
import { registerSchema, type RegisterValues } from '@/features/auth/schemas';
import { spacing } from '@/theme';

/**
 * Registro de pasajero.
 *
 * Aqui solo se registran pasajeros. Los conductores nunca se auto-registran: su
 * cuenta la crea un administrador desde el panel web. Por eso no hay selector de
 * rol, y por eso el rol tampoco viaja en la peticion: lo pone la base de datos.
 *
 * El telefono es obligatorio desde el registro (D92). El backend lo exige para
 * poder solicitar un servicio, y pedirlo mas tarde dejaria cuentas que existen
 * pero no pueden usar la aplicacion.
 */
export default function Register() {
  const router = useRouter();
  const [formError, setFormError] = useState<string | null>(null);

  const { control, handleSubmit, formState } = useForm({
    resolver: zodResolver(registerSchema),
    defaultValues: { fullName: '', phone: '', email: '', password: '' },
  });

  async function onSubmit(values: RegisterValues) {
    setFormError(null);

    const result = await signUp(values);

    if (!result.ok) {
      setFormError(result.failure.message);
    }

    // Al registrarse correctamente Supabase deja la sesion abierta, porque la
    // confirmacion por correo esta desactivada (D91). La guardia de
    // (auth)/_layout se encarga de llevar al usuario a su zona.
  }

  return (
    <Screen scroll header={<Header title="Crear cuenta" onBack={() => router.back()} />}>
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
      </View>

      <View style={styles.actions}>
        <Button
          label="Crear cuenta"
          variant="primary"
          fullWidth
          loading={formState.isSubmitting}
          onPress={() => void handleSubmit(onSubmit)()}
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
