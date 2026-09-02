import { formatWhen, formatTime } from '../format-when';

// Un ancla fija para no depender de la fecha real al correr la prueba.
const AHORA = new Date('2026-08-14T15:40:00');

describe('formatWhen', () => {
  it('dice "Hoy" con la hora para algo de hoy', () => {
    expect(formatWhen('2026-08-14T09:05:00', AHORA)).toBe('Hoy, 9:05 a. m.');
  });

  it('dice "Ayer" con la hora para algo de ayer', () => {
    expect(formatWhen('2026-08-13T20:05:00', AHORA)).toBe('Ayer, 8:05 p. m.');
  });

  it('da dia y mes en espanol para algo de este ano', () => {
    expect(formatWhen('2026-07-02T15:40:00', AHORA)).toBe('2 de julio, 3:40 p. m.');
  });

  it('quita la hora y pone el ano para algo de otro ano', () => {
    expect(formatWhen('2025-08-14T15:40:00', AHORA)).toBe('14 de agosto de 2025');
  });

  it('devuelve cadena vacia para una fecha invalida', () => {
    expect(formatWhen('no-es-fecha', AHORA)).toBe('');
  });
});

describe('formatTime', () => {
  it('escribe medianoche y mediodia como las 12', () => {
    expect(formatTime(new Date('2026-08-14T00:15:00'))).toBe('12:15 a. m.');
    expect(formatTime(new Date('2026-08-14T12:00:00'))).toBe('12:00 p. m.');
  });

  it('rellena los minutos a dos digitos', () => {
    expect(formatTime(new Date('2026-08-14T13:07:00'))).toBe('1:07 p. m.');
  });
});
