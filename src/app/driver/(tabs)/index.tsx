import { useFocusEffect, useRouter } from 'expo-router';
import { CircleCheck, Inbox, MapPinOff, TriangleAlert } from 'lucide-react-native';
import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Switch, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { FormError } from '@/components/ui/form-error';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { hasRated } from '@/features/rating/rating-service';
import {
  acceptOffer,
  completeRide,
  confirmArrival,
  fetchDriverState,
  rejectOffer,
  fetchActiveRides,
  setAvailability,
  startDrivingToPickup,
  startRide,
  type DriverRide,
  type DriverState,
} from '@/features/driver/driver-service';
import { ActiveRideCard, type RideAction } from '@/features/driver/active-ride-card';
import { PendingStops } from '@/features/driver/pending-stops';
import { OfferCard } from '@/features/driver/offer-card';
import { useDriverOffers } from '@/features/driver/use-driver-offers';
import { useLocationReporting } from '@/features/driver/use-location-reporting';
import { useTrackRecording } from '@/features/driver/use-track-recording';
import { useLocation } from '@/features/map/use-location';
import { RIDE_ERROR_CODES } from '@/features/ride/errors';
import { useRequestRealtime } from '@/features/ride/use-request-realtime';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * Driver home.
 *
 * The availability switch is the single most important control in the driver
 * app: it decides whether this driver receives ride offers at all.
 *
 * Three deliberate decisions about how it looks:
 *
 *   - The state is the largest text on the screen, larger than the vehicle. The
 *     vehicle is reference data the driver never touches; the state is what they
 *     act on. Before, the vehicle number was drawn bigger than the state, which
 *     inverted the hierarchy and made both cards read as one indistinct block.
 *   - The whole card takes the brand colour when available, not just the switch.
 *     A driver checks this at a glance, outdoors, in sunlight, sometimes moving,
 *     and should recognise their state without reading a single word.
 *   - The vehicle card is deliberately quieter. One card is a control that
 *     changes something and the other is information that is never touched;
 *     dressing them the same is what made them look glued together.
 *
 * Desde la Fase 12 el interruptor escribe en el servidor y, mientras esta
 * encendido, el telefono manda su posicion cada treinta segundos. Recibir las
 * solicitudes en esta pantalla es el paso siguiente.
 */
export default function DriverHome() {
  const router = useRouter();
  const { colors } = useTheme();
  const { user } = useSession();
  const driverId = user?.id ?? null;

  const [estado, setEstado] = useState<DriverState | null>(null);
  const [cargando, setCargando] = useState(true);
  const [cambiando, setCambiando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const location = useLocation();
  const coords = location.state.kind === 'ready' ? location.state.coords : null;

  const disponible = estado?.isAvailable ?? false;

  /**
   * Los servicios que ya lleva encima.
   *
   * Desde D161 pueden ser varios a la vez: si al conductor le sobran asientos y
   * la solicitud le queda de camino, la recoge. Quien juzga si le queda de camino
   * es el, mirando la ruta, y no el servidor calculando desvios.
   */
  const [viajes, setViajes] = useState<DriverRide[]>([]);

  const envio = useLocationReporting({
    driverId,
    coords,
    available: disponible,
    // Con un servicio encima se envia siempre y mas seguido (R9), tenga el
    // interruptor como lo tenga: puede estar apagado porque el motorraton se
    // lleno, que es justo cuando hay pasajeros esperando verlo llegar.
    riding: viajes.length > 0,
  });

  // El rastro se graba solo mientras hay pasajero a bordo. Un viaje aceptado o de
  // camino no cuenta: eso es la aproximacion, no el recorrido.
  const viajesEnRecorrido = viajes.filter((v) => v.status === 'in_progress').map((v) => v.rideId);
  useTrackRecording(viajesEnRecorrido, coords);

  const sinVehiculoAun = estado !== null && estado.vehicle === null;
  const ofertas = useDriverOffers(disponible && !sinVehiculoAun);

  const cargar = useCallback(async () => {
    if (driverId === null) return;

    const resultado = await fetchDriverState(driverId);
    setCargando(false);

    if (resultado.ok) {
      setEstado(resultado.data);
      setError(null);
    } else {
      setError(resultado.failure.message);
    }
  }, [driverId]);

  const [respondiendo, setRespondiendo] = useState<string | null>(null);
  const [rechazando, setRechazando] = useState<string | null>(null);

  /**
   * Que viaje esta esperando respuesta del servidor, y que fallo en cual.
   *
   * Van por identificador de viaje y no como un booleano suelto porque desde
   * D161 puede haber dos o tres tarjetas a la vez: un girador global las pondria
   * a todas en marcha, y un mensaje de error global aparecerian bajo la tarjeta
   * equivocada.
   */
  const [avanzando, setAvanzando] = useState<string | null>(null);
  const [errorViaje, setErrorViaje] = useState<{ rideId: string; message: string } | null>(null);

  const cargarViajes = useCallback(async () => {
    const resultado = await fetchActiveRides();
    if (resultado.ok) {
      setViajes(resultado.data);
    }
  }, []);

  /**
   * Mueve un servicio al estado siguiente.
   *
   * Se releen los viajes siempre, salga bien o mal, y esa es la parte que
   * importa. Si sale bien, para que la tarjeta ensene el boton que toca ahora.
   * Y si sale mal, porque los dos errores que puede devolver significan lo mismo:
   * **el viaje ya no esta donde la pantalla creia**. Pasa cuando el pasajero
   * cancela mientras el conductor va de camino, o cuando dos toques seguidos
   * llegan al servidor. Dejar la tarjeta como estaba invitaria a insistir contra
   * un estado que ya cambio.
   *
   * `complete_ride` es la unica que ademas hace desaparecer la tarjeta, porque
   * `list_driver_active_rides` solo devuelve los viajes vivos.
   */
  /**
   * El servicio que el conductor acaba de terminar, para poder calificarlo.
   *
   * SE GUARDA AQUI Y NO SE PREGUNTA AL SERVIDOR. Los dos datos que hacen falta
   * —que viaje era y a quien llevaba— los tiene la tarjeta que se acaba de
   * cerrar, asi que preguntarlos otra vez seria una consulta para saber algo que
   * ya sabemos.
   *
   * A cambio, esto no sobrevive a cerrar la aplicacion. No es un descuido: lo que
   * queda sin calificar vive en el historial (paso 4), que es donde el conductor
   * lo va a buscar al dia siguiente. Aqui solo esta el atajo del momento.
   */
  const [recienTerminado, setRecienTerminado] = useState<{
    rideId: string;
    passengerName: string;
  } | null>(null);

  /**
   * Al volver de calificar, comprobar si de verdad califico.
   *
   * La tarjeta se quedaba ofreciendo "Calificar al pasajero" despues de haberlo
   * hecho, porque la calificacion ocurre en otra pantalla. Se pregunta en vez de
   * darlo por hecho: si el conductor entro y volvio sin enviar nada, el atajo
   * tiene que seguir ahi.
   */
  useFocusEffect(
    useCallback(() => {
      if (recienTerminado === null || user === null) return;

      const tarea = setTimeout(() => {
        void hasRated(recienTerminado.rideId, user.id).then((resultado) => {
          if (resultado.ok && resultado.data) setRecienTerminado(null);
        });
      }, 0);

      return () => clearTimeout(tarea);
    }, [recienTerminado, user]),
  );

  const avanzarViaje = useCallback(
    async (viaje: DriverRide, accion: RideAction) => {
      setAvanzando(viaje.rideId);
      setErrorViaje(null);

      const resultado = await (accion === 'on_the_way'
        ? startDrivingToPickup(viaje.rideId)
        : accion === 'arrived'
          ? confirmArrival(viaje.rideId)
          : accion === 'start'
            ? startRide(viaje.rideId)
            : completeRide(viaje.rideId));

      setAvanzando(null);

      if (!resultado.ok) {
        setErrorViaje({ rideId: viaje.rideId, message: resultado.failure.message });

        // Salvo cuando el conductor solo esta lejos: ahi el viaje sigue
        // exactamente donde estaba, y releer no cambiaria nada. Lo que tiene que
        // hacer es acercarse y volver a tocar.
        if (resultado.failure.code !== RIDE_ERROR_CODES.tooFarFromPickup) {
          void cargarViajes();
        }
        return;
      }

      // Terminar un servicio libera asientos, y con ellos puede volver la
      // disponibilidad (D164). Por eso se relee tambien el estado.
      void cargarViajes();
      if (accion === 'complete') {
        void cargar();
        setRecienTerminado({ rideId: viaje.rideId, passengerName: viaje.passengerName });
      }
    },
    [cargar, cargarViajes],
  );

  /**
   * Toma el servicio.
   *
   * Si otro conductor gano la carrera, el servidor responde REQUEST_ALREADY_TAKEN
   * y aqui se trata como lo que es: no un error del que avisar con alarma, sino
   * el desenlace normal de que dos personas quieran el mismo viaje. Se retira la
   * tarjeta, se explica en una linea y se sigue esperando.
   */
  const aceptar = useCallback(
    async (offerId: string) => {
      setRespondiendo(offerId);
      setError(null);

      const resultado = await acceptOffer(offerId);
      setRespondiendo(null);

      if (resultado.ok) {
        ofertas.removeOffer(offerId);

        // Hay que releer las dos cosas. Desde D161 el servidor ya no apaga la
        // disponibilidad sin mas: la recalcula, y solo la apaga si el motorraton
        // se lleno. Sin volver a preguntar, el interruptor diria una cosa y el
        // servidor otra, y ademas los asientos libres que se pintan mas arriba se
        // calculan a partir de los viajes.
        void cargar();
        void cargarViajes();
        return;
      }

      setError(resultado.failure.message);

      // Cualquiera de estos cuatro significa que esa oferta ya no sirve para
      // nada, asi que la tarjeta desaparece en lugar de quedarse invitando a
      // insistir.
      const codigo = resultado.failure.code;
      if (
        codigo === RIDE_ERROR_CODES.requestAlreadyTaken ||
        codigo === RIDE_ERROR_CODES.offerExpired ||
        codigo === RIDE_ERROR_CODES.offerAlreadyAnswered ||
        codigo === RIDE_ERROR_CODES.vehicleCapacityExceeded
      ) {
        ofertas.removeOffer(offerId);
      }

      // Si se lleno, lo que la pantalla creia saber del motorraton ya no vale.
      // Puede haber aceptado otra oferta hace un instante, asi que se releen los
      // viajes y el estado para que los asientos libres cuadren con la realidad.
      if (codigo === RIDE_ERROR_CODES.vehicleCapacityExceeded) {
        void cargar();
        void cargarViajes();
      }
    },
    [ofertas, cargar, cargarViajes],
  );

  /** REGLA R12: rechazar es definitivo, no se le vuelve a ofrecer. */
  const rechazar = useCallback(
    async (offerId: string) => {
      setRechazando(offerId);
      setError(null);

      const resultado = await rejectOffer(offerId);
      setRechazando(null);

      // Se retira en los dos casos. Si el rechazo fallo porque la oferta ya no
      // estaba disponible, el resultado que el conductor queria es el mismo.
      ofertas.removeOffer(offerId);

      if (!resultado.ok && resultado.failure.code !== 'OFFER_NOT_AVAILABLE') {
        setError(resultado.failure.message);
      }
    },
    [ofertas],
  );

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto: el
    // compilador de React rechaza un setState alcanzable desde aqui.
    //
    // Los viajes en curso se leen tambien al abrir, no solo al aceptar: si el
    // conductor cierra la aplicacion con un servicio encima y vuelve, tiene que
    // encontrarlo ahi. Es el mismo criterio que D152 en el lado del pasajero.
    const id = setTimeout(() => {
      void cargar();
      void cargarViajes();
    }, 0);
    return () => clearTimeout(id);
  }, [cargar, cargarViajes]);

  /**
   * Lo que le pase a una solicitud suya, en cuanto pase.
   *
   * Cierra dos huecos que quedaron abiertos en la Fase 12, y los dos terminaban
   * con el conductor actuando sobre informacion falsa:
   *
   *   - **Otro conductor acepta primero.** La oferta se quedaba en pantalla hasta
   *     caducar, y al tocarla recibia "otro motorratón tomó este servicio".
   *     `use-driver-offers` lo dejo escrito como limite conocido a la espera de
   *     que se publicara `ride_requests`, que es lo que se hizo en el paso 2
   *   - **El pasajero cancela un servicio ya aceptado.** Este es el peor: la
   *     tarjeta seguia en pantalla con su nombre y su telefono, y el conductor
   *     podia ir a recoger a alguien que cancelo hace diez minutos
   *
   * Se releen las tres cosas porque una cancelacion las toca todas: la oferta
   * desaparece, el viaje desaparece y la disponibilidad vuelve.
   */
  const alCambiarUnaSolicitud = useCallback(() => {
    void cargar();
    void cargarViajes();
    ofertas.refresh();
  }, [cargar, cargarViajes, ofertas]);

  useRequestRealtime(driverId !== null, alCambiarUnaSolicitud, 'conductor-sus-solicitudes');

  const cambiarDisponibilidad = useCallback(
    async (valor: boolean) => {
      if (driverId === null || estado === null) return;

      // Se pinta el cambio antes de que el servidor conteste. Un interruptor que
      // tarda medio segundo en moverse se siente roto, y quien lo usa vuelve a
      // tocarlo. Si el servidor lo rechaza, se devuelve a su sitio.
      const anterior = estado.isAvailable;
      setEstado({ ...estado, isAvailable: valor });
      setCambiando(true);
      setError(null);

      const resultado = await setAvailability(driverId, valor);
      setCambiando(false);

      if (!resultado.ok) {
        setEstado({ ...estado, isAvailable: anterior });
        setError(resultado.failure.message);
      }
    },
    [driverId, estado],
  );

  if (cargando) {
    return (
      <Screen header={<Header title="Cargando" />}>
        <Spinner label="Consultando tu estado" />
      </Screen>
    );
  }

  const sinVehiculo = estado !== null && estado.vehicle === null;
  const sinUbicacion = disponible && coords === null;

  /**
   * Cuanta gente lleva encima y cuanto sitio le queda.
   *
   * Se cuenta aqui en lugar de pedirselo al servidor porque el dato ya esta: los
   * viajes activos de un conductor van todos en su motorraton, que es una regla
   * que la base de datos hace cumplir desde D161. Sumar lo que ya tenemos evita
   * una consulta mas por cada vez que cambia algo.
   */
  const aBordo = viajes.reduce((total, viaje) => total + viaje.passengerCount, 0);
  const capacidad = estado?.vehicle?.maxPassengers ?? 0;
  const libres = Math.max(0, capacidad - aBordo);

  // Los extremos de lo que ya lleva, para que el mapa de cada oferta los dibuje
  // debajo. Es lo que convierte "por donde va este viaje" en "por donde va
  // respecto de lo que ya tengo", que es la pregunta de D161.
  const rutasEnCurso = viajes.map((viaje) => ({
    origin: viaje.origin,
    destination: viaje.destination,
  }));

  return (
    <Screen scroll header={<Header title={`Hola, ${user?.fullName ?? 'conductor'}`} />}>
      <View style={styles.panels}>
        <Card
          variant="elevated"
          style={
            disponible
              ? { backgroundColor: colors.brandSubtle, borderColor: colors.brand, borderWidth: 1 }
              : undefined
          }
        >
          <View style={styles.statusRow}>
            <View style={styles.statusCopy}>
              <Text variant="title">{disponible ? 'Disponible' : 'No disponible'}</Text>
              <Text variant="caption" color="textSecondary">
                {/* Desde D161 el interruptor puede apagarse solo, sin que el
                    conductor lo toque: ocurre en cuanto acepta el servicio que
                    llena el motorraton. Decirle ahi "no recibirás solicitudes
                    mientras estés en este estado" le haria buscar que hizo mal,
                    cuando no hizo nada. */}
                {disponible
                  ? 'Estás recibiendo solicitudes de servicio.'
                  : aBordo > 0 && libres === 0
                    ? 'Tu motorratón está completo. Volverás a recibir solicitudes cuando termines un servicio.'
                    : 'No recibirás solicitudes mientras estés en este estado.'}
              </Text>
            </View>
            <Switch
              value={disponible}
              onValueChange={(valor) => void cambiarDisponibilidad(valor)}
              disabled={cambiando || estado === null}
              accessibilityLabel="Cambiar disponibilidad"
              trackColor={{ false: colors.border, true: colors.brand }}
              thumbColor={colors.surface}
            />
          </View>
        </Card>

        <Card variant="outlined" padding="md" style={styles.vehicle}>
          <Text variant="caption" color="textTertiary">
            MOTORRATÓN ASIGNADO
          </Text>
          {estado?.vehicle === null || estado === null ? (
            <>
              <Text variant="subheading">Sin asignar</Text>
              <Text variant="caption" color="textSecondary">
                La empresa todavía no te asignó un motorratón. Sin él no podrás tomar servicios.
              </Text>
            </>
          ) : (
            <>
              <Text variant="subheading">Motorratón {estado.vehicle.unitNumber}</Text>
              <Text variant="caption" color="textSecondary">
                Placa {estado.vehicle.plate} · Capacidad {estado.vehicle.maxPassengers} pasajeros
              </Text>
              {/* Los asientos libres solo aparecen cuando lleva a alguien. Con el
                  motorraton vacio seria repetir la capacidad con otras palabras, y
                  la linea de arriba ya la dice. */}
              {aBordo > 0 && (
                <Text variant="bodyStrong" color={libres === 0 ? 'textSecondary' : 'brand'}>
                  {libres === 0
                    ? `Completo · ${aBordo} a bordo`
                    : `${libres === 1 ? 'Un asiento libre' : `${libres} asientos libres`} · ${aBordo} a bordo`}
                </Text>
              )}
            </>
          )}
        </Card>
      </View>

      <FormError message={error} />

      {/* Avisos que solo importan mientras esta disponible. Ensenarlos siempre
          seria ruido permanente para advertir de algo que solo aplica cuando el
          interruptor esta encendido. */}
      {sinUbicacion && (
        <Aviso
          icon={MapPinOff}
          titulo="No sabemos dónde estás"
          detalle="Sin tu ubicación no podemos ofrecerte servicios cercanos. Revisa el permiso de ubicación."
          accion={
            location.state.kind === 'permission-required' && location.state.canAsk
              ? { etiqueta: 'Dar permiso', onPress: () => void location.requestPermission() }
              : location.state.kind === 'permission-required'
                ? { etiqueta: 'Abrir ajustes', onPress: () => void location.openSettings() }
                : location.state.kind === 'services-disabled'
                  ? { etiqueta: 'Activar ubicación', onPress: () => void location.enableServices() }
                  : { etiqueta: 'Reintentar', onPress: location.retry }
          }
        />
      )}

      {disponible && !sinUbicacion && (
        <Aviso
          icon={TriangleAlert}
          titulo="Mantén la aplicación abierta"
          detalle="Si sales de la aplicación dejamos de enviar tu ubicación, y a los dos minutos los pasajeros dejan de verte."
        />
      )}

      {disponible && envio.error !== null && (
        <Aviso icon={TriangleAlert} titulo="No pudimos enviar tu ubicación" detalle={envio.error} />
      )}

      <View style={styles.feed}>
        {ofertas.error !== null && <FormError message={ofertas.error} />}

        {/* Lo primero de la hoja, y solo justo despues de terminar: es lo ultimo
            que ha pasado y lo unico que pide una respuesta suya. Se va en cuanto
            califica o toca "Ahora no". */}
        {recienTerminado !== null && (
          <ServicioTerminado
            passengerName={recienTerminado.passengerName}
            onCalificar={() =>
              router.push({
                pathname: '/driver/rate/[id]',
                params: {
                  id: recienTerminado.rideId,
                  name: recienTerminado.passengerName,
                },
              })
            }
            onCerrar={() => setRecienTerminado(null)}
          />
        )}

        {/* Los encabezados solo aparecen cuando hay las dos cosas a la vez. Con
            una sola lista serian una etiqueta sobre lo evidente; con las dos,
            son lo que impide que se lean como un unico monton de tarjetas.
            Antes de D161 esta situacion no podia darse. */}
        {viajes.length > 0 && ofertas.offers.length > 0 && (
          <Text variant="caption" color="textTertiary" style={styles.seccion}>
            {viajes.length === 1 ? 'TU SERVICIO' : `TUS ${viajes.length} SERVICIOS`}
          </Text>
        )}

        {/* La vista de conjunto va ANTES de las tarjetas: con dos o tres
            servicios abiertos, lo primero que necesita el conductor es saber
            que le falta en total, no leer tres tarjetas completas para
            reconstruirlo. Con un solo servicio no aparece. */}
        <PendingStops rides={viajes} />

        {viajes.map((viaje) => (
          <ActiveRideCard
            key={viaje.rideId}
            ride={viaje}
            onAdvance={(r, accion) => void avanzarViaje(r, accion)}
            advancing={avanzando === viaje.rideId}
            error={errorViaje?.rideId === viaje.rideId ? errorViaje.message : null}
          />
        ))}

        {viajes.length > 0 && ofertas.offers.length > 0 && (
          <Text variant="caption" color="textTertiary" style={styles.seccion}>
            {ofertas.offers.length === 1 ? 'NUEVA SOLICITUD' : 'NUEVAS SOLICITUDES'}
          </Text>
        )}

        {ofertas.offers.map((oferta) => (
          <OfferCard
            key={oferta.offerId}
            offer={oferta}
            aceptando={respondiendo === oferta.offerId}
            rechazando={rechazando === oferta.offerId}
            onAceptar={() => void aceptar(oferta.offerId)}
            onRechazar={() => void rechazar(oferta.offerId)}
            onExpirar={() => ofertas.removeOffer(oferta.offerId)}
            enCurso={rutasEnCurso}
          />
        ))}

        {/* Con un servicio encima y sitio de sobra, el conductor sigue en la cola
            y conviene decirselo: si no, un hueco debajo de su servicio parece que
            la aplicacion dejo de buscarle nada. */}
        {ofertas.offers.length === 0 && viajes.length > 0 && disponible && libres > 0 && (
          <Spinner
            label={
              libres === 1
                ? 'Esperando otra solicitud, te queda un asiento'
                : `Esperando otra solicitud, te quedan ${libres} asientos`
            }
          />
        )}

        {ofertas.offers.length === 0 &&
          viajes.length === 0 &&
          (disponible && !sinVehiculo ? (
            <Spinner label="Esperando solicitudes cercanas" />
          ) : (
            <EmptyState
              icon={Inbox}
              title="Sin solicitudes"
              description={
                sinVehiculo
                  ? 'Necesitas un motorratón asignado para recibir servicios.'
                  : 'Cambia tu estado a disponible para empezar a recibir servicios.'
              }
            />
          ))}
      </View>
    </Screen>
  );
}

interface AvisoProps {
  icon: typeof TriangleAlert;
  titulo: string;
  detalle: string;
  accion?: { etiqueta: string; onPress: () => void };
}

/**
 * Aviso con acento pero sin alarma.
 *
 * No usa FormError a proposito: eso es para lo que salio mal, y esto es para lo
 * que el conductor tiene que saber. Pintar de rojo "mantén la aplicación
 * abierta" haria que pareciera un fallo cuando es una instruccion.
 */
function Aviso({ icon: Icon, titulo, detalle, accion }: AvisoProps) {
  const { colors } = useTheme();

  return (
    <View style={[styles.aviso, { backgroundColor: colors.surfaceSubtle }]}>
      <Icon size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
      <View style={styles.avisoTextos}>
        <Text variant="bodyStrong">{titulo}</Text>
        <Text variant="caption" color="textSecondary">
          {detalle}
        </Text>
        {accion !== undefined && (
          <Button label={accion.etiqueta} variant="secondary" size="sm" onPress={accion.onPress} />
        )}
      </View>
    </View>
  );
}

/**
 * La despedida del conductor.
 *
 * Mas corta que la del pasajero a proposito. El pasajero se esta bajando del
 * motorraton y puede leer; el conductor tiene la siguiente solicitud entrando por
 * la misma pantalla, asi que aqui solo va lo que hace falta para decidir: a quien
 * llevo y dos botones.
 *
 * NO SE CIERRA SOLA. Que desaparezca a los pocos segundos significaria perder la
 * calificacion justo cuando el conductor esta guardando el telefono.
 */
function ServicioTerminado({
  passengerName,
  onCalificar,
  onCerrar,
}: {
  passengerName: string;
  onCalificar: () => void;
  onCerrar: () => void;
}) {
  const { colors } = useTheme();

  return (
    <Card padding="lg">
      <View style={styles.filaTerminado}>
        <CircleCheck size={iconSize.md} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <View style={styles.textosTerminado}>
          <Text variant="bodyStrong">Servicio terminado</Text>
          <Text variant="caption" color="textSecondary">
            Llevaste a {passengerName}
          </Text>
        </View>
      </View>

      <View style={styles.botonesTerminado}>
        <Button label="Calificar al pasajero" variant="brand" fullWidth onPress={onCalificar} />
        <Button label="Ahora no" variant="ghost" fullWidth onPress={onCerrar} />
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  filaTerminado: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  textosTerminado: { flex: 1, gap: spacing.xxs },
  botonesTerminado: { gap: spacing.xs, marginTop: spacing.md },
  aviso: {
    borderRadius: radius.md,
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  avisoTextos: {
    alignItems: 'flex-start',
    flex: 1,
    gap: spacing.xs,
  },
  feed: {
    marginTop: spacing.xl,
  },
  // Las dos tarjetas estaban pegadas: eran hermanas sin separacion, y Screen
  // solo aporta margen horizontal. Lo que parecia un hueco era la sombra.
  panels: {
    gap: spacing.md,
  },
  statusCopy: {
    flex: 1,
    gap: spacing.xxs,
  },
  seccion: {
    marginBottom: spacing.sm,
    marginTop: spacing.lg,
  },
  statusRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  vehicle: {
    borderRadius: radius.md,
  },
});
