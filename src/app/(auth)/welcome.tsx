import { useRouter } from 'expo-router';
import { CarTaxiFront } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

export default function Welcome() {
  const { colors } = useTheme();
  const router = useRouter();

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
