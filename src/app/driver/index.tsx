import { Inbox, MapPinOff, TriangleAlert } from 'lucide-react-native';
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
import {
  acceptOffer,
  fetchDriverState,
  rejectOffer,
  fetchActiveRides,
  setAvailability,
  type DriverRide,
  type DriverState,
} from '@/features/driver/driver-service';
import { ActiveRideCard } from '@/features/driver/active-ride-card';
import { OfferCard } from '@/features/driver/offer-card';
import { useDriverOffers } from '@/features/driver/use-driver-offers';
import { useLocationReporting } from '@/features/driver/use-location-reporting';
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

  const envio = useLocationReporting({ driverId, coords, active: disponible });

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
   * Los servicios que ya lleva encima.
   *
   * Desde D161 pueden ser varios a la vez: si al conductor le sobran asientos y
   * la solicitud le queda de camino, la recoge. Quien juzga si le queda de camino
   * es el, mirando la ruta, y no el servidor calculando desvios.
   */
  const [viajes, setViajes] = useState<DriverRide[]>([]);

  const cargarViajes = useCallback(async () => {
    const resultado = await fetchActiveRides();
    if (resultado.ok) {
      setViajes(resultado.data);
    }
  }, []);

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

        {/* Los encabezados solo aparecen cuando hay las dos cosas a la vez. Con
            una sola lista serian una etiqueta sobre lo evidente; con las dos,
            son lo que impide que se lean como un unico monton de tarjetas.
            Antes de D161 esta situacion no podia darse. */}
        {viajes.length > 0 && ofertas.offers.length > 0 && (
          <Text variant="caption" color="textTertiary" style={styles.seccion}>
            {viajes.length === 1 ? 'TU SERVICIO' : `TUS ${viajes.length} SERVICIOS`}
          </Text>
        )}

        {viajes.map((viaje) => (
          <ActiveRideCard key={viaje.rideId} ride={viaje} />
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

const styles = StyleSheet.create({
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
