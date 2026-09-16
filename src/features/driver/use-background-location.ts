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
 * Ubicacion en segundo plano mientras el conductor esta "disponible" o "en
 * viaje" (pedido de la empresa, validado con el dueno del producto el
 * 2026-09-15; ampliado a "en viaje" el 2026-09-16 tras verlo fallar en un
 * servicio real -ver la cabecera de `background-location-task.ts`-).
 *
 * DELIBERADAMENTE SEPARADO de `useLocationReporting`, que sigue exactamente
 * como estaba: ese hook cubre el envio en PRIMER PLANO y este el de SEGUNDO
 * PLANO. Los dos cubren hoy los mismos dos estados -"disponible" y "en
 * viaje"-, pero seguir separados evita que un cambio en uno arrastre al otro
 * sin querer, y cada uno lee su propio intervalo de `app_settings` sin
 * pisarse.
 *
 * POR QUE EL ALCANCE SE AMPLIO A "EN VIAJE" (2026-09-16). El 2026-09-15 se
 * dejo fuera a proposito, por el argumento de D116: un pasajero viendo a su
 * conductor "congelado" en el mapa es peor que no verlo. Un servicio real al
 * dia siguiente mostro que la alternativa tampoco era buena -el indicador se
 * ponia gris a los dos minutos, y al volver el conductor a la app la posicion
 * "saltaba" medio kilometro de golpe-, y la empresa decidio que ese salto
 * pesa mas que el riesgo del "congelado": con el intervalo corto de "en
 * viaje" (R9, hoy 3 s) el peor caso ya no es una posicion vieja, es una
 * posicion de hace unos segundos.
 *
 * Modelado como union discriminada, mismo criterio que `useLocation` en
 * `features/map/use-location.ts`.
 */
export type BackgroundLocationState =
  /** No aplica ahora mismo: no disponible, no en viaje, o sin sesion. */
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

/** Mismos valores de reserva que `useLocationReporting`, por si el parametro
 * no se puede leer (R9). */
const INTERVALO_DISPONIBLE_FALLBACK = 30;
const INTERVALO_EN_VIAJE_FALLBACK = 10;

export function useBackgroundLocation(
  driverId: string | null,
  disponible: boolean,
  riding: boolean,
): UseBackgroundLocationResult {
  const intervaloDisponible = useNumericSetting(
    'location_interval_available_seconds',
    INTERVALO_DISPONIBLE_FALLBACK,
  );
  const intervaloEnViaje = useNumericSetting(
    'location_interval_in_ride_seconds',
    INTERVALO_EN_VIAJE_FALLBACK,
  );

  const activo = driverId !== null && (disponible || riding);
  const intervaloSegundos = riding ? intervaloEnViaje : intervaloDisponible;

  const [state, setState] = useState<BackgroundLocationState>({ kind: 'off' });

  /** Invalida una verificacion en vuelo si otra mas nueva la releva, mismo
   * patron que `useLocation`. */
  const runId = useRef(0);

  /** Con que intervalo y para que estado esta arrancada la tarea ahora mismo,
   * para saber si hace falta reiniciarla al cambiar de "disponible" a "en
   * viaje" o al reves -`startLocationUpdatesAsync` no actualiza una tarea ya
   * en marcha, solo la deja como estaba la primera vez que arranco, y ese
   * cambio de estado tambien cambia el texto de la notificacion-. */
  const enMarchaConRef = useRef<{ intervalo: number; riding: boolean } | null>(null);

  const verificar = useCallback(async () => {
    runId.current += 1;
    const id = runId.current;
    const isStale = () => id !== runId.current;

    if (!activo) {
      // Se para primero el envio y despues se olvida el conductor, en ese
      // orden: al reves, una entrega que llegara entre las dos lineas
      // encontraria la tarea sin nadie a quien reportarle y se perderia sin
      // motivo aparente.
      const enMarcha = await Location.hasStartedLocationUpdatesAsync(
        BACKGROUND_LOCATION_TASK_NAME,
      ).catch(() => false);
      if (enMarcha) await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK_NAME);
      await setBackgroundLocationDriverId(null);
      enMarchaConRef.current = null;

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
      const yaEstaAsi =
        enMarchaConRef.current?.intervalo === intervaloSegundos &&
        enMarchaConRef.current?.riding === riding;
      if (!enMarcha || !yaEstaAsi) {
        if (enMarcha) await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK_NAME);
        await Location.startLocationUpdatesAsync(
          BACKGROUND_LOCATION_TASK_NAME,
          backgroundLocationOptions(intervaloSegundos, riding),
        );
        enMarchaConRef.current = { intervalo: intervaloSegundos, riding };
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
  }, [activo, driverId, intervaloSegundos, riding]);

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
