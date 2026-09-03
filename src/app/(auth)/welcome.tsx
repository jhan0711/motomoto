import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { radius, spacing } from '@/theme';

// El logo de la marca. Es un PNG y no un icono de lucide: es la identidad de la
// aplicación, no un adorno (Fase 25 paso 3).
const LOGO = require('../../../assets/images/icon.png');

export default function Welcome() {
  const router = useRouter();

  return (
    <Screen>
      <View style={styles.hero}>
        <Image source={LOGO} style={styles.mark} contentFit="cover" />

        <View style={styles.copy}>
          <Text variant="display" align="center">
            AmalfiGoApp
          </Text>
          <Text variant="body" color="textSecondary" align="center">
            Muévete fácil, llega seguro.
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
    borderRadius: radius.xxl,
    height: 112,
    width: 112,
  },
});
