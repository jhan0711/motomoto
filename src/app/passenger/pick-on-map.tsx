import { useLocalSearchParams, useRouter } from 'expo-router';
import { MapPin } from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { describePoint, type PointDescription } from '@/features/destination/describe-point';
import { usePlaces } from '@/features/destination/use-places';
import { Map, type MapHandle } from '@/features/map/map';
import { AMALFI_REGION, regionAround, type Coordinates, type Region } from '@/features/map/region';
import { useLocation } from '@/features/map/use-location';
import { useRideDraft } from '@/features/ride/ride-draft';
import { iconSize, iconStrokeWidth, radius, shadows, spacing, useTheme } from '@/theme';

/**
 * Elegir el destino marcandolo en el mapa.
 *
 * La chincheta no se mueve: esta clavada en el centro de la pantalla y es el
 * mapa el que se arrastra debajo. Es el patron que usan las aplicaciones de
 * movilidad, y funciona mejor que soltar un marcador con el dedo por una razon
 * fisica: el dedo tapa justo el punto que se intenta afinar.
 *
 * Esta es la salida para las cuatro de cada diez direcciones que ningun buscador
 * conoce en Amalfi. Sin ella, esos destinos serian inalcanzables.
 */
export default function PickOnMapScreen() {
  const router = useRouter();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const { setDestination, setOrigin } = useRideDraft();
  const location = useLocation();

  const params = useLocalSearchParams<{ for?: string }>();
  const paraOrigen = params.for === 'origin';
  const guardar = paraOrigen ? setOrigin : setDestination;

  const { places } = usePlaces();
  const [center, setCenter] = useState<Coordinates | null>(null);
  const [description, setDescription] = useState<PointDescription | null>(null);
  const [naming, setNaming] = useState(false);
  const [reference, setReference] = useState('');

  /** Invalida una descripcion en vuelo cuando el mapa se vuelve a mover. */
  const naming_run = useRef(0);

  const alMover = useCallback(
    (region: Region) => {
      const punto = { latitude: region.latitude, longitude: region.longitude };
      setCenter(punto);

      naming_run.current += 1;
      const id = naming_run.current;
      setNaming(true);

      void describePoint(punto, places).then((resultado) => {
        // Descartar una respuesta vieja. Con la conexion de Amalfi, la
        // direccion del punto anterior puede llegar despues de que el pasajero
        // ya haya arrastrado el mapa a otro sitio.
        if (id !== naming_run.current) return;
        setDescription(resultado);
        setNaming(false);
      });
    },
    [places],
  );

  const confirmar = useCallback(() => {
    if (center === null) return;

    const escrita = reference.trim();
    const etiqueta = description?.label ?? (escrita === '' ? null : escrita);
    if (etiqueta === null) return;

    guardar({
      ...center,
      label: etiqueta,
      detail: description?.detail ?? null,
      source: 'map',
      placeId: null,
    });

    // Dos pantallas atras: la de elegir punto y la de buscar. Volver solo una
    // dejaria al pasajero mirando el buscador con el sitio ya elegido.
    router.dismissTo('/passenger');
  }, [center, description, reference, guardar, router]);

  const coords = location.state.kind === 'ready' ? location.state.coords : null;

  /**
   * El mapa arranca en Amalfi y se desliza a la posicion del pasajero cuando el
   * GPS responde.
   *
   * `initialRegion` sola no basta y ademas es peor que inutil: solo se lee en el
   * primer render, y para entonces la ubicacion casi nunca esta lista. El
   * resultado era que la pantalla abria en el centro del pueblo o encima del
   * pasajero segun quien ganara la carrera, sin forma de predecirlo. Misma
   * correccion que en la pantalla de inicio, y por la misma razon.
   */
  const mapRef = useRef<MapHandle>(null);
  const [mapaListo, setMapaListo] = useState(false);
  const yaCentrado = useRef(false);

  useEffect(() => {
    if (!mapaListo || coords === null || yaCentrado.current) return;
    const map = mapRef.current;
    if (map === null) return;

    yaCentrado.current = true;
    map.animateToRegion(regionAround(coords), 700);
  }, [mapaListo, coords]);

  // Sin nombre y sin referencia escrita no hay nada que mandarle al conductor.
  const puedeConfirmar = center !== null && (description?.label != null || reference.trim() !== '');

  return (
    <View style={[styles.root, { backgroundColor: colors.background }]}>
      <Map
        ref={mapRef}
        initialRegion={AMALFI_REGION}
        userCoords={coords}
        showUser={false}
        onReady={() => setMapaListo(true)}
        onRegionSettled={alMover}
        // Aqui la cabecera flotante tapa la esquina de arriba, asi que el logo
        // baja. La hoja de abajo es corta y deja sitio de sobra.
        logoOffset={{ bottom: 12, left: 12 }}
      />

      {/* La chincheta, clavada en el centro. Sin capturar toques: todo gesto
          tiene que llegar al mapa que hay debajo. */}
      <View style={styles.chincheta} pointerEvents="none">
        <MapPin
          size={iconSize.xxl}
          color={colors.brand}
          strokeWidth={iconStrokeWidth}
          fill={colors.brandSubtle}
        />
        <View style={[styles.chinchetaBase, { backgroundColor: colors.brandStrong }]} />
      </View>

      <View style={[styles.cabecera, { top: insets.top + spacing.md }]}>
        <Header
          title={paraOrigen ? 'Marca dónde te recogemos' : 'Marca el punto'}
          variant="floating"
          onBack={() => router.back()}
        />
      </View>

      <View style={[styles.panel, { bottom: insets.bottom + spacing.lg }]}>
        <Card variant="elevated" padding="lg" style={styles.tarjeta}>
          {naming ? (
            <Spinner size="small" label="Leyendo el punto" />
          ) : description?.label != null ? (
            <>
              <Text variant="subheading" numberOfLines={2}>
                {description.label}
              </Text>
              {description.detail !== null && (
                <Text variant="caption" color="textSecondary" numberOfLines={1}>
                  {description.detail}
                </Text>
              )}
            </>
          ) : (
            <>
              <Text variant="bodyStrong">Este punto no tiene nombre</Text>
              <Text variant="caption" color="textSecondary">
                Escribe una referencia para que el conductor sepa dónde es.
              </Text>
              <Input
                placeholder="Ej: la casa de dos pisos frente a la cancha"
                value={reference}
                onChangeText={setReference}
                maxLength={120}
              />
            </>
          )}

          <Button
            label={paraOrigen ? 'Confirmar recogida' : 'Confirmar destino'}
            variant="brand"
            fullWidth
            disabled={!puedeConfirmar}
            onPress={confirmar}
          />
        </Card>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  cabecera: {
    left: spacing.lg,
    position: 'absolute',
    right: spacing.lg,
  },
  chincheta: {
    alignItems: 'center',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  chinchetaBase: {
    borderRadius: radius.full,
    height: 6,
    // El icono de Lucide dibuja la punta abajo, asi que el punto de apoyo va
    // pegado a ella y no en el centro geometrico del icono.
    marginTop: -2,
    width: 6,
  },
  panel: {
    left: spacing.lg,
    position: 'absolute',
    right: spacing.lg,
  },
  root: {
    flex: 1,
  },
  tarjeta: {
    ...shadows.lg,
    gap: spacing.md,
  },
});
