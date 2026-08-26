/**
 * Un valor en pesos colombianos, tal como lo lee una persona.
 *
 * Sin decimales, con el punto de los miles que se usa en espanol de Colombia:
 * "$15.000" y no "$15,000" ni "$15,000.00". La base de datos ya guarda los
 * valores como enteros de pesos (D225), asi que aqui no hay nada que redondear,
 * solo separar y anteponer el signo.
 */
export function formatAmount(pesos: number): string {
  const conMiles = Math.round(pesos)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `$${conMiles}`;
}
