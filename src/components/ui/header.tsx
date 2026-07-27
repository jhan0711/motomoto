import { ChevronLeft } from 'lucide-react-native';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

import {
  MIN_TOUCH_TARGET,
  iconSize,
  iconStrokeWidth,
  radius,
  shadows,
  spacing,
  useTheme,
} from '@/theme';

import { Text } from './text';

export type HeaderVariant = 'plain' | 'floating';

export interface HeaderProps {
  title?: string;
  subtitle?: string;
  /** Shows a back control. Omit it and no back button is rendered. */
  onBack?: () => void;
  /** Optional trailing content, usually an icon button. */
  right?: ReactNode;
  /**
   * `plain` sits on the screen background.
   * `floating` is a rounded surface with a shadow, for headers laid over a map.
   */
  variant?: HeaderVariant;
  style?: StyleProp<ViewStyle>;
}

/**
 * Screen header.
 *
 * The app hides the native expo-router header (`headerShown: false` in the root
 * layout) and uses this instead. Reasons:
 *
 *   - The native header does not follow our theme without duplicating every
 *     color token in navigation options.
 *   - Most screens in this app put the map first, with the header floating over
 *     it. A native header cannot do that.
 *   - Back arrows, titles and actions all come from the same icon family and
 *     the same type scale as the rest of the interface.
 *
 * Navigation is deliberately not imported here. The screen passes `onBack`,
 * which keeps this component free of routing concerns and easy to reuse.
 */
export function Header({ title, subtitle, onBack, right, variant = 'plain', style }: HeaderProps) {
  const { colors } = useTheme();
  const backSlop = Math.max(0, (MIN_TOUCH_TARGET - iconSize.lg) / 2);

  return (
    <View
      style={[
        styles.container,
        variant === 'floating' && [
          styles.floating,
          shadows.md,
          { backgroundColor: colors.surface, borderRadius: radius.xl },
        ],
        style,
      ]}
    >
      {onBack && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Volver"
          hitSlop={backSlop}
          onPress={onBack}
        >
          <ChevronLeft
            size={iconSize.lg}
            color={colors.textPrimary}
            strokeWidth={iconStrokeWidth}
          />
        </Pressable>
      )}

      <View style={styles.titles}>
        {title !== undefined && (
          <Text variant="subheading" numberOfLines={1}>
            {title}
          </Text>
        )}
        {subtitle !== undefined && (
          <Text variant="caption" color="textSecondary" numberOfLines={1}>
            {subtitle}
          </Text>
        )}
      </View>

      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  floating: {
    marginHorizontal: spacing.lg,
  },
  titles: {
    flex: 1,
  },
});
