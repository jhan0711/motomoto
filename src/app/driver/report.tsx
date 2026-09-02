import { useLocalSearchParams } from 'expo-router';

import { ReportForm } from '@/features/report/report-form';

/** Reportar un problema, conductor. Ver el comentario de la ruta del pasajero. */
export default function DriverReport() {
  const { rideId, rideLabel } = useLocalSearchParams<{ rideId?: string; rideLabel?: string }>();

  return <ReportForm rideId={rideId} rideLabel={rideLabel} />;
}
