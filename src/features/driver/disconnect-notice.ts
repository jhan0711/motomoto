/**
 * Por que el servidor dejo a un conductor "no disponible" (D296).
 *
 * El servidor apaga la disponibilidad en tres casos que NO decidio el
 * conductor, y la pantalla tiene que decirselo: si no, ve el interruptor
 * apagado sin saber por que y no entiende por que dejo de recibir servicios.
 *
 * `manual` (lo apago el) no genera aviso. Archivo aparte, sin React Native, para
 * poder probarlo con jest.
 */
export type DisconnectReason = 'manual' | 'unanswered_offers' | 'session_expired' | 'other_device';

const VALID_REASONS: readonly string[] = [
  'manual',
  'unanswered_offers',
  'session_expired',
  'other_device',
];

/** Convierte lo que llega de la base de datos; cualquier valor raro es "sin motivo". */
export function parseDisconnectReason(value: unknown): DisconnectReason | null {
  return typeof value === 'string' && VALID_REASONS.includes(value)
    ? (value as DisconnectReason)
    : null;
}

export interface DisconnectNotice {
  title: string;
  body: string;
}

/**
 * El aviso que se ensena, o null si no hay que ensenar ninguno.
 *
 * Solo cuenta si el conductor esta NO disponible: con el interruptor encendido
 * el motivo anterior ya no importa, aunque la columna conserve el valor.
 */
export function disconnectNotice(
  isAvailable: boolean,
  reason: DisconnectReason | null,
): DisconnectNotice | null {
  if (isAvailable || reason === null || reason === 'manual') return null;

  switch (reason) {
    case 'unanswered_offers':
      return {
        title: 'Te desconectamos',
        body: 'No respondiste varias solicitudes seguidas, así que te pusimos como no disponible para no hacer esperar a los pasajeros. Cuando estés listo, vuelve a conectarte.',
      };
    case 'session_expired':
      return {
        title: 'Tu turno terminó',
        body: 'Llevabas muchas horas conectado y cerramos tu turno por seguridad. Si sigues trabajando, vuelve a conectarte.',
      };
    case 'other_device':
      return {
        title: 'Abriste tu cuenta en otro teléfono',
        body: 'Tu cuenta se conectó desde otro teléfono, así que aquí te pusimos como no disponible. Si quieres recibir servicios en este, vuelve a conectarte.',
      };
  }
}
