import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { SessionProvider, useSession } from '@/features/auth/session';
import { usePushRegistration } from '@/features/notifications/use-push-registration';
import { useTheme } from '@/theme';

/**
 * Root layout.
 *
 * Four things happen here and nowhere else:
 *
 *   1. `GestureHandlerRootView` wraps the app. Without it, gestures silently do
 *      nothing: no error, no warning, the bottom sheet just refuses to drag.
 *   2. `SafeAreaProvider` is mounted. Without it, the `Screen` component cannot
 *      read the device insets and content ends up under the status bar.
 *   3. The native header is switched off for every route. The app uses its own
 *      `Header` component so headers follow the theme and can float over a map.
 *   4. The status bar icons flip between light and dark with the theme. Left
 *      alone, dark icons on a dark background become invisible.
 */
export default function RootLayout() {
  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaProvider>
        <SessionProvider>
          <RootNavigator />
        </SessionProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
});

/**
 * Split out from `RootLayout` because `useTheme` must run inside the provider
 * tree, and because the navigator needs the resolved background color to avoid
 * a white flash between screen transitions in dark mode.
 */
function RootNavigator() {
  const { colors, isDark } = useTheme();
  const { user } = useSession();

  // Una vez por sesion abierta y no por pantalla (Fase 19): asi sirve igual
  // para el pasajero que para el conductor, sin repetir la llamada en cada
  // zona de la aplicacion.
  usePushRegistration(user?.id ?? null);

  return (
    <>
      <StatusBar style={isDark ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: colors.background },
        }}
      />
    </>
  );
}
