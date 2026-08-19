import {
  ArrowRight,
  Circle,
  Flag,
  MapPin,
  Navigation as NavigationIcon,
  Phone,
  Users,
} from 'lucide-react-native';
import { useCallback, useState } from 'react';
import { Linking, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
import { Modal } from '@/components/ui/modal';
import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import type { DriverRide } from './driver-service';
import { openNavigation } from './navigation';

/**
 * Un servicio aceptado, con quien hay que recoger.
 *
 * El telefono es un boton y no un texto. El conductor va a usarlo con una mano,
 * a veces en movimiento, y copiar diez digitos a la aplicacion de llamadas es
 * justo el tipo de friccion que hace que la gente termine llamando por otro
 * canal y deje de usar la aplicacion.
 *
 * DESDE LA FASE 15 LA TARJETA MUEVE EL SERVICIO. Se ve un solo boton, el que
 * toca ahora, y no los cuatro con tres apagados: el conductor la mira de reojo,
 * a veces en movimiento, y una fila de botones grises es ruido que hay que leer
 * para descartar. El estado manda cual es, y el estado lo decide el servidor.
 */

/** Lo que el conductor puede hacer con el servicio en este momento. */
export type RideAction = 'on_the_way' | 'arrived' | 'start' | 'complete';

interface Siguiente {
  action: RideAction;
  label: string;
  /**
   * Finalizar pide confirmacion y las demas no.
   *
   * Es la unica irreversible de las cuatro, y la Fase 0 la dejo escrita como
   * situacion a cubrir: "el conductor termina accidentalmente un servicio". Las
   * otras tres se deshacen solas avanzando, o como mucho adelantan un estado que
   * iba a llegar igual. Pedir confirmacion en todas convertiria el ciclo normal
   * en ocho toques y ensenaria a confirmar sin leer.
   */
  confirma?: { titulo: string; descripcion: string };
}

/** Que toca hacer ahora, o null si el viaje ya no admite nada. */
export function siguienteAccion(status: DriverRide['status']): Siguiente | null {
  switch (status) {
    case 'assigned':
      return { action: 'on_the_way', label: 'Voy en camino' };
    case 'driver_on_the_way':
      return { action: 'arrived', label: 'Llegué al punto' };
    case 'driver_arrived':
      return { action: 'start', label: 'Iniciar recorrido' };
    case 'in_progress':
      return {
        action: 'complete',
        label: 'Finalizar servicio',
        confirma: {
          titulo: '¿Terminaste el servicio?',
          descripcion: 'Se cierra el viaje y ya no se puede deshacer.',
        },
      };
    default:
      return null;
  }
}

/** Como se llama el estado para el conductor. */
function tituloDelEstado(status: DriverRide['status']): string {
  switch (status) {
    case 'driver_on_the_way':
      return 'VAS EN CAMINO';
    case 'driver_arrived':
      return 'ESPERANDO AL PASAJERO';
    case 'in_progress':
      return 'EN RECORRIDO';
    default:
      return 'SERVICIO ACEPTADO';
  }
}

export interface ActiveRideCardProps {
  ride: DriverRide;
  /** Mueve el servicio al estado siguiente. */
  onAdvance: (ride: DriverRide, action: RideAction) => void;
  /** El servidor esta respondiendo a la transicion de ESTE viaje. */
  advancing?: boolean;
  /** Lo que fallo al intentar avanzar, ya traducido. */
  error?: string | null;
}

export function ActiveRideCard({
  ride,
  onAdvance,
  advancing = false,
  error = null,
}: ActiveRideCardProps) {
  const { colors } = useTheme();

  const [errorNavegacion, setErrorNavegacion] = useState<string | null>(null);
  const [confirmando, setConfirmando] = useState(false);

  const siguiente = siguienteAccion(ride.status);

  const avanzar = useCallback(() => {
    if (siguiente === null) return;

    if (siguiente.confirma !== undefined) {
      setConfirmando(true);
      return;
    }

    onAdvance(ride, siguiente.action);
  }, [onAdvance, ride, siguiente]);

  /**
   * Abre la navegacion hacia donde toca ir AHORA.
   *
   * Y "ahora" lo decide el estado, que es lo que la Fase 14 no podia hacer. Con
   * el pasajero todavia fuera se va al punto de recogida; con el ya a bordo, al
   * destino. Antes de que existieran las transiciones, la aplicacion no sabia
   * cual de las dos cosas era cierta, y por eso el boton solo servia para la
   * recogida y desaparecia despues (D179).
   *
   * Se le manda el nombre del sitio ademas de la coordenada, para que el
   * conductor vea "El parque" en su navegador y pueda reconocer el punto antes
   * de arrancar. La referencia escrita no viaja: es una frase para leer, no una
   * direccion, y el sitio donde tiene que leerla es esta tarjeta.
   */
  const yendoAlDestino = ride.status === 'in_progress';
  const parada = yendoAlDestino ? ride.destination : ride.origin;

  const irALaParada = useCallback(async () => {
    setErrorNavegacion(null);

    const abierto = await openNavigation(parada, parada.label);

    if (!abierto) {
      setErrorNavegacion('No pudimos abrir la navegación. La dirección está arriba.');
    }
  }, [parada]);

  return (
    <Card variant="elevated" style={{ borderColor: colors.brand, borderWidth: 1 }}>
      <Text variant="caption" color="textTertiary">
        {tituloDelEstado(ride.status)}
      </Text>
      <Text variant="subheading">{ride.passengerName}</Text>

      <View style={[styles.separador, { backgroundColor: colors.border }]} />

      <View style={styles.fila}>
        <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <View style={styles.filaTextos}>
          <Text variant="caption" color="textTertiary">
            RECOGER EN
          </Text>
          <Text variant="body" numberOfLines={2}>
            {ride.origin.label}
          </Text>

          {/* La referencia va PEGADA al punto de recogida y no como una fila
              aparte, porque no es otro dato del viaje: es la segunda mitad de
              este. El nombre del sitio dice el sector y esto dice donde esta la
              persona dentro de el, que en lugares como "Alto de la Virgen" son
              tres cuadras de diferencia.

              Se destaca con el color de marca a proposito. Es lo unico de la
              tarjeta que el conductor no puede deducir del mapa. */}
          {ride.pickupReference !== null && (
            <View
              style={[
                styles.referencia,
                { backgroundColor: colors.surfaceSubtle, borderLeftColor: colors.brand },
              ]}
            >
              <Text variant="bodyStrong" numberOfLines={3}>
                {ride.pickupReference}
              </Text>
            </View>
          )}
        </View>
      </View>

      <View style={styles.fila}>
        <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <View style={styles.filaTextos}>
          <Text variant="caption" color="textTertiary">
            LLEVAR A
          </Text>
          <Text variant="body" numberOfLines={2}>
            {ride.destination.label}
          </Text>
        </View>
      </View>

      <View style={styles.fila}>
        <Users size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" style={styles.filaTextos}>
          {ride.passengerCount === 1 ? 'Un pasajero' : `${ride.passengerCount} pasajeros`}
        </Text>
      </View>

      {/* Mover el servicio es lo principal, y por eso va en color de marca y
          primero. Navegar y llamar son apoyos: se usan cuando hace falta, no en
          cada viaje. */}
      {siguiente !== null && (
        <Button
          label={siguiente.label}
          variant="brand"
          icon={ArrowRight}
          iconPosition="right"
          fullWidth
          loading={advancing}
          style={styles.llamar}
          onPress={avanzar}
        />
      )}

      {/* La etiqueta dice A DONDE, no solo que se puede navegar. "Cómo llegar" a
          secas obligaba al conductor a deducir el destino del estado de la
          tarjeta, y con dos o tres servicios abiertos esa deduccion se hace
          mirando de reojo mientras conduce. */}
      <Button
        label={yendoAlDestino ? 'Ir al destino' : 'Ir a la recogida'}
        variant="secondary"
        icon={NavigationIcon}
        fullWidth
        style={styles.llamarDespues}
        onPress={() => void irALaParada()}
      />

      <Button
        label={`Llamar a ${primerNombre(ride.passengerName)}`}
        variant="secondary"
        icon={Phone}
        fullWidth
        style={styles.llamarDespues}
        onPress={() => void Linking.openURL(`tel:${ride.passengerPhone}`)}
      />

      <FormError message={errorNavegacion ?? error} />

      <Modal
        visible={confirmando}
        onRequestClose={() => setConfirmando(false)}
        title={siguiente?.confirma?.titulo ?? ''}
        description={siguiente?.confirma?.descripcion}
        icon={Flag}
        confirmLabel="Sí, finalizar"
        cancelLabel="Todavía no"
        onConfirm={() => {
          setConfirmando(false);
          if (siguiente !== null) onAdvance(ride, siguiente.action);
        }}
      />
    </Card>
  );
}

/**
 * Solo el primer nombre en el boton de llamar.
 *
 * "Llamar a Jhan" cabe en una linea; "Llamar a Jhan Roldan Restrepo" se corta o
 * encoge la letra. El nombre completo ya esta arriba, en grande.
 */
function primerNombre(nombre: string): string {
  const partes = nombre.trim().split(/\s+/);
  return partes[0] ?? nombre;
}

const styles = StyleSheet.create({
  fila: {
    alignItems: 'flex-start',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 40,
    paddingVertical: spacing.xs,
  },
  filaTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  llamar: {
    marginTop: spacing.md,
  },
  llamarDespues: {
    marginTop: spacing.sm,
  },
  referencia: {
    borderLeftWidth: 3,
    borderRadius: radius.sm,
    marginTop: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  separador: {
    height: StyleSheet.hairlineWidth,
    marginVertical: spacing.sm,
  },
});
