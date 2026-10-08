import { urlDeNavegacion, urlDeNavegacionWeb } from '../navigation-url';

const punto = { latitude: 6.9097, longitude: -75.0775 };

describe('urlDeNavegacion', () => {
  it('en Android usa geo: con el nombre entre parentesis', () => {
    expect(urlDeNavegacion(punto, 'El parque', 'android')).toBe(
      'geo:6.9097,-75.0775?q=6.9097,-75.0775(El%20parque)',
    );
  });

  it('en iOS abre Apple Maps con la ruta en coche hasta el destino', () => {
    expect(urlDeNavegacion(punto, 'El parque', 'ios')).toBe(
      'https://maps.apple.com/?daddr=6.9097,-75.0775&q=El%20parque&dirflg=d',
    );
  });

  it('un parentesis o una tilde en el nombre no rompen la direccion', () => {
    const android = urlDeNavegacion(punto, 'Tienda (la 10) Ñandú', 'android');
    const ios = urlDeNavegacion(punto, 'Tienda (la 10) Ñandú', 'ios');

    // Los parentesis del nombre salen codificados, asi que solo queda el par que
    // abre y cierra el formato de geo:.
    expect(android.match(/[()]/g)).toHaveLength(2);
    expect(ios).toContain('q=Tienda%20%28la%2010%29%20%C3%91and%C3%BA');
  });

  it('una plataforma desconocida cae en el formato de Android', () => {
    expect(urlDeNavegacion(punto, 'X', 'web')).toMatch(/^geo:/);
  });
});

describe('urlDeNavegacionWeb', () => {
  it('apunta a Google Maps en modo conduccion', () => {
    expect(urlDeNavegacionWeb(punto)).toBe(
      'https://www.google.com/maps/dir/?api=1&destination=6.9097,-75.0775&travelmode=driving',
    );
  });
});
