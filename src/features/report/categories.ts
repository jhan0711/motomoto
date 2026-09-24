/**
 * Los motivos por los que alguien reporta un problema.
 *
 * **CADA ROL VE LOS SUYOS, decidido con el usuario el 2026-09-01.** "No me
 * pago" no le sirve al pasajero y "me cobraron de mas" no le sirve al
 * conductor: una lista comun obligaria a cada persona a saltarse la mitad de
 * las opciones, en una pantalla de celular y con un problema encima.
 *
 * **SE GUARDA LA ETIQUETA EN ESPANOL, NO UN CODIGO.** `reports.category` es
 * texto libre y el panel la ensena tal cual, asi que guardar el texto evita
 * tener la misma traduccion en dos sitios que con el tiempo se separan. Tiene
 * una consecuencia buena y buscada: si manana se cambia el texto de un motivo,
 * **los reportes viejos conservan el que se les enseno**, que es lo que aquella
 * persona eligio de verdad.
 *
 * Son categorias del negocio, no del programa: cambiarlas es editar esta lista.
 */

export const MOTIVOS_PASAJERO = [
  'Me cobraron distinto a lo acordado',
  'El conductor no llegó o tardó mucho',
  'Trato del conductor',
  'Conducción imprudente',
  'Olvidé algo en el motocarro',
  'Problema con la aplicación',
  'Otro',
] as const;

export const MOTIVOS_CONDUCTOR = [
  'El pasajero no estaba',
  'Venían más personas de las pedidas',
  'Trato del pasajero',
  'No me pagó',
  'Problema con la aplicación',
  'Otro',
] as const;

export function motivosDe(rol: string | undefined): readonly string[] {
  return rol === 'driver' ? MOTIVOS_CONDUCTOR : MOTIVOS_PASAJERO;
}
