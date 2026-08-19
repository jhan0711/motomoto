import { useLocalSearchParams, useRouter } from 'expo-router';
import { CircleCheck, CircleSlash, MapPin, SearchX, TimerOff } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Skeleton } from '@/components/ui/skeleton';
import { Text } from '@/components/ui/text';
import { formatWhen } from '@/features/history/format-when';
import { fetchPassengerTrip, type PassengerTripDetail } from '@/features/history/history-service';
import { Timeline } from '@/features/history/timeline';
import { useHistoryDetail } from '@/features/history/use-detail';
import { formatDistance, formatDuration } from '@/features/ride/route-service';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * El detalle de un servicio del pasajero.
 *
 * Lo que anade sobre la fila de la lista es la LINEA DE TIEMPO: a que hora lo
 * pidio, cuando alguien lo tomo, cuando el conductor llego a esperarlo, cuando
 * arranco y cuando termino. Es lo que convierte "un viaje del martes" en algo
 * que se puede reclamar o recordar.
 *
 * Se pide por identificador y no se pasa la fila ya cargada. Cuesta una consulta
 * mas, y a cambio la pantalla funciona igual si se llega desde un enlace, si la
 * aplicacion se reabre encima de ella o si algun dia hay notificaciones.
 */
export default function PassengerTripDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { item, loading, error, offline, notFound, reload } = useHistoryDetail(
    fetchPassengerTrip,
    id,
  );

  const cabecera = <Header title="Detalle del viaje" onBack={() => router.back()} />;

  if (loading) {
    return (
      <Screen header={cabecera} padded>
        <View style={styles.cargando}>
          <Skeleton width="60%" height={20} />
          <Skeleton width="100%" height={120} radius="lg" />
          <Skeleton width="100%" height={180} radius="lg" />
        </View>
      </Screen>
    );
  }

  if (error !== null) {
    return (
      <Screen header={cabecera} padded>
        <ErrorState description={error} onRetry={reload} offline={offline} />
      </Screen>
    );
  }

  // Un identificador que no existe y uno que es de otra persona llegan aqui
  // igual, y esta bien que asi sea: la pantalla no tiene por que confirmarle a
  // nadie que cierto servicio existe.
  if (notFound || item === null) {
    return (
      <Screen header={cabecera} padded>
        <EmptyState
          icon={SearchX}
          title="No encontramos ese viaje"
          description="Puede que ya no exista o que no sea tuyo."
          actionLabel="Volver"
          onAction={() => router.back()}
        />
      </Screen>
    );
  }

  return (
    <Screen header={cabecera} padded scroll>
      <Contenido trip={item} />
    </Screen>
  );
}

function Contenido({ trip }: { trip: PassengerTripDetail }) {
  const { colors } = useTheme();
  const { icon: Icon, color, titulo } = presentacionDe(trip);

  return (
    <View style={styles.cuerpo}>
      <View style={styles.cabecera}>
        <Icon size={iconSize.lg} color={colors[color]} strokeWidth={iconStrokeWidth} />
        <View style={styles.cabeceraTextos}>
          <Text variant="heading">{titulo}</Text>
          <Text variant="caption" color="textSecondary">
            {formatWhen(trip.finishedAt)}
          </Text>
        </View>
      </View>

      <Card padding="lg">
        <View style={styles.punto}>
          <View style={[styles.bolita, { backgroundColor: colors.textTertiary }]} />
          <View style={styles.puntoTextos}>
            <Text variant="caption" color="textTertiary">
              Recogida
            </Text>
            <Text variant="body">{trip.originLabel}</Text>
            {trip.pickupReference !== null && (
              <Text variant="caption" color="textSecondary">
                {trip.pickupReference}
              </Text>
            )}
          </View>
        </View>

        <View style={[styles.hilo, { backgroundColor: colors.border }]} />

        <View style={styles.punto}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <View style={styles.puntoTextos}>
            <Text variant="caption" color="textTertiary">
              Destino
            </Text>
            <Text variant="body">{trip.destinationLabel}</Text>
          </View>
        </View>
      </Card>

      <Card padding="lg">
        <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
          QUÉ PASÓ
        </Text>
        <Timeline
          steps={[
            { label: 'Pediste el servicio', at: trip.requestedAt },
            { label: 'Un conductor lo tomó', at: trip.acceptedAt },
            { label: 'El conductor llegó', at: trip.driverArrivedAt },
            { label: 'Empezó el recorrido', at: trip.startedAt },
            { label: 'Terminó el viaje', at: trip.completedAt },
            { label: 'Se canceló', at: trip.cancelledAt },
            {
              label: 'Se agotó el tiempo de búsqueda',
              at: trip.status === 'expired' ? trip.expiresAt : null,
            },
          ]}
        />
        {trip.cancellationReason !== null && (
          <Text variant="caption" color="textSecondary" style={styles.motivo}>
            Motivo: {trip.cancellationReason}
          </Text>
        )}
      </Card>

      {trip.driverName !== null && (
        <Card padding="lg">
          <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
            QUIÉN TE LLEVÓ
          </Text>
          <Dato etiqueta="Conductor" valor={trip.driverName} />
          {trip.unitNumber !== null && (
            <Dato etiqueta="Motorratón" valor={`Unidad ${trip.unitNumber}`} />
          )}
          {trip.plate !== null && <Dato etiqueta="Placa" valor={trip.plate} />}
        </Card>
      )}

      <Card padding="lg">
        <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
          EL VIAJE
        </Text>
        <Dato
          etiqueta="Pasajeros"
          valor={trip.passengerCount === 1 ? '1 pasajero' : `${trip.passengerCount} pasajeros`}
        />
        {/* La distancia y la duracion faltan cuando el conductor se quedo sin
            cobertura durante el recorrido. Se dice, en lugar de dejar el hueco:
            un dato ausente sin explicacion parece un fallo de la aplicacion. */}
        <Dato
          etiqueta="Distancia"
          valor={trip.meters !== null ? formatDistance(trip.meters) : 'Sin registro'}
        />
        <Dato
          etiqueta="Duración"
          valor={trip.seconds !== null ? formatDuration(trip.seconds) : 'Sin registro'}
        />
      </Card>
    </View>
  );
}

function Dato({ etiqueta, valor }: { etiqueta: string; valor: string }) {
  return (
    <View style={styles.dato}>
      <Text variant="body" color="textSecondary">
        {etiqueta}
      </Text>
      <Text variant="body">{valor}</Text>
    </View>
  );
}

function presentacionDe(trip: PassengerTripDetail) {
  if (trip.status === 'completed') {
    return { icon: CircleCheck, color: 'success' as const, titulo: 'Terminado' };
  }

  if (trip.status === 'cancelled') {
    const porQuien =
      trip.cancelledBy === 'passenger'
        ? 'Lo cancelaste'
        : trip.cancelledBy === 'driver'
          ? 'Lo canceló el conductor'
          : trip.cancelledBy === 'admin'
            ? 'Lo canceló la empresa'
            : 'Cancelado';
    return { icon: CircleSlash, color: 'danger' as const, titulo: porQuien };
  }

  return { icon: TimerOff, color: 'textTertiary' as const, titulo: 'Nadie lo tomó' };
}

const styles = StyleSheet.create({
  cargando: { gap: spacing.lg, paddingTop: spacing.lg },
  cuerpo: { gap: spacing.md, paddingBottom: spacing.xxl, paddingTop: spacing.md },

  cabecera: { alignItems: 'center', flexDirection: 'row', gap: spacing.md },
  cabeceraTextos: { flex: 1, gap: spacing.xxs },

  punto: { flexDirection: 'row', gap: spacing.sm },
  puntoTextos: { flex: 1, gap: spacing.xxs },
  bolita: {
    borderRadius: radius.full,
    height: iconSize.sm - 6,
    marginTop: 4,
    width: iconSize.sm - 6,
  },
  hilo: {
    height: spacing.lg,
    marginLeft: (iconSize.sm - 2) / 2,
    marginVertical: spacing.xs,
    width: 1,
  },

  tituloBloque: { marginBottom: spacing.md },
  dato: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.xs },
  motivo: { marginTop: spacing.sm },
});
