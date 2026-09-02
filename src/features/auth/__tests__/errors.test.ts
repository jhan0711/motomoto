import { toAuthFailure } from '../errors';

describe('toAuthFailure', () => {
  it('traduce un codigo conocido de Supabase Auth', () => {
    const f = toAuthFailure({ code: 'invalid_credentials' });
    expect(f.code).toBe('invalid_credentials');
    expect(f.message).toBe('Correo o contraseña incorrectos.');
  });

  it('los dos codigos de correo repetido dan el mismo texto', () => {
    expect(toAuthFailure({ code: 'user_already_exists' }).message).toBe(
      toAuthFailure({ code: 'email_exists' }).message,
    );
  });

  it('detecta un fallo de red por el nombre AuthRetryableFetchError', () => {
    expect(toAuthFailure({ name: 'AuthRetryableFetchError' }).code).toBe('network_error');
  });

  it('detecta un fallo de red por el texto UnknownHostException', () => {
    const f = toAuthFailure({ message: 'fetch failed: java.net.UnknownHostException' });
    expect(f.code).toBe('network_error');
  });

  it('conserva un codigo desconocido pero da el texto generico', () => {
    const f = toAuthFailure({ code: 'algo_nuevo' });
    expect(f.code).toBe('algo_nuevo');
    expect(f.message).toBe('Ocurrió un error inesperado. Inténtalo de nuevo.');
  });

  it('no revienta con lo que no es objeto', () => {
    expect(toAuthFailure(null).code).toBe('unknown_error');
    expect(toAuthFailure(42).code).toBe('unknown_error');
  });
});
