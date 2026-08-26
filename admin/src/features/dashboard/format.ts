/**
 * Formateo de los valores del tablero.
 *
 * Se escribe a mano y no con `Intl`, por el mismo motivo que D201 en la
 * aplicacion movil: el formato de `Intl` depende del idioma del navegador, y un
 * navegador en ingles pintaria "$4,000.00" y "August 26" dentro de una pantalla
 * en espanol.
 */

/** Pesos colombianos, sin decimales: en Colombia nadie cobra centavos (D225). */
export function formatearPesos(valor: number | null): string {
  if (valor === null) return 'Sin valor';
  return '$' + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/**
 * Cuanto lleva esperando, en palabras.
 *
 * El numero viene del servidor (D154): esta funcion solo lo escribe. Si se
 * calculara aqui restando fechas, el resultado dependeria del reloj del
 * ordenador que abre el panel.
 */
export function formatearEspera(segundos: number): string {
  if (segundos < 60) return `${segundos} s`;

  const minutos = Math.floor(segundos / 60);
  if (minutos < 60) return `${minutos} min`;

  const horas = Math.floor(minutos / 60);
  const resto = minutos % 60;
  return resto === 0 ? `${horas} h` : `${horas} h ${resto} min`;
}

/**
 * Que tan preocupante es la espera. Los cortes son de partida y la empresa los
 * afinara viendo el tablero: por eso viven aqui juntos y no repartidos por la
 * pantalla.
 */
export function nivelDeEspera(segundos: number): 'normal' | 'atencion' | 'alerta' {
  if (segundos >= 300) return 'alerta';
  if (segundos >= 120) return 'atencion';
  return 'normal';
}

/**
 * Hace cuanto se supo donde estaba el conductor.
 *
 * Un tablero que muestra un servicio en marcha con una posicion de hace veinte
 * minutos esta mintiendo. Nulo significa que nunca se supo, que no es lo mismo
 * que "hace mucho" y por eso se dice distinto.
 */
export function formatearAntiguedadPosicion(segundos: number | null): string {
  if (segundos === null) return 'Sin posición';
  if (segundos < 60) return 'Hace instantes';
  return `Hace ${formatearEspera(segundos)}`;
}
