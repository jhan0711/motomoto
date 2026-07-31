import type { Region } from 'react-native-maps';

export interface Coordinates {
  latitude: number;
  longitude: number;
}

/**
 * Parque principal de Amalfi. Verified against the municipal coordinates
 * (6°54'17" N, 75°04'36" W) during the Phase 8 provider evaluation.
 *
 * This is where the map opens before the device reports a position. A blank
 * screen would tell the passenger nothing; the town square tells them where the
 * service operates while the GPS gets a fix.
 */
export const AMALFI_CENTER: Coordinates = {
  latitude: 6.9047,
  longitude: -75.0767,
};

/**
 * Deltas control the zoom level: they are the height and width of the visible
 * area, in degrees. Smaller means closer.
 *
 * Roughly: 1 degree of latitude is 111 km anywhere on Earth. At Amalfi's
 * latitude a degree of longitude is about 110 km, so the two deltas can stay
 * equal without the map looking stretched.
 */
const TOWN_DELTA = 0.02; // ~2.2 km across. The whole urban area.
const CLOSE_DELTA = 0.005; // ~550 m across. Street level.

/** Opening view: the town, before we know where the passenger is. */
export const AMALFI_REGION: Region = {
  ...AMALFI_CENTER,
  latitudeDelta: TOWN_DELTA,
  longitudeDelta: TOWN_DELTA,
};

/** Street-level view around a point. Used when recentering on the passenger. */
export function regionAround(coords: Coordinates): Region {
  return {
    ...coords,
    latitudeDelta: CLOSE_DELTA,
    longitudeDelta: CLOSE_DELTA,
  };
}
