/**
 * Design system entry point.
 *
 * Components import from here and nowhere else:
 *
 *   import { spacing, radius, textStyles } from '@/theme';
 *
 * Colors are the exception: they depend on the active light or dark scheme, so
 * they are read through the `useTheme` hook instead of imported directly.
 */

export { darkColors, lightColors } from './colors';
export type { ThemeColors } from './colors';

export { iconSize, iconStrokeWidth } from './icons';
export type { IconSizeToken } from './icons';

export { radius } from './radius';
export type { RadiusToken } from './radius';

export { shadows } from './shadows';
export type { ElevationToken } from './shadows';

export { MIN_TOUCH_TARGET, spacing } from './spacing';
export type { SpacingToken } from './spacing';

export { fontFamily, fontSize, fontWeight, textStyles } from './typography';
export type { TextVariant } from './typography';

export { useTheme } from './use-theme';
export type { ColorSchemeName, Theme } from './use-theme';
