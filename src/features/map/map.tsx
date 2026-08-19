import Mapbox, { Camera, MapView, MarkerView, ShapeSource, LineLayer } from '@rnmapbox/maps';
import { Bike } from 'lucide-react-native';
import { useCallback, useEffect, useImperativeHandle, useRef, useState, type Ref } from 'react';
import { StyleSheet, View } from 'react-native';

import { radius, shadows, useTheme } from '@/theme';

import type { Coordinates, Region } from './region';

/**
 * El mapa, envuelto.
 *
 * Ninguna pantalla importa la libreria de mapas. Todo pasa por este componente,
 * asi que la decision del proveedor vive en un archivo y no en doce. Eso lo
 * escribio D117 en la Fase 8 pensando en el dia que hubiera que cambiarlo, y ese
 * dia llego: **este archivo paso de Google a Mapbox y ninguna pantalla se
 * entero**, salvo por el tipo de la referencia.
 *
 * POR QUE SE CAMBIO (hallazgo H18). La ruta se calcula con Mapbox desde la Fase
 * 11 y se dibujaba sobre un mapa de Google. En Amalfi los dos no coinciden: el
 * usuario vio la linea cruzando manzanas vacias, y al renderizar la MISMA ruta
 * con las MISMAS coordenadas sobre el mapa de Mapbox, cada tramo caia sobre una
 * calle. La ruta estaba bien; al mapa de debajo le faltaban calles. Encaja con
 * lo que ya sabiamos desde la Fase 8, cuando se probaron 39 sitios reales del
 * municipio: Mapbox acerto 22 y Google 13.
 *
 * OJO AL ORDEN DE LAS COORDENADAS. Mapbox trabaja en [longitud, latitud], al
 * reves de como las nombra el resto del proyecto. Invertirlas no da error: pone
 * Amalfi en Somalia. Toda la traduccion ocurre aqui dentro, en `aPosicion`, para
 * que nadie mas tenga que acordarse.
 */

/**
 * El token publico, el mismo que ya usaban el buscador y las rutas.
 *
 * Se registra una sola vez al cargar el modulo. Es el token que viaja dentro de
 * la aplicacion; el secreto de descarga no aparece por aqui, solo lo usa Gradle
 * al compilar.
 */
const TOKEN = process.env.EXPO_PUBLIC_MAPBOX_SEARCH_TOKEN ?? '';
void Mapbox.setAccessToken(TOKEN);

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

/**
 * El motorraton, moviendose por el mapa.
 *
 * Va aparte de `markers` y no como una variante suya porque no es lo mismo: los
 * marcadores senalan sitios que no se mueven, y este es un vehiculo que avanza.
 */
export interface MapVehicle {
  coordinate: Coordinates;
  /**
   * Atenuado cuando la posicion ya no es de fiar.
   *
   * Un motorraton quieto porque el conductor perdio cobertura no puede pintarse
   * igual que uno que de verdad esta ahi. El texto de la hoja lo explica; esto
   * es lo que se ve sin leer.
   */
  stale?: boolean;
}

/**
 * Lo que las pantallas pueden pedirle al mapa.
 *
 * **Son exactamente los dos metodos que ofrecia `react-native-maps`, con la
 * misma firma.** No es casualidad ni pereza: es lo que permitio cambiar de
 * proveedor sin tocar `passenger/index.tsx` ni `pick-on-map.tsx`. Por dentro los
 * dos se traducen a la camara de Mapbox, que piensa en limites y no en deltas.
 */
export interface MapHandle {
  /** Lleva la camara a una region, con una animacion de `duration` ms. */
  animateToRegion: (region: Region, duration?: number) => void;
  /** Encuadra todos los puntos dejando el margen que se le pida. */
  fitToCoordinates: (
    coordinates: Coordinates[],
    options?: {
      edgePadding?: { top: number; right: number; bottom: number; left: number };
      animated?: boolean;
    },
  ) => void;
}

export interface MapProps {
  ref?: Ref<MapHandle>;
  /** Donde arranca la camara. Cambiarlo despues no tiene efecto, por diseno. */
  initialRegion: Region;
  /** La posicion del usuario, o null mientras se desconoce. */
  userCoords: Coordinates | null;
  /** Trazados a dibujar. Se pintan en orden: el ultimo queda encima. */
  routes?: MapRoute[];
  /** Puntos senalados, como la recogida y el destino. */
  markers?: MapMarker[];
  /** El motorraton asignado, cuando ya viene uno. */
  vehicle?: MapVehicle | null;
  /**
   * A false, el mapa se mira pero no se toca.
   *
   * Lo necesita el recuadro dentro de una tarjeta: ahi el mapa vive dentro de
   * una lista que se desplaza, y un mapa que captura el gesto deja al conductor
   * sin poder pasar de largo la tarjeta.
   */
  interactive?: boolean;
  /** Se dispara cuando el mapa termina de cargar y acepta ordenes de camara. */
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
  /**
   * Donde se dibujan el logo y la atribucion de Mapbox.
   *
   * **Lo decide cada pantalla porque cada una tapa un sitio distinto**, y esto no
   * es una preferencia estetica: los terminos de Mapbox exigen que sean
   * visibles, asi que dejarlos debajo de una hoja o de una cabecera es
   * incumplirlos. Se comprobo en pantalla que el sitio por defecto, abajo a la
   * izquierda, queda tapado por el bottom sheet en el mapa del pasajero, y que
   * arriba del todo queda tapado por la cabecera al elegir un punto.
   */
  logoOffset?: MapOrnamentPosition;
}

/**
 * Los estilos, claro y oscuro.
 *
 * Se usan los estandar de Mapbox en lugar del estilo propio que habia para
 * Google. Aquel apagaba los puntos de interes por D125, con dos motivos: que
 * competian con nuestros marcadores y que **en Amalfi eran en buena parte
 * incorrectos**. El segundo motivo desaparece aqui, porque los datos de Mapbox
 * para este municipio son justamente los buenos: es la razon por la que se eligio
 * para buscar direcciones en la Fase 9. El primero hay que mirarlo en pantalla,
 * y si estorban se hace un estilo propio en Mapbox Studio.
 */
const ESTILO_CLARO = 'mapbox://styles/mapbox/streets-v12';
const ESTILO_OSCURO = 'mapbox://styles/mapbox/dark-v11';

/** De nuestras coordenadas al orden que quiere Mapbox. */
function aPosicion(c: Coordinates): [number, number] {
  return [c.longitude, c.latitude];
}

/** Las dos esquinas de una region, que es lo que entiende la camara. */
function aLimites(region: Region): { ne: [number, number]; sw: [number, number] } {
  const mitadLat = region.latitudeDelta / 2;
  const mitadLng = region.longitudeDelta / 2;

  return {
    ne: [region.longitude + mitadLng, region.latitude + mitadLat],
    sw: [region.longitude - mitadLng, region.latitude - mitadLat],
  };
}

export function Map({
  ref,
  initialRegion,
  userCoords,
  routes,
  markers,
  vehicle,
  interactive = true,
  onReady,
  onRegionSettled,
  showUser = true,
  logoOffset = ESQUINA_POR_DEFECTO,
}: MapProps) {
  const { isDark } = useTheme();
  const camera = useRef<Camera>(null);

  /**
   * Se traducen los dos metodos de siempre a la camara de Mapbox.
   *
   * `fitBounds` recibe el margen como [arriba, derecha, abajo, izquierda], que
   * es el mismo orden de CSS y el contrario al del objeto que reciben las
   * pantallas. Equivocarse aqui encuadra la ruta detras de la hoja, que es
   * justo lo que el margen existe para evitar.
   */
  useImperativeHandle(
    ref,
    (): MapHandle => ({
      animateToRegion: (region, duration = 500) => {
        const { ne, sw } = aLimites(region);
        camera.current?.fitBounds(ne, sw, 0, duration);
      },
      fitToCoordinates: (coordinates, options) => {
        if (coordinates.length === 0) return;

        let minLat = coordinates[0]!.latitude;
        let maxLat = coordinates[0]!.latitude;
        let minLng = coordinates[0]!.longitude;
        let maxLng = coordinates[0]!.longitude;

        for (const punto of coordinates) {
          minLat = Math.min(minLat, punto.latitude);
          maxLat = Math.max(maxLat, punto.latitude);
          minLng = Math.min(minLng, punto.longitude);
          maxLng = Math.max(maxLng, punto.longitude);
        }

        const p = options?.edgePadding;

        camera.current?.fitBounds(
          [maxLng, maxLat],
          [minLng, minLat],
          p === undefined ? 40 : [p.top, p.right, p.bottom, p.left],
          options?.animated === false ? 0 : 600,
        );
      },
    }),
    [],
  );

  /**
   * Del evento de Mapbox a la region que esperan las pantallas.
   *
   * Mapbox entrega los limites visibles; la pantalla de elegir punto quiere el
   * centro. Se reconstruye aqui para no obligarla a saber de limites.
   */
  const alQuedarQuieto = useCallback(
    (evento: { properties?: { bounds?: { ne: number[]; sw: number[] } } }) => {
      if (onRegionSettled === undefined) return;

      const limites = evento.properties?.bounds;
      if (limites === undefined) return;

      const [neLng, neLat] = limites.ne;
      const [swLng, swLat] = limites.sw;

      if (
        neLng === undefined ||
        neLat === undefined ||
        swLng === undefined ||
        swLat === undefined
      ) {
        return;
      }

      onRegionSettled({
        latitude: (neLat + swLat) / 2,
        longitude: (neLng + swLng) / 2,
        latitudeDelta: Math.abs(neLat - swLat),
        longitudeDelta: Math.abs(neLng - swLng),
      });
    },
    [onRegionSettled],
  );

  const limitesIniciales = aLimites(initialRegion);

  return (
    <MapView
      style={StyleSheet.absoluteFill}
      styleURL={isDark ? ESTILO_OSCURO : ESTILO_CLARO}
      onDidFinishLoadingMap={onReady}
      onMapIdle={alQuedarQuieto}
      scrollEnabled={interactive}
      zoomEnabled={interactive}
      // El mapa no gira ni se inclina, igual que antes. Una brujula torcida
      // obliga a reorientarse cada vez que se mira, y aqui el mapa se mira de
      // reojo.
      rotateEnabled={false}
      pitchEnabled={false}
      // EL LOGO Y LA ATRIBUCION SON OBLIGATORIOS por los terminos de Mapbox, y
      // van ARRIBA A LA IZQUIERDA, no en su sitio por defecto.
      //
      // Por defecto se dibujan abajo a la izquierda, y ahi **quedan tapados por
      // el bottom sheet**, que en estas pantallas cubre la parte baja siempre:
      // no es que estorben, es que dejan de verse, y entonces no se esta
      // cumpliendo la condicion. Se comprobo en pantalla tras el cambio.
      //
      // Arriba a la izquierda esta libre en las cuatro pantallas con mapa: los
      // botones flotantes van a la derecha y el aviso de "buscando tu ubicacion"
      // va centrado.
      logoEnabled
      logoPosition={logoOffset}
      attributionEnabled
      attributionPosition={aLaDerechaDelLogo(logoOffset)}
      scaleBarEnabled={false}
      compassEnabled={false}
    >
      <Camera
        ref={camera}
        defaultSettings={{
          bounds: { ne: limitesIniciales.ne, sw: limitesIniciales.sw },
        }}
      />

      {routes?.map((ruta, indice) => (
        <ShapeSource
          // Las rutas no tienen identidad propia: son el trazado de un viaje o
          // de una oferta, y quien las ordena es el que llama. El indice sirve
          // porque la lista se reconstruye entera cada vez que cambia.
          key={`ruta-${indice}`}
          id={`ruta-${indice}`}
          shape={{
            type: 'Feature',
            properties: {},
            geometry: {
              type: 'LineString',
              coordinates: ruta.coordinates.map(aPosicion),
            },
          }}
        >
          <LineLayer
            id={`ruta-linea-${indice}`}
            style={{
              lineColor: ruta.color,
              lineWidth: ruta.width ?? 4,
              // Extremos y uniones redondeados: sin esto una ruta con curvas
              // cerradas ensena picos en cada vertice.
              lineCap: 'round',
              lineJoin: 'round',
            }}
          />
        </ShapeSource>
      ))}

      {markers?.map((marca, indice) => (
        <MarkerView
          key={`marca-${indice}`}
          coordinate={aPosicion(marca.coordinate)}
          anchor={CENTRO}
        >
          <RoutePoint color={marca.color} filled={marca.filled} />
        </MarkerView>
      ))}

      {vehicle != null && (
        <MarkerView coordinate={aPosicion(vehicle.coordinate)} anchor={CENTRO}>
          <VehicleDot stale={vehicle.stale === true} />
        </MarkerView>
      )}

      {showUser && userCoords !== null && (
        <MarkerView coordinate={aPosicion(userCoords)} anchor={CENTRO}>
          <UserDot />
        </MarkerView>
      )}
    </MapView>
  );
}

/** Los marcadores se centran sobre su punto, no cuelgan de el. */
const CENTRO = { x: 0.5, y: 0.5 };

/**
 * Donde van el logo y la atribucion cuando la pantalla no dice otra cosa.
 *
 * Arriba a la izquierda, por debajo de la barra de estado. Con 12 el logo
 * quedaba a la altura del reloj, comprobado en pantalla.
 */
const ESQUINA_POR_DEFECTO = { top: 56, left: 12 };

/** El ancho del logo, para que la atribucion caiga a su derecha y no encima. */
const ANCHO_LOGO = 84;

/**
 * Una esquina, con sus dos margenes.
 *
 * Se escribe como union de las cuatro esquinas y no como cuatro campos
 * opcionales porque es lo que exige la libreria, y porque un objeto con los
 * cuatro margenes a la vez no significa nada.
 */
export type MapOrnamentPosition =
  | { top: number; left: number }
  | { top: number; right: number }
  | { bottom: number; left: number }
  | { bottom: number; right: number };

/** La atribucion, corrida a la derecha del logo. */
function aLaDerechaDelLogo(p: MapOrnamentPosition): MapOrnamentPosition {
  return 'left' in p ? { ...p, left: p.left + ANCHO_LOGO } : { ...p, right: p.right + ANCHO_LOGO };
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
 * El motorraton en el mapa del pasajero.
 *
 * Disco de marca con el icono del vehiculo y un aro blanco alrededor, que es lo
 * que lo mantiene visible tanto sobre asfalto oscuro como sobre un parque. El
 * mismo aro que lleva el punto del pasajero, por la misma razon.
 *
 * Atenuado cuando la posicion esta caducada. No se oculta: desaparecer daria a
 * entender que el servicio se cancelo, cuando lo que pasa es que el conductor
 * perdio cobertura y sigue viniendo.
 */
function VehicleDot({ stale }: { stale: boolean }) {
  const { colors } = useTheme();

  return (
    <View style={[styles.vehicleRing, shadows.sm, { backgroundColor: colors.surface }]}>
      <View
        style={[
          styles.vehicleCore,
          { backgroundColor: stale ? colors.textTertiary : colors.brand },
        ]}
      >
        <Bike size={16} color={colors.surface} strokeWidth={2.5} />
      </View>
    </View>
  );
}

/**
 * El marcador de la posicion del pasajero.
 *
 * Un punto del color de marca dentro de un aro blanco. El aro es lo que lo
 * mantiene visible tanto sobre calles oscuras como sobre parques; un punto
 * naranja a secas desaparece sobre algunas superficies del mapa.
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
 * En Android, las vistas propias de un marcador se dibujan una vez y se guardan
 * en cache. Si la vista no esta medida en ese momento, el marcador sale en
 * blanco y no se recupera.
 *
 * Con `MarkerView` de Mapbox el problema no se da, porque la vista se compone en
 * cada fotograma en lugar de convertirse en imagen. Se conserva el hook porque
 * `useMarkerSettle` lo importaba el mapa anterior y quitarlo de golpe romperia
 * cualquier pantalla que lo use; hoy no lo usa ninguna.
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
  vehicleCore: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
  vehicleRing: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
});
