/**
 * La direccion que abre la navegacion hacia un punto, segun la plataforma.
 *
 * Aparte de `navigation.ts` y sin importar nada de React Native, para poder
 * probarla con Jest sin arrastrar el modulo nativo (mismo criterio que
 * `route-for-notification.ts`).
 *
 * ANDROID usa `geo:`, el esquema estandar del sistema (ver la cabecera de
 * `navigation.ts` para el porque). iOS NO tiene un equivalente: un `geo:` ahi no
 * lo atiende nadie y `Linking.openURL` falla. El enlace de Apple Maps
 * (`maps.apple.com`) lo abre directamente la app Mapas -viene instalada en todo
 * iPhone, asi que no hace falta declarar esquemas en el Info.plist-, y arranca
 * la ruta en coche hasta el destino.
 *
 * En iOS el nombre del sitio va en `q`: Apple Maps lo ensena como etiqueta del
 * destino igual que `geo:` lo hacia entre parentesis.
 */
export interface PuntoNavegacion {
  latitude: number;
  longitude: number;
}

export function urlDeNavegacion(
  point: PuntoNavegacion,
  label: string,
  plataforma: 'ios' | 'android' | string,
): string {
  const coords = `${point.latitude},${point.longitude}`;
  // El nombre puede llevar espacios, tildes y parentesis: sin codificar, un
  // parentesis dentro del texto cerraria el del formato de `geo:`.
  // `encodeURIComponent` NO codifica los parentesis (deja pasar `( ) ! ' * ~`),
  // asi que se hace aparte. La version anterior de `navigation.ts` suponia que si
  // y un lugar llamado "Tienda (la 10)" rompia el punto en Android.
  const nombre = encodeURIComponent(label).replace(
    /[()]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );

  if (plataforma === 'ios') {
    return `https://maps.apple.com/?daddr=${coords}&q=${nombre}&dirflg=d`;
  }
  return `geo:${coords}?q=${coords}(${nombre})`;
}

/** Ultimo recurso si no hay ninguna aplicacion de mapas: el navegador. */
export function urlDeNavegacionWeb(point: PuntoNavegacion): string {
  const coords = `${point.latitude},${point.longitude}`;
  return 'https://www.google.com/maps/dir/?api=1' + `&destination=${coords}&travelmode=driving`;
}
