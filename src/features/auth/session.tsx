import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

/**
 * TEMPORARY session state.
 *
 * There is no backend yet. This file fakes a signed-in user so the navigation
 * structure, the route guards and the role split can be built and tested before
 * Supabase exists.
 *
 * In Phase 6 the internals are replaced by Supabase Auth. The exported shape
 * stays the same, so no screen and no guard has to change: they already consume
 * `user`, `isLoading`, `signInAs` and `signOut`.
 *
 * Everything marked TEMPORARY below is what disappears.
 */

/**
 * Roles that use the mobile app.
 *
 * `admin` is intentionally absent: administrators work from the web panel built
 * in Phase 20 and never sign in here.
 */
export type UserRole = 'passenger' | 'driver';

export interface SessionUser {
  id: string;
  fullName: string;
  role: UserRole;
}

interface SessionValue {
  /** Null when nobody is signed in. */
  user: SessionUser | null;
  /**
   * True while the stored session is being restored. Guards must wait for this
   * to be false before redirecting, otherwise a returning user is bounced to
   * the welcome screen for a frame before their session loads.
   */
  isLoading: boolean;
  signInAs: (role: UserRole) => void;
  signOut: () => void;
}

const SessionContext = createContext<SessionValue | null>(null);

/** TEMPORARY: stand-in users until real accounts exist. */
const FAKE_USERS: Record<UserRole, SessionUser> = {
  passenger: {
    id: 'temp-passenger',
    fullName: 'Ana Restrepo',
    role: 'passenger',
  },
  driver: {
    id: 'temp-driver',
    fullName: 'Carlos Mesa',
    role: 'driver',
  },
};

export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null);

  // TEMPORARY: always false. Phase 6 sets this true while Supabase restores the
  // stored session from disk.
  const isLoading = false;

  const signInAs = useCallback((role: UserRole) => {
    setUser(FAKE_USERS[role]);
  }, []);

  const signOut = useCallback(() => {
    setUser(null);
  }, []);

  const value = useMemo<SessionValue>(
    () => ({ user, isLoading, signInAs, signOut }),
    [user, isLoading, signInAs, signOut],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

/**
 * Reads the current session.
 *
 * Throws when used outside the provider. That is deliberate: a screen silently
 * receiving `null` because the provider is missing would look exactly like a
 * signed-out user, and the bug would surface as a mysterious redirect loop.
 */
export function useSession(): SessionValue {
  const context = useContext(SessionContext);

  if (context === null) {
    throw new Error('useSession debe usarse dentro de SessionProvider');
  }

  return context;
}

/** Home route for each role. Used by the guards and after signing in. */
export function homeRouteFor(role: UserRole): '/passenger' | '/driver' {
  return role === 'driver' ? '/driver' : '/passenger';
}
