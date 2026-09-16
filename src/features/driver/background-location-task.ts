import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Location from 'expo-location';
import type { LocationObject, LocationTaskOptions } from 'expo-location';
import * as TaskManager from 'expo-task-manager';

import { reportLocation } from './driver-service';

/**
 * Ubicacion del conductor con la aplicacion minimizada (pedido de la empresa,
 * validado con el dueno del producto el 2026-09-15; revierte D116 solo para
 * el estado "disponible", nunca "en viaje" -ver use-background-location.ts).
 *
 * POR QUE UN ARCHIVO APARTE Y NO DENTRO DEL HOOK. `TaskManager.defineTask`
 * tiene que llamarse UNA VEZ, en cuanto se carga el modulo de JavaScript, y
 * antes de que exista ningun componente: Android puede volver a lanzar el
 * motor de JavaScript solo para entregar una posicion en segundo plano, sin
 * pasar por App.tsx ni por ninguna pantalla. Si la tarea se definiera dentro
 * de un componente, esa entrega no tendria donde caer. Por eso este archivo
 * se importa por su efecto secundario desde `app/_layout.tsx`, lo mas cerca
 * posible del arranque.
 *
 * POR QUE EL CONDUCTOR SE GUARDA EN AsyncStorage Y NO EN UNA VARIABLE DEL
 * MODULO. La tarea puede correr en una instancia de JavaScript reciclada por
 * el sistema operativo, sin memoria de lo que paso antes. AsyncStorage es lo
 * unico que sobrevive a eso -es el mismo mecanismo que ya guarda la sesion de
 * Supabase en `lib/supabase.ts`-. El cliente de Supabase si se puede reusar
 * tal cual: el servicio en primer plano que exige esta funcion mantiene el
 * proceso de la aplicacion vivo, que es lo que de verdad hace falta para que
 * `reportLocation` -y la sesion que ya trae cargada `supabase`- sigan
 * funcionando.
 */
export const BACKGROUND_LOCATION_TASK_NAME = 'motomoto-driver-background-location';

const DRIVER_ID_KEY = 'motomoto.background-location.driver-id';

/**
 * Que conductor reportar cuando la tarea reciba una posicion.
 *
 * `use-background-location.ts` la llama con el id al arrancar el seguimiento
 * y con `null` al pararlo -asi una entrega tardia, ya con el seguimiento
 * detenido, no encuentra a nadie a quien reportarle y no hace nada-.
 */
export async function setBackgroundLocationDriverId(driverId: string | null): Promise<void> {
  if (driverId === null) {
    await AsyncStorage.removeItem(DRIVER_ID_KEY);
  } else {
    await AsyncStorage.setItem(DRIVER_ID_KEY, driverId);
  }
}

/** Opciones de arranque. El intervalo es el mismo que ya usa el reporte en
 * primer plano (`location_interval_available_seconds`, R9): no se inventa un
 * segundo numero de bateria que ajustar por separado, y ese parametro ya se
 * puede retocar desde el panel sin publicar una version nueva. */
export function backgroundLocationOptions(intervaloSegundos: number): LocationTaskOptions {
  return {
    // La misma que ya usa el mapa del pasajero en foreground (use-location.ts):
    // unos metros de error no importan aqui, y la de mayor precision mantendria
    // el chip de GPS encendido sin necesidad -justo el costo de bateria que
    // este pedido pidio vigilar.
    accuracy: Location.Accuracy.Balanced,
    timeInterval: intervaloSegundos * 1000,
    // SIN `distanceInterval`, y a proposito -no es un olvido-. En Android,
    // `expo-location` lo traduce a `setMinUpdateDistanceMeters` de
    // `LocationRequest`, que en el sistema operativo actua como filtro
    // OBLIGATORIO junto al intervalo, no como un adelanto: una posicion solo
    // se entrega si YA paso el intervalo *Y ADEMAS* el aparato se movio esa
    // distancia. Con 25 m puestos aqui, `driver_locations.updated_at` dejaba
    // de avanzar en cuanto el motorraton se quedaba quieto -verificado en la
    // tablet fisica el 2026-09-15 con `adb logcat`, que mostraba
    // `FusedLocation: ... blocked - too close` cada ~30 s sin fin-. R9 solo
    // pide distancia para "en viaje" (D189), nunca para "disponible": este
    // campo no pertenece aqui.
    foregroundService: {
      notificationTitle: 'AmalfiGoApp',
      notificationBody: 'Buscando servicios cerca de ti.',
      notificationColor: '#F27127',
      // Sin esto la notificacion podria quedar huerfana -encendida, diciendo
      // "buscando servicios"- si Android mata el proceso entero en vez de solo
      // pausarlo. `pausesUpdatesAutomatically` de esta misma opcion es de iOS
      // (ver el tipo `LocationTaskOptions`): en Android no hace nada, por eso
      // no se pone aqui.
      killServiceOnDestroy: true,
    },
  };
}

TaskManager.defineTask<{ locations: LocationObject[] }>(
  BACKGROUND_LOCATION_TASK_NAME,
  async ({ data, error }) => {
    // Un error aqui lo reporta el sistema operativo, no el servidor: no hay
    // conductor al que devolverselo ni pantalla que lo muestre. Se ignora en
    // vez de intentar registrarlo -un throw dentro de esta tarea la deja de
    // recibir mas entregas hasta que el proceso se reinicie.
    if (error !== null) return;

    // La mas reciente. Android puede entregar varias posiciones juntas si se
    // acumularon mientras el proceso estaba suspendido.
    const ultima = data.locations.at(-1);
    if (ultima === undefined) return;

    const driverId = await AsyncStorage.getItem(DRIVER_ID_KEY);
    if (driverId === null) return;

    await reportLocation(
      driverId,
      { latitude: ultima.coords.latitude, longitude: ultima.coords.longitude },
      {
        heading: ultima.coords.heading,
        speedKmh: ultima.coords.speed !== null ? ultima.coords.speed * 3.6 : null,
        accuracyM: ultima.coords.accuracy,
      },
    );
  },
);
