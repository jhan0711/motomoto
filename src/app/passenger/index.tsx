import { useRouter } from 'expo-router';
import { History, MapPin, Navigation, Search, UserRound } from 'lucide-react-native';
import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import {
  MIN_TOUCH_TARGET,
  iconSize,
  iconStrokeWidth,
  radius,
  shadows,
  spacing,
  useTheme,
} from '@/theme';

/**
 * Passenger home.
 *
 * The map fills the screen from Phase 8 onward; right now it is a placeholder.
 * Everything the passenger does starts from the sheet at the bottom.
 *
 * Navigation to history and profile happens through the floating controls over
 * the map rather than a tab bar, for the reason stated in the layout.
 */
export default function PassengerHome() {
  const { colors } = useTheme();
  const router = useRouter();
  const { user } = useSession();
  const [sheetIndex, setSheetIndex] = useState(0);

  return (
    <View style={[styles.root, { backgroundColor: colors.surfaceSubtle }]}>
      <View style={styles.mapPlaceholder}>
        <MapPin size={iconSize.xxl} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
        <Text variant="caption" color="textTertiary" align="center">
          El mapa de Amalfi se integra en la Fase 8
        </Text>
      </View>

      <View style={styles.floatingControls}>
        <FloatingButton
          label="Perfil"
          icon={UserRound}
          onPress={() => router.push('/passenger/profile')}
        />
        <FloatingButton
          label="Historial"
          icon={History}
          onPress={() => router.push('/passenger/history')}
        />
      </View>

      <BottomSheet
        snapPoints={[0.3, 0.72]}
        index={sheetIndex}
        onIndexChange={setSheetIndex}
        header={<Text variant="subheading">Hola, {user?.fullName ?? 'pasajero'}</Text>}
      >
        <Input placeholder="¿A dónde vas?" icon={Search} />

        <Text variant="label" color="textTertiary">
          LUGARES FRECUENTES
        </Text>

        <Card
          variant="filled"
          padding="md"
          onPress={() => {}}
          accessibilityLabel="Parque principal"
        >
          <Text variant="bodyStrong">Parque principal</Text>
          <Text variant="caption" color="textSecondary">
            Centro de Amalfi
          </Text>
        </Card>

        <Button label="Solicitar servicio" variant="brand" icon={Navigation} fullWidth />
      </BottomSheet>
    </View>
  );
}

interface FloatingButtonProps {
  label: string;
  icon: typeof UserRound;
  onPress: () => void;
}

/** Round control laid over the map. Local to this screen for now. */
function FloatingButton({ label, icon: Icon, onPress }: FloatingButtonProps) {
  const { colors } = useTheme();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.floatingButton,
        shadows.md,
        { backgroundColor: pressed ? colors.surfacePressed : colors.surface },
      ]}
    >
      <Icon size={iconSize.md} color={colors.textPrimary} strokeWidth={iconStrokeWidth} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  floatingButton: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: MIN_TOUCH_TARGET,
    justifyContent: 'center',
    width: MIN_TOUCH_TARGET,
  },
  floatingControls: {
    gap: spacing.md,
    position: 'absolute',
    right: spacing.lg,
    top: spacing.xxl,
  },
  mapPlaceholder: {
    alignItems: 'center',
    flex: 1,
    gap: spacing.md,
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
  },
  root: {
    flex: 1,
  },
});
