/**
 * La fecha de un servicio, escrita como la diria una persona.
 *
 * A MANO Y NO CON `Intl`. Hermes trae Intl en Android, pero el formato exacto
 * depende de los datos de idioma del aparato: un telefono en ingles pintaria
 * "August 14, 3:40 PM" dentro de una pantalla en espanol, y un emulador limpio
 * puede no traer el idioma instalado. Aqui son doce nombres de mes y ninguna
 * dependencia, y el resultado es el mismo en cualquier aparato.
 *
 * Doce horas y no veinticuatro, que es como se dice la hora en Colombia.
 */

const MESES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/**
 * Ejemplos, en este orden de cercania:
 *
 *   Hoy, 3:40 p. m.
 *   Ayer, 8:05 a. m.
 *   14 de agosto, 3:40 p. m.
 *   14 de agosto de 2025
 *
 * La hora desaparece al pasar de ano a proposito: a esa distancia ya no dice
 * nada, y el ano si.
 */
export function formatWhen(iso: string, ahora: Date = new Date()): string {
  const fecha = new Date(iso);
  if (Number.isNaN(fecha.getTime())) return '';

  const hora = formatTime(fecha);

  if (mismoDia(fecha, ahora)) {
    return `Hoy, ${hora}`;
  }

  const ayer = new Date(ahora);
  ayer.setDate(ayer.getDate() - 1);
  if (mismoDia(fecha, ayer)) {
    return `Ayer, ${hora}`;
  }

  const dia = fecha.getDate();
  const mes = MESES[fecha.getMonth()];

  if (fecha.getFullYear() !== ahora.getFullYear()) {
    return `${dia} de ${mes} de ${fecha.getFullYear()}`;
  }

  return `${dia} de ${mes}, ${hora}`;
}

/** Solo la hora: "3:40 p. m.". */
export function formatTime(fecha: Date): string {
  const horas24 = fecha.getHours();
  // Medianoche y mediodia son los dos casos que se escapan de un resto simple:
  // las 0 y las 12 se dicen las dos "12".
  const horas12 = horas24 % 12 === 0 ? 12 : horas24 % 12;
  const minutos = fecha.getMinutes().toString().padStart(2, '0');
  const franja = horas24 < 12 ? 'a. m.' : 'p. m.';
  return `${horas12}:${minutos} ${franja}`;
}

function mismoDia(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}
