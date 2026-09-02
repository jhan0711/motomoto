import { formatAmount } from '../format-amount';

describe('formatAmount', () => {
  it('antepone el signo y no pone decimales', () => {
    expect(formatAmount(4000)).toBe('$4.000');
  });

  it('usa el punto de los miles del espanol de Colombia', () => {
    expect(formatAmount(15000)).toBe('$15.000');
    expect(formatAmount(1234567)).toBe('$1.234.567');
  });

  it('no separa por debajo de mil', () => {
    expect(formatAmount(0)).toBe('$0');
    expect(formatAmount(999)).toBe('$999');
  });

  it('redondea al peso, porque la pantalla nunca muestra centavos', () => {
    expect(formatAmount(4000.4)).toBe('$4.000');
    expect(formatAmount(4000.5)).toBe('$4.001');
  });
});
