/**
 * Icon tokens.
 *
 * The whole app draws icons with `lucide-react-native`, a single family with a
 * consistent grid and stroke. Mixing icon families is the fastest way to make a
 * careful interface look sloppy, so there is exactly one source.
 *
 * Emojis are never used as icons. That rule is deliberate: emojis render
 * differently on every Android version and manufacturer skin, cannot be
 * recolored, and cannot be resized reliably.
 */
export const iconSize = {
  /** 14 - inline with small text. */
  xs: 14,
  /** 16 - inline with body text. */
  sm: 16,
  /** 20 - inside buttons and list rows. */
  md: 20,
  /** 24 - default. Lucide is designed on a 24px grid. */
  lg: 24,
  /** 32 - section headers. */
  xl: 32,
  /** 48 - empty states and error states. */
  xxl: 48,
} as const;

export type IconSizeToken = keyof typeof iconSize;

/**
 * Stroke width, in the units Lucide expects.
 *
 * Lucide's own default is 2. We use 1.75 because at the sizes this app renders
 * icons, 2 reads slightly heavy next to the type.
 */
export const iconStrokeWidth = 1.75;
