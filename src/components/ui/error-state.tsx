import { TriangleAlert, WifiOff, type LucideIcon } from 'lucide-react-native';
import type { StyleProp, ViewStyle } from 'react-native';

import { EmptyState } from './empty-state';

export interface ErrorStateProps {
  title?: string;
  description?: string;
  /** Shows a retry button. Omit it and no action is offered. */
  onRetry?: () => void;
  retryLabel?: string;
  /**
   * Switches the icon and default copy to a connectivity failure. Relevant in
   * Amalfi, where mobile coverage is uneven outside the town center.
   */
  offline?: boolean;
  icon?: LucideIcon;
  style?: StyleProp<ViewStyle>;
}

/**
 * Failure state.
 *
 * Built on top of `EmptyState` rather than duplicating its layout: an error is
 * an empty state with a different tone and a retry action. Keeping one layout
 * means both can never drift apart visually.
 *
 * The default copy avoids technical language. "No pudimos cargar la
 * información" is actionable for a passenger; "Error 500" is not.
 */
export function ErrorState({
  title,
  description,
  onRetry,
  retryLabel = 'Reintentar',
  offline = false,
  icon,
  style,
}: ErrorStateProps) {
  const resolvedIcon = icon ?? (offline ? WifiOff : TriangleAlert);

  const resolvedTitle = title ?? (offline ? 'Sin conexión' : 'Algo salió mal');

  const resolvedDescription =
    description ??
    (offline
      ? 'Revisa tu conexión a internet e inténtalo de nuevo.'
      : 'No pudimos cargar la información. Vuelve a intentarlo.');

  return (
    <EmptyState
      icon={resolvedIcon}
      title={resolvedTitle}
      description={resolvedDescription}
      tone="danger"
      actionLabel={onRetry !== undefined ? retryLabel : undefined}
      onAction={onRetry}
      style={style}
    />
  );
}
