import { Package, Route as RouteIcon, User, Wallet } from 'lucide-react-native';
import { useCallback } from 'react';
import { FlatList, RefreshControl, StyleSheet, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Skeleton } from '@/components/ui/skeleton';
import { Text } from '@/components/ui/text';
import { formatWhen } from '@/features/history/format-when';
import { PeriodToggle } from '@/features/earnings/period-toggle';
import { useEarnings } from '@/features/earnings/use-earnings';
import type { EarningsRow } from '@/features/earnings/types';
import { formatAmount } from '@/features/fare/format-amount';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

/**
 * El recaudo del conductor (D217, paso 7).
 *
 * NO ES EL HISTORIAL: la pestana "Servicios" cuenta todo lo que paso, rechazos
 * y expiraciones incluidos, sin valor. Esta solo cuenta dinero: lo que SI se
 * completo, cuanto valio cada uno y el total del periodo, que es para lo que
 * sirve al cuadrar caja con la empresa al final del turno.
 */
export default function DriverEarnings() {
  const { colors } = useTheme();
  const { rows, period, setPeriod, total, loading, refreshing, error, offline, refresh } =
    useEarnings();

  const renderItem = useCallback(
    ({ item }: { item: EarningsRow }) => <FilaRecaudo item={item} />,
    [],
  );

  const cabecera = <Header title="Recaudo" />;

  if (loading) {
    return (
      <Screen header={cabecera} padded>
        <View style={styles.lista}>
          <Skeleton width="100%" height={90} radius="lg" />
          {[0, 1, 2].map((n) => (
            <Card key={n} padding="lg">
              <Skeleton width="45%" height={14} />
              <View style={styles.espacio} />
              <Skeleton width="90%" height={18} />
            </Card>
          ))}
        </View>
      </Screen>
    );
  }

  if (error !== null && rows.length === 0) {
    return (
      <Screen header={cabecera} padded>
        <PeriodToggle value={period} onChange={setPeriod} />
        <View style={styles.espacioGrande} />
        <ErrorState description={error} onRetry={refresh} offline={offline} />
      </Screen>
    );
  }

  return (
    <Screen header={cabecera} padded={false}>
      <FlatList
        data={rows}
        keyExtractor={(fila) => fila.rideId}
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
        ListHeaderComponent={
          <View style={styles.cabeceraLista}>
            <PeriodToggle value={period} onChange={setPeriod} />
            <Card padding="lg">
              <View style={styles.totalFila}>
                <Wallet size={iconSize.lg} color={colors.brand} strokeWidth={iconStrokeWidth} />
                <View style={styles.totalTextos}>
                  <Text variant="caption" color="textSecondary">
                    {period === 'today' ? 'Total de hoy' : 'Total de esta semana'}
                  </Text>
                  <Text variant="heading">{formatAmount(total)}</Text>
                </View>
              </View>
            </Card>
          </View>
        }
        ListEmptyComponent={
          <EmptyState
            icon={Wallet}
            title="Sin recaudo todavía"
            description={
              period === 'today'
                ? 'Cuando completes un servicio hoy, aparece aquí con su valor.'
                : 'No completaste servicios esta semana.'
            }
          />
        }
      />
    </Screen>
  );
}

function Separador() {
  return <View style={styles.espacio} />;
}

function FilaRecaudo({ item }: { item: EarningsRow }) {
  const { colors } = useTheme();
  const Icon = item.serviceType === 'parcel' ? Package : User;

  return (
    <Card padding="lg">
      <View style={styles.filaCabecera}>
        <Icon size={iconSize.sm} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
        <Text variant="body" color="textSecondary" style={styles.filaTitulo} numberOfLines={1}>
          {item.serviceType === 'parcel'
            ? (item.parcelDescription ?? 'Encomienda')
            : item.originLabel}
        </Text>
        <Text variant="caption" color="textSecondary">
          {formatWhen(item.completedAt)}
        </Text>
      </View>

      <View style={styles.filaCuerpo}>
        <View style={styles.filaRuta}>
          <RouteIcon size={iconSize.xs} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
          <Text
            variant="caption"
            color="textSecondary"
            numberOfLines={1}
            style={styles.filaRutaTexto}
          >
            {item.originLabel} → {item.destinationLabel}
          </Text>
        </View>
        <Text variant="bodyStrong">
          {item.fareAmount !== null ? formatAmount(item.fareAmount) : 'Sin valor'}
        </Text>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  lista: { gap: spacing.md, paddingTop: spacing.md },
  contenido: { padding: spacing.lg },
  espacio: { height: spacing.md },
  espacioGrande: { height: spacing.lg },

  cabeceraLista: { gap: spacing.md, marginBottom: spacing.md },
  totalFila: { alignItems: 'center', flexDirection: 'row', gap: spacing.md },
  totalTextos: { gap: spacing.xxs },

  filaCabecera: { alignItems: 'center', flexDirection: 'row', gap: spacing.sm },
  filaTitulo: { flex: 1 },

  filaCuerpo: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'space-between',
    marginTop: spacing.sm,
  },
  filaRuta: { alignItems: 'center', flex: 1, flexDirection: 'row', gap: spacing.xs },
  filaRutaTexto: { flex: 1 },
});
