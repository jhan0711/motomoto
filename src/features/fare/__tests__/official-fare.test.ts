import { officialFareAmount } from '../official-fare';

describe('officialFareAmount', () => {
  it('suma viaje y carga en un servicio de pasajeros', () => {
    expect(officialFareAmount('passenger', 4000, 3000)).toBe(7000);
  });

  it('en una encomienda manda la mayor de las dos partes', () => {
    expect(officialFareAmount('parcel', 4000, 9000)).toBe(9000);
    expect(officialFareAmount('parcel', 6000, 3000)).toBe(6000);
  });

  it('sin desglose no hay tarifa oficial', () => {
    expect(officialFareAmount('passenger', null, 0)).toBeNull();
    expect(officialFareAmount('passenger', 4000, null)).toBeNull();
  });
});
