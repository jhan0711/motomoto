import { Redirect, Stack } from 'expo-router';

import { homeRouteFor, useSession } from '@/features/auth/session';

/**
 * Passenger zone guard.
 *
 * Two separate checks, and both matter:
 *   - no session at all sends the user to the public zone
 *   - a driver who somehow lands here is sent to their own zone, not signed out
 *
 * Note this is a convenience, not a security boundary. Anything that actually
 * protects data lives in the database policies built in Phase 5. A guard in the
 * client only decides what is rendered.
 *
 * No bottom tab bar here, deliberately: the map screen puts a bottom sheet
 * exactly where the tabs would sit, and both would fight for the same gesture.
 */
export default function PassengerLayout() {
  const { user, isLoading } = useSession();

  if (isLoading) {
    return null;
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  if (user.role !== 'passenger') {
    return <Redirect href={homeRouteFor(user.role)} />;
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
