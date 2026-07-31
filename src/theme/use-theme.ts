import { useMemo } from 'react';
import { useColorScheme } from 'react-native';

import { darkColors, lightColors, type ThemeColors } from './colors';

export type ColorSchemeName = 'light' | 'dark';

export interface Theme {
  /** Semantic colors for the active scheme. */
  colors: ThemeColors;
  /** The active scheme. */
  scheme: ColorSchemeName;
  /** Convenience flag, for the common `isDark ? a : b` case. */
  isDark: boolean;
}

/**
 * Reads the active color scheme and returns the matching color set.
 *
 * Right now this follows the operating system, which is what
 * `userInterfaceStyle: 'automatic'` in app.config.ts enables. There is no
 * in-app theme switch yet.
 *
 * When one is needed, only the body of this hook changes: it will read from a
 * context provider instead of from the OS. Every component that calls
 * `useTheme()` keeps working untouched, which is the reason components never
 * import `lightColors` or `darkColors` directly.
 *
 * The result is memoized because it is an object: without this, every render
 * would produce a new reference and any `useEffect` depending on it would fire
 * on every render.
 */
export function useTheme(): Theme {
  const systemScheme = useColorScheme();

  return useMemo<Theme>(() => {
    // useColorScheme can return null while the value is unknown. Light is the
    // safe default: the interface is designed light-first.
    const scheme: ColorSchemeName = systemScheme === 'dark' ? 'dark' : 'light';

    return {
      colors: scheme === 'dark' ? darkColors : lightColors,
      scheme,
      isDark: scheme === 'dark',
    };
  }, [systemScheme]);
}
