import { useFocusEffect, useRouter } from 'expo-router';
import {
  ArrowRight,
  Ban,
  Bike as BikeIcon,
  Circle,
  CircleCheck,
  Clock,
  History,
  Info,
  LocateFixed,
  MapPin,
  Navigation,
  Package,
  Phone,
  RotateCw,
  Route as RouteIcon,
  Search,
  Star,
  UserRound,
  WifiOff,
  X,
} from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  AppState,
  Linking,
  Pressable,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { describePoint } from '@/features/destination/describe-point';
import type { ChosenPoint, Place } from '@/features/destination/types';
import { usePlaces } from '@/features/destination/use-places';
import { CargoPicker } from '@/features/fare/cargo-picker';
import { ChosenCargoList } from '@/features/fare/chosen-cargo-list';
import { fetchRequestCargo, type RequestCargoLine } from '@/features/fare/fare-service';
import { FareRow } from '@/features/fare/fare-row';
import { formatAmount } from '@/features/fare/format-amount';
import { ServiceTypeToggle } from '@/features/fare/service-type-toggle';
import type { CargoItem, CargoType, FareQuote, ServiceType } from '@/features/fare/types';
import { useCargoTypes } from '@/features/fare/use-cargo-types';
import { useFareQuote, type FareQuotePending } from '@/features/fare/use-fare-quote';
import { LocationGate, blockingState } from '@/features/map/location-gate';
import { Map, type MapHandle, type MapMarker, type MapRoute } from '@/features/map/map';
import { AMALFI_REGION, regionAround } from '@/features/map/region';
import { useLocation } from '@/features/map/use-location';
import { messageForCode } from '@/features/ride/errors';
import { PassengerCount } from '@/features/ride/passenger-count';
import { useRideDraft } from '@/features/ride/ride-draft';
import {
  cancelRequest,
  createRequest,
  fetchActiveRequest,
  fetchDriverCancelledNotice,
  fetchFinishedRequest,
  type ActiveRequest,
  type AssignedDriver,
  type DriverCancelledNotice,
  type FinishedRequest,
  type RequestFare,
  type RideStatus,
} from '@/features/ride/ride-service';
import {
  fetchRoute,
  formatDistance,
  formatDuration,
  type Route,
  type RouteEstimate,
} from '@/features/ride/route-service';
import { useDriverLocation } from '@/features/ride/use-driver-location';
import { useMaxPassengers, useNumericSetting } from '@/features/ride/settings';
import { formatCountdown, useCountdown } from '@/features/ride/use-countdown';
import { useRequestRealtime } from '@/features/ride/use-request-realtime';
import { useRideRealtime } from '@/features/ride/use-ride-realtime';
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
  const { height: screenHeight } = useWindowDimensions();

  /**
   * Arranca en 1 y no en 0 porque el 0 es ahora la hoja bajada del todo. Es un
   * sitio al que se va a proposito para mirar el mapa, no donde se empieza.
   */
  const [sheetIndex, setSheetIndex] = useState(1);
  const location = useLocation();
  const mapRef = useRef<MapHandle>(null);

  const {
    origin,
    destination,
    passengerCount,
    pickupReference,
    serviceType,
    parcelDescription,
    cargoItems,
    setDestination,
    setPassengerCount,
    setPickupReference,
    setServiceType,
    setParcelDescription,
    setCargoItemQuantity,
    clear: limpiarBorrador,
  } = useRideDraft();
  const { places } = usePlaces();
  const maxPasajeros = useMaxPassengers();
  // El catalogo de carga solo hace falta cuando el pasajero elige "encomienda".
  // Pedirlo en el primer pintado era una llamada de red compitiendo con las que
  // si pintan la pantalla (Fase 24 paso 4).
  //
  // Se evaluo adelantar el pedido a "resumen" en lugar de a "encomienda" (asi
  // el catalogo ya estaria listo para cuando el pasajero llegue a tocarlo) y se
  // descarto para este arreglo: en "resumen" ya compiten la tarifa y la ruta, el
  // mismo problema que motivo la carga perezosa, solo que un paso mas tarde. La
  // solucion de fondo -que el dialogo nunca muestre una lista vacia sin avisar,
  // sea cual sea el momento en que se pida- no depende de cuando se dispare el
  // pedido, y es la que se hizo aqui. Adelantar el disparador sigue siendo una
  // mejora valida, pero es una decision de rendimiento aparte, no parte de este
  // arreglo.
  const {
    cargoTypes,
    loading: cargandoTiposDeCarga,
    error: errorTiposDeCarga,
    reload: reintentarTiposDeCarga,
  } = useCargoTypes(serviceType === 'parcel');

  /** Cuantos van de verdad. En una encomienda son cero, sin importar lo que
   * quedara guardado en el borrador de la ultima vez que fue un viaje de
   * pasajeros (D220). */
  const pasajerosEfectivos = serviceType === 'parcel' ? 0 : passengerCount;

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

  /**
   * El servicio que acaba de terminar, mientras el pasajero no lo cierre.
   *
   * Vive aparte de `solicitud` a proposito: no es un servicio en curso, es una
   * despedida. Mezclarlos obligaria a que cada rama del panel comprobara si lo
   * que tiene delante todavia existe.
   */
  const [resumenFinal, setResumenFinal] = useState<FinishedRequest | null>(null);

  /**
   * El aviso de que el conductor cancelo con el pasajero a bordo (D187, Fase 18).
   *
   * Vive aparte de `resumenFinal` por el mismo motivo que ese vive aparte de
   * `solicitud`: no es un servicio en curso ni una despedida normal, es un
   * desenlace distinto y la hoja tiene que poder distinguirlo.
   */
  const [avisoCancelacion, setAvisoCancelacion] = useState<DriverCancelledNotice | null>(null);

  /** Las seis caras de la hoja, en el orden en que las ve el pasajero. */
  const modo: ModoHoja = restaurando
    ? 'cargando'
    : solicitud !== null
      ? 'buscando'
      : resumenFinal !== null
        ? 'terminado'
        : avisoCancelacion !== null
          ? 'cancelado_conductor'
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

  /**
   * Cuanto va a costar, mientras el pasajero decide (D217).
   *
   * Solo aplica al resumen: la solicitud ya enviada guarda su propio valor
   * congelado (D225) y lo trae `get_active_request`, asi que no hace falta
   * volver a cotizar nada mientras se espera un conductor.
   */
  const tarifa = useFareQuote({
    serviceType,
    passengerCount: pasajerosEfectivos,
    // D233: hace falta el origen ademas del destino. `origenLat`/`origenLng`
    // ya resuelven "mi ubicacion actual" contra el GPS (D137); si no hay ni
    // punto elegido ni GPS, quedan en null y el hook lo trata como "falta
    // saber de donde sale", no como un error.
    originLatitude: origenLat,
    originLongitude: origenLng,
    originPlaceId: origin?.placeId ?? null,
    destinationLatitude: destinoLat,
    destinationLongitude: destinoLng,
    destinationPlaceId: destination?.placeId ?? null,
    cargo: cargoItems,
  });

  const [ruta, setRuta] = useState<Route | null>(null);
  const [estimando, setEstimando] = useState(false);

  /**
   * La estimacion caduca en cuanto cambia cualquiera de los cuatro numeros.
   *
   * Se limpia en el render, con el mismo patron que el modo de la hoja. Hacerlo
   * dentro del efecto dejaria un fotograma con la distancia del viaje anterior
   * bajo el destino nuevo, que es de las cosas que nadie reporta y todo el mundo
   * ve.
   */
  /**
   * Los cuatro numeros del viaje que hay que dibujar y medir.
   *
   * La solicitud enviada manda sobre el borrador, y no al reves. El borrador
   * vive en memoria (D137), asi que quien reabre la aplicacion con un servicio
   * en curso lo tiene vacio: si la ruta dependiera de el, el mapa se quedaria
   * sin dibujar justo cuando el pasajero esta esperando a que lo recojan, que es
   * cuando mas mira la pantalla.
   */
  const viajeOrigenLat = solicitud?.origen.latitude ?? origenLat;
  const viajeOrigenLng = solicitud?.origen.longitude ?? origenLng;
  const viajeDestinoLat = solicitud?.destino.latitude ?? destinoLat;
  const viajeDestinoLng = solicitud?.destino.longitude ?? destinoLng;

  const claveRuta = `${viajeOrigenLat},${viajeOrigenLng},${viajeDestinoLat},${viajeDestinoLng}`;
  const [claveRutaAnterior, setClaveRutaAnterior] = useState(claveRuta);

  if (claveRuta !== claveRutaAnterior) {
    setClaveRutaAnterior(claveRuta);
    setRuta(null);
  }

  /**
   * El error del servidor caduca en cuanto cambia lo que se le pregunto.
   *
   * Sin esto, el pasajero que lee "el punto de recogida esta fuera de la zona de
   * servicio", cambia el origen y lo arregla, sigue viendo el mismo aviso bajo un
   * viaje que ya es valido. La pantalla estaria mintiendo, y ademas sobre lo
   * unico que el pasajero acaba de corregir.
   *
   * Va la cantidad de pasajeros ademas de las coordenadas: "no hay motocarros
   * disponibles" puede deberse a que ninguno tiene capacidad para tres, y baja a
   * dos deja de ser cierto.
   */
  const claveSolicitud = `${claveRuta}|${passengerCount}`;
  const [claveSolicitudAnterior, setClaveSolicitudAnterior] = useState(claveSolicitud);

  if (claveSolicitud !== claveSolicitudAnterior) {
    setClaveSolicitudAnterior(claveSolicitud);
    setErrorSolicitud(null);
  }

  /**
   * Al volver de calificar, releer la despedida.
   *
   * La tarjeta se quedaba ofreciendo "Calificar el viaje" despues de haberlo
   * calificado: la calificacion se guarda en otra pantalla y esta no se entera
   * de nada. Se vio en dispositivo, no en el codigo.
   *
   * Solo se relee si hay despedida en pantalla. Volver al mapa desde el destino
   * o desde el historial no tiene por que costar una consulta.
   */
  const hayDespedida = resumenFinal !== null;

  useFocusEffect(
    useCallback(() => {
      if (!hayDespedida) return;

      // Diferido, como en el resto de la aplicacion: el compilador de React
      // rechaza un setState alcanzable sincronamente desde un efecto.
      const tarea = setTimeout(() => {
        void fetchFinishedRequest().then((resultado) => {
          if (resultado.ok) {
            setResumenFinal(resultado.data);
          }
        });
      }, 0);

      return () => clearTimeout(tarea);
      // Depende de si HAY despedida, no de cual: con el objeto entero cada
      // relectura dispararia la siguiente, en bucle.
    }, [hayDespedida]),
  );

  useEffect(() => {
    if (
      viajeOrigenLat === null ||
      viajeOrigenLng === null ||
      viajeDestinoLat === null ||
      viajeDestinoLng === null
    ) {
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
        const resultado = await fetchRoute(
          { latitude: viajeOrigenLat, longitude: viajeOrigenLng },
          { latitude: viajeDestinoLat, longitude: viajeDestinoLng },
        );
        if (!vigente) return;
        // Un fallo deja la ruta en null: ni se pinta la fila de la distancia
        // (D149) ni se dibuja nada en el mapa. Inventar una distancia seria peor
        // que no dar ninguna, y una linea recta entre los dos puntos seria peor
        // todavia, porque en Amalfi no se parece a ninguna carretera.
        setRuta(resultado.ok ? resultado.route : null);
        setEstimando(false);
      })();
    }, 0);

    return () => {
      vigente = false;
      clearTimeout(id);
    };
  }, [viajeOrigenLat, viajeOrigenLng, viajeDestinoLat, viajeDestinoLng]);

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

    // Las dos reglas de la encomienda, comprobadas antes de llamar al servidor.
    // No es desconfianza de `request_ride`, que las vuelve a exigir de todos
    // modos: es que las dos son cosas que la propia pantalla ya sabe sin
    // necesidad de un viaje de red, y esperar a que el servidor las rechace
    // seria una espera sin sentido para algo que ya se podia decir aqui.
    if (serviceType === 'parcel') {
      const descripcion = parcelDescription.trim();
      if (descripcion.length < 3 || descripcion.length > 120) {
        setErrorSolicitud(messageForCode('PARCEL_DESCRIPTION_LENGTH'));
        return;
      }
      if (cargoItems.length === 0) {
        setErrorSolicitud(messageForCode('PARCEL_NEEDS_CARGO'));
        return;
      }
    }

    setEnviando(true);
    setErrorSolicitud(null);

    /**
     * "Tu ubicacion actual" NO puede viajar al conductor.
     *
     * Ese texto esta escrito desde el punto de vista del pasajero, y era lo que
     * se guardaba como nombre del punto de recogida. El conductor abria su
     * pantalla y leia "RECOGER EN: Tu ubicacion actual", que no le dice nada:
     * ni una direccion, ni una referencia, ni un barrio. Lo vio el usuario en la
     * tablet.
     *
     * Se resuelve con `describePoint`, el mismo criterio que usa elegir un punto
     * en el mapa (D127): el nombre del lugar si esta encima de uno, "Cerca de X"
     * si esta a media distancia, y la direccion de Mapbox en los demas casos.
     *
     * Cuesta una llamada de red antes de crear la solicitud, y se paga a
     * proposito: el conductor va a conducir hasta ese punto. Si la red falla se
     * envia un texto que al menos es honesto y lo manda al mapa, que si trae la
     * coordenada exacta.
     */
    let origenLabel = origin?.label ?? null;

    if (origenLabel === null) {
      const descripcion = await describePoint(
        { latitude: origenLat, longitude: origenLng },
        places,
      );
      origenLabel = descripcion.label ?? 'Punto compartido por el pasajero';
    }

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
      passengerCount: pasajerosEfectivos,
      pickupReference,
      serviceType,
      parcelDescription: serviceType === 'parcel' ? parcelDescription : null,
      cargo: cargoItems,
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
      // La que se acaba de enviar. El servidor la habria devuelto ya recortada,
      // pero esta rama existe justo porque no se pudo preguntar.
      referencia: pickupReference.trim() === '' ? null : pickupReference.trim(),
      origen: { latitude: origenLat, longitude: origenLng },
      destino: { latitude: destination.latitude, longitude: destination.longitude },
      destinoLabel: destination.label,
      pasajeros: pasajerosEfectivos,
      segundosRestantes: null,
      // Acaba de crearse, asi que por fuerza no hay conductor todavia.
      conductor: null,
      tipoServicio: serviceType,
      descripcionEncomienda: serviceType === 'parcel' ? parcelDescription.trim() : null,
      // El valor real lo tiene el servidor, congelado en la fila que se acaba
      // de insertar. Esta rama existe justo porque no se pudo releer esa fila,
      // asi que aqui no hay nada honesto que ensenar: se deja en null y la
      // pantalla de espera no pinta el precio, en lugar de inventarselo.
      tarifa: null,
    });
  }, [
    destination,
    origin,
    origenLat,
    origenLng,
    pasajerosEfectivos,
    pickupReference,
    places,
    serviceType,
    parcelDescription,
    cargoItems,
  ]);

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

    // El servidor dice que no queda ninguna viva. Antes de dar nada por
    // caducado hay que preguntar por lo contrario: que haya TERMINADO.
    //
    // Sin esta pregunta, el pasajero que acaba de bajarse del motocarro veia su
    // cuenta atras en cero y, debajo, "Volver a pedirlo" y "Cambiar el viaje",
    // como si nadie lo hubiera recogido. Es el mismo dato leido al reves.
    const terminada = await fetchFinishedRequest();

    if (turno !== sincronizacion.current) return;

    if (terminada.ok && terminada.data !== null) {
      setSolicitud(null);
      setResumenFinal(terminada.data);
      // El viaje elegido se limpia aqui y no antes: hasta este momento seguia
      // siendo el viaje en curso, y borrarlo habria dejado la pantalla sin saber
      // de donde a donde iba.
      limpiarBorrador();
      return;
    }

    // Tampoco termino: puede que el conductor haya cancelado con el pasajero
    // a bordo (D187). NO se limpia el borrador aqui, a diferencia de arriba: el
    // pasajero seguia queriendo llegar a ese destino, y perderlo lo obligaria a
    // escribirlo otra vez justo despues de que le cancelaran el servicio.
    const cancelada = await fetchDriverCancelledNotice();

    if (turno !== sincronizacion.current) return;

    if (cancelada.ok && cancelada.data !== null) {
      setSolicitud(null);
      setAvisoCancelacion(cancelada.data);
      return;
    }

    // No termino, no la cancelo el conductor y no esta viva: se acabo el
    // tiempo. Se deja en cero para que el pasajero lo vea, en lugar de
    // encontrarse el mapa limpio sin explicacion.
    setSolicitud((actual) => (actual === null ? null : { ...actual, segundosRestantes: 0 }));
  }, [limpiarBorrador]);

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

  /**
   * Y ademas, en cuanto el servidor tenga algo que contar.
   *
   * Solo se escucha mientras hay una solicitud viva: sin ella no hay nada que
   * pueda cambiar, y un canal abierto de mas es una conexion abierta de mas en el
   * telefono de alguien.
   */
  useRequestRealtime(solicitud !== null, sincronizarSolicitud, 'pasajero-su-solicitud');

  /**
   * Y del viaje concreto, que es donde viven las transiciones del conductor.
   *
   * Las dos suscripciones se solapan a proposito en dos de los cuatro estados:
   * iniciar y finalizar tocan las dos tablas, asi que llegan por los dos canales
   * y se relee dos veces. Es una lectura de mas en dos momentos de todo el
   * servicio, y a cambio no hay que decidir en el cliente que evento ignorar.
   */
  useRideRealtime(solicitud?.conductor?.rideId ?? null, sincronizarSolicitud);

  /**
   * Donde esta su motocarro, mientras haya uno asignado.
   *
   * Antes de que alguien acepte no hay a quien seguir, y el hook se queda quieto:
   * un canal abierto de mas es una conexion abierta de mas en el telefono de
   * alguien, con el mismo criterio que se aplico al de la solicitud.
   */
  const posicionConductor = useDriverLocation(solicitud?.conductor?.id ?? null);

  /**
   * A partir de cuantos segundos una posicion deja de ser de fiar.
   *
   * Es el mismo parametro con el que el servidor descarta a un conductor sin
   * cobertura (R10). Si la empresa lo cambia, las dos cosas se mueven juntas, que
   * es justo lo que evita que la pantalla diga que un motocarro viene mientras
   * el buscador ya lo da por desconectado.
   */
  // Solo sirve cuando hay un motocarro asignado a quien seguir. Hasta entonces
  // no se lee: es otra llamada fuera del primer pintado (Fase 24 paso 4).
  const segundosParaCaducar = useNumericSetting(
    'driver_location_stale_seconds',
    120,
    solicitud?.conductor != null,
  );
  const posicionCaducada =
    posicionConductor !== null && posicionConductor.ageSeconds > segundosParaCaducar;

  /**
   * Cuanto falta para que llegue a recogerlo.
   *
   * No se recalcula en cada posicion recibida. El conductor manda una cada diez
   * segundos (R9), asi que serian seis peticiones a Mapbox por minuto y por
   * servicio para afinar un numero que se ensena redondeado a minutos. Se
   * recalcula como mucho cada medio minuto, y entre medias el numero se queda
   * quieto: preferimos un minuto que se sostiene dos ciclos a una cifra que
   * parpadea y que nadie ha pedido.
   */
  const [llegada, setLlegada] = useState<RouteEstimate | null>(null);

  /**
   * Cuando se calculo por ultima vez, y para que conductor.
   *
   * Lleva el conductor dentro y no solo la hora porque si no la espera de medio
   * minuto se heredaria: al pasajero al que le acaban de asignar otro motocarro
   * le tocaria esperar a que venciera el turno del anterior para ver su primer
   * tiempo de llegada.
   */
  const ultimoCalculoLlegada = useRef<{ conductor: string | null; cuando: number }>({
    conductor: null,
    cuando: 0,
  });

  const conductorLat = posicionConductor?.latitude ?? null;
  const conductorLng = posicionConductor?.longitude ?? null;

  /**
   * Hacia donde se mide el tiempo que falta, que cambia a mitad del servicio.
   *
   * Mientras viene a recogerlo, al punto de recogida. Con el pasajero ya dentro,
   * al destino: seguir midiendo hasta la recogida seria contar los minutos que
   * faltan para llegar al sitio del que acaba de salir, y el numero encima
   * bajaria hasta cero y se quedaria ahi.
   */
  const enRecorrido = solicitud?.conductor?.rideStatus === 'in_progress';
  const recogidaLat = enRecorrido
    ? (solicitud?.destino.latitude ?? null)
    : (solicitud?.origen.latitude ?? null);
  const recogidaLng = enRecorrido
    ? (solicitud?.destino.longitude ?? null)
    : (solicitud?.origen.longitude ?? null);

  /**
   * Cambiar de conductor caduca el tiempo de llegada del anterior.
   *
   * Se ajusta en el render, con el mismo patron que la ruta y el modo de la
   * hoja: es la forma que React documenta para corregir estado cuando cambia una
   * entrada, y la unica que no deja un fotograma diciendo cuanto tarda un
   * motocarro que ya no viene.
   */
  const claveLlegada = solicitud?.conductor?.id ?? null;
  const [claveLlegadaAnterior, setClaveLlegadaAnterior] = useState(claveLlegada);

  /**
   * El conductor que tenia desaparecio y la solicitud sigue viva (Fase 18).
   *
   * Solo puede pasar por una razon: cancelo antes de recogerlo, y
   * `cancel_ride` devolvio la solicitud a 'searching' para reofrecerla (D187,
   * rama contraria a `avisoCancelacion`). No hace falta preguntarle nada al
   * servidor: el propio cambio de `claveLlegada` de no-nulo a nulo, con
   * `solicitud` todavia viva, ES el aviso.
   *
   * Se apaga solo en cuanto vuelva a haber conductor, o al salir de
   * 'buscando': sin eso, un servicio nuevo heredaria el aviso del anterior.
   */
  const [conductorCancelo, setConductorCancelo] = useState(false);

  if (claveLlegada !== claveLlegadaAnterior) {
    setClaveLlegadaAnterior(claveLlegada);
    setLlegada(null);
    setConductorCancelo(
      claveLlegadaAnterior !== null && claveLlegada === null && solicitud !== null,
    );
  } else if (solicitud === null && conductorCancelo) {
    setConductorCancelo(false);
  }

  useEffect(() => {
    if (
      conductorLat === null ||
      conductorLng === null ||
      recogidaLat === null ||
      recogidaLng === null
    ) {
      return;
    }

    const ahora = Date.now();
    const previo = ultimoCalculoLlegada.current;

    if (previo.conductor === claveLlegada && ahora - previo.cuando < ESPERA_ENTRE_LLEGADAS_MS) {
      return;
    }

    ultimoCalculoLlegada.current = { conductor: claveLlegada, cuando: ahora };

    let vigente = true;

    const id = setTimeout(() => {
      void (async () => {
        const resultado = await fetchRoute(
          { latitude: conductorLat, longitude: conductorLng },
          { latitude: recogidaLat, longitude: recogidaLng },
        );
        if (!vigente) return;
        setLlegada(resultado.ok && resultado.route !== null ? resultado.route : null);
      })();
    }, 0);

    return () => {
      vigente = false;
      clearTimeout(id);
    };
  }, [claveLlegada, conductorLat, conductorLng, recogidaLat, recogidaLng]);

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

  /**
   * Encuadra la ruta entera en cuanto se puede dibujar.
   *
   * Sin esto, el mapa se queda donde estaba y el viaje puede quedar entero fuera
   * de pantalla: dibujar una ruta que no se ve es lo mismo que no dibujarla.
   *
   * El margen inferior es medio alto de pantalla y no un numero fijo, porque lo
   * que hay ahi abajo es la hoja, y la hoja mide distinto en cada teléfono.
   * Encuadrar contra la pantalla completa dejaria media ruta debajo del panel.
   *
   * Marca la camara como ya movida a proposito. El centrado en la ubicacion del
   * pasajero ocurre una sola vez y puede llegar tarde, cuando el GPS por fin
   * responde: sin esta marca, aparecia el viaje encuadrado y un segundo despues
   * la camara saltaba sola al punto azul.
   */
  useEffect(() => {
    if (!isMapReady || ruta === null) return;
    const map = mapRef.current;
    if (map === null) return;

    hasCentered.current = true;

    map.fitToCoordinates(ruta.coordinates, {
      edgePadding: {
        top: insets.top + spacing.xxl,
        right: spacing.xxl,
        bottom: Math.round(screenHeight * 0.5),
        left: spacing.xxl,
      },
      animated: true,
    });
  }, [isMapReady, ruta, insets.top, screenHeight]);

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

  /**
   * El viaje, dibujado.
   *
   * Lo pidio el usuario durante la Fase 13, al ver que el conductor si tenia su
   * ruta y el no. Es el mismo trazado y el mismo color de marca que ve el
   * conductor, para que los dos esten mirando lo mismo.
   *
   * Los extremos se toman de la propia ruta y no de las coordenadas pedidas, que
   * es lo que hace la pantalla del conductor. Mapbox devuelve la ruta pegada a
   * la via, asi que su primer punto es donde el motocarro puede parar de
   * verdad; la coordenada cruda puede caer dentro de una manzana.
   */
  const trazado: MapRoute[] =
    ruta === null ? [] : [{ coordinates: ruta.coordinates, color: colors.brand, width: 5 }];

  const marcas: MapMarker[] = [];

  if (ruta !== null) {
    const primero = ruta.coordinates[0];
    const ultimo = ruta.coordinates[ruta.coordinates.length - 1];

    if (primero !== undefined) {
      marcas.push({ coordinate: primero, color: colors.brand, filled: false });
    }
    if (ultimo !== undefined) {
      marcas.push({ coordinate: ultimo, color: colors.brand, filled: true });
    }
  }

  return (
    <View style={[styles.root, { backgroundColor: colors.surfaceSubtle }]}>
      <Map
        ref={mapRef}
        initialRegion={AMALFI_REGION}
        userCoords={coords}
        routes={trazado}
        markers={marcas}
        vehicle={
          posicionConductor === null
            ? null
            : {
                coordinate: {
                  latitude: posicionConductor.latitude,
                  longitude: posicionConductor.longitude,
                },
                stale: posicionCaducada,
              }
        }
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
        //   Destino/Buscando -> una fraccion, porque la lista de lugares no
        //                tiene un alto natural: cuantos se vean es una decision
        //                de diseno, no del contenido.
        //   Resumen   -> 'content' con `scroll`: la hoja mide justo lo que ocupa
        //                la tarjeta y el boton de confirmar, y el resto es mapa
        //                con la ruta a la vista. En reposo se pliega solo hasta
        //                el boton, no hasta el borde. (Se probo con `0,8` fijo y
        //                el usuario lo rechazo: o tapaba media pantalla o se
        //                escondia, sin punto medio.) El `mapa asomando por
        //                debajo` que se veia al volver del selector de "Cambiar"
        //                NO era la medida: era el mapa dibujandose sobre la hoja
        //                con GLSurfaceView; se arreglo pasando el `MapView` a
        //                TextureView (`018f829`). `scroll` cubre el unico caso
        //                que 'content' no puede: un resumen mas alto que el 85 %
        //                de un telefono (carga + direcciones largas + error).
        //   El resto  -> 'content'; son cortos y estables, sin scroll.
        snapPoints={modo === 'destino' ? [PEEK, 0.3, 0.72] : [PEEK, 'content']}
        scroll={modo === 'resumen'}
        index={sheetIndex}
        onIndexChange={setSheetIndex}
        header={
          modo === 'destino' || modo === 'cargando' ? (
            <Text variant="subheading">Hola, {user?.fullName ?? 'pasajero'}</Text>
          ) : modo === 'resumen' ? (
            // Descartar el viaje lo descarta ENTERO, origen incluido. Antes solo
            // borraba el destino, asi que un origen elegido a mano se quedaba
            // pegado al siguiente viaje y al siguiente: el pasajero pedia "desde
            // cero" y salia recogiendolo donde estuvo una vez.
            <CabeceraDelViaje onCancelar={limpiarBorrador} />
          ) : (
            // Sin aspa aqui. Descartar un viaje elegido y cancelar uno ya
            // solicitado no son la misma accion, y la segunda no puede quedar a
            // un toque descuidado: tiene su propio boton, con su nombre escrito.
            // El titulo tiene que contar lo mismo que la tarjeta de abajo. Con
            // un conductor ya asignado, "Buscando motocarro" contradecia a
            // "Tu motocarro va en camino" a dos centimetros de distancia.
            <Text variant="subheading">
              {modo === 'terminado'
                ? 'Llegaste'
                : modo === 'cancelado_conductor'
                  ? 'Servicio cancelado'
                  : solicitud?.conductor != null
                    ? tituloDelViaje(solicitud.conductor.rideStatus)
                    : expirada
                      ? 'Nadie tomó tu servicio'
                      : 'Buscando motocarro'}
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
            referencia={pickupReference}
            ruta={ruta}
            estimando={estimando}
            enviando={enviando}
            error={errorSolicitud}
            onCambiarReferencia={setPickupReference}
            onCambiarPasajeros={setPassengerCount}
            onEditarOrigen={() =>
              router.push({ pathname: '/passenger/destination', params: { for: 'origin' } })
            }
            onEditarDestino={abrirBuscador}
            onConfirmar={() => void confirmar()}
            tipoServicio={serviceType}
            onCambiarTipoServicio={setServiceType}
            descripcionEncomienda={parcelDescription}
            onCambiarDescripcionEncomienda={setParcelDescription}
            tiposDeCarga={cargoTypes}
            cargandoTiposDeCarga={cargandoTiposDeCarga}
            errorTiposDeCarga={errorTiposDeCarga}
            onReintentarTiposDeCarga={reintentarTiposDeCarga}
            carga={cargoItems}
            onCambiarCantidadDeCarga={setCargoItemQuantity}
            tarifa={tarifa.quote}
            calculandoTarifa={tarifa.loading}
            errorTarifa={tarifa.error}
            tarifaPendiente={tarifa.pending}
          />
        )}

        {modo === 'terminado' && resumenFinal !== null && (
          <ViajeTerminado resumen={resumenFinal} onCerrar={() => setResumenFinal(null)} />
        )}

        {modo === 'cancelado_conductor' && avisoCancelacion !== null && (
          <ServicioCanceladoPorConductor
            aviso={avisoCancelacion}
            onCerrar={() => setAvisoCancelacion(null)}
          />
        )}

        {modo === 'buscando' && solicitud !== null && (
          <BuscandoConductor
            solicitud={solicitud}
            segundosRestantes={segundosRestantes}
            expirada={expirada}
            cancelando={cancelando}
            reintentando={enviando}
            llegada={llegada}
            enRecorrido={enRecorrido}
            yaLlego={solicitud.conductor?.rideStatus === 'driver_arrived'}
            posicionCaducada={posicionCaducada}
            sinPosicion={solicitud.conductor !== null && posicionConductor === null}
            conductorCancelo={conductorCancelo}
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

/** Las seis caras de la hoja del pasajero. */
type ModoHoja =
  'cargando' | 'destino' | 'resumen' | 'buscando' | 'terminado' | 'cancelado_conductor';

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
  /** Lo que escribio para que lo encuentren. Nulo si no escribio nada. */
  referencia: string | null;
  /**
   * Las coordenadas de los dos extremos, ademas de sus nombres.
   *
   * Hacen falta para dibujar la ruta. Se guardan aqui y no se leen del borrador
   * porque el borrador esta vacio al reabrir la aplicacion (D137), que es
   * justamente cuando esta pantalla tiene que reconstruirse sola.
   */
  origen: { latitude: number; longitude: number };
  destino: { latitude: number; longitude: number };
  destinoLabel: string;
  pasajeros: number;
  /** Nulo cuando no se pudo leer del servidor: entonces no se pinta cuenta atras. */
  segundosRestantes: number | null;
  /** Quien viene a recogerlo. Nulo mientras nadie ha aceptado. */
  conductor: AssignedDriver | null;
  /** Pasajero solo o con carga, contra encomienda sola. */
  tipoServicio: ServiceType;
  /** Que es la encomienda. Nulo en un viaje de pasajeros. */
  descripcionEncomienda: string | null;
  /**
   * El valor ya congelado del servicio. Nulo en las solicitudes de antes de
   * D217, y tambien en la rama de `confirmar` que no pudo releer del servidor
   * justo despues de crear: en ese caso no hay nada honesto que mostrar, y es
   * mejor no pintar precio que inventarlo.
   */
  tarifa: RequestFare | null;
}

/** Traduce lo que devuelve el servidor a lo que pinta el panel. */
function aSolicitudEnCurso(activa: ActiveRequest): SolicitudEnCurso {
  return {
    id: activa.id,
    origenLabel: activa.origin.label,
    referencia: activa.pickupReference,
    origen: { latitude: activa.origin.latitude, longitude: activa.origin.longitude },
    destino: { latitude: activa.destination.latitude, longitude: activa.destination.longitude },
    destinoLabel: activa.destination.label,
    pasajeros: activa.passengerCount,
    segundosRestantes: activa.secondsRemaining,
    conductor: activa.driver,
    tipoServicio: activa.serviceType,
    descripcionEncomienda: activa.parcelDescription,
    tarifa: activa.fare,
  };
}

/**
 * Como se llama cada estado del viaje para el pasajero.
 *
 * Se distingue "aceptó" de "va en camino" a proposito, aunque para el pasajero
 * las dos signifiquen esperar. Son momentos distintos: en la primera el
 * conductor se comprometio pero puede no haber arrancado, y en la segunda ya
 * viene. Juntarlas obligaria a decir "va en camino" antes de que sea cierto, que
 * es la clase de mentira pequeña que hace que la gente deje de creerle a la
 * pantalla.
 */
function tituloDelViaje(status: RideStatus): string {
  switch (status) {
    case 'driver_arrived':
      return 'Tu motocarro llegó';
    case 'in_progress':
      return 'Vas en camino';
    default:
      return 'Servicio confirmado';
  }
}

/** La linea grande de la tarjeta, en las palabras del pasajero. */
function mensajeDelViaje(status: RideStatus): string {
  switch (status) {
    case 'assigned':
      return 'Un motocarro tomó tu servicio';
    case 'driver_on_the_way':
      return 'Tu motocarro va en camino';
    case 'driver_arrived':
      return 'Tu motocarro está esperándote';
    case 'in_progress':
      return 'Vas camino a tu destino';
    default:
      return 'Tu motocarro va en camino';
  }
}

/** Cuantos lugares caben en la hoja sin obligar a desplegarla. */
const ATAJOS_VISIBLES = 4;

/**
 * Cada cuanto se vuelve a preguntar cuanto falta para que llegue.
 *
 * Medio minuto. El tiempo se ensena en minutos, asi que recalcularlo mas seguido
 * gasta peticiones para cambiar un numero que casi nunca cambia.
 */
const ESPERA_ENTRE_LLEGADAS_MS = 30_000;

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
  referencia: string;
  ruta: Route | null;
  estimando: boolean;
  enviando: boolean;
  error: string | null;
  onCambiarReferencia: (valor: string) => void;
  onCambiarPasajeros: (valor: number) => void;
  onEditarOrigen: () => void;
  onEditarDestino: () => void;
  onConfirmar: () => void;
  // El bloque especial: tipo de servicio, encomienda y carga.
  tipoServicio: ServiceType;
  onCambiarTipoServicio: (valor: ServiceType) => void;
  descripcionEncomienda: string;
  onCambiarDescripcionEncomienda: (valor: string) => void;
  tiposDeCarga: CargoType[];
  cargandoTiposDeCarga: boolean;
  errorTiposDeCarga: string | null;
  onReintentarTiposDeCarga: () => void;
  carga: CargoItem[];
  onCambiarCantidadDeCarga: (cargoTypeId: string, cantidad: number) => void;
  tarifa: FareQuote | null;
  calculandoTarifa: boolean;
  errorTarifa: string | null;
  tarifaPendiente: FareQuotePending | null;
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
  referencia,
  ruta,
  estimando,
  enviando,
  error,
  onCambiarReferencia,
  onCambiarPasajeros,
  onEditarOrigen,
  onEditarDestino,
  onConfirmar,
  tipoServicio,
  onCambiarTipoServicio,
  descripcionEncomienda,
  onCambiarDescripcionEncomienda,
  tiposDeCarga,
  cargandoTiposDeCarga,
  errorTiposDeCarga,
  onReintentarTiposDeCarga,
  carga,
  onCambiarCantidadDeCarga,
  tarifa,
  calculandoTarifa,
  errorTarifa,
  tarifaPendiente,
}: ResumenDelViajeProps) {
  const { colors } = useTheme();
  const esEncomienda = tipoServicio === 'parcel';

  /**
   * El selector de carga es un dialogo propio, y vive aqui y no en la pantalla
   * que contiene a esta: mismo criterio que la confirmacion de cancelar de
   * `BuscandoConductor`, mas abajo en este archivo. Solo esta pantalla necesita
   * saber si esta abierto.
   */
  const [selectorDeCargaVisible, setSelectorDeCargaVisible] = useState(false);

  return (
    <>
      <ServiceTypeToggle value={tipoServicio} onChange={onCambiarTipoServicio} />

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

        {/* Va pegado al punto de recogida, sin linea que los separe, porque es
            parte de el: el punto dice el sitio y esto dice donde esperar dentro
            del sitio.

            Sin etiqueta encima. El texto de ejemplo ya explica que se espera, y
            una etiqueta anadiria una linea a una hoja donde cada pixel se le
            quita al mapa. Que sea opcional se dice ahi mismo, no en una linea de
            ayuda aparte. */}
        <Input
          value={referencia}
          onChangeText={onCambiarReferencia}
          placeholder="Referencia para encontrarte (opcional)"
          // El servidor rechaza mas de 80 (PICKUP_REFERENCE_TOO_LONG). Cortar
          // aqui evita que alguien escriba un parrafo y lo pierda al confirmar,
          // pero la regla sigue siendo la del servidor: esto es comodidad, no
          // validacion.
          maxLength={80}
          // Una referencia es una frase corta, no un nombre propio ni un
          // correo. Sin mayuscula automatica al empezar y sin corrector, que en
          // nombres de tiendas y apodos locales acierta poco.
          autoCapitalize="sentences"
          autoCorrect={false}
          returnKeyType="done"
          style={styles.campoReferencia}
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

        {/* Pasajero contra encomienda cambian que se pide aqui debajo, no solo
            un texto: uno pide cuantos van, el otro pide que es lo que se
            manda. Los dos casos no se confunden (D224). */}
        {esEncomienda ? (
          <Input
            value={descripcionEncomienda}
            onChangeText={onCambiarDescripcionEncomienda}
            placeholder="Qué es la encomienda (ej. Caja con documentos)"
            maxLength={120}
            autoCapitalize="sentences"
            autoCorrect={false}
            returnKeyType="done"
          />
        ) : (
          <PassengerCount value={pasajeros} onChange={onCambiarPasajeros} max={maxPasajeros} />
        )}

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <ChosenCargoList
          cargoTypes={tiposDeCarga}
          items={carga}
          onOpenPicker={() => setSelectorDeCargaVisible(true)}
          onRemove={(cargoTypeId) => onCambiarCantidadDeCarga(cargoTypeId, 0)}
          required={esEncomienda}
        />

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <FareRow
          quote={tarifa}
          loading={calculandoTarifa}
          error={errorTarifa}
          pending={tarifaPendiente}
        />

        {/* La estimacion solo ocupa sitio cuando existe. Si Mapbox no responde
            no se pinta nada, en lugar de ensenar un numero fabricado (D149). */}
        {(estimando || ruta !== null) && (
          <>
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />
            <View style={styles.filaEstimacion}>
              <RouteIcon
                size={iconSize.sm}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              {ruta !== null ? (
                <Text variant="caption" color="textSecondary">
                  {formatDistance(ruta.meters)} · {formatDuration(ruta.seconds)} aproximadamente
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
        // D217: el pasajero tiene que VER el valor antes de confirmar, no solo
        // poder confirmar mientras se calcula. Mientras no hay un numero valido
        // -cargando, sin cotizar todavia, o rechazado por el servidor, como una
        // encomienda sin carga o un destino sin tarifa- el boton espera. La
        // misma llamada que hace esta fila es la que hara `request_ride`, asi
        // que si aqui no hay precio, confirmar tampoco lo tendria.
        disabled={calculandoTarifa || tarifa === null || errorTarifa !== null}
        onPress={onConfirmar}
      />

      <CargoPicker
        visible={selectorDeCargaVisible}
        onRequestClose={() => setSelectorDeCargaVisible(false)}
        cargoTypes={tiposDeCarga}
        loading={cargandoTiposDeCarga}
        error={errorTiposDeCarga}
        onRetry={onReintentarTiposDeCarga}
        items={carga}
        onChangeQuantity={onCambiarCantidadDeCarga}
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
  /** Cuanto falta para llegar. Nulo si no se pudo calcular. */
  llegada: RouteEstimate | null;
  /** El pasajero ya va dentro, asi que el tiempo es hasta su destino. */
  enRecorrido: boolean;
  /** El motocarro ya esta en el punto de recogida, esperando. */
  yaLlego: boolean;
  /** Su ultima posicion es demasiado vieja para fiarse. */
  posicionCaducada: boolean;
  /** Hay conductor pero todavia no ha llegado ninguna posicion suya. */
  sinPosicion: boolean;
  /** El conductor que tenia cancelo antes de recogerlo y se busca otro (Fase 18, D187). */
  conductorCancelo: boolean;
  error: string | null;
  onCancelar: () => void;
  onReintentar: () => void;
  onCambiarViaje: () => void;
}

/**
 * La solicitud ya esta enviada: se busca quien la tome, ya viene alguien, o se
 * acabo el tiempo.
 *
 * Es el primer estado de la aplicacion en el que existe algo en el servidor, asi
 * que la salida no puede ser un aspa discreta: cancelar aqui deshace un servicio
 * pedido, no una eleccion. Va como boton con su nombre completo.
 *
 * Cuando expira cambian las tres cosas a la vez, y a proposito: el texto, el
 * icono y los botones. Dejar el mismo panel con un "0:00" seria pedirle al
 * pasajero que dedujera el, de un numero, que ya no va a venir nadie.
 *
 * DESDE LA FASE 13 HAY UN TERCER ESTADO, y llega solo por tiempo real: alguien
 * acepto. Se distingue tanto como la expiracion, porque es la noticia que el
 * pasajero esta esperando desde que pidio el servicio. Antes de esto la pantalla
 * seguia diciendo "avisando a los motocarros cercanos" con el motocarro ya en
 * camino.
 */
function BuscandoConductor({
  solicitud,
  segundosRestantes,
  expirada,
  cancelando,
  reintentando,
  llegada,
  enRecorrido,
  yaLlego,
  posicionCaducada,
  sinPosicion,
  conductorCancelo,
  error,
  onCancelar,
  onReintentar,
  onCambiarViaje,
}: BuscandoConductorProps) {
  const { colors } = useTheme();
  const conductor = solicitud.conductor;

  /**
   * El detalle de la carga, si lleva. `SolicitudEnCurso` no la trae porque
   * `get_active_request` devuelve como mucho una fila y un servicio puede
   * llevar varias cargas (ver el comentario de la migracion que extendio esa
   * funcion). Se relee aparte, una vez por cada solicitud distinta.
   */
  const [cargaDelServicio, setCargaDelServicio] = useState<RequestCargoLine[]>([]);

  useEffect(() => {
    let vigente = true;

    // Diferido, mismo motivo de siempre: el compilador de React rechaza un
    // setState alcanzable sincronamente desde un efecto.
    const id = setTimeout(() => {
      void fetchRequestCargo(solicitud.id).then((resultado) => {
        if (!vigente) return;
        if (resultado.ok) {
          setCargaDelServicio(resultado.data);
        }
      });
    }, 0);

    return () => {
      vigente = false;
      clearTimeout(id);
    };
  }, [solicitud.id]);

  /**
   * Confirmacion antes de cancelar (Fase 18).
   *
   * Antes se cancelaba al primer toque. Es la unica accion irreversible de
   * este panel: deshace un servicio pedido, y con conductor ya asignado le
   * avisa a una persona real que iba de camino.
   */
  const [confirmando, setConfirmando] = useState(false);

  return (
    <>
      {conductorCancelo && conductor === null && !expirada && (
        <View style={[styles.avisoConductorCancelo, { backgroundColor: colors.surfaceSubtle }]}>
          <Info size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <Text variant="caption" color="textSecondary" style={styles.avisoConductorCanceloTexto}>
            Tu conductor anterior canceló. Seguimos buscando otro.
          </Text>
        </View>
      )}

      <Card
        variant="outlined"
        padding="md"
        style={conductor === null ? undefined : { borderColor: colors.brand, borderWidth: 1 }}
      >
        <View style={styles.filaBuscando}>
          {conductor !== null ? (
            <BikeIcon size={iconSize.md} color={colors.brand} strokeWidth={iconStrokeWidth} />
          ) : expirada ? (
            <Clock size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          ) : (
            <ActivityIndicator color={colors.brand} />
          )}
          <View style={styles.filaLugarTextos}>
            <Text variant="bodyStrong">
              {conductor !== null
                ? mensajeDelViaje(conductor.rideStatus)
                : expirada
                  ? 'Ningún motocarro tomó el servicio'
                  : 'Avisando a los motocarros cercanos'}
            </Text>
            <Text variant="caption" color="textSecondary">
              {conductor !== null
                ? `Motocarro ${conductor.vehicle.unitNumber} · Placa ${conductor.vehicle.plate}`
                : expirada
                  ? 'Puedes volver a pedirlo o cambiar el viaje.'
                  : 'Te avisamos en cuanto uno acepte.'}
            </Text>
          </View>
          {/* El tiempo solo se ensena mientras corre y solo si el servidor lo
              dijo. Sin dato no se pinta nada: un contador inventado sobre el
              reloj del telefono seria peor que no tener contador. Con conductor
              asignado deja de tener sentido: ya no hay nada que esperar. */}
          {conductor === null && !expirada && segundosRestantes !== null && (
            <Text variant="bodyStrong" color="textSecondary" style={styles.numeroQueCambia}>
              {formatCountdown(segundosRestantes)}
            </Text>
          )}
        </View>

        {/* Que es y cuanto vale, mientras se espera. `solicitud.tarifa` es nulo
            en las solicitudes de antes de D217 y en la rama de `confirmar` que
            no pudo releer del servidor: en los dos casos no hay nada honesto
            que ensenar, y la fila simplemente no aparece. */}
        {(solicitud.tipoServicio === 'parcel' || solicitud.tarifa !== null) && (
          <>
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />
            <View style={styles.filaBuscando}>
              <Package
                size={iconSize.sm}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              <View style={styles.filaLugarTextos}>
                {solicitud.tipoServicio === 'parcel' &&
                  solicitud.descripcionEncomienda !== null && (
                    <Text variant="body">{solicitud.descripcionEncomienda}</Text>
                  )}
                {solicitud.tarifa !== null && (
                  <Text variant="caption" color="textSecondary">
                    {formatAmount(solicitud.tarifa.amount)}
                    {solicitud.tarifa.reference !== null
                      ? ` · Tarifa de ${solicitud.tarifa.reference}`
                      : ''}
                  </Text>
                )}
                {cargaDelServicio.length > 0 && (
                  <Text variant="caption" color="textTertiary">
                    {cargaDelServicio
                      .map((linea) =>
                        linea.quantity > 1
                          ? `${linea.cargoTypeName} ×${linea.quantity}`
                          : linea.cargoTypeName,
                      )
                      .join(', ')}
                  </Text>
                )}
              </View>
            </View>
          </>
        )}

        {conductor !== null && (
          <>
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

            <View style={styles.filaBuscando}>
              <View style={styles.filaLugarTextos}>
                <Text variant="subheading">{conductor.name}</Text>
                <View style={styles.notaConductor}>
                  <Star size={iconSize.sm} color={colors.warning} strokeWidth={iconStrokeWidth} />
                  {/* Un conductor sin calificaciones no tiene un cero, tiene una
                      hoja en blanco. Pintarle un 0,0 al pasajero le atribuiria
                      un mal servicio que nadie ha dado. */}
                  <Text variant="caption" color="textSecondary">
                    {conductor.rating === null
                      ? 'Sin calificaciones todavía'
                      : conductor.rating.toFixed(1).replace('.', ',')}
                  </Text>
                </View>
              </View>
            </View>

            {/* Cuanto falta, y de cuando es ese dato.

                Los cuatro casos se distinguen a proposito. "Sin senal" y "llega
                en cuatro minutos" no se parecen en nada para quien espera en la
                calle: en el primero el motocarro del mapa puede llevar dos
                minutos donde ya no esta, y callarlo seria ensenarle una posicion
                falsa sin decirselo. Y "en camino" sin numero es honesto cuando
                la posicion es buena pero no se pudo calcular la ruta, que es el
                mismo criterio de D149 aplicado aqui. */}
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

            <View style={styles.filaEstimacion}>
              {posicionCaducada ? (
                <WifiOff
                  size={iconSize.sm}
                  color={colors.textSecondary}
                  strokeWidth={iconStrokeWidth}
                />
              ) : (
                <Navigation
                  size={iconSize.sm}
                  color={colors.textTertiary}
                  strokeWidth={iconStrokeWidth}
                />
              )}
              <Text variant="caption" color={posicionCaducada ? 'textSecondary' : 'textSecondary'}>
                {posicionCaducada
                  ? enRecorrido
                    ? 'Perdimos la señal del motocarro. El viaje sigue.'
                    : yaLlego
                      ? 'Perdimos su señal, pero ya está en el punto de recogida.'
                      : 'Perdimos su señal. El motocarro sigue en camino.'
                  : sinPosicion
                    ? 'Ubicando su motocarro'
                    : yaLlego
                      ? // Con el motocarro parado en el punto, los minutos que
                        // faltan son cero y repetirlo no aporta nada. Lo que hay
                        // que decir es que salga.
                        'Te está esperando en el punto de recogida'
                      : llegada !== null
                        ? enRecorrido
                          ? `Llegas en ${formatDuration(llegada.seconds)} aproximadamente`
                          : `Llega en ${formatDuration(llegada.seconds)} aproximadamente`
                        : enRecorrido
                          ? 'Vas camino a tu destino'
                          : 'Va en camino hacia ti'}
              </Text>
            </View>

            {/* Boton y no texto, por lo mismo que en la tarjeta del conductor:
                se usa con una mano, a veces en la calle, y copiar diez digitos a
                mano es la friccion que hace que la gente termine llamando por
                otro lado. */}
            <Button
              label="Llamar al conductor"
              variant="secondary"
              icon={Phone}
              fullWidth
              style={styles.llamarConductor}
              onPress={() => void Linking.openURL(`tel:${conductor.phone}`)}
            />
          </>
        )}

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <View style={styles.puntoViaje}>
          <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {solicitud.origenLabel}
            </Text>
            {/* Se le devuelve lo que escribio, ya pasado por el servidor. No es
                informacion nueva para el, pero es la unica forma de que
                compruebe que la referencia que dio es la que le llego al
                conductor, y de que la recuerde al reabrir la aplicacion sobre un
                servicio en curso. */}
            {solicitud.referencia !== null && (
              <Text variant="caption" color="textSecondary" numberOfLines={2}>
                {solicitud.referencia}
              </Text>
            )}
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
        // Sin boton en 'in_progress': el servidor ya no admite cancelar desde
        // aqui (INVALID_STATE_TRANSITION) porque el pasajero va a bordo, y
        // ofrecer un boton que siempre falla es peor que no ofrecerlo. Antes
        // se veia igual en los cinco estados; lo encontro el usuario mirando
        // la pantalla (seccion 15.15).
        !enRecorrido && (
          <Button
            label="Cancelar servicio"
            variant="secondary"
            fullWidth
            loading={cancelando}
            onPress={() => setConfirmando(true)}
          />
        )
      )}

      <Modal
        visible={confirmando}
        onRequestClose={() => setConfirmando(false)}
        title={conductor === null ? '¿Cancelar la búsqueda?' : '¿Cancelar este servicio?'}
        description={
          conductor === null
            ? 'Dejaremos de buscarte un motocarro.'
            : 'Le avisamos al conductor y queda libre para tomar otro servicio.'
        }
        icon={Ban}
        tone="danger"
        confirmLabel="Sí, cancelar"
        cancelLabel="No"
        onConfirm={() => {
          setConfirmando(false);
          onCancelar();
        }}
      />
    </>
  );
}

/**
 * La despedida.
 *
 * No hay estrellas todavia: calificar es de la Fase 17. Lo que si tiene que
 * haber es un final, porque hasta ahora el servicio terminaba y la pantalla se
 * quedaba diciendo que el motocarro venia en camino.
 *
 * La distancia y el tiempo pueden faltar, y cuando faltan no se pinta la fila en
 * lugar de rellenarla con ceros. Faltan cuando el conductor no tuvo cobertura
 * para registrar el recorrido, y un "0 m" seria peor que no decir nada.
 *
 * El pasajero lo cierra cuando quiera. No se va solo a los cinco segundos: puede
 * estar bajandose del motocarro, guardando el telefono o pagando.
 */
function ViajeTerminado({ resumen, onCerrar }: { resumen: FinishedRequest; onCerrar: () => void }) {
  const { colors } = useTheme();
  const router = useRouter();

  // Solo se ofrece calificar si hay viaje y si no lo hizo ya. Un boton que lleva
  // a una pantalla que va a responder "ya calificaste este servicio" es un
  // callejon sin salida con buena cara.
  const puedeCalificar = resumen.rideId !== null && !resumen.alreadyRated;

  return (
    <>
      <Card variant="outlined" padding="md">
        <View style={styles.filaBuscando}>
          <CircleCheck size={iconSize.md} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <View style={styles.filaLugarTextos}>
            <Text variant="bodyStrong">Servicio terminado</Text>
            <Text variant="caption" color="textSecondary">
              {resumen.driverName !== null && resumen.unitNumber !== null
                ? `${resumen.driverName} · Motocarro ${resumen.unitNumber}`
                : 'Gracias por viajar con nosotros.'}
            </Text>
          </View>
        </View>

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <View style={styles.puntoViaje}>
          <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {resumen.originLabel}
            </Text>
          </View>
        </View>

        <View style={styles.puntoViaje}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {resumen.destinationLabel}
            </Text>
          </View>
        </View>

        {(resumen.meters !== null || resumen.seconds !== null) && (
          <>
            <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />
            <View style={styles.filaEstimacion}>
              <RouteIcon
                size={iconSize.sm}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              <Text variant="caption" color="textSecondary">
                {[
                  resumen.meters !== null ? formatDistance(resumen.meters) : null,
                  resumen.seconds !== null ? formatDuration(resumen.seconds) : null,
                ]
                  .filter((parte) => parte !== null)
                  .join(' · ')}
              </Text>
            </View>
          </>
        )}
      </Card>

      {puedeCalificar && resumen.rideId !== null ? (
        <>
          <Button
            label="Calificar el viaje"
            variant="brand"
            fullWidth
            onPress={() =>
              router.push({
                pathname: '/passenger/rate/[id]',
                params: {
                  id: resumen.rideId ?? '',
                  // El nombre viaja por parametro y no se vuelve a consultar: ya
                  // esta en pantalla, y la calificacion no depende de el.
                  ...(resumen.driverName !== null ? { name: resumen.driverName } : {}),
                },
              })
            }
          />
          <Button label="Ahora no" variant="ghost" fullWidth onPress={onCerrar} />
        </>
      ) : (
        <Button label="Listo" variant="brand" fullWidth onPress={onCerrar} />
      )}
    </>
  );
}

/**
 * D187: que ve el pasajero cuando el conductor cancela con el a bordo.
 *
 * Pantalla propia y no un texto suelto, con el mismo criterio que
 * `ViajeTerminado`: es un desenlace del servicio y merece que el pasajero lo
 * cierre cuando quiera, no que desaparezca solo.
 *
 * No ofrece calificar ni "Volver a pedirlo": lo primero no tiene sentido para
 * un viaje que no se completo (R8, `rate_ride` exige 'completed'), y lo
 * segundo tampoco hace falta, porque al cerrar esta pantalla el borrador del
 * viaje sigue puesto (no se llama a `limpiarBorrador`) y el pasajero cae
 * directo en el resumen, listo para confirmar otra vez.
 */
function ServicioCanceladoPorConductor({
  aviso,
  onCerrar,
}: {
  aviso: DriverCancelledNotice;
  onCerrar: () => void;
}) {
  const { colors } = useTheme();

  return (
    <>
      <Card variant="outlined" padding="md">
        <View style={styles.filaBuscando}>
          <Ban size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.filaLugarTextos}>
            <Text variant="bodyStrong">
              {aviso.driverName !== null
                ? `${aviso.driverName} canceló el servicio`
                : 'El conductor canceló el servicio'}
            </Text>
            <Text variant="caption" color="textSecondary">
              Puedes volver a pedirlo cuando quieras.
            </Text>
          </View>
        </View>

        <View style={[styles.separadorViaje, { backgroundColor: colors.border }]} />

        <View style={styles.puntoViaje}>
          <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {aviso.originLabel}
            </Text>
          </View>
        </View>

        <View style={styles.puntoViaje}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoViajeTextos}>
            <Text variant="body" numberOfLines={1}>
              {aviso.destinationLabel}
            </Text>
          </View>
        </View>
      </Card>

      <Button label="Entendido" variant="brand" fullWidth onPress={onCerrar} />
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
  avisoConductorCancelo: {
    alignItems: 'center',
    borderRadius: radius.md,
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.md,
    padding: spacing.md,
  },
  avisoConductorCanceloTexto: {
    flex: 1,
  },
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
  campoReferencia: {
    marginBottom: spacing.xs,
    // Alineado con el texto de las filas de arriba, no con el borde de la
    // tarjeta: asi queda debajo del punto de recogida y no debajo de su icono.
    marginLeft: spacing.xl,
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
  llamarConductor: {
    marginTop: spacing.sm,
  },
  notaConductor: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  /**
   * Cifras de ancho fijo para lo que cambia solo.
   *
   * En la tipografia normal cada digito mide distinto, asi que "26:53" y "26:52"
   * no ocupan lo mismo. El contador vive en una fila junto a un bloque con
   * `flex: 1`, de modo que al encoger un pixel el texto de al lado se reajusta:
   * el resultado era un panel que temblaba UNA VEZ POR SEGUNDO. Lo reporto el
   * usuario, y se confirmo midiendo que columnas se redibujaban entre dos
   * instantes: cambiaba la anchura entera del texto, no solo la del numero.
   *
   * `tabular-nums` hace que todas las cifras midan igual, asi que el ancho deja
   * de depender de que numero toque.
   */
  numeroQueCambia: {
    fontVariant: ['tabular-nums'],
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
