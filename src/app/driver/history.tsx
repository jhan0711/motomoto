import { History } from 'lucide-react-native';

import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';

/**
 * Driver service history.
 *
 * No back control: this is a tab root, not a pushed screen. Built for real in
 * Phase 16.
 */
export default function DriverHistory() {
  return (
    <Screen header={<Header title="Servicios realizados" />}>
      <EmptyState
        icon={History}
        title="Sin servicios todavía"
        description="Aquí verás los viajes que completes, con su fecha, su recorrido y la calificación que recibas."
      />
    </Screen>
  );
}
