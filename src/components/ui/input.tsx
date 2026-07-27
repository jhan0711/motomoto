import { CircleAlert, Eye, EyeOff, type LucideIcon } from 'lucide-react-native';
import { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';

import {
  MIN_TOUCH_TARGET,
  iconSize,
  iconStrokeWidth,
  radius,
  spacing,
  textStyles,
  useTheme,
} from '@/theme';

import { Text } from './text';

export interface InputProps extends Omit<TextInputProps, 'style' | 'placeholderTextColor'> {
  /** Field name shown above the input. */
  label?: string;
  /** Guidance shown below the input. Hidden while an error is present. */
  helperText?: string;
  /** Validation message. Its presence is what puts the field in error state. */
  errorText?: string;
  /** Leading icon, passed uninstantiated: `icon={Mail}`. */
  icon?: LucideIcon;
  style?: StyleProp<ViewStyle>;
}

const FIELD_HEIGHT = 52;

/**
 * Text field.
 *
 * Error handling is driven by `errorText` alone rather than a separate boolean.
 * One source of truth means a field can never be red without saying why, which
 * is a real failure mode in forms.
 *
 * When `secureTextEntry` is set, a visibility toggle appears automatically.
 * Passwords that cannot be revealed cause typos and failed logins, and this app
 * will be used outdoors on small screens.
 */
export function Input({
  label,
  helperText,
  errorText,
  icon: Icon,
  secureTextEntry = false,
  editable = true,
  style,
  ...rest
}: InputProps) {
  const { colors } = useTheme();
  const [isFocused, setIsFocused] = useState(false);
  const [isSecureVisible, setIsSecureVisible] = useState(false);

  const hasError = errorText !== undefined && errorText.length > 0;

  const borderColor = hasError ? colors.danger : isFocused ? colors.brand : colors.border;

  const ToggleIcon = isSecureVisible ? EyeOff : Eye;
  const toggleSlop = Math.max(0, (MIN_TOUCH_TARGET - iconSize.md) / 2);

  return (
    <View style={[styles.container, style]}>
      {label !== undefined && (
        <Text variant="label" color={editable ? 'textSecondary' : 'textTertiary'}>
          {label}
        </Text>
      )}

      <View
        style={[
          styles.field,
          {
            backgroundColor: editable ? colors.surface : colors.surfaceSubtle,
            borderColor,
            borderRadius: radius.md,
          },
        ]}
      >
        {Icon && (
          <Icon
            size={iconSize.md}
            color={hasError ? colors.danger : colors.textTertiary}
            strokeWidth={iconStrokeWidth}
          />
        )}

        <TextInput
          style={[styles.input, textStyles.body, { color: colors.textPrimary }]}
          placeholderTextColor={colors.textTertiary}
          secureTextEntry={secureTextEntry && !isSecureVisible}
          editable={editable}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          accessibilityLabel={label}
          {...rest}
        />

        {secureTextEntry && (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={isSecureVisible ? 'Ocultar contraseña' : 'Mostrar contraseña'}
            hitSlop={toggleSlop}
            onPress={() => setIsSecureVisible((visible) => !visible)}
          >
            <ToggleIcon
              size={iconSize.md}
              color={colors.textSecondary}
              strokeWidth={iconStrokeWidth}
            />
          </Pressable>
        )}
      </View>

      {hasError ? (
        <View style={styles.message}>
          <CircleAlert size={iconSize.sm} color={colors.danger} strokeWidth={iconStrokeWidth} />
          <Text variant="caption" color="danger" style={styles.messageText}>
            {errorText}
          </Text>
        </View>
      ) : helperText !== undefined ? (
        <Text variant="caption" color="textTertiary">
          {helperText}
        </Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.xs,
  },
  field: {
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth * 2,
    flexDirection: 'row',
    gap: spacing.sm,
    height: FIELD_HEIGHT,
    paddingHorizontal: spacing.md,
  },
  input: {
    flex: 1,
    // Android adds vertical padding to TextInput by default, which breaks the
    // fixed field height. Zeroing it keeps the text centered.
    paddingVertical: 0,
  },
  message: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  messageText: {
    flex: 1,
  },
});
