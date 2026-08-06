import { useEffect, useState, type Ref } from 'react';
import { StyleSheet, View } from 'react-native';
import MapView, { Marker, Polyline, PROVIDER_GOOGLE, type Region } from 'react-native-maps';

import { radius, shadows, useTheme } from '@/theme';

import { darkMapStyle, lightMapStyle } from './map-style';
import type { Coordinates } from './region';

/**
 * Un trazado dibujado sobre el mapa.
 *
 * El color lo decide quien lo pinta y no este componente, porque el mismo mapa
 * ensena rutas que significan cosas distintas: desde D161, el conductor ve a la
 * vez el viaje que ya lleva y el que le estan ofreciendo, y distinguirlos es
 * justo lo que le permite decidir.
 */
export interface MapRoute {
  coordinates: Coordinates[];
  color: string;
  /** Mas fina para lo secundario. Por defecto, el grosor normal. */
  width?: number;
}

/** Un punto senalado en el mapa. */
export interface MapMarker {
  coordinate: Coordinates;
  color: string;
  /** Relleno para el destino, hueco para la recogida. */
  filled: boolean;
}

export interface MapProps {
  ref?: Ref<MapView>;
  /** Where the camera starts. Changing it later has no effect, by design. */
  initialRegion: Region;
  /** The passenger's position, or null while unknown. */
  userCoords: Coordinates | null;
  /** Trazados a dibujar. Se pintan en orden: el ultimo queda encima. */
  routes?: MapRoute[];
  /** Puntos senalados, como la recogida y el destino. */
  markers?: MapMarker[];
  /**
   * A false, el mapa se mira pero no se toca.
   *
   * Lo necesita el recuadro dentro de una tarjeta: ahi el mapa vive dentro de
   * una lista que se desplaza, y un mapa que captura el gesto deja al conductor
   * sin poder pasar de largo la tarjeta.
   */
  interactive?: boolean;
  /**
   * Fires when the native map is ready to accept camera commands.
   *
   * Worth waiting for: `animateToRegion` called before this point is dropped
   * silently, with no error and no return value to check.
   */
  onReady?: () => void;
  /**
   * Se dispara cuando la camara termina de moverse, no mientras se mueve.
   *
   * Lo usa la pantalla de elegir un punto en el mapa. Con el evento continuo
   * habria una peticion de direccion por cada fotograma del arrastre; con este,
   * una cuando el dedo se levanta.
   */
  onRegionSettled?: (region: Region) => void;
  /** Oculta el marcador del usuario. La pantalla de elegir punto usa su propia chincheta. */
  showUser?: boolean;
}

/**
 * The map, wrapped.
 *
 * No screen imports `react-native-maps` directly. Everything goes through this
 * component, so the provider decision (D110) lives in one file. If it ever
 * changes, this is what gets rewritten instead of every screen that shows a map.
 *
 * PROVIDER_GOOGLE is explicit rather than left to the default: on Android the
 * default already is Google, but stating it means the code says which map this
 * is instead of relying on a platform default that could shift.
 */
export function Map({
  ref,
  initialRegion,
  userCoords,
  routes,
  markers,
  interactive = true,
  onReady,
  onRegionSettled,
  showUser = true,
}: MapProps) {
  const { isDark } = useTheme();
  const tracksMarker = useMarkerSettle();

  return (
    <MapView
      ref={ref}
      provider={PROVIDER_GOOGLE}
      style={StyleSheet.absoluteFill}
      initialRegion={initialRegion}
      onMapReady={onReady}
      onRegionChangeComplete={onRegionSettled}
      customMapStyle={isDark ? darkMapStyle : lightMapStyle}
      scrollEnabled={interactive}
      zoomEnabled={interactive}
      // Google's own blue dot is switched off in favour of our marker below.
      // Two dots for one person is confusing, and the built-in one ignores the
      // brand color that was chosen in Phase 3 precisely for map legibility.
      showsUserLocation={false}
      showsMyLocationButton={false}
      showsCompass={false}
      // The toolbar is the pair of Google buttons that jump to the Maps app.
      // Sending the passenger out of the app mid-request is the opposite of
      // what this screen is for.
      toolbarEnabled={false}
      rotateEnabled={false}
      pitchEnabled={false}
    >
      {routes?.map((ruta, indice) => (
        <Polyline
          // Las rutas no tienen identidad propia: son el trazado de un viaje o
          // de una oferta, y quien las ordena es el que llama. El indice sirve
          // porque la lista se reconstruye entera cada vez que cambia.
          key={indice}
          coordinates={ruta.coordinates}
          strokeColor={ruta.color}
          strokeWidth={ruta.width ?? 4}
        />
      ))}

      {markers?.map((marca, indice) => (
        <Marker
          key={indice}
          coordinate={marca.coordinate}
          anchor={{ x: 0.5, y: 0.5 }}
          tracksViewChanges={tracksMarker}
        >
          <RoutePoint color={marca.color} filled={marca.filled} />
        </Marker>
      ))}

      {showUser && userCoords !== null && (
        <Marker
          coordinate={userCoords}
          anchor={{ x: 0.5, y: 0.5 }}
          tracksViewChanges={tracksMarker}
        >
          <UserDot />
        </Marker>
      )}
    </MapView>
  );
}

/**
 * Los extremos de una ruta.
 *
 * Hueco para la recogida y relleno para el destino, que es la misma pareja de
 * formas que usan las tarjetas del conductor desde la Fase 12. Repetir ahi el
 * criterio de un icono y aqui otro obligaria a traducir mentalmente entre la
 * lista y el mapa.
 */
function RoutePoint({ color, filled }: { color: string; filled: boolean }) {
  const { colors } = useTheme();

  return (
    <View
      style={[
        styles.routePoint,
        {
          backgroundColor: filled ? color : colors.surface,
          borderColor: color,
        },
      ]}
    />
  );
}

/**
 * The passenger's position marker.
 *
 * A brand-colored dot inside a white ring. The ring is what keeps it visible
 * over dark roads and over parks alike; a bare orange dot disappears against
 * some map surfaces.
 */
function UserDot() {
  const { colors } = useTheme();

  return (
    <View style={[styles.dotRing, shadows.sm, { backgroundColor: colors.surface }]}>
      <View style={[styles.dotCore, { backgroundColor: colors.brand }]} />
    </View>
  );
}

/**
 * Custom marker views on Android are drawn once and cached. If the view is not
 * fully laid out at that moment, the marker renders blank and never recovers.
 *
 * Redrawing continuously would fix it and cost battery on every frame, so this
 * hook lets the marker track changes just long enough to settle, then stops.
 * Exported for Phase 14, where the driver marker will need the same treatment.
 */
export function useMarkerSettle(): boolean {
  const [tracking, setTracking] = useState(true);

  useEffect(() => {
    const id = setTimeout(() => setTracking(false), 1000);
    return () => clearTimeout(id);
  }, []);

  return tracking;
}

const styles = StyleSheet.create({
  dotCore: {
    borderRadius: radius.full,
    height: 14,
    width: 14,
  },
  dotRing: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 24,
    justifyContent: 'center',
    width: 24,
  },
  routePoint: {
    borderRadius: radius.full,
    borderWidth: 3,
    height: 14,
    width: 14,
  },
});
