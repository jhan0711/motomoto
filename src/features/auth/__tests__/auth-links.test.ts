/* eslint-disable import/first -- jest.mock debe ir antes del import; babel lo eleva igual */
// `isRecoveryLink` e `isConfirmationLink` son puras (solo parten la URL), pero
// viven en auth-service.ts, que importa el cliente de Supabase y con el
// AsyncStorage. Se corta esa dependencia: la prueba es del reparto por `type`.
jest.mock('@/lib/supabase', () => ({ supabase: {} }));

import { isConfirmationLink, isRecoveryLink } from '../auth-service';

describe('reconocimiento de enlaces del correo', () => {
  const recuperacion = 'https://amalfigo.app/auth#access_token=aaa&refresh_token=bbb&type=recovery';
  const confirmacion = 'https://amalfigo.app/auth#access_token=aaa&refresh_token=bbb&type=signup';

  it('reconoce el enlace de recuperacion por type=recovery', () => {
    expect(isRecoveryLink(recuperacion)).toBe(true);
    expect(isConfirmationLink(recuperacion)).toBe(false);
  });

  it('reconoce el enlace de confirmacion por type=signup', () => {
    expect(isConfirmationLink(confirmacion)).toBe(true);
    expect(isRecoveryLink(confirmacion)).toBe(false);
  });

  it('sigue reconociendo el enlace motomoto:// viejo de recuperacion', () => {
    expect(isRecoveryLink('motomoto://reset-password#type=recovery')).toBe(true);
  });

  it('una apertura normal de la app no es ninguno de los dos', () => {
    expect(isRecoveryLink('motomoto://')).toBe(false);
    expect(isConfirmationLink('motomoto://')).toBe(false);
  });
});
