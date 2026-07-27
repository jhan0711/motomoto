import { Text as RNText, type TextProps as RNTextProps, type TextStyle } from 'react-native';

import { textStyles, useTheme, type ThemeColors, type TextVariant } from '@/theme';

/**
 * Any semantic color name from the theme. Typing the prop this way means an
 * invalid color is a compile error, not a silently transparent text.
 */
export type ColorToken = keyof ThemeColors;

export interface TextProps extends RNTextProps {
  /** Size and weight preset. Defaults to body copy. */
  variant?: TextVariant;
  /** Semantic color name. Defaults to primary text. */
  color?: ColorToken;
  /** Horizontal alignment. */
  align?: TextStyle['textAlign'];
}

/**
 * The only text component the app uses.
 *
 * Screens never import `Text` from react-native directly. Going through this
 * component is what guarantees that every string in the app picks its size,
 * weight and color from the design tokens, and that all of it re-themes
 * correctly in dark mode.
 */
export function Text({
  variant = 'body',
  color = 'textPrimary',
  align,
  style,
  ...rest
}: TextProps) {
  const { colors } = useTheme();

  return (
    <RNText
      style={[
        textStyles[variant],
        { color: colors[color] },
        align ? { textAlign: align } : null,
        style,
      ]}
      {...rest}
    />
  );
}
