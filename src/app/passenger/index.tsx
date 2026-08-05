import { useRouter } from 'expo-router';
import {
  ArrowRight,
  Circle,
  Clock,
  History,
  LocateFixed,
  MapPin,
  RotateCw,
  Route as RouteIcon,
  Search,
  Star,
  UserRound,
  X,
} from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, AppState, Pressable, StyleSheet, View } from 'react-native';
import type MapView from 'react-native-maps';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
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
import {
  cancelRequest,
  createRequest,
  fetchActiveRequest,
  type ActiveRequest,
} from '@/features/ride/ride-service';
import {
  fetchRouteEstimate,
  formatDistance,
  formatDuration,
  type RouteEstimate,
} from '@/features/ride/route-service';
import { useMaxPassengers } from '@/features/ride/settings';
import { formatCountdown, useCountdown } from '@/features/ride/use-countdown';
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
   * La solicitud ya enviada, cuando la hay.
   *
   * Se guarda con la forma que necesita el panel y no con la que devuelve el
   * servidor, porque puede venir de dos sitios: de get_active_request o, si esa
   * lectura falla justo despues de crearla, de lo que la propia pantalla ya
   * sabe. Las dos rutas producen lo mismo y el panel no tiene que enterarse.
   */
  const [solicitud, setSolicitud] = useState<SolicitudEnCurso | null>(null);
  const [enviando, setEnviando] = useState(false);
  const [cancelando, setCancelando] = useState(false);
  const [errorSolicitud, setErrorSolicitud] = useState<string | null>(null);

  /**
   * Mientras se le pregunta al servidor si hay algo en marcha no se sabe nada.
   *
   * Arranca en true a proposito. Sin esta espera, quien reabre la aplicacion con
   * un servicio pedido ve primero "¿A dónde vas?" y medio segundo despues el
   * panel de busqueda: un parpadeo que da a entender que se habia perdido y ha
   * vuelto. Medio segundo de girador honesto es mejor que un estado falso.
   */
  const [restaurando, setRestaurando] = useState(true);

  /** Las cuatro caras de la hoja, en el orden en que las ve el pasajero. */
  const modo: ModoHoja = restaurando
    ? 'cargando'
    : solicitud !== null
      ? 'buscando'
      : destination !== null
        ? 'resumen'
        : 'destino';

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
  const [modoAnterior, setModoAnterior] = useState(modo);

  if (modo !== modoAnterior) {
    setModoAnterior(modo);
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
   * De donde se recoge, ya resuelto a numeros.
   *
   * El borrador guarda el origen en null cuando significa "mi ubicacion actual"
   * (D137). Traducir eso a una coordenada solo puede hacerse aqui, que es lo
   * unico que sabe donde esta el telefono ahora mismo.
   *
   * Se guardan latitud y longitud sueltas, y no un objeto, porque son lo que
   * llevan las dependencias del efecto de mas abajo. Un objeto nuevo en cada
   * render dispararia una llamada a Mapbox en cada render.
   */
  const origenLat = origin?.latitude ?? coords?.latitude ?? null;
  const origenLng = origin?.longitude ?? coords?.longitude ?? null;
  const destinoLat = destination?.latitude ?? null;
  const destinoLng = destination?.longitude ?? null;

  const [estimacion, setEstimacion] = useState<RouteEstimate | null>(null);
  const [estimando, setEstimando] = useState(false);

  /**
   * La estimacion caduca en cuanto cambia cualquiera de los cuatro numeros.
   *
   * Se limpia en el render, con el mismo patron que el modo de la hoja. Hacerlo
   * dentro del efecto dejaria un fotograma con la distancia del viaje anterior
   * bajo el destino nuevo, que es de las cosas que nadie reporta y todo el mundo
   * ve.
   */
  const claveRuta = `${origenLat},${origenLng},${destinoLat},${destinoLng}`;
  const [claveRutaAnterior, setClaveRutaAnterior] = useState(claveRuta);

  if (claveRuta !== claveRutaAnterior) {
    setClaveRutaAnterior(claveRuta);
    setEstimacion(null);
  }

  /**
   * El error del servidor caduca en cuanto cambia lo que se le pregunto.
   *
   * Sin esto, el pasajero que lee "el punto de recogida esta fuera de la zona de
   * servicio", cambia el origen y lo arregla, sigue viendo el mismo aviso bajo un
   * viaje que ya es valido. La pantalla estaria mintiendo, y ademas sobre lo
   * unico que el pasajero acaba de corregir.
   *
   * Va la cantidad de pasajeros ademas de las coordenadas: "no hay motorratones
   * disponibles" puede deberse a que ninguno tiene capacidad para tres, y baja a
   * dos deja de ser cierto.
   */
  const claveSolicitud = `${claveRuta}|${passengerCount}`;
  const [claveSolicitudAnterior, setClaveSolicitudAnterior] = useState(claveSolicitud);

  if (claveSolicitud !== claveSolicitudAnterior) {
    setClaveSolicitudAnterior(claveSolicitud);
    setErrorSolicitud(null);
  }

  useEffect(() => {
    if (origenLat === null || origenLng === null || destinoLat === null || destinoLng === null) {
      return;
    }

    // Vigente evita que una respuesta lenta de un viaje ya descartado pise a la
    // del viaje actual. Sin esto, cambiar de destino deprisa deja la distancia
    // del anterior en pantalla.
    let vigente = true;

    // Diferido fuera del cuerpo del efecto, igual que en usePlaces: el
    // compilador de React rechaza un setState alcanzable desde aqui, y no sabe
    // seguir la frontera del await.
    const id = setTimeout(() => {
      void (async () => {
        setEstimando(true);
        const resultado = await fetchRouteEstimate(
          { latitude: origenLat, longitude: origenLng },
          { latitude: destinoLat, longitude: destinoLng },
        );
        if (!vigente) return;
        // Un fallo deja la estimacion en null y la fila no se pinta (D149).
        // Inventar una distancia seria peor que no dar ninguna.
        setEstimacion(resultado.ok ? resultado.estimate : null);
        setEstimando(false);
      })();
    }, 0);

    return () => {
      vigente = false;
      clearTimeout(id);
    };
  }, [origenLat, origenLng, destinoLat, destinoLng]);

  /**
   * Envia la solicitud.
   *
   * Aqui no se valida la zona de servicio, ni la capacidad, ni si ya hay un
   * servicio en curso: eso lo decide el servidor y vuelve como un mensaje ya
   * traducido. Lo unico que se comprueba antes es que sepamos donde recoger,
   * porque sin coordenada no hay ni siquiera algo que enviar.
   */
  const confirmar = useCallback(async () => {
    if (destination === null) return;

    if (origenLat === null || origenLng === null) {
      setErrorSolicitud(
        'No sabemos dónde recogerte. Toca el punto de recogida y elígelo en el mapa.',
      );
      return;
    }

    setEnviando(true);
    setErrorSolicitud(null);

    const origenLabel = origin?.label ?? 'Tu ubicación actual';

    const creada = await createRequest({
      origin: {
        latitude: origenLat,
        longitude: origenLng,
        label: origenLabel,
        placeId: origin?.placeId ?? null,
      },
      destination: {
        latitude: destination.latitude,
        longitude: destination.longitude,
        label: destination.label,
        placeId: destination.placeId,
      },
      passengerCount,
    });

    if (!creada.ok) {
      setEnviando(false);
      setErrorSolicitud(creada.failure.message);
      return;
    }

    // La cuenta atras la da el servidor, no el reloj del telefono, que puede ir
    // desviado. Por eso se relee en vez de construirla aqui.
    const activa = await fetchActiveRequest();
    setEnviando(false);

    if (activa.ok && activa.data !== null) {
      setSolicitud(aSolicitudEnCurso(activa.data));
      return;
    }

    // La solicitud existe: el servidor devolvio su identificador. Si la relectura
    // falla, dejar la pantalla en el resumen seria lo peor posible, porque el
    // pasajero no veria lo que ya pidió ni tendria como cancelarlo.
    setSolicitud({
      id: creada.data,
      origenLabel,
      destinoLabel: destination.label,
      pasajeros: passengerCount,
      segundosRestantes: null,
    });
  }, [destination, origin, origenLat, origenLng, passengerCount]);

  /**
   * Cancela la solicitud enviada.
   *
   * No borra el viaje elegido a proposito: quien cancela suele querer cambiar un
   * detalle y volver a pedir, no empezar de cero. Vuelve al resumen con todo
   * puesto.
   */
  /**
   * La cuenta atras de los cinco minutos de la regla R1.
   *
   * Arranca del numero que da el servidor y corre sola. Cuando llega a cero, la
   * solicitud esta caducada de hecho aunque el servidor tarde hasta un minuto en
   * marcarla, que es la ventana de pg_cron (D151). Ensenar "0:00" y seguir
   * diciendo "buscando" seria la pantalla mintiendo otra vez.
   */
  // La clave es el identificador de la solicitud, no los segundos: dos
  // solicitudes seguidas empiezan siempre con el mismo numero (E27).
  const segundosRestantes = useCountdown(
    solicitud?.segundosRestantes ?? null,
    solicitud?.id ?? null,
  );
  const expirada = solicitud !== null && segundosRestantes !== null && segundosRestantes <= 0;

  /**
   * Pregunta al servidor si el pasajero tiene un servicio en marcha (D152).
   *
   * Corre al abrir la pantalla y cada vez que la aplicacion vuelve a primer
   * plano. Lo segundo no es un extra: mientras el telefono esta bloqueado los
   * temporizadores de JavaScript se frenan, asi que al volver la cuenta atras
   * estaria retrasada. Al releer del servidor se corrige sola.
   */
  const sincronizacion = useRef(0);

  const sincronizarSolicitud = useCallback(async () => {
    const turno = ++sincronizacion.current;
    const activa = await fetchActiveRequest();

    // Una respuesta que llega tarde no puede pisar a una accion posterior del
    // pasajero, como acabar de crear o de cancelar.
    if (turno !== sincronizacion.current) return;

    setRestaurando(false);

    // No se pudo preguntar. No se toca nada: borrar lo que hay porque falla la
    // red seria inventarse que la solicitud ya no existe.
    if (!activa.ok) return;

    if (activa.data !== null) {
      setSolicitud(aSolicitudEnCurso(activa.data));
      return;
    }

    // El servidor dice que no queda ninguna viva. Si teniamos una, no se borra
    // en silencio: se deja en cero para que el pasajero vea que se acabo el
    // tiempo, en lugar de encontrarse el mapa limpio y preguntarse que paso.
    setSolicitud((actual) => (actual === null ? null : { ...actual, segundosRestantes: 0 }));
  }, []);

  useEffect(() => {
    const listener = AppState.addEventListener('change', (siguiente) => {
      if (siguiente === 'active') void sincronizarSolicitud();
    });

    // Diferido fuera del cuerpo del efecto, como en use-location y usePlaces.
    const primera = setTimeout(() => void sincronizarSolicitud(), 0);

    return () => {
      listener.remove();
      clearTimeout(primera);
      sincronizacion.current += 1;
    };
  }, [sincronizarSolicitud]);

  /** Deja el viaje elegido y vuelve al resumen, sin pedir nada. */
  const descartarSolicitud = useCallback(() => {
    setSolicitud(null);
    setErrorSolicitud(null);
  }, []);

  const cancelar = useCallback(async () => {
    if (solicitud === null) return;

    setCancelando(true);
    setErrorSolicitud(null);

    const resultado = await cancelRequest(solicitud.id);
    setCancelando(false);

    if (!resultado.ok) {
      setErrorSolicitud(resultado.failure.message);
      return;
    }

    setSolicitud(null);
  }, [solicitud]);

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
        snapPoints={modo === 'destino' ? [PEEK, 0.3, 0.72] : [PEEK, 'content']}
        index={sheetIndex}
        onIndexChange={setSheetIndex}
        header={
          modo === 'destino' || modo === 'cargando' ? (
            <Text variant="subheading">Hola, {user?.fullName ?? 'pasajero'}</Text>
          ) : modo === 'resumen' ? (
            <CabeceraDelViaje onCancelar={() => setDestination(null)} />
          ) : (
            // Sin aspa aqui. Descartar un viaje elegido y cancelar uno ya
            // solicitado no son la misma accion, y la segunda no puede quedar a
            // un toque descuidado: tiene su propio boton, con su nombre escrito.
            <Text variant="subheading">
              {expirada ? 'Nadie tomó tu servicio' : 'Buscando motorratón'}
            </Text>
          )
        }
      >
        {modo === 'cargando' && (
          <View style={styles.filaBuscando}>
            <ActivityIndicator color={colors.brand} />
            <Text variant="body" color="textSecondary">
              Revisando si tienes un servicio en curso
            </Text>
          </View>
        )}

        {modo === 'destino' && (
          <BuscarDestino places={places} onOpenSearch={abrirBuscador} onPickPlace={elegirLugar} />
        )}

        {modo === 'resumen' && destination !== null && (
          <ResumenDelViaje
            origen={origin}
            destino={destination}
            pasajeros={passengerCount}
            maxPasajeros={maxPasajeros}
            estimacion={estimacion}
            estimando={estimando}
            enviando={enviando}
            error={errorSolicitud}
            onCambiarPasajeros={setPassengerCount}
            onEditarOrigen={() =>
              router.push({ pathname: '/passenger/destination', params: { for: 'origin' } })
            }
            onEditarDestino={abrirBuscador}
            onConfirmar={() => void confirmar()}
          />
        )}

        {modo === 'buscando' && solicitud !== null && (
          <BuscandoConductor
            solicitud={solicitud}
            segundosRestantes={segundosRestantes}
            expirada={expirada}
            cancelando={cancelando}
            reintentando={enviando}
            error={errorSolicitud}
            onCancelar={() => void cancelar()}
            onReintentar={() => void confirmar()}
            onCambiarViaje={descartarSolicitud}
          />
        )}
      </BottomSheet>
    </View>
  );
}

/** Las cuatro caras de la hoja del pasajero. */
type ModoHoja = 'cargando' | 'destino' | 'resumen' | 'buscando';

/**
 * Lo minimo para pintar el panel de busqueda.
 *
 * Se define aqui, y no se reutiliza ActiveRequest, porque este objeto se
 * construye desde dos sitios: la lectura del servidor y, cuando esa lectura
 * falla justo despues de crear, lo que la pantalla ya tiene en la mano. Pedir el
 * tipo completo obligaria a rellenar campos que en el segundo caso no se
 * conocen, y rellenarlos con valores inventados para contentar al tipo es
 * exactamente como se cuela un dato falso en una pantalla.
 */
interface SolicitudEnCurso {
  id: string;
  origenLabel: string;
  destinoLabel: string;
  pasajeros: number;
  /** Nulo cuando no se pudo leer del servidor: entonces no se pinta cuenta atras. */
  segundosRestantes: number | null;
}

/** Traduce lo que devuelve el servidor a lo que pinta el panel. */
function aSolicitudEnCurso(activa: ActiveRequest): SolicitudEnCurso {
  return {
    id: activa.id,
    origenLabel: activa.origin.label,
    destinoLabel: activa.destination.label,
    pasajeros: activa.passengerCount,
    segundosRestantes: activa.secondsRemaining,
  };
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
  estimacion: RouteEstimate | null;
  estimando: boolean;
  enviando: boolean;
  error: string | null;
  onCambiarPasajeros: (valor: number) => void;
  onEditarOrigen: () => void;
  onEditarDestino: () => void;
  onConfirmar: () => void;
}

/**
 * Confirmacion visual del viaje: de donde sale y a donde va.
 *
 * El origen en null se muestra como "Tu ubicación actual", que es lo que quiere
 * casi todo el mundo y por eso no hay que elegirlo. Sigue siendo tocable, porque
 * a veces se pide el servicio para recoger en otro sitio.
 */
function ResumenDelViaje({
  origen,
  destino,
  pasajeros,
  maxPasajeros,
  estimacion,
  estimando,
  enviando,
  error,
  onCambiarPasajeros,
  onEditarOrigen,
  onEditarDestino,
  onConfirmar,
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

        {/* La estimacion solo ocupa sitio cuando existe. Si Mapbox no responde
            no se pinta nada, en lugar de ensenar un numero fabricado (D149). */}
        {(estimando || estimacion !== null) && (
          <>
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />
            <View style={styles.filaEstimacion}>
              <RouteIcon
                size={iconSize.sm}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              {estimacion !== null ? (
                <Text variant="caption" color="textSecondary">
                  {formatDistance(estimacion.meters)} · {formatDuration(estimacion.seconds)}{' '}
                  aproximadamente
                </Text>
              ) : (
                <Text variant="caption" color="textTertiary">
                  Calculando el recorrido
                </Text>
              )}
            </View>
          </>
        )}
      </Card>

      <FormError message={error} />

      <Button
        label="Confirmar servicio"
        variant="brand"
        icon={ArrowRight}
        iconPosition="right"
        fullWidth
        loading={enviando}
        onPress={onConfirmar}
      />
    </>
  );
}

interface BuscandoConductorProps {
  solicitud: SolicitudEnCurso;
  segundosRestantes: number | null;
  expirada: boolean;
  cancelando: boolean;
  reintentando: boolean;
  error: string | null;
  onCancelar: () => void;
  onReintentar: () => void;
  onCambiarViaje: () => void;
}

/**
 * La solicitud ya esta enviada: se busca quien la tome, o se acabo el tiempo.
 *
 * Es el primer estado de la aplicacion en el que existe algo en el servidor, asi
 * que la salida no puede ser un aspa discreta: cancelar aqui deshace un servicio
 * pedido, no una eleccion. Va como boton con su nombre completo.
 *
 * Cuando expira cambian las tres cosas a la vez, y a proposito: el texto, el
 * icono y los botones. Dejar el mismo panel con un "0:00" seria pedirle al
 * pasajero que dedujera el, de un numero, que ya no va a venir nadie.
 *
 * Que un conductor acepte todavia no se entera aqui. Eso llega con el tiempo
 * real de la Fase 13.
 */
function BuscandoConductor({
  solicitud,
  segundosRestantes,
  expirada,
  cancelando,
  reintentando,
  error,
  onCancelar,
  onReintentar,
  onCambiarViaje,
}: BuscandoConductorProps) {
  const { colors } = useTheme();

  return (
    <>
      <Card variant="outlined" padding="md">
        <View style={styles.filaBuscando}>
          {expirada ? (
            <Clock size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          ) : (
            <ActivityIndicator color={colors.brand} />
          )}
          <View style={styles.filaLugarTextos}>
            <Text variant="bodyStrong">
              {expirada
                ? 'Ningún motorratón tomó el servicio'
                : 'Avisando a los motorratones cercanos'}
            </Text>
            <Text variant="caption" color="textSecondary">
              {expirada
                ? 'Puedes volver a pedirlo o cambiar el viaje.'
                : 'Te avisamos en cuanto uno acepte.'}
            </Text>
          </View>
          {/* El tiempo solo se ensena mientras corre y solo si el servidor lo
              dijo. Sin dato no se pinta nada: un contador inventado sobre el
              reloj del telefono seria peor que no tener contador. */}
          {!expirada && segundosRestantes !== null && (
            <Text variant="bodyStrong" color="textSecondary">
              {formatCountdown(segundosRestantes)}
            </Text>
          )}
        </View>

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <View style={styles.puntoViaje}>
          <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {solicitud.origenLabel}
            </Text>
          </View>
        </View>

        <View style={styles.puntoViaje}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {solicitud.destinoLabel}
            </Text>
          </View>
        </View>
      </Card>

      <FormError message={error} />

      {expirada ? (
        <>
          <Button
            label="Volver a pedirlo"
            variant="brand"
            icon={RotateCw}
            fullWidth
            loading={reintentando}
            onPress={onReintentar}
          />
          <Button label="Cambiar el viaje" variant="secondary" fullWidth onPress={onCambiarViaje} />
        </>
      ) : (
        <Button
          label="Cancelar servicio"
          variant="secondary"
          fullWidth
          loading={cancelando}
          onPress={onCancelar}
        />
      )}
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
  filaBuscando: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: MIN_TOUCH_TARGET,
  },
  filaEstimacion: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 32,
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
