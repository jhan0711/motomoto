/**
 * Limpia los datos opcionales de una posicion antes de mandarlos al servidor.
 *
 * POR QUE EXISTE (2026-11-10). iOS entrega `heading` (rumbo) y `speed`
 * (velocidad) con el valor **-1** cuando no tiene el dato, y no lo tiene justo
 * cuando el aparato esta QUIETO. `driver_locations` rechaza `heading` fuera de
 * 0-360 y `speed_kmh` negativo (CHECK `driver_locations_heading_range` y
 * `_speed_positive`), asi que cada envio en segundo plano de un iPhone quieto
 * fallaba con 23514 y el conductor desaparecia de las busquedas a los pocos
 * minutos, aunque la tarea nativa SI se ejecutaba. Lo destapo el diario tecnico
 * (`driver_tracking_events`, kind `task_report_failed`). Android entrega 0 o un
 * valor valido, por eso alli no se veia.
 *
 * La regla: un dato fuera de rango es un dato que falta. Se manda `null`, no se
 * descarta la posicion entera.
 */
export interface LocationExtras {
  heading: number | null;
  speedKmh: number | null;
  accuracyM: number | null;
}

function validOrNull(valor: number | null | undefined, min: number, max: number): number | null {
  if (typeof valor !== 'number' || !Number.isFinite(valor)) return null;
  if (valor < min || valor > max) return null;
  return valor;
}

export function sanitizeLocationExtras(extras?: {
  heading?: number | null;
  speedKmh?: number | null;
  accuracyM?: number | null;
}): LocationExtras {
  return {
    heading: validOrNull(extras?.heading, 0, 360),
    speedKmh: validOrNull(extras?.speedKmh, 0, Number.POSITIVE_INFINITY),
    accuracyM: validOrNull(extras?.accuracyM, 0, Number.POSITIVE_INFINITY),
  };
}
