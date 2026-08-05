import type { LucideIcon } from 'lucide-react-native';
import type { ReactNode } from 'react';
import { Modal as RNModal, Pressable, StyleSheet, View } from 'react-native';

import { iconSize, iconStrokeWidth, radius, shadows, spacing, useTheme } from '@/theme';

import { Button } from './button';
import { Text } from './text';

export type ModalTone = 'neutral' | 'danger';

export interface ModalProps {
  visible: boolean;
  /** Fired by the Android back button and by tapping the scrim. */
  onRequestClose: () => void;
  title: string;
  description?: string;
  icon?: LucideIcon;
  /** `danger` for destructive confirmations, such as cancelling a ride. */
  tone?: ModalTone;
  confirmLabel?: string;
  onConfirm?: () => void;
  cancelLabel?: string;
  /** Blocks the confirm button and shows a spinner on it. */
  confirmLoading?: boolean;
  /** Extra content between the description and the actions. */
  children?: ReactNode;
}

/**
 * Centered dialog for confirmations and short decisions.
 *
 * Used instead of React Native's `Alert` so confirmations follow the app's
 * theme, typography and icon set. `Alert` renders a system dialog that ignores
 * all of it and looks different on every Android skin.
 *
 * The Android hardware back button is wired to `onRequestClose`. Skipping that
 * leaves users trapped in a dialog, which is a common and very visible bug.
 */
export function Modal({
  visible,
  onRequestClose,
  title,
  description,
  icon: Icon,
  tone = 'neutral',
  confirmLabel,
  onConfirm,
  cancelLabel = 'Cancelar',
  confirmLoading = false,
  children,
}: ModalProps) {
  const { colors } = useTheme();
  const isDanger = tone === 'danger';

  return (
    <RNModal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={onRequestClose}
    >
      {/* The scrim closes the dialog. Nested Pressable stops taps on the card
          from bubbling up and closing it by accident. */}
      <Pressable
        style={[styles.scrim, { backgroundColor: colors.overlay }]}
        onPress={onRequestClose}
        accessibilityRole="button"
        accessibilityLabel="Cerrar"
      >
        <Pressable
          style={[
            styles.card,
            shadows.lg,
            { backgroundColor: colors.surface, borderRadius: radius.xl },
          ]}
          onPress={() => {}}
        >
          {Icon && (
            <View
              style={[
                styles.iconWrapper,
                { backgroundColor: isDanger ? colors.dangerSubtle : colors.surfaceSubtle },
              ]}
            >
              <Icon
                size={iconSize.xl}
                color={isDanger ? colors.onDangerSubtle : colors.textSecondary}
                strokeWidth={iconStrokeWidth}
              />
            </View>
          )}

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

          {children}

          <View style={styles.actions}>
            {confirmLabel !== undefined && onConfirm !== undefined && (
              <Button
                label={confirmLabel}
                variant={isDanger ? 'danger' : 'primary'}
                fullWidth
                loading={confirmLoading}
                onPress={onConfirm}
              />
            )}
            <Button
              label={cancelLabel}
              variant="ghost"
              fullWidth
              disabled={confirmLoading}
              onPress={onRequestClose}
            />
          </View>
        </Pressable>
      </Pressable>
    </RNModal>
  );
}

const styles = StyleSheet.create({
  actions: {
    gap: spacing.sm,
    width: '100%',
  },
  card: {
    alignItems: 'center',
    gap: spacing.lg,
    maxWidth: 420,
    padding: spacing.xl,
    width: '100%',
  },
  copy: {
    gap: spacing.xs,
  },
  iconWrapper: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 64,
    justifyContent: 'center',
    width: 64,
  },
  scrim: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
    padding: spacing.xl,
  },
});
