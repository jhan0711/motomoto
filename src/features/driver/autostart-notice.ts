import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Device from 'expo-device';
import * as IntentLauncher from 'expo-intent-launcher';
import { useCallback, useEffect, useState } from 'react';
import { Platform } from 'react-native';

/**
 * El aviso de "Autoinicio" de Xiaomi/MIUI (encontrado en la auditoria del
 * 2026-09-29, punto 2 del pedido del usuario sobre segundo plano).
 *
 * POR QUE HACE FALTA, ADEMAS DEL AVISO DE BATERIA. D274 ya dejo escrito que la
 * entrega en segundo plano se cortaba en la tablet Xiaomi **incluso con la
 * bateria sin restricciones y la app bloqueada en "Apps recientes"** -las dos
 * cosas que el aviso de bateria ya cubre-. HyperOS/MIUI tiene un TERCER
 * interruptor, separado de los otros dos, que decide si una app puede
 * arrancar sola sin que el usuario la haya abierto (justo lo que hace falta
 * para que el servicio en primer plano sobreviva a que el sistema mate el
 * proceso): "Autoinicio" (Autostart), dentro de Seguridad > Permisos. Viene
 * apagado por defecto para toda app que no sea del sistema.
 *
 * SOLO SE MUESTRA EN XIAOMI/REDMI/POCO. Es un ajuste que no existe en el
 * Android de otros fabricantes, y ensenarselo a alguien con un Samsung o un
 * Motorola seria un boton que no lleva a ningun lado.
 *
 * LA PANTALLA EXACTA NO ES API PUBLICA DE ANDROID -Xiaomi no documenta esta
 * actividad-, asi que puede faltar en alguna variante de HyperOS. Por eso el
 * intento va en un try/catch que no rompe nada si falla: mismo criterio que
 * `battery-optimization-notice.ts`, que ya asumio ese riesgo para el suyo.
 *
 * Descartable y recordado, mismo motivo que el de bateria: no hay forma de
 * preguntarle al sistema si el conductor ya lo activo.
 */
const DESCARTADO_KEY = 'motomoto.autostart-notice.descartado';

const FABRICANTES_MIUI = ['xiaomi', 'redmi', 'poco'];

function esProbablementeMiui(): boolean {
  if (Platform.OS !== 'android') return false;

  const fabricante = (Device.manufacturer ?? '').toLowerCase();
  return FABRICANTES_MIUI.some((f) => fabricante.includes(f));
}

export interface UseAutostartNoticeResult {
  /** `false` mientras se lee el valor guardado o en un telefono que no es MIUI. */
  mostrar: boolean;
  descartar: () => void;
  abrirAjustes: () => Promise<void>;
}

export function useAutostartNotice(activo: boolean): UseAutostartNoticeResult {
  // Inicializador perezoso: se pregunta una sola vez, al montar, no en cada
  // render -el fabricante del telefono no cambia mientras la app esta viva-.
  const [esMiui] = useState(esProbablementeMiui);
  const [descartado, setDescartado] = useState<boolean | null>(null);

  useEffect(() => {
    // En un telefono que no es MIUI no hay nada que leer: nunca se muestra,
    // sin necesidad de tocar el estado aqui dentro del efecto.
    if (!esMiui) return;

    const id = setTimeout(() => {
      // Con `.catch`: si la lectura falla, se prefiere ensenar el aviso de
      // mas -queda "no descartado"- a esconderlo para siempre por un fallo
      // que nada tiene que ver con si el conductor ya lo vio.
      AsyncStorage.getItem(DESCARTADO_KEY)
        .then((valor) => setDescartado(valor === '1'))
        .catch(() => setDescartado(false));
    }, 0);
    return () => clearTimeout(id);
  }, [esMiui]);

  const descartar = useCallback(() => {
    setDescartado(true);
    void AsyncStorage.setItem(DESCARTADO_KEY, '1');
  }, []);

  const abrirAjustes = useCallback(async () => {
    try {
      // Sin categoria ni accion documentadas por Android: es la actividad
      // concreta que Xiaomi usa para esta lista, identificada por su paquete y
      // su clase, igual que se lanzaria cualquier otra app desde fuera.
      await IntentLauncher.startActivityAsync('android.intent.action.MAIN', {
        packageName: 'com.miui.securitycenter',
        className: 'com.miui.permcenter.autostart.AutoStartManagementActivity',
      });
    } catch {
      // Esta pantalla no es API publica: puede no existir en alguna variante
      // de HyperOS. No hay otro sitio al que mandar al conductor, asi que no
      // queda mas que dejarlo estar (mismo criterio que el aviso de bateria).
    }
  }, []);

  return { mostrar: activo && descartado === false, descartar, abrirAjustes };
}
