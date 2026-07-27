import type { TextStyle } from 'react-native';

/**
 * Typography tokens.
 *
 * FONT CHOICE: the app uses the platform's system font (Roboto on Android)
 * rather than shipping a custom typeface.
 *
 * Reasons, so the decision can be revisited with full context:
 *   - Roboto is a modern, highly legible grotesque. It meets the Phase 0 brief.
 *   - System fonts render on first frame. A bundled font has to load before
 *     text appears, which means coordinating with the splash screen.
 *   - System fonts honor the user's OS-level font size preference, which
 *     matters for drivers reading a screen in daylight, at a glance.
 *   - It adds no weight to the APK.
 *
 * If a custom face is adopted later, only `fontFamily` below changes, plus a
 * font loader in the root layout. No screen needs to be touched.
 */

/** Set to a loaded font family name to switch the whole app at once. */
export const fontFamily: TextStyle['fontFamily'] = undefined;

export const fontSize = {
  xs: 11,
  sm: 13,
  md: 15,
  lg: 17,
  xl: 20,
  xxl: 24,
  xxxl: 32,
} as const;

/**
 * Weights as strings, which is what React Native expects.
 * Android maps 600 to a real semibold cut of Roboto.
 */
export const fontWeight = {
  regular: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
} as const satisfies Record<string, TextStyle['fontWeight']>;

export type TextVariant =
  | 'display'
  | 'title'
  | 'heading'
  | 'subheading'
  | 'body'
  | 'bodyStrong'
  | 'button'
  | 'label'
  | 'caption';

/**
 * Ready-made text styles. Components pick a variant instead of assembling a
 * size and a weight by hand, which is what keeps screens visually consistent.
 *
 * Line heights get tighter as the size grows: large type needs proportionally
 * less leading to look right.
 */
export const textStyles: Record<TextVariant, TextStyle> = {
  display: {
    fontFamily,
    fontSize: fontSize.xxxl,
    fontWeight: fontWeight.bold,
    lineHeight: 38,
    letterSpacing: -0.5,
  },
  title: {
    fontFamily,
    fontSize: fontSize.xxl,
    fontWeight: fontWeight.bold,
    lineHeight: 30,
    letterSpacing: -0.3,
  },
  heading: {
    fontFamily,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.semibold,
    lineHeight: 26,
  },
  subheading: {
    fontFamily,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.semibold,
    lineHeight: 24,
  },
  body: {
    fontFamily,
    fontSize: fontSize.md,
    fontWeight: fontWeight.regular,
    lineHeight: 22,
  },
  bodyStrong: {
    fontFamily,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    lineHeight: 22,
  },
  button: {
    fontFamily,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    lineHeight: 20,
  },
  label: {
    fontFamily,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
    lineHeight: 18,
  },
  caption: {
    fontFamily,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.regular,
    lineHeight: 18,
  },
};
