import { useRouter } from 'expo-router';
import { Bike, CarTaxiFront, UserRound } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

export default function Welcome() {
  const { colors } = useTheme();
  const router = useRouter();
  const { signInAs } = useSession();

  return (
    <Screen>
      <View style={styles.hero}>
        <View style={[styles.mark, { backgroundColor: colors.brand }]}>
          <CarTaxiFront size={iconSize.xxl} color={colors.onBrand} strokeWidth={iconStrokeWidth} />
        </View>

        <View style={styles.copy}>
          <Text variant="display" align="center">
            MotoMoto
          </Text>
          <Text variant="body" color="textSecondary" align="center">
            Solicita tu motorratón en Amalfi, sin llamadas y sin esperas.
          </Text>
        </View>
      </View>

      <View style={styles.actions}>
        <Button
          label="Crear cuenta"
          variant="primary"
          fullWidth
          onPress={() => router.push('/register')}
        />
        <Button
          label="Ya tengo cuenta"
          variant="secondary"
          fullWidth
          onPress={() => router.push('/login')}
        />
      </View>

      {/* TEMPORARY: role switcher. There is no backend yet, so this is the only
          way to reach the passenger and driver zones. Removed in Phase 6. */}
      <View style={[styles.devBlock, { borderColor: colors.border }]}>
        <Text variant="label" color="textTertiary" align="center">
          MODO DESARROLLO
        </Text>
        <Text variant="caption" color="textTertiary" align="center">
          Acceso directo sin autenticación. Desaparece en la Fase 6.
        </Text>
        <View style={styles.devButtons}>
          <Button
            label="Entrar como pasajero"
            variant="ghost"
            size="sm"
            icon={UserRound}
            onPress={() => signInAs('passenger')}
          />
          <Button
            label="Entrar como conductor"
            variant="ghost"
            size="sm"
            icon={Bike}
            onPress={() => signInAs('driver')}
          />
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: spacing.md,
  },
  copy: {
    gap: spacing.sm,
  },
  devBlock: {
    borderRadius: radius.lg,
    borderStyle: 'dashed',
    borderWidth: 1,
    gap: spacing.xs,
    marginTop: spacing.xl,
    padding: spacing.lg,
  },
  devButtons: {
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  hero: {
    alignItems: 'center',
    flex: 1,
    gap: spacing.xl,
    justifyContent: 'center',
  },
  mark: {
    alignItems: 'center',
    borderRadius: radius.xxl,
    height: 96,
    justifyContent: 'center',
    width: 96,
  },
});
