import type { LucideIcon } from 'lucide-react-native';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  View,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import {
  MIN_TOUCH_TARGET,
  iconSize,
  iconStrokeWidth,
  radius,
  spacing,
  useTheme,
  type ThemeColors,
} from '@/theme';

import { Text, type ColorToken } from './text';

export type ButtonVariant = 'primary' | 'brand' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends Omit<PressableProps, 'style' | 'children' | 'disabled'> {
  /** Visible label. Never empty: an icon-only control is a different component. */
  label: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** A Lucide icon component, passed uninstantiated: `icon={MapPin}`. */
  icon?: LucideIcon;
  iconPosition?: 'left' | 'right';
  /** Replaces the label with a spinner and blocks presses. */
  loading?: boolean;
  disabled?: boolean;
  /** Stretches to the width of the parent. */
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
}

/** Height per size. `sm` sits below the 48dp minimum on purpose, see below. */
const HEIGHT: Record<ButtonSize, number> = { sm: 40, md: 48, lg: 56 };
const PADDING: Record<ButtonSize, number> = { sm: spacing.md, md: spacing.lg, lg: spacing.xl };

interface VariantColors {
  background: string;
  backgroundPressed: string;
  content: ColorToken;
  border?: string;
}

function resolveVariant(variant: ButtonVariant, colors: ThemeColors): VariantColors {
  switch (variant) {
    case 'primary':
      return {
        background: colors.action,
        backgroundPressed: colors.actionPressed,
        content: 'onAction',
      };
    case 'brand':
      return {
        background: colors.brand,
        backgroundPressed: colors.brandStrong,
        content: 'onBrand',
      };
    case 'secondary':
      return {
        background: colors.surface,
        backgroundPressed: colors.surfacePressed,
        content: 'textPrimary',
        border: colors.border,
      };
    case 'ghost':
      return {
        background: 'transparent',
        backgroundPressed: colors.surfacePressed,
        content: 'textPrimary',
      };
    case 'danger':
      return {
        background: colors.danger,
        backgroundPressed: colors.danger,
        content: 'onDanger',
      };
  }
}

/**
 * Primary action control.
 *
 * Touch target: `sm` is 40dp tall, below the 48dp accessibility floor. Rather
 * than inflate the visual size, it gets `hitSlop` so the tappable area reaches
 * 48dp while the button still looks small. This is the correct fix in React
 * Native and it matters here: drivers tap these outdoors, one-handed.
 */
export function Button({
  label,
  variant = 'primary',
  size = 'md',
  icon: Icon,
  iconPosition = 'left',
  loading = false,
  disabled = false,
  fullWidth = false,
  style,
  ...rest
}: ButtonProps) {
  const { colors } = useTheme();
  const variantColors = resolveVariant(variant, colors);

  // Two separate concerns, deliberately not merged:
  //   - `isInert` blocks the press. Both states block it.
  //   - `disabled` alone changes the appearance. A loading button keeps its
  //     variant colors so the user still sees the action they just triggered,
  //     instead of a control that looks broken.
  const isInert = disabled || loading;
  const height = HEIGHT[size];
  const verticalSlop = Math.max(0, (MIN_TOUCH_TARGET - height) / 2);

  const contentColor = disabled ? 'textTertiary' : variantColors.content;
  const resolvedIconSize = size === 'sm' ? iconSize.sm : iconSize.md;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: isInert, busy: loading }}
      accessibilityLabel={label}
      disabled={isInert}
      hitSlop={{ top: verticalSlop, bottom: verticalSlop }}
      style={({ pressed }) => [
        styles.base,
        {
          height,
          paddingHorizontal: PADDING[size],
          borderRadius: radius.lg,
          backgroundColor: disabled
            ? colors.actionDisabled
            : pressed
              ? variantColors.backgroundPressed
              : variantColors.background,
        },
        variantColors.border !== undefined && {
          borderWidth: StyleSheet.hairlineWidth * 2,
          borderColor: disabled ? colors.border : variantColors.border,
        },
        fullWidth && styles.fullWidth,
        style,
      ]}
      {...rest}
    >
      {loading ? (
        <ActivityIndicator color={colors[contentColor]} size="small" />
      ) : (
        <View style={styles.content}>
          {Icon && iconPosition === 'left' && (
            <Icon
              size={resolvedIconSize}
              color={colors[contentColor]}
              strokeWidth={iconStrokeWidth}
            />
          )}
          <Text variant="button" color={contentColor} numberOfLines={1}>
            {label}
          </Text>
          {Icon && iconPosition === 'right' && (
            <Icon
              size={resolvedIconSize}
              color={colors[contentColor]}
              strokeWidth={iconStrokeWidth}
            />
          )}
        </View>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    justifyContent: 'center',
  },
  content: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
  },
  fullWidth: {
    alignSelf: 'stretch',
  },
});
