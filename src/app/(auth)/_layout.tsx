import { Redirect, Stack } from 'expo-router';

import { homeRouteFor, useSession } from '@/features/auth/session';

/**
 * Public zone guard.
 *
 * Keeps signed-in users out of the welcome, login and register screens. Without
 * it, pressing back after signing in lands on the login form again, which reads
 * as if the session was lost.
 *
 * The guard lives in the layout rather than in each screen so a new public
 * screen is protected the moment it is created, with nothing to remember.
 */
export default function AuthLayout() {
  const { user, isLoading, isRecoveringPassword } = useSession();

  if (isLoading) {
    return null;
  }

  // Durante una recuperacion hay sesion abierta, pero el usuario debe quedarse
  // aqui hasta cambiar la contrasena. Sin esta excepcion, el enlace del correo
  // lo mandaria a la pantalla principal y nunca llegaria a cambiarla.
  if (user !== null && !isRecoveringPassword) {
    return <Redirect href={homeRouteFor(user.role)} />;
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
