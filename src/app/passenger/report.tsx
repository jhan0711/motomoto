import { useLocalSearchParams } from 'expo-router';

import { ReportForm } from '@/features/report/report-form';

/**
 * Reportar un problema, pasajero.
 *
 * La pantalla entera vive en `features/report`: lo unico que cambia entre los
 * dos roles son los motivos que se ofrecen. Esta ruta existe porque los
 * `_layout` de cada rol son los que protegen el acceso.
 */
export default function PassengerReport() {
  const { rideId, rideLabel } = useLocalSearchParams<{ rideId?: string; rideLabel?: string }>();

  return <ReportForm rideId={rideId} rideLabel={rideLabel} />;
}
