/**
 * Spacing scale, in density-independent pixels.
 *
 * Every margin, padding and gap in the app comes from this scale. The steps are
 * multiples of 4, which is what Android's material grid and most icon sets are
 * built on, so components line up without manual nudging.
 *
 * Naming is intentionally abstract (`md`, `lg`) rather than numeric. If the
 * whole interface ever needs to breathe more, the values change here and every
 * screen follows.
 */
export const spacing = {
  /** 2 - hairline separation, rarely needed. */
  xxs: 2,
  /** 4 - between an icon and its label. */
  xs: 4,
  /** 8 - inside compact controls. */
  sm: 8,
  /** 12 - default gap between related elements. */
  md: 12,
  /** 16 - screen horizontal padding, card padding. */
  lg: 16,
  /** 24 - separation between sections. */
  xl: 24,
  /** 32 - generous breathing room. */
  xxl: 32,
  /** 48 - empty states, top of onboarding screens. */
  xxxl: 48,
} as const;

export type SpacingToken = keyof typeof spacing;

/**
 * Minimum touch target, in dp.
 *
 * Android accessibility guidance sets 48dp as the floor. This matters more than
 * usual here: drivers will tap these controls one-handed, outdoors, sometimes
 * wearing gloves. Any pressable smaller than this must be padded to reach it.
 */
export const MIN_TOUCH_TARGET = 48;
