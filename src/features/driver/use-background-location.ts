import * as Location from 'expo-location';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Linking } from 'react-native';

import { useNumericSetting } from '@/features/ride/settings';

import {
  BACKGROUND_LOCATION_TASK_NAME,
  backgroundLocationOptions,
  setBackgroundLocationDriverId,
} from './background-location-task';

/**
 * Ubicacion en segundo plano mientras el conductor esta disponible (pedido de
 * la empresa, validado con el dueno del producto el 2026-09-15).
 *
 * DELIBERADAMENTE SEPARADO de `useLocationReporting`, que sigue exactamente
 * como estaba: ese hook cubre el envio en PRIMER PLANO -disponible y en
 * viaje- y este cubre el envio en SEGUNDO PLANO, y SOLO para "disponible".
 * El alcance se decidio con el dueno del producto: "en viaje" se queda fuera
 * a proposito, porque ahi el argumento de D116 pesa mas -un pasajero viendo a
 * su conductor "congelado" en el mapa es peor que no verlo-, y separar los
 * dos hooks hace ese limite imposible de cruzar sin querer: este nunca recibe
 * "riding" como motivo para arrancar.
 *
 * Modelado como union discriminada, mismo criterio que `useLocation` en
 * `features/map/use-location.ts`.
 */
export type BackgroundLocationState =
  /** No aplica ahora mismo: no disponible, en viaje, o sin sesion. */
  | { kind: 'off' }
  | { kind: 'checking' }
  /** `canAsk` en falso desde Android 11 significa que no hay dialogo posible:
   * el conductor tiene que ir a Ajustes y elegir "Permitir todo el tiempo" a
   * mano, el sistema operativo ya no lo ofrece con un toque. */
  | { kind: 'permission-required'; canAsk: boolean }
  | { kind: 'active' }
  | { kind: 'error'; message: string };

export interface UseBackgroundLocationResult {
  state: BackgroundLocationState;
  /** Solo util cuando `state.kind === 'permission-required' && canAsk`. */
  requestPermission: () => Promise<void>;
  /** Para el caso donde ya no hay dialogo: la pantalla de ajustes de la app. */
  openSettings: () => Promise<void>;
}

/** Mismo valor de reserva que `useLocationReporting`, por si el parametro no
 * se puede leer (R9). */
const INTERVALO_DISPONIBLE_FALLBACK = 30;

export function useBackgroundLocation(
  driverId: string | null,
  disponibleSinViaje: boolean,
): UseBackgroundLocationResult {
  const intervaloDisponible = useNumericSetting(
    'location_interval_available_seconds',
    INTERVALO_DISPONIBLE_FALLBACK,
    disponibleSinViaje,
  );

  const [state, setState] = useState<BackgroundLocationState>({ kind: 'off' });

  /** Invalida una verificacion en vuelo si otra mas nueva la releva, mismo
   * patron que `useLocation`. */
  const runId = useRef(0);

  const verificar = useCallback(async () => {
    runId.current += 1;
    const id = runId.current;
    const isStale = () => id !== runId.current;

    if (!disponibleSinViaje || driverId === null) {
      // Se para primero el envio y despues se olvida el conductor, en ese
      // orden: al reves, una entrega que llegara entre las dos lineas
      // encontraria la tarea sin nadie a quien reportarle y se perderia sin
      // motivo aparente.
      const enMarcha = await Location.hasStartedLocationUpdatesAsync(
        BACKGROUND_LOCATION_TASK_NAME,
      ).catch(() => false);
      if (enMarcha) await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK_NAME);
      await setBackgroundLocationDriverId(null);

      if (!isStale()) setState({ kind: 'off' });
      return;
    }

    if (!isStale()) setState({ kind: 'checking' });

    const permiso = await Location.getBackgroundPermissionsAsync();
    if (isStale()) return;

    if (!permiso.granted) {
      setState({ kind: 'permission-required', canAsk: permiso.canAskAgain });
      return;
    }

    try {
      // El conductor se guarda ANTES de arrancar: si el sistema entrega una
      // posicion en el instante mismo de arrancar, ya hay a quien reportarle.
      await setBackgroundLocationDriverId(driverId);

      const enMarcha = await Location.hasStartedLocationUpdatesAsync(BACKGROUND_LOCATION_TASK_NAME);
      if (!enMarcha) {
        await Location.startLocationUpdatesAsync(
          BACKGROUND_LOCATION_TASK_NAME,
          backgroundLocationOptions(intervaloDisponible),
        );
      }

      if (!isStale()) setState({ kind: 'active' });
    } catch (e) {
      if (!isStale()) {
        setState({
          kind: 'error',
          message:
            e instanceof Error ? e.message : 'No pudimos activar la ubicación en segundo plano.',
        });
      }
    }
  }, [disponibleSinViaje, driverId, intervaloDisponible]);

  useEffect(() => {
    // Diferido, mismo motivo que en el resto del proyecto: el compilador de
    // React rechaza un setState alcanzable desde el cuerpo de un efecto.
    const id = setTimeout(() => void verificar(), 0);
    return () => clearTimeout(id);
  }, [verificar]);

  const requestPermission = useCallback(async () => {
    await Location.requestBackgroundPermissionsAsync();
    // Se vuelve a comprobar en vez de fiarse de la respuesta del dialogo: en
    // Android 11+ puede no haber dialogo -el sistema manda directo a
    // Ajustes-, y el estado real solo se sabe preguntando otra vez.
    await verificar();
  }, [verificar]);

  const openSettings = useCallback(async () => {
    await Linking.openSettings();
  }, []);

  return { state, requestPermission, openSettings };
}
