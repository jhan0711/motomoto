/* eslint-disable import/first -- jest.mock debe ir antes del import; babel lo eleva igual */
// `homeRouteFor` es una funcion pura, pero vive en session.tsx junto al
// proveedor, que arrastra expo-linking, el cliente de Supabase y AsyncStorage.
// Se cortan esas dependencias: la prueba es de la tabla rol -> ruta, nada mas.
jest.mock('expo-linking', () => ({ getInitialURL: jest.fn(), addEventListener: jest.fn() }));
jest.mock('../auth-service', () => ({
  fetchProfile: jest.fn(),
  fetchDriver: jest.fn(),
  isRecoveryLink: jest.fn(),
  completeRecoveryFromLink: jest.fn(),
  onAuthUserChange: jest.fn(() => () => {}),
  signOut: jest.fn(),
}));

import { homeRouteFor } from '../session';

describe('homeRouteFor', () => {
  it('el conductor va a su zona', () => {
    expect(homeRouteFor('driver')).toBe('/driver');
  });

  it('el pasajero va a la suya', () => {
    expect(homeRouteFor('passenger')).toBe('/passenger');
  });

  it('admin y super_admin van a la pantalla que les explica donde entrar', () => {
    expect(homeRouteFor('admin')).toBe('/account-status');
    expect(homeRouteFor('super_admin')).toBe('/account-status');
  });
});
