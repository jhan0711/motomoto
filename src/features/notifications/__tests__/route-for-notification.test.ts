import { rutaDelAviso } from '../route-for-notification';

describe('rutaDelAviso', () => {
  it('un aviso con offerId es del conductor', () => {
    expect(rutaDelAviso({ offerId: 'a1b2' })).toBe('/driver');
  });

  it('un aviso con rideId es del pasajero', () => {
    expect(rutaDelAviso({ rideId: 'c3d4' })).toBe('/passenger');
  });

  it('offerId manda si por error llegaran los dos', () => {
    expect(rutaDelAviso({ offerId: 'a1b2', rideId: 'c3d4' })).toBe('/driver');
  });

  it('sin ninguno de los dos, o con datos que no son texto, no hay ruta', () => {
    expect(rutaDelAviso({})).toBeNull();
    expect(rutaDelAviso({ offerId: 42 })).toBeNull();
    expect(rutaDelAviso(null)).toBeNull();
    expect(rutaDelAviso(undefined)).toBeNull();
    expect(rutaDelAviso('texto suelto')).toBeNull();
  });
});
