/* eslint-disable import/first -- jest.mock debe ir antes del import; babel lo eleva igual */
// `isRecoveryLink` e `isConfirmationLink` son puras (solo parten la URL), pero
// viven en auth-service.ts, que importa el cliente de Supabase y con el
// AsyncStorage. Se corta esa dependencia: la prueba es del reparto por `type`.
jest.mock('@/lib/supabase', () => ({ supabase: {} }));

import {
  completeEmailChangeFromLink,
  isConfirmationLink,
  isEmailChangeLink,
  isRecoveryLink,
} from '../auth-service';

describe('reconocimiento de enlaces del correo', () => {
  const recuperacion = 'https://amalfigo.app/auth#access_token=aaa&refresh_token=bbb&type=recovery';
  const confirmacion = 'https://amalfigo.app/auth#access_token=aaa&refresh_token=bbb&type=signup';
  const cambioCorreo =
    'https://amalfigo.app/auth#message=Confirmation+link+accepted&type=email_change';

  it('reconoce el enlace de recuperacion por type=recovery', () => {
    expect(isRecoveryLink(recuperacion)).toBe(true);
    expect(isConfirmationLink(recuperacion)).toBe(false);
    expect(isEmailChangeLink(recuperacion)).toBe(false);
  });

  it('reconoce el enlace de confirmacion por type=signup', () => {
    expect(isConfirmationLink(confirmacion)).toBe(true);
    expect(isRecoveryLink(confirmacion)).toBe(false);
  });

  it('reconoce el enlace de cambio de correo por type=email_change', () => {
    expect(isEmailChangeLink(cambioCorreo)).toBe(true);
    expect(isRecoveryLink(cambioCorreo)).toBe(false);
    expect(isConfirmationLink(cambioCorreo)).toBe(false);
  });

  it('reconoce el formato directo nuevo con token_hash en la query', () => {
    expect(isRecoveryLink('https://amalfigo.app/auth?token_hash=pkce_x&type=recovery')).toBe(true);
    expect(isConfirmationLink('https://amalfigo.app/auth?token_hash=pkce_x&type=signup')).toBe(
      true,
    );
    expect(isEmailChangeLink('https://amalfigo.app/auth?token_hash=pkce_x&type=email_change')).toBe(
      true,
    );
    // Y por el esquema propio, cuando la pagina de respaldo rebota a la app.
    expect(isRecoveryLink('motomoto://auth?token_hash=pkce_x&type=recovery')).toBe(true);
  });

  it('sigue reconociendo el enlace motomoto:// viejo de recuperacion', () => {
    expect(isRecoveryLink('motomoto://reset-password#type=recovery')).toBe(true);
  });

  it('una apertura normal de la app no es ninguno de los tres', () => {
    expect(isRecoveryLink('motomoto://')).toBe(false);
    expect(isConfirmationLink('motomoto://')).toBe(false);
    expect(isEmailChangeLink('motomoto://')).toBe(false);
  });
});

describe('completeEmailChangeFromLink', () => {
  it('sin tokens y sin error: falta abrir el otro enlace', async () => {
    const result = await completeEmailChangeFromLink(
      'https://amalfigo.app/auth#message=accepted&type=email_change',
    );
    expect(result).toEqual({ ok: true, data: 'falta_el_otro' });
  });

  it('un enlace caducado se reporta como fallo', async () => {
    const result = await completeEmailChangeFromLink(
      'https://amalfigo.app/auth#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid',
    );
    expect(result.ok).toBe(false);
  });
});
