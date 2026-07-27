import type { ViewStyle } from 'react-native';

/**
 * Elevation tokens.
 *
 * React Native draws shadows differently per platform: Android uses the
 * `elevation` property, iOS uses the `shadow*` family. Each token sets both so
 * a component gets the right result without checking the platform.
 *
 * The Phase 0 direction asks for discreet shadows. These are deliberately
 * subtle: on a screen dominated by a map, heavy shadows make cards look like
 * they are floating away from the interface.
 */
export type ElevationToken = 'none' | 'sm' | 'md' | 'lg';

export const shadows: Record<ElevationToken, ViewStyle> = {
  none: {
    elevation: 0,
    shadowColor: 'transparent',
    shadowOpacity: 0,
    shadowRadius: 0,
    shadowOffset: { width: 0, height: 0 },
  },
  /** Resting cards and list rows. */
  sm: {
    elevation: 2,
    shadowColor: '#000000',
    shadowOpacity: 0.06,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 1 },
  },
  /** Elements sitting on top of the map. */
  md: {
    elevation: 5,
    shadowColor: '#000000',
    shadowOpacity: 0.1,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 3 },
  },
  /** Bottom sheets and modals. */
  lg: {
    elevation: 12,
    shadowColor: '#000000',
    shadowOpacity: 0.16,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 8 },
  },
};
