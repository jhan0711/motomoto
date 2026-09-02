/* eslint-disable import/first -- jest.mock debe ir antes del import; babel lo eleva igual */
jest.mock('@/lib/supabase', () => ({ supabase: {} }));

import { edadDesde } from '../use-driver-location';

describe('edadDesde', () => {
  const AHORA = new Date('2026-09-02T18:14:00.000Z').getTime();

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(AHORA);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('cuenta los segundos transcurridos desde la marca del servidor', () => {
    expect(edadDesde('2026-09-02T18:13:44.198+00:00')).toBe(16);
  });

  it('acepta el formato ISO con microsegundos y desfase que manda Postgres', () => {
    expect(edadDesde('2026-09-02T18:13:30.198511+00:00')).toBe(30);
  });

  it('nunca devuelve negativo si la marca viene del futuro', () => {
    expect(edadDesde('2026-09-02T18:15:00.000Z')).toBe(0);
  });

  it('devuelve 0 ante una marca ilegible en vez de NaN', () => {
    expect(edadDesde('vaya-marca')).toBe(0);
  });
});
