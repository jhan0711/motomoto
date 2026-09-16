import * as Location from 'expo-location';
import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState, Linking } from 'react-native';

import type { Coordinates } from './region';

/**
 * Every situation the passenger's location can be in.
 *
 * Modelled as a discriminated union rather than a handful of booleans. With
 * booleans, `isLoading && hasError && !hasPermission` is representable and
 * meaningless; here the screen handles a fixed list of cases and TypeScript
 * refuses to let one be forgotten.
 */
export type LocationState =
  /** Asking the system what the situation is. Sub-second, but real. */
  | { kind: 'checking' }
  /**
   * No permission. `canAsk` false means the user denied it permanently and
   * Android will no longer show the dialog: the only way out is Settings.
   */
  | { kind: 'permission-required'; canAsk: boolean }
  /** Permission granted, but the device's location services are switched off. */
  | { kind: 'services-disabled' }
  /** Permission granted, waiting for the first fix. */
  | { kind: 'locating' }
  /** Gave up waiting. Indoors, or no satellite view. Retryable. */
  | { kind: 'unavailable' }
  | { kind: 'ready'; coords: Coordinates };

/**
 * How long to wait for the first fix before showing a way out.
 *
 * Indoors a cold GPS start can take a minute or more. Leaving the passenger
 * looking at a spinner that whole time reads as a frozen app, so at 20 seconds
 * we say what is happening and offer a retry. The watcher keeps running: if the
 * fix arrives at second 40, the screen updates on its own.
 */
const FIRST_FIX_TIMEOUT_MS = 20_000;

export interface UseLocationResult {
  state: LocationState;
  /** Triggers the system permission dialog. Only useful when `canAsk` is true. */
  requestPermission: () => Promise<void>;
  /** Android dialog to switch location services on, without leaving the app. */
  enableServices: () => Promise<void>;
  /** For the permanently denied case: the app's page in system Settings. */
  openSettings: () => Promise<void>;
  /** Re-runs the whole check. */
  retry: () => void;
}

/**
 * Foreground location for the passenger's map.
 *
 * Foreground only, deliberately: the passenger's own position never needs to
 * be known while the app is minimized, there is no screen to show it on. The
 * driver's location has a background counterpart since 2026-09-15
 * (`useBackgroundLocation`, `features/driver/use-background-location.ts`),
 * scoped to the driver's own "available" state and not shared with this hook.
 */
export function useLocation(): UseLocationResult {
  const [state, setState] = useState<LocationState>({ kind: 'checking' });

  const subscription = useRef<Location.LocationSubscription | null>(null);
  const timeoutId = useRef<ReturnType<typeof setTimeout> | null>(null);
  /**
   * Guards against a resolved promise writing state after the screen is gone,
   * and against an older check overwriting a newer one when the user retries
   * while a check is still in flight.
   */
  const runId = useRef(0);

  const stopWatching = useCallback(() => {
    subscription.current?.remove();
    subscription.current = null;
    if (timeoutId.current !== null) {
      clearTimeout(timeoutId.current);
      timeoutId.current = null;
    }
  }, []);

  const check = useCallback(async () => {
    runId.current += 1;
    const id = runId.current;
    const isStale = () => id !== runId.current;

    stopWatching();

    // Nothing sets state before this await, on purpose. The mount effect calls
    // this function, and React's compiler rejects a synchronous setState inside
    // an effect body: it causes a second render before the first has painted.
    // The 'checking' state is set by `retry`, which is an event handler and may
    // do it freely. On mount it is redundant anyway, since that is the initial
    // value of the state.
    const permission = await Location.getForegroundPermissionsAsync();
    if (isStale()) return;

    if (!permission.granted) {
      setState({ kind: 'permission-required', canAsk: permission.canAskAgain });
      return;
    }

    const servicesOn = await Location.hasServicesEnabledAsync();
    if (isStale()) return;

    if (!servicesOn) {
      setState({ kind: 'services-disabled' });
      return;
    }

    setState({ kind: 'locating' });

    timeoutId.current = setTimeout(() => {
      if (isStale()) return;
      // Only a timeout if nothing arrived. Once a fix lands the state is
      // 'ready', and overwriting it here would blank a working map.
      setState((current) => (current.kind === 'locating' ? { kind: 'unavailable' } : current));
    }, FIRST_FIX_TIMEOUT_MS);

    try {
      subscription.current = await Location.watchPositionAsync(
        {
          // Balanced, not BestForNavigation. On the passenger's map a few metres
          // of error are invisible, and the high-accuracy mode keeps the GPS
          // chip busy continuously. Turn-by-turn precision is the driver's
          // problem, in Phase 14.
          accuracy: Location.Accuracy.Balanced,
          timeInterval: 5000,
          distanceInterval: 10,
        },
        (position) => {
          if (isStale()) return;
          setState({
            kind: 'ready',
            coords: {
              latitude: position.coords.latitude,
              longitude: position.coords.longitude,
            },
          });
        },
      );
    } catch {
      if (isStale()) return;
      setState({ kind: 'unavailable' });
    }
  }, [stopWatching]);

  /**
   * The only effect: subscribe to the app's foreground/background changes, and
   * kick off the first check.
   *
   * Re-checking on foreground matters. Without it, a passenger who leaves to
   * grant the permission in Settings comes back to the same "no permission"
   * screen and concludes the app is broken. Same for switching GPS on from the
   * notification shade.
   *
   * The first check is deferred through a timer rather than called straight from
   * the effect body. React's compiler rejects a setState reachable from an
   * effect body, and it is right to: state that changes during commit forces a
   * second render before the first has painted. Running it from the timer's
   * callback puts the work after the commit, which is where it belongs.
   */
  useEffect(() => {
    const listener = AppState.addEventListener('change', (next) => {
      if (next === 'active') void check();
    });

    const firstCheck = setTimeout(() => void check(), 0);

    return () => {
      listener.remove();
      clearTimeout(firstCheck);
      // Invalidates any check still in flight, so a late resolution cannot
      // write state after the screen is gone.
      runId.current += 1;
      stopWatching();
    };
  }, [check, stopWatching]);

  const requestPermission = useCallback(async () => {
    await Location.requestForegroundPermissionsAsync();
    // Re-check rather than trusting the dialog's answer: services may still be
    // off, so granting alone does not mean we can locate anyone.
    await check();
  }, [check]);

  const enableServices = useCallback(async () => {
    try {
      // Android's in-app dialog. Better than sending them to Settings, because
      // they come straight back with it enabled.
      await Location.enableNetworkProviderAsync();
    } catch {
      // Rejecting the dialog throws. Not an error: it is an answer.
    }
    await check();
  }, [check]);

  const openSettings = useCallback(async () => {
    await Linking.openSettings();
  }, []);

  const retry = useCallback(() => {
    // Safe here, and needed: this runs from a button press, not from an effect,
    // and without it the previous error stays on screen with no sign that
    // anything is happening.
    setState({ kind: 'checking' });
    void check();
  }, [check]);

  return { state, requestPermission, enableServices, openSettings, retry };
}
