import { formatAmountInput, parseOfferAmount, sanitizeOfferText } from '../offer-amount';

describe('parseOfferAmount', () => {
  it('lee un entero simple', () => {
    expect(parseOfferAmount('4500')).toBe(4500);
  });

  it('acepta el punto de miles y el signo pegados', () => {
    expect(parseOfferAmount('$ 4.500')).toBe(4500);
  });

  it('un campo vacio o sin digitos no es una oferta', () => {
    expect(parseOfferAmount('')).toBeNull();
    expect(parseOfferAmount('abc')).toBeNull();
  });

  it('cero no es una oferta', () => {
    expect(parseOfferAmount('0')).toBeNull();
    expect(parseOfferAmount('000')).toBeNull();
  });
});

describe('sanitizeOfferText', () => {
  it('deja solo digitos y quita los ceros a la izquierda', () => {
    expect(sanitizeOfferText('0$4.500x')).toBe('4500');
  });

  it('recorta un pegado exageradamente largo', () => {
    expect(sanitizeOfferText('1'.repeat(30))).toHaveLength(9);
  });
});

describe('formatAmountInput', () => {
  it('pinta pesos con el punto de los miles', () => {
    expect(formatAmountInput('12500')).toBe('$12.500');
    expect(formatAmountInput('1000000')).toBe('$1.000.000');
  });

  it('acepta lo que ya viene formateado', () => {
    expect(formatAmountInput('$12.500')).toBe('$12.500');
  });

  it('sin digitos deja el campo vacio, no en $0', () => {
    expect(formatAmountInput('')).toBe('');
    expect(formatAmountInput('$')).toBe('');
    expect(formatAmountInput('0')).toBe('');
  });
});
