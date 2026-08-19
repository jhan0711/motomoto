import { useRouter } from 'expo-router';
import {
  CircleCheck,
  CircleSlash,
  History,
  MapPin,
  Route as RouteIcon,
  TimerOff,
  User,
  Users,
  type LucideIcon,
} from 'lucide-react-native';
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
import { fetchPassengerHistory, type PassengerTrip } from '@/features/history/history-service';
import { useHistory } from '@/features/history/use-history';
import { formatDistance, formatDuration } from '@/features/ride/route-service';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme, type ThemeColors } from '@/theme';

/**
 * Los viajes del pasajero.
 *
 * Salen los tres finales que puede tener una solicitud: terminada, cancelada y
 * caducada. Una solicitud que un conductor rechazo no aparece como tal, y no es
 * un olvido: desde el lado del pasajero no paso nada, su solicitud siguio
 * buscando y acabo en uno de esos tres sitios. El rechazo es un hecho entre el
 * conductor y su oferta, y vive en la pantalla del conductor.
 *
 * La lista no se recarga sola. Un historial no cambia mientras se mira, y el
 * unico caso en que si —terminar un viaje— pasa en otra pantalla, con esta
 * cerrada. Para lo demas esta el tiron hacia abajo.
 */
export default function PassengerHistory() {
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
  } = useHistory(fetchPassengerHistory);

  const renderItem = useCallback(
    ({ item }: { item: PassengerTrip }) => (
      <TripCard
        trip={item}
        onPress={() =>
          router.push({ pathname: '/passenger/trip/[id]', params: { id: item.requestId } })
        }
      />
    ),
    [router],
  );

  // Primera carga: el esqueleto de la lista y no una rueda girando. Dice lo que
  // viene y cuanto, y la pantalla no pega un salto cuando llegan los datos.
  if (loading) {
    return (
      <Screen header={<Header title="Mis viajes" onBack={() => router.back()} />} padded>
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

  // Un fallo con la lista vacia ocupa la pantalla; con filas ya puestas iria al
  // pie, para no borrar lo que el pasajero estaba leyendo.
  if (error !== null && rows.length === 0) {
    return (
      <Screen header={<Header title="Mis viajes" onBack={() => router.back()} />} padded>
        <ErrorState description={error} onRetry={refresh} offline={offline} />
      </Screen>
    );
  }

  if (rows.length === 0) {
    return (
      <Screen header={<Header title="Mis viajes" onBack={() => router.back()} />} padded>
        <EmptyState
          icon={History}
          title="Todavía no tienes viajes"
          description="Cuando solicites tu primer motorratón, aparecerá aquí con su fecha, su recorrido y el conductor que te llevó."
          actionLabel="Solicitar un viaje"
          onAction={() => router.replace('/passenger')}
        />
      </Screen>
    );
  }

  return (
    <Screen header={<Header title="Mis viajes" onBack={() => router.back()} />} padded={false}>
      <FlatList
        data={rows}
        keyExtractor={(trip) => trip.requestId}
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
        // Medio alto de pantalla por delante: pide la siguiente tanda antes de
        // que el pasajero llegue al final, asi que la espera no se ve.
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
          No hay más viajes
        </Text>
      </View>
    );
  }

  return null;
}

/**
 * Como se anuncia cada final.
 *
 * EL COLOR VA EN EL ICONO Y NUNCA EN EL TEXTO. Son las dos mitades del hallazgo
 * H14: los pares de color de estado no llegan al contraste minimo, asi que un
 * "Terminado" escrito en verde seria dificil de leer para bastante gente. En un
 * icono, que acompana a una palabra que ya lo dice todo, el color es un apoyo y
 * no la informacion.
 */
interface Presentacion {
  icon: LucideIcon;
  color: keyof ThemeColors;
  titulo: string;
}

function presentacionDe(trip: PassengerTrip): Presentacion {
  if (trip.status === 'completed') {
    return { icon: CircleCheck, color: 'success', titulo: 'Terminado' };
  }

  if (trip.status === 'cancelled') {
    return { icon: CircleSlash, color: 'danger', titulo: tituloDeCancelacion(trip.cancelledBy) };
  }

  // Caducada. "Caducado" es palabra de sistema; lo que le paso al pasajero es
  // que nadie fue por el.
  return { icon: TimerOff, color: 'textTertiary', titulo: 'Nadie lo tomó' };
}

function tituloDeCancelacion(porQuien: PassengerTrip['cancelledBy']): string {
  switch (porQuien) {
    case 'passenger':
      return 'Lo cancelaste';
    case 'driver':
      return 'Lo canceló el conductor';
    case 'admin':
      return 'Lo canceló la empresa';
    default:
      return 'Cancelado';
  }
}

function TripCard({ trip, onPress }: { trip: PassengerTrip; onPress: () => void }) {
  const { colors } = useTheme();
  const { icon: Icon, color, titulo } = presentacionDe(trip);

  // DOS LINEAS Y NO UNA. En la primera prueba iban juntas, y con un nombre de
  // conductor normal la fila se cortaba a la mitad de "11 min": lo primero que
  // desaparecia era justo el dato del viaje. Ahora el recorrido va arriba, que
  // es lo que se busca al mirar el historial, y quien lo llevo debajo.
  const recorrido = [
    trip.meters !== null ? formatDistance(trip.meters) : null,
    trip.seconds !== null ? formatDuration(trip.seconds) : null,
  ].filter((parte): parte is string => parte !== null);

  // En una solicitud caducada no hubo conductor, y entonces esta linea no sale.
  const conductor = [
    trip.driverName,
    trip.unitNumber !== null ? `Unidad ${trip.unitNumber}` : null,
  ].filter((parte): parte is string => parte !== null);

  return (
    <Card
      padding="lg"
      onPress={onPress}
      accessibilityLabel={`${titulo}. De ${trip.originLabel} a ${trip.destinationLabel}. Ver detalle`}
    >
      <View style={styles.cabecera}>
        <Icon size={iconSize.sm} color={colors[color]} strokeWidth={iconStrokeWidth} />
        <Text variant="bodyStrong" style={styles.titulo} numberOfLines={1}>
          {titulo}
        </Text>
        <Text variant="caption" color="textSecondary">
          {formatWhen(trip.finishedAt)}
        </Text>
      </View>

      <View style={styles.recorrido}>
        <View style={styles.punto}>
          <View style={[styles.bolita, { backgroundColor: colors.textTertiary }]} />
          <Text variant="body" color="textSecondary" numberOfLines={1} style={styles.puntoTexto}>
            {trip.originLabel}
          </Text>
        </View>
        <View style={[styles.hilo, { backgroundColor: colors.border }]} />
        <View style={styles.punto}>
          <MapPin size={iconSize.sm} color={colors.brand} strokeWidth={iconStrokeWidth} />
          <Text variant="body" numberOfLines={1} style={styles.puntoTexto}>
            {trip.destinationLabel}
          </Text>
        </View>
      </View>

      <View style={[styles.separador, { backgroundColor: colors.border }]} />

      <View style={styles.pieDatos}>
        <View style={styles.pieLinea}>
          <Users size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
          <Text variant="caption" color="textSecondary">
            {trip.passengerCount === 1 ? '1 pasajero' : `${trip.passengerCount} pasajeros`}
          </Text>

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

        {conductor.length > 0 && (
          <View style={styles.pieLinea}>
            <User size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
            <Text variant="caption" color="textSecondary" style={styles.pieTexto} numberOfLines={1}>
              {conductor.join(' · ')}
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
  // Alineado con el centro de la bolita para que el recorrido se lea como una
  // linea y no como dos filas sueltas.
  hilo: { height: spacing.md, marginLeft: (iconSize.sm - 2) / 2, width: 1 },

  separador: { height: StyleSheet.hairlineWidth * 2, marginVertical: spacing.md },
  pieDatos: { gap: spacing.xs },
  pieLinea: { alignItems: 'center', flexDirection: 'row', gap: spacing.xs },
  pieTexto: { flex: 1 },
});
