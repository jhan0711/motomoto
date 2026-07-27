/**
 * Border radius scale.
 *
 * The Phase 0 direction calls for moderately rounded corners: soft enough to
 * feel current, restrained enough to stay professional.
 */
export const radius = {
  /** 4 - badges, small tags. */
  sm: 4,
  /** 8 - inputs, small buttons. */
  md: 8,
  /** 12 - cards, primary buttons. */
  lg: 12,
  /** 16 - prominent containers. */
  xl: 16,
  /** 24 - bottom sheet top corners. */
  xxl: 24,
  /** Pill shape. Any value larger than half the height works. */
  full: 999,
} as const;

export type RadiusToken = keyof typeof radius;
