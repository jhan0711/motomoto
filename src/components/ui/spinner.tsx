import { ActivityIndicator, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

import { spacing, useTheme } from '@/theme';

import { Text, type ColorToken } from './text';

export interface SpinnerProps {
  size?: 'small' | 'large';
  color?: ColorToken;
  /** Optional caption below the indicator. */
  label?: string;
  /** Centers the spinner in all available space. */
  centered?: boolean;
  style?: StyleProp<ViewStyle>;
}

/**
 * Indeterminate loading indicator.
 *
 * Use it for short waits where the shape of the result is unknown, such as
 * submitting a form. For anything list-shaped, `Skeleton` is the better choice.
 */
export function Spinner({
  size = 'small',
  color = 'textSecondary',
  label,
  centered = false,
  style,
}: SpinnerProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.container, centered && styles.centered, style]}>
      <ActivityIndicator size={size} color={colors[color]} />
      {label !== undefined && (
        <Text variant="caption" color="textSecondary" align="center">
          {label}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  centered: {
    flex: 1,
    justifyContent: 'center',
  },
  container: {
    alignItems: 'center',
    gap: spacing.sm,
  },
});
