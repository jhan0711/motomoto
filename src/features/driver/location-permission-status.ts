import * as Location from 'expo-location';

/**
 * El permiso de ubicacion del telefono, en los tres valores que guarda el
 * servidor (`drivers.location_permission`, D296).
 *
 * Sirve para saber, desde el panel y desde el diario, si un conductor que dejo
 * de reportar tiene la causa en el permiso. Nunca lanza: si no se puede leer,
 * se devuelve `null` y el servidor conserva lo que tenia.
 */
export type LocationPermissionStatus = 'always' | 'while_in_use' | 'denied';

export async function readLocationPermissionStatus(): Promise<LocationPermissionStatus | null> {
  try {
    const fondo = await Location.getBackgroundPermissionsAsync();
    if (fondo.granted) return 'always';

    const primerPlano = await Location.getForegroundPermissionsAsync();
    return primerPlano.granted ? 'while_in_use' : 'denied';
  } catch {
    return null;
  }
}
