import {
  CircleCheck,
  CircleHelp,
  CircleSlash,
  History,
  MapPin,
  Package,
  Route as RouteIcon,
  Star,
  TimerOff,
  User,
  UserCheck,
  Users,
  Wallet,
  type LucideIcon,
} from 'lucide-react-native';
import { useRouter } from 'expo-router';
import { useCallback } from 'react';
import { FlatList, RefreshControl, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Skeleton } from '@/components/ui/skeleton';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { formatWhen } from '@/features/history/format-when';
import { fetchDriverHistory, type DriverJob } from '@/features/history/history-service';
import { useHistory } from '@/features/history/use-history';
import { formatAmount } from '@/features/fare/format-amount';
import { formatDistance, formatDuration } from '@/features/ride/route-service';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme, type ThemeColors } from '@/theme';

/**
 * Los servicios del conductor.
 *
 * NO ES UNA LISTA DE VIAJES, es una lista de ofertas, y por eso salen tambien
 * las que rechazo y las que dejo pasar. La lista de viajes seria mas corta y mas
 * halagadora, pero no responderia la unica pregunta que la empresa se va a hacer
 * al mirar esto en la Fase 20: cuantas se estan rechazando.
 *
 * Sin control de volver: es una pestana, no una pantalla apilada.
 */
export default function DriverHistory() {
  const router = useRouter();
  const { colors } = useTheme();
  const {
    rows,
    loading,
    refreshing,
    loadingMore,
    error,
    offline,
    hasMore,
    refresh,
    loadMore,
    retryMore,
  } = useHistory(fetchDriverHistory);

  const renderItem = useCallback(
    ({ item }: { item: DriverJob }) => (
      <JobCard
        job={item}
        onPress={() => router.push({ pathname: '/driver/job/[id]', params: { id: item.offerId } })}
      />
    ),
    [router],
  );

  if (loading) {
    return (
      <Screen header={<Header title="Servicios realizados" />} padded>
        <View style={styles.lista}>
          {[0, 1, 2, 3].map((n) => (
            <Card key={n} padding="lg">
              <Skeleton width="45%" height={14} />
              <View style={styles.espacio} />
              <Skeleton width="90%" height={18} />
              <View style={styles.espacio} />
              <Skeleton width="60%" height={14} />
            </Card>
          ))}
        </View>
      </Screen>
    );
  }

  if (error !== null && rows.length === 0) {
    return (
      <Screen header={<Header title="Servicios realizados" />} padded>
        <ErrorState description={error} onRetry={refresh} offline={offline} />
      </Screen>
    );
  }

  if (rows.length === 0) {
    return (
      <Screen header={<Header title="Servicios realizados" />} padded>
        <EmptyState
          icon={History}
          title="Sin servicios todavía"
          description="Aquí verás los viajes que completes y las solicitudes que te lleguen, con su fecha y su recorrido."
        />
      </Screen>
    );
  }

  return (
    <Screen header={<Header title="Servicios realizados" />} padded={false}>
      <FlatList
        data={rows}
        keyExtractor={(job) => job.offerId}
        renderItem={renderItem}
        contentContainerStyle={styles.contenido}
        ItemSeparatorComponent={Separador}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={refresh}
            colors={[colors.brand]}
            tintColor={colors.brand}
          />
        }
        onEndReached={loadMore}
        onEndReachedThreshold={0.5}
        ListFooterComponent={
          <Pie
            loadingMore={loadingMore}
            error={rows.length > 0 ? error : null}
            hasMore={hasMore}
            onRetry={retryMore}
          />
        }
      />
    </Screen>
  );
}

function Separador() {
  return <View style={styles.espacio} />;
}

interface PieProps {
  loadingMore: boolean;
  error: string | null;
  hasMore: boolean;
  onRetry: () => void;
}

function Pie({ loadingMore, error, hasMore, onRetry }: PieProps) {
  if (error !== null) {
    return (
      <View style={styles.pie}>
        <Text variant="caption" color="textSecondary" align="center">
          {error}
        </Text>
        <Button label="Reintentar" variant="secondary" size="sm" onPress={onRetry} />
      </View>
    );
  }

  if (loadingMore) {
    return (
      <View style={styles.pie}>
        <Spinner />
      </View>
    );
  }

  if (!hasMore) {
    return (
      <View style={styles.pie}>
        <Text variant="caption" color="textTertiary" align="center">
          No hay más servicios
        </Text>
      </View>
    );
  }

  return null;
}

/**
 * Como se anuncia cada desenlace.
 *
 * CADA UNO CON SU FORMA, no solo con su color. Los cinco se distinguen por el
 * icono ademas de por el texto, porque el color por si solo no vale: los pares
 * de color de estado del sistema de diseno no llegan al contraste minimo
 * (hallazgo H14), y por eso aqui el color vive en el icono y el texto va en el
 * color normal.
 *
 * "La rechazaste" no lleva tono de reproche a proposito. Rechazar una solicitud
 * es una decision legitima del conductor, y la pantalla la registra, no la
 * juzga.
 */
interface Presentacion {
  icon: LucideIcon;
  color: keyof ThemeColors;
  titulo: string;
}

function presentacionDe(job: DriverJob): Presentacion {
  switch (job.outcome) {
    case 'completed':
      return { icon: CircleCheck, color: 'success', titulo: 'Terminado' };
    case 'cancelled':
      return { icon: CircleSlash, color: 'danger', titulo: tituloDeCancelacion(job.cancelledBy) };
    case 'rejected':
      return { icon: CircleSlash, color: 'warning', titulo: 'La rechazaste' };
    case 'taken_by_other':
      return { icon: UserCheck, color: 'textTertiary', titulo: 'La tomó otro conductor' };
    case 'expired':
      return { icon: TimerOff, color: 'textTertiary', titulo: 'Se agotó el tiempo' };
    default:
      return { icon: CircleHelp, color: 'textTertiary', titulo: 'Sin detalle' };
  }
}

function tituloDeCancelacion(porQuien: DriverJob['cancelledBy']): string {
  switch (porQuien) {
    case 'passenger':
      return 'Lo canceló el pasajero';
    case 'driver':
      return 'Lo cancelaste';
    case 'admin':
      return 'Lo canceló la empresa';
    default:
      return 'Cancelado';
  }
}

function JobCard({ job, onPress }: { job: DriverJob; onPress: () => void }) {
  const { colors } = useTheme();
  const { icon: Icon, color, titulo } = presentacionDe(job);

  const recorrido = [
    job.meters !== null ? formatDistance(job.meters) : null,
    job.seconds !== null ? formatDuration(job.seconds) : null,
  ].filter((parte): parte is string => parte !== null);

  // En lo que no llego a viaje, el dato que queda es a que distancia estaba el
  // punto de recogida cuando le sono la oferta. Es lo que explica por que le
  // llego a el y no a otro.
  const aparte =
    job.rideId === null && job.pickupMeters !== null
      ? `A ${formatDistance(job.pickupMeters)} de la recogida`
      : null;

  return (
    <Card
      padding="lg"
      onPress={onPress}
      accessibilityLabel={`${titulo}. De ${job.originLabel} a ${job.destinationLabel}. Ver detalle`}
    >
      <View style={styles.cabecera}>
        <Icon size={iconSize.sm} color={colors[color]} strokeWidth={iconStrokeWidth} />
        <Text variant="bodyStrong" style={styles.titulo} numberOfLines={1}>
          {titulo}
        </Text>
        <Text variant="caption" color="textSecondary">
          {formatWhen(job.finishedAt)}
        </Text>
      </View>

      <View style={styles.recorrido}>
        <View style={styles.punto}>
          <View style={[styles.bolita, { backgroundColor: colors.textTertiary }]} />
          <Text variant="body" color="textSecondary" numberOfLines={1} style={styles.puntoTexto}>
            {job.originLabel}
          </Text>
        </View>
        <View style={[styles.hilo, { backgroundColor: colors.border }]} />
        <View style={styles.punto}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <Text variant="body" numberOfLines={1} style={styles.puntoTexto}>
            {job.destinationLabel}
          </Text>
        </View>
      </View>

      <View style={[styles.separador, { backgroundColor: colors.border }]} />

      <View style={styles.pieDatos}>
        <View style={styles.pieLinea}>
          {job.serviceType === 'parcel' ? (
            <>
              <Package
                size={iconSize.xs}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              <Text variant="caption" color="textSecondary">
                Encomienda
              </Text>
            </>
          ) : (
            <>
              <Users size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
              <Text variant="caption" color="textSecondary">
                {job.passengerCount === 1 ? '1 pasajero' : `${job.passengerCount} pasajeros`}
              </Text>
            </>
          )}

          {recorrido.length > 0 && (
            <>
              <RouteIcon
                size={iconSize.xs}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              <Text variant="caption" color="textSecondary">
                {recorrido.join(' · ')}
              </Text>
            </>
          )}
        </View>

        {job.passengerName !== null && (
          <View style={styles.pieLinea}>
            <User size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
            <Text variant="caption" color="textSecondary" style={styles.pieTexto} numberOfLines={1}>
              {job.passengerName}
            </Text>
          </View>
        )}

        {aparte !== null && (
          <View style={styles.pieLinea}>
            <MapPin size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
            <Text variant="caption" color="textSecondary" style={styles.pieTexto} numberOfLines={1}>
              {aparte}
            </Text>
          </View>
        )}

        {job.outcome === 'completed' && job.fareAmount !== null && (
          <View style={styles.pieLinea}>
            <Wallet size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
            <Text variant="bodyStrong">{formatAmount(job.fareAmount)}</Text>
            {job.fareReference !== null && (
              <Text variant="caption" color="textSecondary">
                · Tarifa de {job.fareReference}
              </Text>
            )}
          </View>
        )}

        {job.alreadyRated === false && (
          <View style={styles.pieLinea}>
            <Star size={iconSize.xs} color={colors.warning} strokeWidth={iconStrokeWidth} />
            <Text variant="caption" color="textSecondary">
              Sin calificar
            </Text>
          </View>
        )}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  lista: { gap: spacing.md, paddingTop: spacing.md },
  contenido: { padding: spacing.lg },
  espacio: { height: spacing.md },
  pie: { alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.xl },

  cabecera: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  titulo: { flex: 1 },

  recorrido: { marginTop: spacing.md },
  punto: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  puntoTexto: { flex: 1 },
  bolita: { borderRadius: radius.full, height: iconSize.sm - 6, width: iconSize.sm - 6 },
  hilo: { height: spacing.md, marginLeft: (iconSize.sm - 2) / 2, width: 1 },

  separador: { height: StyleSheet.hairlineWidth * 2, marginVertical: spacing.md },
  pieDatos: { gap: spacing.xs },
  pieLinea: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  pieTexto: { flex: 1 },
});
