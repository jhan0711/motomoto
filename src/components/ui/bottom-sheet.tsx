/* eslint-disable react-hooks/immutability --
 * The React Compiler treats any value handed to a hook as immutable. Reanimated
 * shared values are handed to `useAnimatedStyle` and `useAnimatedReaction`, and
 * are then written from worklets, which is their entire reason to exist.
 *
 * The two tools disagree by design, and no restructuring resolves it: rendering
 * an animated position requires passing the shared value to a hook, and driving
 * a gesture requires writing to it.
 *
 * Scope is deliberately narrow: this file only, this rule only. Everywhere else
 * in the project the rule stays on.
 */
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo } from 'react';
import {
  StyleSheet,
  useWindowDimensions,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedReaction,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { MAX_CONTENT_WIDTH, radius, shadows, spacing, useTheme } from '@/theme';

export interface BottomSheetProps {
  children: ReactNode;
  /**
   * Heights as a fraction of the screen, ascending. `[0.25, 0.7]` means a
   * collapsed state covering a quarter of the screen and an expanded one
   * covering seventy percent.
   */
  snapPoints?: readonly number[];
  /** Index of the active snap point. Controlled by the parent. */
  index?: number;
  onIndexChange?: (index: number) => void;
  /** Content pinned above the scrollable area, such as a title. */
  header?: ReactNode;
  style?: StyleProp<ViewStyle>;
}

const DEFAULT_SNAP_POINTS = [0.28, 0.68] as const;

/** Tuned for a sheet that feels responsive without overshooting. */
const SPRING_CONFIG = {
  damping: 45,
  stiffness: 320,
  mass: 0.9,
} as const;

/**
 * Panel that slides up from the bottom of the screen.
 *
 * This is the primary surface of the passenger experience: choosing a
 * destination, confirming a ride, watching the driver approach. The map stays
 * visible and interactive behind it, which is why this is not a modal.
 *
 * Built on Reanimated and Gesture Handler instead of a third-party sheet
 * library. Both are already project dependencies, the gesture runs entirely on
 * the UI thread, and the component keeps working when the map behind it is
 * being panned.
 *
 * Deliberately out of scope: scrollable lists nested inside the sheet. That is
 * the genuinely hard part of a bottom sheet and nothing in the MVP needs it.
 * If that changes, the implementation swaps out behind this same API.
 */
export function BottomSheet({
  children,
  snapPoints = DEFAULT_SNAP_POINTS,
  index = 0,
  onIndexChange,
  header,
  style,
}: BottomSheetProps) {
  const { colors } = useTheme();
  const { height: screenHeight } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  /** Ascending fractions, defensive against an unsorted prop. */
  const points = useMemo(() => [...snapPoints].sort((a, b) => a - b), [snapPoints]);

  /** The sheet is always as tall as its largest snap point. */
  const sheetHeight = useMemo(
    () => screenHeight * (points[points.length - 1] ?? 0.7),
    [points, screenHeight],
  );

  /**
   * Vertical offsets, in pixels, for each snap point. Offset 0 means fully
   * expanded; larger values push the sheet further down.
   */
  const offsets = useMemo(
    () => points.map((point) => sheetHeight - screenHeight * point),
    [points, screenHeight, sheetHeight],
  );

  const collapsedOffset = offsets[0] ?? 0;
  const translateY = useSharedValue(collapsedOffset);
  const dragStart = useSharedValue(0);
  const targetOffset = useSharedValue(collapsedOffset);

  // Two shared values instead of one, on purpose.
  //
  // `translateY` is the live position and is written only from worklets: the
  // pan gesture and the reaction below. `targetOffset` is the position React
  // asks for and is written only from this effect.
  //
  // Keeping them separate is what lets the controlled `index` prop coexist with
  // dragging. Writing to `translateY` from both React and the gesture is also
  // what the react-hooks/immutability rule forbids, and it is right to: a value
  // driven from two places is a race waiting to happen.
  useEffect(() => {
    targetOffset.value = offsets[index] ?? collapsedOffset;
  }, [index, offsets, collapsedOffset, targetOffset]);

  useAnimatedReaction(
    () => targetOffset.value,
    (next, previous) => {
      if (next !== previous) {
        translateY.value = withSpring(next, SPRING_CONFIG);
      }
    },
  );

  const notifyIndexChange = useCallback(
    (nextIndex: number) => {
      if (nextIndex !== index) {
        onIndexChange?.(nextIndex);
      }
    },
    [index, onIndexChange],
  );

  const maxOffset = offsets[0] ?? 0;

  // Deliberately not wrapped in useMemo. The React Compiler is enabled for this
  // project and memoizes it automatically, and wrapping it manually trips the
  // react-hooks/immutability rule: a useMemo body must be pure, and these
  // callbacks write to shared values.
  const panGesture = Gesture.Pan()
    .onStart(() => {
      dragStart.value = translateY.value;
    })
    .onUpdate((event) => {
      const next = dragStart.value + event.translationY;
      // Clamp between fully expanded and the lowest snap point, so the sheet
      // can never be dragged off-screen or above its own height.
      translateY.value = Math.min(Math.max(next, 0), maxOffset);
    })
    .onEnd((event) => {
      // Project where the drag would land, so a flick reaches the next snap
      // point instead of falling back to the nearest one.
      const projected = translateY.value + event.velocityY * 0.12;

      let closestIndex = 0;
      let smallestDistance = Number.POSITIVE_INFINITY;

      for (let i = 0; i < offsets.length; i += 1) {
        const offset = offsets[i] ?? 0;
        const distance = Math.abs(projected - offset);
        if (distance < smallestDistance) {
          smallestDistance = distance;
          closestIndex = i;
        }
      }

      translateY.value = withSpring(offsets[closestIndex] ?? 0, SPRING_CONFIG);
      runOnJS(notifyIndexChange)(closestIndex);
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View
        style={[
          styles.sheet,
          shadows.lg,
          {
            backgroundColor: colors.surface,
            borderTopLeftRadius: radius.xxl,
            borderTopRightRadius: radius.xxl,
            height: sheetHeight,
            paddingBottom: insets.bottom,
          },
          animatedStyle,
          style,
        ]}
      >
        <View style={styles.grabberArea}>
          <View style={[styles.grabber, { backgroundColor: colors.border }]} />
        </View>

        {/* The sheet surface spans the full width, because it is anchored to the
            bottom edge of the display. Its contents do not: on a tablet an
            800dp-wide row of controls is as unusable inside a sheet as anywhere
            else. */}
        <View style={styles.inner}>
          {header !== undefined && <View style={styles.header}>{header}</View>}

          <View style={styles.content}>{children}</View>
        </View>
      </Animated.View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  grabber: {
    borderRadius: radius.full,
    height: 4,
    width: 40,
  },
  grabberArea: {
    alignItems: 'center',
    // A generous target: the grabber is the affordance users aim for.
    paddingBottom: spacing.sm,
    paddingTop: spacing.md,
  },
  header: {
    paddingBottom: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  inner: {
    alignSelf: 'center',
    flex: 1,
    maxWidth: MAX_CONTENT_WIDTH,
    width: '100%',
  },
  sheet: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
  },
});
