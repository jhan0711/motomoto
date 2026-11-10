import { useEffect, useRef } from 'react';
import { AppState } from 'react-native';

import type { DisconnectReason } from './disconnect-notice';
import { touchDriver } from './driver-service';

/**
 * Le dice al servidor que el conductor esta vivo, y recibe su estado real (D296).
 *
 * Se llama al abrir la pantalla y cada vez que la app vuelve a primer plano. Es
 * lo que cierra el hueco de la "variable local": el servidor puede apagar la
 * disponibilidad mientras la app esta minimizada -ofertas sin responder, turno
 * de 12 horas, otro telefono-, y sin esto la pantalla seguia diciendo
 * "disponible" hasta que algo la releyera.
 *
 * NO usa temporizadores: solo reacciona a abrir y a volver a primer plano. En
 * segundo plano no hace nada ni pretende hacerlo.
 */
export interface DriverPresenceState {
  isAvailable: boolean;
  disconnectReason: DisconnectReason | null;
}

export function useDriverPresence(
  driverId: string | null,
  onState: (estado: DriverPresenceState) => void,
): void {
  // El callback va en una referencia: si estuviera en las dependencias, cada
  // render lo cambiaria y el efecto reabriria la suscripcion cada vez.
  const onStateRef = useRef(onState);

  useEffect(() => {
    onStateRef.current = onState;
  }, [onState]);

  useEffect(() => {
    if (driverId === null) return;

    const tocar = async () => {
      const resultado = await touchDriver();
      if (resultado.ok) onStateRef.current(resultado.data);
    };

    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto.
    const id = setTimeout(() => void tocar(), 0);

    const suscripcion = AppState.addEventListener('change', (siguiente) => {
      if (siguiente === 'active') void tocar();
    });

    return () => {
      clearTimeout(id);
      suscripcion.remove();
    };
  }, [driverId]);
}
