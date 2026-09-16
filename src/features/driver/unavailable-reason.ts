import type { UnavailableReasonCode } from './driver-service';

/**
 * El catalogo cerrado de motivos para desconectarse (D270).
 *
 * El orden importa: es el orden en que se pintan las opciones del modal, de
 * mas frecuente a menos. "Otro" siempre va al final, sea cual sea el resto.
 */
export const UNAVAILABLE_REASON_CODES: readonly UnavailableReasonCode[] = [
  'almuerzo',
  'descanso',
  'combustible',
  'fin_de_turno',
  'otro',
];

export const UNAVAILABLE_REASON_LABELS: Record<UnavailableReasonCode, string> = {
  almuerzo: 'Almuerzo',
  descanso: 'Descanso',
  combustible: 'Cargando combustible',
  fin_de_turno: 'Fin de turno',
  otro: 'Otro',
};
