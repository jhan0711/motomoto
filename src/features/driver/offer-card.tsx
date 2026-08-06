import { Circle, MapPin, Users } from 'lucide-react-native';
import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { formatCountdown, useCountdown } from '@/features/ride/use-countdown';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import type { DriverOffer } from './driver-service';
import { RoutePreview, type RouteEnds } from './route-preview';

/**
 * Una solicitud ofrecida, con el tiempo que queda para responderla.
 *
 * Lo que se le ensena y lo que no. Ve de donde a donde, cuanta gente y a que
 * distancia esta la recogida: lo que necesita para decidir si le conviene el
 * viaje. No ve quien es el pasajero. Eso aparece al aceptar, que es cuando
 * alguien se compromete a llevarla.
 *
 * La cuenta atras es la misma pieza que usa el pasajero mientras espera, con el
 * identificador de la oferta como clave de reinicio. Esa clave no es un detalle:
 * dos ofertas seguidas empiezan las dos en veinte segundos, asi que el valor no
 * sirve para distinguirlas y el contador se quedaria clavado (E27).
 */

export interface OfferCardProps {
  offer: DriverOffer;
  aceptando: boolean;
  rechazando: boolean;
  onAceptar: () => void;
  onRechazar: () => void;
  /** Se llama cuando se agota el tiempo, para que quien manda la retire. */
  onExpirar: () => void;
  /**
   * Los viajes que el conductor ya lleva, para dibujarlos bajo esta ruta.
   *
   * DECISION D161: sin verlos junto a la ruta ofrecida no puede juzgar si le
   * queda de camino, que es exactamente lo que la decision le pide decidir.
   */
  enCurso?: RouteEnds[];
}

export function OfferCard({
  offer,
  aceptando,
  rechazando,
  onAceptar,
  onRechazar,
  onExpirar,
  enCurso,
}: OfferCardProps) {
  const { colors } = useTheme();
  const restantes = useCountdown(offer.secondsRemaining, offer.offerId);
  const agotado = restantes !== null && restantes <= 0;

  useEffect(() => {
    if (!agotado) return;

    // Se avisa desde un temporizador y no desde el cuerpo del efecto, porque
    // quien recibe el aviso cambia estado y el compilador de React no admite un
    // setState alcanzable de forma sincrona desde aqui.
    const id = setTimeout(onExpirar, 0);
    return () => clearTimeout(id);
  }, [agotado, onExpirar]);

  return (
    <Card variant="elevated" style={{ borderColor: colors.brand, borderWidth: 1 }}>
      <View style={styles.cabecera}>
        <View style={styles.cabeceraTextos}>
          <Text variant="subheading">Nueva solicitud</Text>
          {offer.distanceM !== null && (
            <Text variant="caption" color="textSecondary">
              A {formatDistanciaRecogida(offer.distanceM)} de ti
            </Text>
          )}
        </View>

        {/* Por debajo del minuto, segundos sueltos: con los veinte de la regla
            R2, "0:14" obliga a leer dos numeros para entender uno. Por encima se
            pasa a cronometro, porque "134" tampoco se entiende de un vistazo.

            Y la burbuja crece con el contenido en lugar de ser un circulo fijo.
            El primer intento tenia ancho y alto de 52, y con la ventana subida a
            1800 segundos para poder probar sin prisa, el "1344" se salio y
            partio en dos lineas. Ese valor sale de `offer_response_seconds`, que
            la empresa puede cambiar: dar por hecho que caben dos digitos es la
            misma suposicion que la Fase 10 enseño a no hacer. */}
        {restantes !== null && (
          <View style={[styles.reloj, { backgroundColor: colors.brandSubtle }]}>
            <Text variant="title" color="brand">
              {restantes < 60 ? Math.max(0, restantes) : formatCountdown(restantes)}
            </Text>
          </View>
        )}
      </View>

      <View style={[styles.separador, { backgroundColor: colors.border }]} />

      <View style={styles.punto}>
        <Circle size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" numberOfLines={1} style={styles.puntoTexto}>
          {offer.origin.label}
        </Text>
      </View>

      <View style={styles.punto}>
        <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <Text variant="body" numberOfLines={1} style={styles.puntoTexto}>
          {offer.destination.label}
        </Text>
      </View>

      <View style={styles.punto}>
        <Users size={iconSize.sm} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" style={styles.puntoTexto}>
          {offer.passengerCount === 1 ? 'Un pasajero' : `${offer.passengerCount} pasajeros`}
        </Text>
      </View>

      {/* El mapa va despues de las direcciones y antes de los botones. Ese orden
          es el de la decision: primero se lee a donde, luego se mira por donde,
          y solo entonces se acepta. Ponerlo arriba del todo lo convertiria en
          adorno; ponerlo debajo de los botones seria pedirle que decida antes de
          ver. */}
      <RoutePreview
        route={{ origin: offer.origin, destination: offer.destination }}
        context={enCurso}
      />

      <View style={styles.acciones}>
        <Button
          label="Aceptar"
          variant="brand"
          fullWidth
          loading={aceptando}
          disabled={rechazando || agotado}
          onPress={onAceptar}
        />
        {/* Rechazar es definitivo: la regla R12 impide que se le vuelva a
            ofrecer. Por eso va en secundario y debajo, no al lado del principal
            donde se toca sin querer. */}
        <Button
          label="Rechazar"
          variant="secondary"
          fullWidth
          loading={rechazando}
          disabled={aceptando || agotado}
          onPress={onRechazar}
        />
      </View>
    </Card>
  );
}

/**
 * La distancia a la recogida, redondeada sin fingir precision.
 *
 * Por debajo del kilometro se redondea a la cincuentena: el conductor decide con
 * "a 300 metros", y decirle 287 sugiere una exactitud que la posicion del GPS no
 * tiene.
 */
export function formatDistanciaRecogida(meters: number): string {
  if (meters < 1000) {
    return `${Math.max(50, Math.round(meters / 50) * 50)} m`;
  }
  return `${(meters / 1000).toFixed(1).replace('.', ',')} km`;
}

const styles = StyleSheet.create({
  acciones: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  cabecera: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  cabeceraTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  punto: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    minHeight: 32,
  },
  puntoTexto: {
    flex: 1,
  },
  reloj: {
    alignItems: 'center',
    borderRadius: radius.full,
    justifyContent: 'center',
    minHeight: 52,
    // Crece a lo ancho si el numero es largo, en lugar de recortarlo. minWidth
    // conserva la forma de circulo en el caso normal, que son dos digitos.
    minWidth: 52,
    paddingHorizontal: spacing.sm,
  },
  separador: {
    height: StyleSheet.hairlineWidth,
    marginVertical: spacing.sm,
  },
});
