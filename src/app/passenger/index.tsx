import { useRouter } from 'expo-router';
import { History, LocateFixed, Navigation, Search, UserRound } from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import type MapView from 'react-native-maps';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { LocationGate, blockingState } from '@/features/map/location-gate';
import { Map } from '@/features/map/map';
import { AMALFI_REGION, regionAround } from '@/features/map/region';
import { useLocation } from '@/features/map/use-location';
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
 * The map is the screen; everything else floats over it. The passenger starts
 * every request from the sheet at the bottom.
 *
 * Navigation to history and profile happens through the floating controls rather
 * than a tab bar, for the reason stated in the layout.
 */
export default function PassengerHome() {
  const { colors } = useTheme();
  const router = useRouter();
  const { user } = useSession();
  const insets = useSafeAreaInsets();

  const [sheetIndex, setSheetIndex] = useState(0);
  const location = useLocation();
  const mapRef = useRef<MapView>(null);

  /**
   * Set when the passenger chooses to continue without location. Without it,
   * the gate would reappear on every foreground check and there would be no way
   * past it other than granting the permission.
   */
  const [skippedGate, setSkippedGate] = useState(false);

  const coords = location.state.kind === 'ready' ? location.state.coords : null;

  /**
   * Slide to the passenger the first time we know where they are.
   *
   * Only the first time: after that the camera belongs to whoever moved it last,
   * and yanking it back on every GPS update would make the map unusable.
   *
   * Waiting for `isMapReady` is not optional. The first fix routinely arrives
   * before the native map has finished setting up, and a camera command sent
   * then is discarded without a word. Marking the move as done anyway left the
   * passenger looking at the town center while the app already knew exactly
   * where they were.
   */
  const [isMapReady, setIsMapReady] = useState(false);
  const hasCentered = useRef(false);

  useEffect(() => {
    if (!isMapReady || coords === null || hasCentered.current) return;
    const map = mapRef.current;
    if (map === null) return;

    hasCentered.current = true;
    map.animateToRegion(regionAround(coords), 900);
  }, [isMapReady, coords]);

  const recenter = useCallback(() => {
    if (coords === null) return;
    mapRef.current?.animateToRegion(regionAround(coords), 500);
  }, [coords]);

  const handleSkip = useCallback(() => setSkippedGate(true), []);

  if (location.state.kind === 'checking') {
    return (
      <View style={[styles.centered, { backgroundColor: colors.background }]}>
        <ActivityIndicator color={colors.brand} />
      </View>
    );
  }

  const blocking = blockingState(location.state);

  if (blocking !== null && !skippedGate) {
    return (
      <LocationGate
        state={blocking}
        onRequestPermission={() => void location.requestPermission()}
        onEnableServices={() => void location.enableServices()}
        onOpenSettings={() => void location.openSettings()}
        onRetry={location.retry}
        onSkip={handleSkip}
      />
    );
  }

  return (
    <View style={[styles.root, { backgroundColor: colors.surfaceSubtle }]}>
      <Map
        ref={mapRef}
        initialRegion={AMALFI_REGION}
        userCoords={coords}
        onReady={() => setIsMapReady(true)}
      />

      <View style={[styles.floatingControls, { top: insets.top + spacing.md }]}>
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
        {coords !== null && (
          <FloatingButton label="Centrar en mi ubicación" icon={LocateFixed} onPress={recenter} />
        )}
      </View>

      {location.state.kind === 'locating' && (
        <View style={[styles.statusBar, { top: insets.top + spacing.md }]} pointerEvents="none">
          <View style={[styles.statusPill, shadows.sm, { backgroundColor: colors.surface }]}>
            <ActivityIndicator size="small" color={colors.brand} />
            <Text variant="caption" color="textSecondary">
              Buscando tu ubicación
            </Text>
          </View>
        </View>
      )}

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
  centered: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
  },
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
  },
  root: {
    flex: 1,
  },
  // Full-width row so the pill can center itself while still hugging its text.
  // `alignSelf` on an absolutely positioned element does not center it.
  statusBar: {
    alignItems: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
  },
  statusPill: {
    alignItems: 'center',
    borderRadius: radius.full,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
});
