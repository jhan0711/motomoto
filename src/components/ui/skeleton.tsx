import { useEffect } from 'react';
import { StyleSheet, type DimensionValue, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

import { radius as radiusTokens, useTheme, type RadiusToken } from '@/theme';

export interface SkeletonProps {
  /** Any valid width: a number, a percentage string, or 'auto'. */
  width?: DimensionValue;
  height?: number;
  /** A radius token, or a raw number for circles. */
  radius?: RadiusToken | number;
  style?: StyleProp<ViewStyle>;
}

const PULSE_DURATION_MS = 900;

/**
 * Placeholder shown while content loads.
 *
 * Preferred over a spinner for anything list-shaped. A skeleton tells the user
 * what is coming and roughly how much of it, so the screen does not jump when
 * the data lands. A spinner tells them only that something is happening.
 *
 * The pulse runs on the UI thread through Reanimated, so it keeps animating
 * smoothly even while the JavaScript thread is busy parsing the response that
 * will replace it.
 */
export function Skeleton({ width = '100%', height = 16, radius = 'sm', style }: SkeletonProps) {
  const { colors } = useTheme();
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withRepeat(
      withTiming(1, { duration: PULSE_DURATION_MS, easing: Easing.inOut(Easing.ease) }),
      -1,
      true,
    );
  }, [progress]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: 0.45 + progress.value * 0.35,
  }));

  const resolvedRadius = typeof radius === 'number' ? radius : radiusTokens[radius];

  return (
    <Animated.View
      accessibilityRole="progressbar"
      accessibilityLabel="Cargando"
      style={[
        styles.base,
        { backgroundColor: colors.skeleton, borderRadius: resolvedRadius, height, width },
        animatedStyle,
        style,
      ]}
    />
  );
}

const styles = StyleSheet.create({
  base: {
    overflow: 'hidden',
  },
});
