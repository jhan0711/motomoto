import type { Coordinates } from '@/features/map/region';

import type { Place } from './types';

const EARTH_RADIUS_M = 6371000;

const toRadians = (degrees: number): number => (degrees * Math.PI) / 180;

/**
 * Distance between two coordinates, in metres, over the surface of the Earth.
 *
 * The haversine formula. Treating the Earth as a sphere is off by up to about
 * half a percent, which over the two kilometres of Amalfi's urban area is a
 * couple of metres. Nothing in this app cares about that, and the alternative
 * pulls in a geodesy library to compute distances a passenger will never see.
 *
 * Deliberately not asking the database. Thirty-six places fit in memory, and a
 * round trip to compute "which of these is nearest" would put a spinner in front
 * of the passenger every time they drag the map. In Amalfi the connection is
 * irregular; this way choosing a destination keeps working without it.
 */
export function distanceInMeters(a: Coordinates, b: Coordinates): number {
  const dLat = toRadians(b.latitude - a.latitude);
  const dLng = toRadians(b.longitude - a.longitude);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(a.latitude)) * Math.cos(toRadians(b.latitude)) * Math.sin(dLng / 2) ** 2;

  return Math.round(EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h)));
}

export interface NearestPlace {
  place: Place;
  meters: number;
}

/** The closest curated place to a point, or null when the list is empty. */
export function nearestPlace(point: Coordinates, places: readonly Place[]): NearestPlace | null {
  let best: NearestPlace | null = null;

  for (const place of places) {
    const meters = distanceInMeters(point, place);
    if (best === null || meters < best.meters) {
      best = { place, meters };
    }
  }

  return best;
}

/**
 * Close enough that the point simply is the place.
 *
 * Measured on twelve points across Amalfi during the Phase 9 evaluation. Eighty
 * metres is roughly the block, and inside it "El comando" is the truth. The
 * tempting thing was to widen it so more points resolve to a friendly name, and
 * that would be lying to the driver: at a hundred and fifty metres from the park
 * you are not at the park.
 */
export const AT_PLACE_METERS = 80;

/**
 * Far enough to still be a useful reference, near enough not to be misleading.
 * Between the two thresholds the label says "Cerca de", never the bare name.
 */
export const NEAR_PLACE_METERS = 250;
