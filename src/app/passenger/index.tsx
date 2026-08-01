import { useRouter } from 'expo-router';
import {
  ArrowRight,
  Circle,
  History,
  LocateFixed,
  MapPin,
  Search,
  Star,
  UserRound,
  X,
} from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import type MapView from 'react-native-maps';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import type { ChosenPoint, Place } from '@/features/destination/types';
import { usePlaces } from '@/features/destination/use-places';
import { LocationGate, blockingState } from '@/features/map/location-gate';
import { Map } from '@/features/map/map';
import { AMALFI_REGION, regionAround } from '@/features/map/region';
import { useLocation } from '@/features/map/use-location';
import { PassengerCount } from '@/features/ride/passenger-count';
import { useRideDraft } from '@/features/ride/ride-draft';
import { useMaxPassengers } from '@/features/ride/settings';
import {
  MIN_TOUCH_TARGET,
  iconSize,
  iconStrokeWidth,
  radius,
  shadows,
  spacing,
  useTheme,
} from '@/theme';

/**
 * Passenger home.
 *
 * The map is the screen; everything else floats over it. The passenger starts
 * every request from the sheet at the bottom.
 *
 * Navigation to history and profile happens through the floating controls rather
 * than a tab bar, for the reason stated in the layout.
 */
export default function PassengerHome() {
  const { colors } = useTheme();
  const router = useRouter();
  const { user } = useSession();
  const insets = useSafeAreaInsets();

  /**
   * Arranca en 1 y no en 0 porque el 0 es ahora la hoja bajada del todo. Es un
   * sitio al que se va a proposito para mirar el mapa, no donde se empieza.
   */
  const [sheetIndex, setSheetIndex] = useState(1);
  const location = useLocation();
  const mapRef = useRef<MapView>(null);

  const { origin, destination, passengerCount, setDestination, setPassengerCount } = useRideDraft();
  const { places } = usePlaces();
  const maxPasajeros = useMaxPassengers();

  /**
   * La hoja vuelve a su altura minima cuando cambia lo que contiene.
   *
   * Sin esto, quien despliega la hoja para ver mas lugares y elige uno se
   * encuentra el resumen ocupando tres cuartos de pantalla: el indice se quedo
   * en 1, y en el resumen ese 1 ya significa otra altura.
   *
   * Ajustado en el render y no en un efecto. Es la forma que React documenta
   * para corregir estado cuando cambia una entrada, y ademas la unica que no
   * provoca un segundo render con la hoja ya pintada a la altura equivocada.
   */
  const modoResumen = destination !== null;
  const [modoAnterior, setModoAnterior] = useState(modoResumen);

  if (modoResumen !== modoAnterior) {
    setModoAnterior(modoResumen);
    setSheetIndex(1);
  }

  const abrirBuscador = useCallback(() => {
    router.push('/passenger/destination');
  }, [router]);

  /** Atajo desde la hoja: los lugares mas usados sin pasar por el buscador. */
  const elegirLugar = useCallback(
    (place: Place) => {
      setDestination({
        latitude: place.latitude,
        longitude: place.longitude,
        label: place.name,
        detail: place.description,
        source: 'place',
        placeId: place.id,
      });
    },
    [setDestination],
  );

  /**
   * Set when the passenger chooses to continue without location. Without it,
   * the gate would reappear on every foreground check and there would be no way
   * past it other than granting the permission.
   */
  const [skippedGate, setSkippedGate] = useState(false);

  const coords = location.state.kind === 'ready' ? location.state.coords : null;

  /**
   * Slide to the passenger the first time we know where they are.
   *
   * Only the first time: after that the camera belongs to whoever moved it last,
   * and yanking it back on every GPS update would make the map unusable.
   *
   * Waiting for `isMapReady` is not optional. The first fix routinely arrives
   * before the native map has finished setting up, and a camera command sent
   * then is discarded without a word. Marking the move as done anyway left the
   * passenger looking at the town center while the app already knew exactly
   * where they were.
   */
  const [isMapReady, setIsMapReady] = useState(false);
  const hasCentered = useRef(false);

  useEffect(() => {
    if (!isMapReady || coords === null || hasCentered.current) return;
    const map = mapRef.current;
    if (map === null) return;

    hasCentered.current = true;
    map.animateToRegion(regionAround(coords), 900);
  }, [isMapReady, coords]);

  const recenter = useCallback(() => {
    if (coords === null) return;
    mapRef.current?.animateToRegion(regionAround(coords), 500);
  }, [coords]);

  const handleSkip = useCallback(() => setSkippedGate(true), []);

  if (location.state.kind === 'checking') {
    return (
      <View style={[styles.centered, { backgroundColor: colors.background }]}>
        <ActivityIndicator color={colors.brand} />
      </View>
    );
  }

  const blocking = blockingState(location.state);

  if (blocking !== null && !skippedGate) {
    return (
      <LocationGate
        state={blocking}
        onRequestPermission={() => void location.requestPermission()}
        onEnableServices={() => void location.enableServices()}
        onOpenSettings={() => void location.openSettings()}
        onRetry={location.retry}
        onSkip={handleSkip}
      />
    );
  }

  return (
    <View style={[styles.root, { backgroundColor: colors.surfaceSubtle }]}>
      <Map
        ref={mapRef}
        initialRegion={AMALFI_REGION}
        userCoords={coords}
        onReady={() => setIsMapReady(true)}
      />

      <View style={[styles.floatingControls, { top: insets.top + spacing.md }]}>
        <FloatingButton
          label="Perfil"
          icon={UserRound}
          onPress={() => router.push('/passenger/profile')}
        />
        <FloatingButton
          label="Historial"
          icon={History}
          onPress={() => router.push('/passenger/history')}
        />
        {coords !== null && (
          <FloatingButton label="Centrar en mi ubicación" icon={LocateFixed} onPress={recenter} />
        )}
      </View>

      {location.state.kind === 'locating' && (
        <View style={[styles.statusBar, { top: insets.top + spacing.md }]} pointerEvents="none">
          <View style={[styles.statusPill, shadows.sm, { backgroundColor: colors.surface }]}>
            <ActivityIndicator size="small" color={colors.brand} />
            <Text variant="caption" color="textSecondary">
              Buscando tu ubicación
            </Text>
          </View>
        </View>
      )}

      <BottomSheet
        // El primer valor deja la hoja reducida al asa, para apartarla y ver el
        // mapa. El segundo es distinto en cada estado:
        //
        //   Buscando  -> una fraccion, porque la lista de lugares no tiene un
        //                alto natural: cuantos se vean es una decision de
        //                diseno, no del contenido.
        //   Resumen   -> 'content', porque aqui si lo tiene. Con fracciones, la
        //                misma cifra sobraba en la tablet y cortaba el boton
        //                "Continuar" en el telefono.
        snapPoints={destination === null ? [PEEK, 0.3, 0.72] : [PEEK, 'content']}
        index={sheetIndex}
        onIndexChange={setSheetIndex}
        header={
          destination === null ? (
            <Text variant="subheading">Hola, {user?.fullName ?? 'pasajero'}</Text>
          ) : (
            <CabeceraDelViaje onCancelar={() => setDestination(null)} />
          )
        }
      >
        {destination === null ? (
          <BuscarDestino places={places} onOpenSearch={abrirBuscador} onPickPlace={elegirLugar} />
        ) : (
          <ResumenDelViaje
            origen={origin}
            destino={destination}
            pasajeros={passengerCount}
            maxPasajeros={maxPasajeros}
            onCambiarPasajeros={setPassengerCount}
            onEditarOrigen={() =>
              router.push({ pathname: '/passenger/destination', params: { for: 'origin' } })
            }
            onEditarDestino={abrirBuscador}
          />
        )}
      </BottomSheet>
    </View>
  );
}

/** Cuantos lugares caben en la hoja sin obligar a desplegarla. */
const ATAJOS_VISIBLES = 4;

/**
 * La hoja bajada del todo: solo el asa y un dedo de superficie.
 *
 * Es la salida para quien quiere mirar el mapa. Sin ella, el panel se queda
 * siempre delante y no hay forma de apartarlo. No baja a cero a proposito: una
 * hoja que desaparece por completo no deja nada que agarrar para subirla.
 */
const PEEK = 0.07;

interface BuscarDestinoProps {
  places: readonly Place[];
  onOpenSearch: () => void;
  onPickPlace: (place: Place) => void;
}

/**
 * Estado inicial de la hoja: el pasajero todavia no ha dicho a donde va.
 *
 * El campo no es un campo. Es un boton con aspecto de campo, y abre la pantalla
 * de busqueda. Escribir aqui dentro obligaria a subir la hoja por encima del
 * teclado y a meter la lista de resultados en un espacio de trescientos pixeles.
 */
function BuscarDestino({ places, onOpenSearch, onPickPlace }: BuscarDestinoProps) {
  const { colors } = useTheme();
  const atajos = places.slice(0, ATAJOS_VISIBLES);

  return (
    <>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Elegir a dónde vas"
        onPress={onOpenSearch}
        style={({ pressed }) => [
          styles.campoFalso,
          {
            backgroundColor: pressed ? colors.surfacePressed : colors.surfaceSubtle,
            borderColor: colors.border,
          },
        ]}
      >
        <Search size={iconSize.md} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" color="textTertiary">
          ¿A dónde vas?
        </Text>
      </Pressable>

      {atajos.length > 0 && (
        <>
          <Text variant="label" color="textTertiary">
            LUGARES FRECUENTES
          </Text>

          {atajos.map((place) => (
            <Card
              key={place.id}
              variant="filled"
              padding="md"
              onPress={() => onPickPlace(place)}
              accessibilityLabel={place.name}
            >
              <View style={styles.filaLugar}>
                <Star
                  size={iconSize.sm}
                  color={colors.textTertiary}
                  strokeWidth={iconStrokeWidth}
                />
                <View style={styles.filaLugarTextos}>
                  <Text variant="bodyStrong" numberOfLines={1}>
                    {place.name}
                  </Text>
                  {place.description !== null && (
                    <Text variant="caption" color="textSecondary" numberOfLines={1}>
                      {place.description}
                    </Text>
                  )}
                </View>
              </View>
            </Card>
          ))}
        </>
      )}
    </>
  );
}

/**
 * Cabecera del resumen: el titulo y la salida para dejarlo.
 *
 * La cancelacion vive aqui y no como un boton mas abajo por dos razones. Ocupa
 * alto cero, porque la cabecera ya existia. Y sigue a la vista cuando el
 * pasajero baja el panel para mirar el mapa, que es justo cuando puede decidir
 * que se ha equivocado de sitio.
 *
 * Esto NO es cancelar un viaje ya solicitado, que es de la Fase 18 y tiene sus
 * propias reglas. Aqui todavia no se ha pedido nada: solo se descarta lo elegido.
 */
function CabeceraDelViaje({ onCancelar }: { onCancelar: () => void }) {
  const { colors } = useTheme();

  return (
    <View style={styles.cabeceraViaje}>
      <Text variant="subheading">Tu viaje</Text>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Cancelar y elegir otro destino"
        onPress={onCancelar}
        hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        style={({ pressed }) => [
          styles.botonCancelar,
          { backgroundColor: pressed ? colors.surfacePressed : 'transparent' },
        ]}
      >
        <X size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
      </Pressable>
    </View>
  );
}

interface ResumenDelViajeProps {
  origen: ChosenPoint | null;
  destino: ChosenPoint;
  pasajeros: number;
  maxPasajeros: number;
  onCambiarPasajeros: (valor: number) => void;
  onEditarOrigen: () => void;
  onEditarDestino: () => void;
}

/**
 * Confirmacion visual del viaje: de donde sale y a donde va.
 *
 * El origen en null se muestra como "Tu ubicación actual", que es lo que quiere
 * casi todo el mundo y por eso no hay que elegirlo. Sigue siendo tocable, porque
 * a veces se pide el servicio para recoger en otro sitio.
 *
 * El boton todavia no crea nada. La cantidad de pasajeros es de la Fase 10 y la
 * solicitud real de la Fase 11.
 */
function ResumenDelViaje({
  origen,
  destino,
  pasajeros,
  maxPasajeros,
  onCambiarPasajeros,
  onEditarOrigen,
  onEditarDestino,
}: ResumenDelViajeProps) {
  const { colors } = useTheme();

  return (
    <>
      {/* Ruta y pasajeros en una sola tarjeta y no en tres bloques sueltos. Son
          tres decisiones del mismo viaje, y separarlas en cajas distintas
          gastaba dos huecos y un borde de mas en una hoja donde cada pixel se
          le quita al mapa. */}
      <Card variant="outlined" padding="sm">
        <PuntoDelViaje
          icon={Circle}
          color={colors.textSecondary}
          titulo={origen?.label ?? 'Tu ubicación actual'}
          detalle={origen?.detail ?? null}
          onPress={onEditarOrigen}
          accesible="Cambiar el punto de recogida"
        />

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <PuntoDelViaje
          icon={MapPin}
          color={colors.brand}
          titulo={destino.label}
          detalle={destino.detail}
          onPress={onEditarDestino}
          accesible="Cambiar el destino"
        />

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <PassengerCount value={pasajeros} onChange={onCambiarPasajeros} max={maxPasajeros} />
      </Card>

      <Button
        label="Continuar"
        variant="brand"
        icon={ArrowRight}
        iconPosition="right"
        fullWidth
        onPress={() => {}}
      />
    </>
  );
}

interface PuntoDelViajeProps {
  icon: typeof MapPin;
  color: string;
  titulo: string;
  detalle: string | null;
  onPress: () => void;
  accesible: string;
}

function PuntoDelViaje({
  icon: Icon,
  color,
  titulo,
  detalle,
  onPress,
  accesible,
}: PuntoDelViajeProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accesible}
      onPress={onPress}
      style={styles.puntoViaje}
    >
      <Icon size={iconSize.sm} color={color} strokeWidth={iconStrokeWidth} />
      <View style={styles.puntoViajeTextos}>
        <Text variant="bodyStrong" numberOfLines={1}>
          {titulo}
        </Text>
        {detalle !== null && detalle !== '' && (
          <Text variant="caption" color="textSecondary" numberOfLines={1}>
            {detalle}
          </Text>
        )}
      </View>
      <Text variant="caption" color="textTertiary">
        Cambiar
      </Text>
    </Pressable>
  );
}

interface FloatingButtonProps {
  label: string;
  icon: typeof UserRound;
  onPress: () => void;
}

/** Round control laid over the map. Local to this screen for now. */
function FloatingButton({ label, icon: Icon, onPress }: FloatingButtonProps) {
  const { colors } = useTheme();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.floatingButton,
        shadows.md,
        { backgroundColor: pressed ? colors.surfacePressed : colors.surface },
      ]}
    >
      <Icon size={iconSize.md} color={colors.textPrimary} strokeWidth={iconStrokeWidth} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  botonCancelar: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 32,
    justifyContent: 'center',
    width: 32,
  },
  cabeceraViaje: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  campoFalso: {
    alignItems: 'center',
    borderRadius: radius.lg,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.md,
    height: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.lg,
  },
  centered: {
    alignItems: 'center',
    flex: 1,
    justifyContent: 'center',
  },
  filaLugar: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  filaLugarTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  puntoViaje: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: MIN_TOUCH_TARGET,
  },
  puntoViajeTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  separadorViaje: {
    height: StyleSheet.hairlineWidth,
    // Sangrado hasta donde empieza el texto, para que la linea separe las filas
    // sin cortar la columna de iconos.
    marginLeft: spacing.xl,
    marginVertical: spacing.xxs,
  },
  floatingButton: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: MIN_TOUCH_TARGET,
    justifyContent: 'center',
    width: MIN_TOUCH_TARGET,
  },
  floatingControls: {
    gap: spacing.md,
    position: 'absolute',
    right: spacing.lg,
  },
  root: {
    flex: 1,
  },
  // Full-width row so the pill can center itself while still hugging its text.
  // `alignSelf` on an absolutely positioned element does not center it.
  statusBar: {
    alignItems: 'center',
    left: 0,
    position: 'absolute',
    right: 0,
  },
  statusPill: {
    alignItems: 'center',
    borderRadius: radius.full,
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
});
