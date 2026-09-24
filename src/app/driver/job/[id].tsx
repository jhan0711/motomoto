import { useLocalSearchParams, useRouter } from 'expo-router';
import {
  CircleCheck,
  CircleHelp,
  CircleSlash,
  MapPin,
  Package,
  SearchX,
  TimerOff,
  UserCheck,
  Wallet,
} from 'lucide-react-native';
import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';
import { Skeleton } from '@/components/ui/skeleton';
import { Text } from '@/components/ui/text';
import { fetchRequestCargo, type RequestCargoLine } from '@/features/fare/fare-service';
import { formatAmount } from '@/features/fare/format-amount';
import { officialFareAmount } from '@/features/fare/official-fare';
import { formatWhen } from '@/features/history/format-when';
import { StarPicker } from '@/features/rating/star-picker';
import { fetchDriverJob, type DriverJobDetail } from '@/features/history/history-service';
import { Timeline } from '@/features/history/timeline';
import { useHistoryDetail } from '@/features/history/use-detail';
import { formatDistance, formatDuration } from '@/features/ride/route-service';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * El detalle de una oferta del conductor.
 *
 * Empieza antes que el del pasajero: la primera hora de la linea de tiempo no es
 * cuando alguien pidio el servicio, sino cuando le sono a el, y la segunda es
 * que hizo con esa oferta. Es lo que hace que una fila que dice "la rechazaste"
 * pueda explicarse.
 *
 * Del pasajero solo sale el nombre, y solo si lo llevo. El telefono no aparece
 * en el historial: hace falta durante el servicio, no despues.
 */
export default function DriverJobDetailScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { item, loading, error, offline, notFound, reload } = useHistoryDetail(fetchDriverJob, id);

  const cabecera = <Header title="Detalle del servicio" onBack={() => router.back()} />;

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

  if (notFound || item === null) {
    return (
      <Screen header={cabecera} padded>
        <EmptyState
          icon={SearchX}
          title="No encontramos ese servicio"
          description="Puede que ya no exista o que no sea tuyo."
          actionLabel="Volver"
          onAction={() => router.back()}
        />
      </Screen>
    );
  }

  return (
    <Screen header={cabecera} padded scroll>
      <Contenido job={item} />
    </Screen>
  );
}

function Contenido({ job }: { job: DriverJobDetail }) {
  const { colors } = useTheme();
  const router = useRouter();
  const { icon: Icon, color, titulo } = presentacionDe(job);

  const tarifaOficial = officialFareAmount(
    job.serviceType,
    job.fareTripAmount,
    job.fareCargoAmount,
  );
  const ofertaDistinta =
    tarifaOficial !== null && job.fareAmount !== null && tarifaOficial !== job.fareAmount;

  /**
   * El detalle de la carga, si lleva. Igual criterio que en el resumen del
   * pasajero (`passenger/index.tsx`): `get_driver_job` devuelve como mucho
   * una fila y un servicio puede llevar varias cargas, asi que se relee
   * aparte, una vez por cada oferta distinta.
   */
  const [cargaDelServicio, setCargaDelServicio] = useState<RequestCargoLine[]>([]);

  useEffect(() => {
    let vigente = true;

    const id = setTimeout(() => {
      void fetchRequestCargo(job.requestId).then((resultado) => {
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
  }, [job.requestId]);

  return (
    <View style={styles.cuerpo}>
      <View style={styles.cabecera}>
        <Icon size={iconSize.lg} color={colors[color]} strokeWidth={iconStrokeWidth} />
        <View style={styles.cabeceraTextos}>
          <Text variant="heading">{titulo}</Text>
          <Text variant="caption" color="textSecondary">
            {formatWhen(job.finishedAt)}
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
            <Text variant="body">{job.originLabel}</Text>
            {job.pickupReference !== null && (
              <Text variant="caption" color="textSecondary">
                {job.pickupReference}
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
            <Text variant="body">{job.destinationLabel}</Text>
          </View>
        </View>
      </Card>

      <Card padding="lg">
        <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
          QUÉ PASÓ
        </Text>
        <Timeline
          steps={[
            { label: 'Te llegó la solicitud', at: job.offeredAt },
            { label: etiquetaRespuesta(job), at: job.respondedAt },
            { label: 'Llegaste al punto de recogida', at: job.driverArrivedAt },
            { label: 'Empezó el recorrido', at: job.startedAt },
            { label: 'Terminó el viaje', at: job.completedAt },
            { label: 'Se canceló', at: job.cancelledAt },
          ]}
        />
        {job.cancellationReason !== null && (
          <Text variant="caption" color="textSecondary" style={styles.motivo}>
            Motivo: {job.cancellationReason}
          </Text>
        )}
      </Card>

      <Card padding="lg">
        <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
          LA SOLICITUD
        </Text>
        {job.serviceType === 'parcel' ? (
          <Dato etiqueta="Servicio" valor={job.parcelDescription ?? 'Encomienda'} />
        ) : (
          <Dato
            etiqueta="Pasajeros"
            valor={job.passengerCount === 1 ? '1 pasajero' : `${job.passengerCount} pasajeros`}
          />
        )}
        {job.passengerName !== null && <Dato etiqueta="Pasajero" valor={job.passengerName} />}
        <Dato
          etiqueta="Estabas a"
          valor={job.pickupMeters !== null ? formatDistance(job.pickupMeters) : 'Sin registro'}
        />
      </Card>

      {/* El valor, solo cuando hay uno que mostrar. Nulo en las solicitudes de
          antes de D217, que no tenian tarifa calculada. */}
      {job.fareAmount !== null && (
        <Card padding="lg">
          <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
            EL VALOR
          </Text>
          <View style={styles.valorCabecera}>
            <Wallet size={iconSize.lg} color={colors.brand} strokeWidth={iconStrokeWidth} />
            <View style={styles.valorTextos}>
              <Text variant="heading">{formatAmount(job.fareAmount)}</Text>
              {/* D277: si el pasajero ofrecio algo distinto de la tarifa, el
                  desglose de abajo -que es el de la tarifa oficial- ya no suma
                  este valor, y ensenarlo seria mostrar cuentas que no cuadran.
                  Se dice de que se aparto en lugar de eso. */}
              {ofertaDistinta && (
                <Text variant="caption" color="textSecondary">
                  Oferta del pasajero · Tarifa {formatAmount(tarifaOficial ?? 0)}
                </Text>
              )}
              {!ofertaDistinta && job.fareReference !== null && (
                <Text variant="caption" color="textSecondary">
                  Tarifa de {job.fareReference}
                </Text>
              )}
              {!ofertaDistinta && job.fareIsNight === true && (
                <Text variant="caption" color="textSecondary">
                  Con recargo nocturno
                </Text>
              )}
            </View>
          </View>
          {!ofertaDistinta &&
            job.serviceType === 'passenger' &&
            job.fareCargoAmount !== null &&
            job.fareCargoAmount > 0 && (
              <>
                <Dato etiqueta="Viaje" valor={formatAmount(job.fareTripAmount ?? 0)} />
                <Dato etiqueta="Carga" valor={formatAmount(job.fareCargoAmount)} />
              </>
            )}
          {cargaDelServicio.length > 0 && (
            <View style={styles.carga}>
              <Package
                size={iconSize.xs}
                color={colors.textTertiary}
                strokeWidth={iconStrokeWidth}
              />
              <Text variant="caption" color="textSecondary" style={styles.cargaTexto}>
                {cargaDelServicio
                  .map((linea) =>
                    linea.quantity > 1
                      ? `${linea.cargoTypeName} ×${linea.quantity}`
                      : linea.cargoTypeName,
                  )
                  .join(', ')}
              </Text>
            </View>
          )}
        </Card>
      )}

      {job.rideId !== null && (
        <Card padding="lg">
          <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
            EL RECORRIDO
          </Text>
          <Dato
            etiqueta="Distancia"
            valor={job.meters !== null ? formatDistance(job.meters) : 'Sin registro'}
          />
          <Dato
            etiqueta="Duración"
            valor={job.seconds !== null ? formatDuration(job.seconds) : 'Sin registro'}
          />
        </Card>
      )}

      {/* La calificacion, o la forma de darla. Va al final: es lo ultimo que se
          hace con un viaje, y solo aparece cuando hubo viaje que calificar. */}
      {job.alreadyRated !== null && (
        <Card padding="lg">
          <Text variant="label" color="textSecondary" style={styles.tituloBloque}>
            TU CALIFICACIÓN
          </Text>

          {job.myStars !== null ? (
            <View style={styles.calificacion}>
              <StarPicker value={job.myStars} size={22} />
              {job.myComment !== null && (
                <Text variant="caption" color="textSecondary">
                  {job.myComment}
                </Text>
              )}
            </View>
          ) : (
            <View style={styles.calificacion}>
              <Text variant="caption" color="textSecondary">
                Todavía no calificaste este servicio.
              </Text>
              <Button
                label="Calificar"
                variant="secondary"
                fullWidth
                onPress={() =>
                  router.push({
                    pathname: '/driver/rate/[id]',
                    params: {
                      id: job.rideId ?? '',
                      ...(job.passengerName !== null ? { name: job.passengerName } : {}),
                    },
                  })
                }
              />
            </View>
          )}
        </Card>
      )}
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

/**
 * Que dice el segundo paso de la linea de tiempo.
 *
 * La hora es la misma —cuando la oferta dejo de estar pendiente— pero lo que
 * ocurrio no: aceptar es una decision suya, y que se la llevara otro o se
 * acabara el tiempo no lo son.
 */
function etiquetaRespuesta(job: DriverJobDetail): string {
  switch (job.outcome) {
    case 'rejected':
      return 'La rechazaste';
    case 'taken_by_other':
      return 'La tomó otro conductor';
    case 'expired':
      return 'Se agotó el tiempo';
    default:
      return 'La aceptaste';
  }
}

function presentacionDe(job: DriverJobDetail) {
  switch (job.outcome) {
    case 'completed':
      return { icon: CircleCheck, color: 'success' as const, titulo: 'Terminado' };
    case 'cancelled':
      return {
        icon: CircleSlash,
        color: 'danger' as const,
        titulo:
          job.cancelledBy === 'passenger'
            ? 'Lo canceló el pasajero'
            : job.cancelledBy === 'driver'
              ? 'Lo cancelaste'
              : job.cancelledBy === 'admin'
                ? 'Lo canceló la empresa'
                : 'Cancelado',
      };
    case 'rejected':
      return { icon: CircleSlash, color: 'warning' as const, titulo: 'La rechazaste' };
    case 'taken_by_other':
      return { icon: UserCheck, color: 'textTertiary' as const, titulo: 'La tomó otro conductor' };
    case 'expired':
      return { icon: TimerOff, color: 'textTertiary' as const, titulo: 'Se agotó el tiempo' };
    default:
      return { icon: CircleHelp, color: 'textTertiary' as const, titulo: 'Sin detalle' };
  }
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
  calificacion: { alignItems: 'flex-start', gap: spacing.md },

  valorCabecera: { alignItems: 'center', flexDirection: 'row', gap: spacing.md },
  valorTextos: { gap: spacing.xxs },
  carga: { flexDirection: 'row', gap: spacing.xs, marginTop: spacing.sm },
  cargaTexto: { flex: 1 },
});
