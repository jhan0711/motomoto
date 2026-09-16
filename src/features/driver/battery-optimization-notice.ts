import * as IntentLauncher from 'expo-intent-launcher';
import { useCallback, useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * El aviso de "revisa el ahorro de batería" (2026-09-16).
 *
 * POR QUE HACE FALTA, ADEMAS DEL ARREGLO DE `distanceInterval`. Ese arreglo
 * corrigio un bug real -Android bloqueaba la entrega por completo mientras el
 * aparato estaba quieto-, pero no es lo unico que puede frenar el envio en
 * segundo plano con el tiempo: fabricantes como Xiaomi (HyperOS/MIUI)
 * restringen las tareas en segundo plano de una app que no este en su lista
 * de "sin restricciones" de bateria, cada vez mas agresivo cuanto mas rato
 * lleva la pantalla apagada. El codigo no puede forzar ese ajuste -es una
 * decision del usuario en Ajustes del sistema-, asi que lo unico que se
 * puede hacer es guiarlo hasta alli.
 *
 * `IGNORE_BATTERY_OPTIMIZATION_SETTINGS` y no
 * `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. El segundo abre un dialogo directo
 * de un solo toque, pero exige un permiso especial
 * (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) que Google Play revisa con la
 * misma lupa que la ubicacion en segundo plano -y justo se acaba de mandar a
 * revision un build con esa declaracion (D271/D272)-. El primero abre la
 * lista general de apps sin pedir ningun permiso nuevo: mas toques para el
 * conductor, pero sin sumar otra declaracion de Play Store a la cola.
 *
 * SE PUEDE DESCARTAR, Y SE RECUERDA. Mostrarlo sin fin cada vez que el
 * conductor esta disponible seria ruido permanente por algo que, si ya lo
 * hizo, no hay forma de comprobar desde la app -no existe una consulta para
 * saber si el sistema ya la dejo sin restricciones-. Se confia en que el
 * conductor lo hizo si dijo que si, igual que el resto de la app confia en
 * lo que contesta el sistema operativo a los permisos.
 */
const DESCARTADO_KEY = 'motomoto.battery-optimization-notice.descartado';

export interface UseBatteryOptimizationNoticeResult {
  /** `false` mientras se esta leyendo el valor guardado, para no ensenar el
   * aviso un instante antes de saber si ya se descarto. */
  mostrar: boolean;
  descartar: () => void;
  abrirAjustes: () => Promise<void>;
}

export function useBatteryOptimizationNotice(activo: boolean): UseBatteryOptimizationNoticeResult {
  const [descartado, setDescartado] = useState<boolean | null>(null);

  useEffect(() => {
    const id = setTimeout(() => {
      // Con `.catch`: si la lectura falla, se prefiere ensenar el aviso de
      // mas -queda "no descartado"- a esconderlo para siempre por un fallo
      // que nada tiene que ver con si el conductor ya lo vio.
      AsyncStorage.getItem(DESCARTADO_KEY)
        .then((valor) => setDescartado(valor === '1'))
        .catch(() => setDescartado(false));
    }, 0);
    return () => clearTimeout(id);
  }, []);

  const descartar = useCallback(() => {
    setDescartado(true);
    void AsyncStorage.setItem(DESCARTADO_KEY, '1');
  }, []);

  const abrirAjustes = useCallback(async () => {
    try {
      await IntentLauncher.startActivityAsync(
        IntentLauncher.ActivityAction.IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
      );
    } catch {
      // Algunos fabricantes no traen esta pantalla exacta. No hay a donde
      // mas mandar al conductor -Ajustes de la app tampoco tiene siempre
      // esta opcion-, asi que no queda mas que dejarlo estar.
    }
  }, []);

  return { mostrar: activo && descartado === false, descartar, abrirAjustes };
}
