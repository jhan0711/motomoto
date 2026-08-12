import { Circle, MapPin, Navigation as NavigationIcon, Phone, Users } from 'lucide-react-native';
import { useCallback, useState } from 'react';
import { Linking, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
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
 * Las transiciones del servicio, que son "voy en camino", "llegue", "iniciar" y
 * "finalizar", son de la Fase 15. Esta tarjeta enseña a quien recoger y donde;
 * moverlo por sus estados es otra cosa.
 */

export interface ActiveRideCardProps {
  ride: DriverRide;
}

export function ActiveRideCard({ ride }: ActiveRideCardProps) {
  const { colors } = useTheme();

  const [errorNavegacion, setErrorNavegacion] = useState<string | null>(null);

  /**
   * Abre la navegacion hacia donde hay que recoger.
   *
   * Se le manda el nombre del sitio ademas de la coordenada, para que el
   * conductor vea "El parque" en su navegador y pueda reconocer el punto antes
   * de arrancar. La referencia escrita no viaja: es una frase para leer, no una
   * direccion, y el sitio donde tiene que leerla es esta tarjeta.
   */
  const irAlPuntoDeRecogida = useCallback(async () => {
    setErrorNavegacion(null);

    const abierto = await openNavigation(ride.origin, ride.origin.label);

    if (!abierto) {
      setErrorNavegacion('No pudimos abrir la navegación. La dirección está arriba.');
    }
  }, [ride.origin]);

  return (
    <Card variant="elevated" style={{ borderColor: colors.brand, borderWidth: 1 }}>
      <Text variant="caption" color="textTertiary">
        SERVICIO ACEPTADO
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

      {/* Ir primero, llamar despues. El conductor acaba de aceptar y lo
          siguiente que hace es arrancar; llamar es lo que hace cuando ya llego y
          no encuentra a nadie. Por eso este va en color de marca y el otro
          queda como accion secundaria.

          IMPORTANTE: lleva al PUNTO DE RECOGIDA, no al destino. El del destino
          va en la Fase 15, junto a "iniciar recorrido", porque hasta que exista
          ese boton la aplicacion no sabe si ya recogio al pasajero, y dos
          botones sin ese dato pueden mandarlo al sitio equivocado. */}
      <Button
        label="Cómo llegar"
        variant="brand"
        icon={NavigationIcon}
        fullWidth
        style={styles.llamar}
        onPress={() => void irAlPuntoDeRecogida()}
      />

      <Button
        label={`Llamar a ${primerNombre(ride.passengerName)}`}
        variant="secondary"
        icon={Phone}
        fullWidth
        style={styles.llamarDespues}
        onPress={() => void Linking.openURL(`tel:${ride.passengerPhone}`)}
      />

      <FormError message={errorNavegacion} />
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
