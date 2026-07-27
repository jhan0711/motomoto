import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

import { radius, shadows, spacing, useTheme, type SpacingToken } from '@/theme';

export type CardVariant = 'elevated' | 'outlined' | 'filled';

export interface CardProps {
  children: ReactNode;
  /**
   * `elevated` floats above the background with a shadow. Reserved for content
   * sitting on top of the map.
   * `outlined` uses a hairline border. The default for lists and forms.
   * `filled` uses a tinted surface with no border or shadow.
   */
  variant?: CardVariant;
  /** Inner padding, from the spacing scale. */
  padding?: SpacingToken;
  /** Turns the card into a pressable row. Omit for static content. */
  onPress?: () => void;
  /** Required by accessibility tooling when `onPress` is set. */
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

/**
 * Container for grouped content.
 *
 * Shadows are used sparingly on purpose: on a screen dominated by a map, a
 * heavy shadow makes a card look detached from the interface. `outlined` is the
 * default for that reason.
 */
export function Card({
  children,
  variant = 'outlined',
  padding = 'lg',
  onPress,
  accessibilityLabel,
  style,
}: CardProps) {
  const { colors } = useTheme();

  const base: ViewStyle = {
    backgroundColor: variant === 'filled' ? colors.surfaceSubtle : colors.surface,
    borderRadius: radius.lg,
    padding: spacing[padding],
  };

  const decoration: ViewStyle =
    variant === 'outlined'
      ? { borderColor: colors.border, borderWidth: StyleSheet.hairlineWidth * 2 }
      : variant === 'elevated'
        ? shadows.md
        : {};

  if (!onPress) {
    return <View style={[base, decoration, style]}>{children}</View>;
  }

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      onPress={onPress}
      style={({ pressed }) => [
        base,
        decoration,
        pressed && { backgroundColor: colors.surfacePressed },
        style,
      ]}
    >
      {children}
    </Pressable>
  );
}
