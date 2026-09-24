import { messageForCode, toRideFailure, RIDE_ERROR_CODES } from '../errors';

describe('toRideFailure', () => {
  it('traduce un hint conocido a su codigo y su texto', () => {
    const f = toRideFailure({ hint: 'NO_DRIVERS_AVAILABLE', code: 'P0001' });
    expect(f.code).toBe('NO_DRIVERS_AVAILABLE');
    expect(f.message).toBe('No hay motocarros disponibles en este momento.');
  });

  it('recorta los espacios del hint antes de compararlo', () => {
    expect(toRideFailure({ hint: '  RIDE_NOT_FOUND  ' }).code).toBe('RIDE_NOT_FOUND');
  });

  it('trata la cadena vacia de PostgREST como ausencia de hint', () => {
    const f = toRideFailure({ hint: '', message: 'algo raro' });
    expect(f.code).toBe('unknown_error');
  });

  it('reconoce un fallo de red por el nombre TypeError', () => {
    const f = toRideFailure({ name: 'TypeError', message: 'Failed to fetch' });
    expect(f.code).toBe('network_error');
  });

  it('reconoce un fallo de red por el texto, sin DNS', () => {
    const f = toRideFailure({ message: 'fetch failed: java.net.UnknownHostException: ...' });
    expect(f.code).toBe('network_error');
  });

  it('conserva un hint que no sabe traducir en vez de perderlo', () => {
    const f = toRideFailure({ hint: 'ALGUN_CODIGO_NUEVO' });
    expect(f.code).toBe('ALGUN_CODIGO_NUEVO');
    expect(f.message).toBe('Ocurrió un error inesperado. Inténtalo de nuevo.');
  });

  it('no revienta con entradas que no son objeto', () => {
    expect(toRideFailure(null).code).toBe('unknown_error');
    expect(toRideFailure('texto').code).toBe('unknown_error');
    expect(toRideFailure(undefined).code).toBe('unknown_error');
  });
});

describe('messageForCode', () => {
  it('da el mismo texto que daria el servidor', () => {
    expect(messageForCode('PARCEL_DESCRIPTION_REQUIRED')).toBe('Cuéntanos qué es la encomienda.');
  });

  it('cae en el generico para un codigo desconocido', () => {
    expect(messageForCode('NO_EXISTE')).toBe('Ocurrió un error inesperado. Inténtalo de nuevo.');
  });
});

describe('RIDE_ERROR_CODES', () => {
  it('cada constante apunta a una clave que messageForCode sabe traducir', () => {
    for (const [nombre, codigo] of Object.entries(RIDE_ERROR_CODES)) {
      if (codigo === 'network_error' || codigo === 'unknown_error') continue;
      expect(messageForCode(codigo)).not.toBe('Ocurrió un error inesperado. Inténtalo de nuevo.');
      expect(typeof nombre).toBe('string');
    }
  });
});
