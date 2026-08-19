import { Circle, MapPin, Navigation as NavigationIcon } from 'lucide-react-native';
import { Pressable, StyleSheet, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { MIN_TOUCH_TARGET, iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import type { DriverRide } from './driver-service';
import { openNavigation } from './navigation';

/**
 * Las paradas que le quedan al conductor, cuando lleva mas de un servicio.
 *
 * ESTO ES LO QUE EL USUARIO PREGUNTO AL CERRAR LA FASE 14: como se le muestran
 * los puntos de recogida y de destino cuando lleva dos o tres viajes a la vez
 * (D161). Entonces no se podia responder, y el motivo esta en D180: para saber
 * que le falta a cada viaje hay que saber **quien va ya a bordo**, y eso solo lo
 * dice el estado, que nacio en el paso 1 de esta fase.
 *
 * Ahora sale del dato y no de una suposicion:
 *
 *   - un viaje que aun no arranco aporta su PUNTO DE RECOGIDA
 *   - un viaje en curso aporta su DESTINO
 *
 * NO SE REORDENAN. Aparecen en el orden en que el conductor los acepto, que es
 * el unico orden que no nos hemos inventado. Ordenarlas por cercania seria
 * facil y seria mentir: la mas cercana en linea recta puede estar al otro lado
 * de una quebrada, y quien conoce Amalfi y sabe si algo le queda de camino es el
 * conductor. Es exactamente lo que dice D161.
 *
 * SOLO APARECE CON DOS O MAS SERVICIOS. Con uno, su tarjeta ya lo cuenta todo y
 * esta lista seria repetir lo mismo dos veces en la misma pantalla.
 *
 * CADA PARADA SE NAVEGA POR SEPARADO, y no todas juntas en una ruta. Una ruta
 * con paradas intermedias obliga a Google Maps, porque **Waze no las admite
 * desde un enlace**, y eso dejaria sin efecto el selector de aplicaciones que
 * D178 puso justamente para que el conductor use la que ya conoce.
 */

export interface PendingStopsProps {
  rides: readonly DriverRide[];
}

interface Parada {
  rideId: string;
  tipo: 'recogida' | 'destino';
  quien: string;
  label: string;
  point: { latitude: number; longitude: number };
}

/** Que le falta a cada viaje, segun donde este. */
export function paradasPendientes(rides: readonly DriverRide[]): Parada[] {
  const paradas: Parada[] = [];

  for (const ride of rides) {
    if (ride.status === 'in_progress') {
      paradas.push({
        rideId: ride.rideId,
        tipo: 'destino',
        quien: ride.passengerName,
        label: ride.destination.label,
        point: ride.destination,
      });
    } else {
      paradas.push({
        rideId: ride.rideId,
        tipo: 'recogida',
        quien: ride.passengerName,
        label: ride.origin.label,
        point: ride.origin,
      });
    }
  }

  return paradas;
}

export function PendingStops({ rides }: PendingStopsProps) {
  const { colors } = useTheme();

  if (rides.length < 2) return null;

  const paradas = paradasPendientes(rides);

  return (
    <Card variant="outlined" padding="md">
      <Text variant="caption" color="textTertiary">
        TUS PARADAS
      </Text>

      {paradas.map((parada) => (
        <Pressable
          key={parada.rideId}
          accessibilityRole="button"
          accessibilityLabel={`Ir a ${parada.label}`}
          onPress={() => void openNavigation(parada.point, parada.label)}
          style={({ pressed }) => [
            styles.fila,
            {
              backgroundColor: pressed ? colors.surfacePressed : 'transparent',
              borderRadius: radius.md,
            },
          ]}
        >
          {/* El mismo par de simbolos que el mapa y las tarjetas: hueco para
              recoger, relleno para dejar. Cambiarlos aqui obligaria a traducir
              mentalmente entre tres sitios de la misma pantalla. */}
          {parada.tipo === 'recogida' ? (
            <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          ) : (
            <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          )}

          <View style={styles.textos}>
            <Text variant="body" numberOfLines={1}>
              {parada.tipo === 'recogida' ? 'Recoger a ' : 'Dejar a '}
              {primerNombre(parada.quien)}
            </Text>
            <Text variant="caption" color="textSecondary" numberOfLines={1}>
              {parada.label}
            </Text>
          </View>

          <NavigationIcon
            size={iconSize.sm}
            color={colors.textTertiary}
            strokeWidth={iconStrokeWidth}
          />
        </Pressable>
      ))}

      <Text variant="caption" color="textTertiary" style={styles.nota}>
        En el orden en que los aceptaste. Tú decides por cuál seguir.
      </Text>
    </Card>
  );
}

/** Solo el primer nombre: la fila es estrecha y el apellido no ayuda a ubicarlo. */
function primerNombre(nombre: string): string {
  const partes = nombre.trim().split(/\s+/);
  return partes[0] ?? nombre;
}

const styles = StyleSheet.create({
  fila: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: MIN_TOUCH_TARGET,
    paddingHorizontal: spacing.xs,
  },
  nota: {
    marginTop: spacing.xs,
  },
  textos: {
    flex: 1,
    gap: spacing.xxs,
  },
});
