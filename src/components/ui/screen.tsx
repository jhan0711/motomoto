import type { ReactNode } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView, type Edge } from 'react-native-safe-area-context';

import { MAX_CONTENT_WIDTH, spacing, useTheme } from '@/theme';

export interface ScreenProps {
  children: ReactNode;
  /**
   * Rendered above the content and outside the scroll area, so it stays fixed
   * while the body scrolls. Usually a `Header`.
   */
  header?: ReactNode;
  /** Wraps the content in a ScrollView. Off by default: most screens are maps. */
  scroll?: boolean;
  /** Applies the standard horizontal padding. Turn off for full-bleed maps. */
  padded?: boolean;
  /**
   * Which safe area edges to respect. Screens whose content runs under the
   * status bar, such as a full-screen map, should drop 'top'.
   */
  edges?: readonly Edge[];
  /** `background` for plain screens, `surface` for card-like ones. */
  background?: 'background' | 'surface';
  /**
   * Caps the content column at MAX_CONTENT_WIDTH and centers it, so the layout
   * stays readable on tablets. On a phone it has no effect, since the screen is
   * already narrower than the cap. Turn it off for screens that must fill the
   * display edge to edge.
   */
  constrained?: boolean;
  contentContainerStyle?: StyleProp<ViewStyle>;
  style?: StyleProp<ViewStyle>;
}

const DEFAULT_EDGES: readonly Edge[] = ['top', 'bottom'];

/**
 * Screen container.
 *
 * Every route renders inside one of these. Centralizing it means no screen can
 * forget the background color, run its content under the notch, or leave a form
 * hidden behind the keyboard. Those three bugs are individually trivial and
 * collectively guarantee an app that feels unfinished.
 *
 * On Android, `KeyboardAvoidingView` gets no behavior on purpose: the system
 * already resizes the window (`adjustResize`), and adding a behavior on top of
 * that shifts the layout twice.
 */
export function Screen({
  children,
  header,
  scroll = false,
  padded = true,
  edges = DEFAULT_EDGES,
  background = 'background',
  constrained = true,
  contentContainerStyle,
  style,
}: ScreenProps) {
  const { colors } = useTheme();

  const body = scroll ? (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={[padded && styles.padded, styles.scrollContent, contentContainerStyle]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.flex, padded && styles.padded, contentContainerStyle]}>{children}</View>
  );

  return (
    <SafeAreaView
      edges={edges}
      style={[
        styles.flex,
        { backgroundColor: background === 'surface' ? colors.surface : colors.background },
        style,
      ]}
    >
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        {/* The header goes inside the constrained column too, so its title lines
            up with the content below instead of drifting to the far edge. */}
        <View style={[styles.flex, constrained && styles.constrained]}>
          {header}
          {body}
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  constrained: {
    alignSelf: 'center',
    maxWidth: MAX_CONTENT_WIDTH,
    width: '100%',
  },
  flex: {
    flex: 1,
  },
  padded: {
    paddingHorizontal: spacing.lg,
  },
  scrollContent: {
    flexGrow: 1,
    paddingBottom: spacing.xxl,
  },
});
