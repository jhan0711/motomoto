import { formatCountdown } from '../use-countdown';

describe('formatCountdown', () => {
  it('escribe minutos y segundos como un cronometro', () => {
    expect(formatCountdown(247)).toBe('4:07');
    expect(formatCountdown(300)).toBe('5:00');
  });

  it('rellena los segundos a dos digitos', () => {
    expect(formatCountdown(65)).toBe('1:05');
  });

  it('nunca baja de cero', () => {
    expect(formatCountdown(0)).toBe('0:00');
    expect(formatCountdown(-10)).toBe('0:00');
  });
});
