import { LocateOff, MapPinOff, RotateCw, Settings } from 'lucide-react-native';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { Screen } from '@/components/ui/screen';
import { spacing } from '@/theme';

import type { LocationState } from './use-location';

/** The states that stop us from placing the passenger on the map. */
export type BlockingState = Extract<
  LocationState,
  { kind: 'permission-required' } | { kind: 'services-disabled' } | { kind: 'unavailable' }
>;

/**
 * Narrows a location state to a blocking one, or null if nothing is blocking.
 *
 * A `switch` rather than a boolean check so TypeScript does the narrowing for
 * us. Testing `kind === 'a' || kind === 'b'` and then asserting the type would
 * compile just as well and would keep compiling after someone adds a new state,
 * which is exactly when it would start being wrong.
 */
export function blockingState(state: LocationState): BlockingState | null {
  switch (state.kind) {
    case 'permission-required':
    case 'services-disabled':
    case 'unavailable':
      return state;
    case 'checking':
    case 'locating':
    case 'ready':
      return null;
  }
}

export interface LocationGateProps {
  state: BlockingState;
  onRequestPermission: () => void;
  onEnableServices: () => void;
  onOpenSettings: () => void;
  onRetry: () => void;
  /** Lets the passenger carry on with the map centered on Amalfi. */
  onSkip: () => void;
}

/**
 * The explanation shown before, and instead of, the map when we cannot locate
 * the passenger.
 *
 * This screen exists because of how Android handles permissions: deny the system
 * dialog twice and it never appears again. Spending that dialog without having
 * said what the permission is for wastes something we cannot get back, so the
 * request always comes from a button the passenger chose to press.
 *
 * Every branch has a way out. Acceptance criterion 6 of the MVP requires that
 * denying location does not break the app, and an escape that only leads back to
 * the same wall is not a way out.
 */
export function LocationGate({
  state,
  onRequestPermission,
  onEnableServices,
  onOpenSettings,
  onRetry,
  onSkip,
}: LocationGateProps) {
  const content = resolve(state);

  return (
    <Screen>
      <View style={styles.container}>
        <EmptyState
          icon={content.icon}
          title={content.title}
          description={content.description}
          actionLabel={content.actionLabel}
          onAction={
            {
              request: onRequestPermission,
              settings: onOpenSettings,
              services: onEnableServices,
              retry: onRetry,
            }[content.action]
          }
        />

        <Button label="Continuar sin ubicación" variant="ghost" onPress={onSkip} />
      </View>
    </Screen>
  );
}

type ActionKind = 'request' | 'settings' | 'services' | 'retry';

interface GateContent {
  icon: typeof MapPinOff;
  title: string;
  description: string;
  actionLabel: string;
  action: ActionKind;
}

function resolve(state: BlockingState): GateContent {
  switch (state.kind) {
    case 'permission-required':
      return state.canAsk
        ? {
            icon: MapPinOff,
            title: 'Necesitamos saber dónde estás',
            description:
              'MotoMoto usa tu ubicación para mostrarte en el mapa y para que el conductor sepa dónde recogerte. Solo mientras tengas la aplicación abierta.',
            actionLabel: 'Permitir ubicación',
            action: 'request',
          }
        : {
            icon: Settings,
            title: 'El permiso está desactivado',
            description:
              'Denegaste el permiso de ubicación, así que Android ya no vuelve a preguntarlo. Puedes activarlo desde los ajustes del teléfono, en Permisos.',
            actionLabel: 'Abrir ajustes',
            action: 'settings',
          };

    case 'services-disabled':
      return {
        icon: LocateOff,
        title: 'La ubicación del teléfono está apagada',
        description:
          'Diste el permiso, pero el teléfono tiene la ubicación desactivada. Actívala para que podamos encontrarte.',
        actionLabel: 'Activar ubicación',
        action: 'services',
      };

    case 'unavailable':
      return {
        icon: RotateCw,
        title: 'No conseguimos tu ubicación',
        description:
          'Puede pasar bajo techo o con mala señal de satélite. Sal a un espacio abierto e inténtalo otra vez.',
        actionLabel: 'Reintentar',
        action: 'retry',
      };
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: spacing.md,
    justifyContent: 'center',
  },
});
