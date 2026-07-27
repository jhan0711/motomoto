import { Redirect } from 'expo-router';

import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { homeRouteFor, useSession } from '@/features/auth/session';

/**
 * Entry route.
 *
 * Renders nothing of its own: it reads the session and sends the user where
 * they belong. Centralizing this here means no other screen has to reason about
 * whether somebody is signed in.
 *
 * The loading branch matters more than it looks. When Phase 6 restores a stored
 * session from disk, that read is asynchronous. Without waiting for it, a user
 * who is already signed in gets a flash of the welcome screen on every cold
 * start.
 */
export default function Index() {
  const { user, isLoading } = useSession();

  if (isLoading) {
    return (
      <Screen>
        <Spinner size="large" centered label="Cargando" />
      </Screen>
    );
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  return <Redirect href={homeRouteFor(user.role)} />;
}
