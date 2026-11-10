import { sanitizeLocationExtras } from '../location-extras';

describe('sanitizeLocationExtras', () => {
  it('convierte en null el -1 que iOS entrega con el aparato quieto', () => {
    expect(sanitizeLocationExtras({ heading: -1, speedKmh: -3.6, accuracyM: 5 })).toEqual({
      heading: null,
      speedKmh: null,
      accuracyM: 5,
    });
  });

  it('conserva los valores validos, incluido el cero', () => {
    expect(sanitizeLocationExtras({ heading: 0, speedKmh: 0, accuracyM: 0 })).toEqual({
      heading: 0,
      speedKmh: 0,
      accuracyM: 0,
    });
    expect(sanitizeLocationExtras({ heading: 360, speedKmh: 42.5, accuracyM: 12 })).toEqual({
      heading: 360,
      speedKmh: 42.5,
      accuracyM: 12,
    });
  });

  it('rechaza rumbo mayor a 360, NaN e infinitos', () => {
    expect(
      sanitizeLocationExtras({ heading: 361, speedKmh: Number.NaN, accuracyM: Infinity }),
    ).toEqual({ heading: null, speedKmh: null, accuracyM: null });
  });

  it('sin datos devuelve todo null', () => {
    expect(sanitizeLocationExtras()).toEqual({ heading: null, speedKmh: null, accuracyM: null });
    expect(sanitizeLocationExtras({ heading: null, speedKmh: undefined })).toEqual({
      heading: null,
      speedKmh: null,
      accuracyM: null,
    });
  });
});
