/**
 * Layout tokens.
 *
 * MAX_CONTENT_WIDTH is the widest a column of content is allowed to become,
 * regardless of how large the display is.
 *
 * Why this exists: verified on a Lenovo TB-X306X, a tablet whose logical width
 * is 800dp against a phone's 411dp. Without a cap, a full-width button stretches
 * across the entire display. That is bad in two measurable ways: a line of text
 * past roughly 75 characters is harder to read, and a 20-centimeter-wide button
 * forces the eye to hunt for its label instead of seeing it.
 *
 * 520dp is deliberately close to a large phone. The interface then looks like
 * the same app on every device, only better centered, instead of a phone layout
 * inflated to fill a tablet.
 *
 * Screens that must fill the display, such as the map, opt out.
 */
export const MAX_CONTENT_WIDTH = 520;
