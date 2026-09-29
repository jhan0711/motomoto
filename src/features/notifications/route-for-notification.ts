/**
 * A que pantalla lleva un aviso, segun la FORMA de sus datos.
 *
 * Aparte de `use-notification-response.ts` y sin ningun import de React
 * Native ni de expo-router: esa es la unica razon de que exista este archivo,
 * para poder probar la decision con jest sin arrastrar sus dependencias
 * nativas (mismo criterio que `format-amount.ts` u `offer-amount.ts`).
 *
 * No hay un campo `type` que diga de que aviso se trata -`send_push_notification`
 * no lo manda-, asi que se distingue por la forma: `offerId` es del conductor
 * (`notify_new_offer`), `rideId` es del pasajero (`notify_driver_arrived`).
 */
export function rutaDelAviso(data: unknown): '/driver' | '/passenger' | null {
  if (typeof data !== 'object' || data === null) return null;
  const d = data as Record<string, unknown>;

  if (typeof d.offerId === 'string') return '/driver';
  if (typeof d.rideId === 'string') return '/passenger';
  return null;
}
