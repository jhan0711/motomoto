import type { LucideIcon } from 'lucide-react-native';
import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';

import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import { Button } from './button';
import { Text } from './text';

export type EmptyStateTone = 'neutral' | 'danger';

export interface EmptyStateProps {
  /** A Lucide icon component, passed uninstantiated. Never an emoji. */
  icon: LucideIcon;
  title: string;
  description?: string;
  /** Shows an action button. Both props are needed for it to appear. */
  actionLabel?: string;
  onAction?: () => void;
  tone?: EmptyStateTone;
  style?: StyleProp<ViewStyle>;
}

/**
 * Placeholder for a screen or list with nothing to show.
 *
 * Every list in this app gets one. "No hay viajes todavía" with an explanation
 * is information; a blank screen is a bug the user cannot distinguish from a
 * failed request.
 *
 * The icon is deliberately typed as a Lucide component rather than a string or
 * a node: it is the only way to guarantee nobody drops an emoji in here.
 */
export function EmptyState({
  icon: Icon,
  title,
  description,
  actionLabel,
  onAction,
  tone = 'neutral',
  style,
}: EmptyStateProps) {
  const { colors } = useTheme();
  const isDanger = tone === 'danger';

  return (
    <View style={[styles.container, style]}>
      <View
        style={[
          styles.iconWrapper,
          { backgroundColor: isDanger ? colors.dangerSubtle : colors.surfaceSubtle },
        ]}
      >
        <Icon
          size={iconSize.xxl}
          color={isDanger ? colors.onDangerSubtle : colors.textTertiary}
          strokeWidth={iconStrokeWidth}
        />
      </View>

      <View style={styles.copy}>
        <Text variant="subheading" align="center">
          {title}
        </Text>
        {description !== undefined && (
          <Text variant="body" color="textSecondary" align="center">
            {description}
          </Text>
        )}
      </View>

      {actionLabel !== undefined && onAction !== undefined && (
        <Button label={actionLabel} variant="secondary" onPress={onAction} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    gap: spacing.lg,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.xxl,
  },
  copy: {
    gap: spacing.xs,
  },
  iconWrapper: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 88,
    justifyContent: 'center',
    width: 88,
  },
});
