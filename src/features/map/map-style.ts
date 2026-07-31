/**
 * Dark map styling for Google Maps.
 *
 * Google's default map is light. Left alone in dark mode it becomes a slab of
 * white under a dark interface, which is uncomfortable at night and exactly when
 * a lot of these rides happen.
 *
 * The colors mirror the neutral scale in `src/theme/colors.ts`. They are written
 * as literals here because this array is consumed by the native Google Maps SDK,
 * which knows nothing about our tokens. This file is the one documented
 * exception to "no hardcoded colors".
 *
 * Points of interest and public transport labels are switched off: they compete
 * with our own markers, and in Amalfi they are mostly wrong anyway, as the
 * Phase 8 provider evaluation showed.
 */
export const darkMapStyle = [
  { elementType: 'geometry', stylers: [{ color: '#27272A' }] },
  { elementType: 'labels.text.fill', stylers: [{ color: '#A1A1AA' }] },
  { elementType: 'labels.text.stroke', stylers: [{ color: '#18181B' }] },
  { elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },

  { featureType: 'administrative', elementType: 'geometry', stylers: [{ color: '#3F3F46' }] },
  {
    featureType: 'administrative.locality',
    elementType: 'labels.text.fill',
    stylers: [{ color: '#D4D4D8' }],
  },

  { featureType: 'poi', stylers: [{ visibility: 'off' }] },
  { featureType: 'transit', stylers: [{ visibility: 'off' }] },

  { featureType: 'landscape.natural', elementType: 'geometry', stylers: [{ color: '#27272A' }] },
  // 'poi.park' and not 'park'. There is no bare 'park' feature type, and Google
  // does not ignore the unknown entry: it throws InvalidStyleException and drops
  // the WHOLE style, silently on screen and visible only in logcat. The map then
  // looks like a plain unstyled Google map, which is easy to mistake for the
  // style having been applied and simply not looking like much.
  { featureType: 'poi.park', elementType: 'geometry', stylers: [{ color: '#1F3A2E' }] },

  { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#3F3F46' }] },
  { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: '#27272A' }] },
  { featureType: 'road', elementType: 'labels.text.fill', stylers: [{ color: '#A1A1AA' }] },
  { featureType: 'road.arterial', elementType: 'geometry', stylers: [{ color: '#52525B' }] },
  { featureType: 'road.highway', elementType: 'geometry', stylers: [{ color: '#71717A' }] },
  { featureType: 'road.local', elementType: 'geometry', stylers: [{ color: '#3F3F46' }] },

  { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#17313E' }] },
  { featureType: 'water', elementType: 'labels.text.fill', stylers: [{ color: '#52525B' }] },
];

/**
 * Light map styling.
 *
 * Google's defaults are already close to what we want, so this only removes the
 * clutter that fights with our markers, for the same reasons as above.
 */
export const lightMapStyle = [
  { elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },
  { featureType: 'poi', stylers: [{ visibility: 'off' }] },
  { featureType: 'transit', stylers: [{ visibility: 'off' }] },
];
