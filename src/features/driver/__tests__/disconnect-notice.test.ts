import { disconnectNotice, parseDisconnectReason } from '../disconnect-notice';

describe('parseDisconnectReason', () => {
  it('acepta los cuatro motivos validos', () => {
    expect(parseDisconnectReason('manual')).toBe('manual');
    expect(parseDisconnectReason('unanswered_offers')).toBe('unanswered_offers');
    expect(parseDisconnectReason('session_expired')).toBe('session_expired');
    expect(parseDisconnectReason('other_device')).toBe('other_device');
  });

  it('trata cualquier otra cosa como sin motivo', () => {
    expect(parseDisconnectReason(null)).toBeNull();
    expect(parseDisconnectReason(undefined)).toBeNull();
    expect(parseDisconnectReason('inventado')).toBeNull();
    expect(parseDisconnectReason(3)).toBeNull();
  });
});

describe('disconnectNotice', () => {
  it('no avisa si el conductor esta disponible, aunque quede un motivo guardado', () => {
    expect(disconnectNotice(true, 'unanswered_offers')).toBeNull();
  });

  it('no avisa cuando el apago el mismo ni cuando no hay motivo', () => {
    expect(disconnectNotice(false, 'manual')).toBeNull();
    expect(disconnectNotice(false, null)).toBeNull();
  });

  it('avisa de los tres casos que decide el servidor', () => {
    for (const motivo of ['unanswered_offers', 'session_expired', 'other_device'] as const) {
      const aviso = disconnectNotice(false, motivo);
      expect(aviso).not.toBeNull();
      expect(aviso?.title.length).toBeGreaterThan(0);
      expect(aviso?.body.length).toBeGreaterThan(0);
    }
  });
});
