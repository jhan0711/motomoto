import { useRouter } from 'expo-router';
import { History } from 'lucide-react-native';

import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Screen } from '@/components/ui/screen';

/**
 * Passenger trip history.
 *
 * Shows the empty state because there is no data source yet. Built for real in
 * Phase 16, once rides exist.
 */
export default function PassengerHistory() {
  const router = useRouter();

  return (
    <Screen header={<Header title="Mis viajes" onBack={() => router.back()} />}>
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
