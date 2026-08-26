import type { ServiceType } from '@/features/history/history-service';

/**
 * Los dos periodos que ofrece la pantalla. El servidor tambien acepta
 * 'custom' con fechas (`list_driver_earnings`, paso 7), pero esta version no
 * ofrece un selector de rango: "hoy" y "esta semana" cubren la razon de ser
 * del recaudo, que es cuadrar caja con la empresa, y un calendario completo
 * es una pantalla que nadie pidio todavia.
 */
export type EarningsPeriod = 'today' | 'week';

/** Un servicio completado, tal como cuenta para el recaudo. */
export interface EarningsRow {
  rideId: string;
  requestId: string;
  completedAt: string;
  originLabel: string;
  destinationLabel: string;
  serviceType: ServiceType;
  parcelDescription: string | null;
  passengerCount: number;
  /**
   * Nulo en servicios de antes de D217, que no tenian valor calculado. La
   * pantalla los deja fuera del total en vez de sumar un cero que no es
   * cierto.
   */
  fareAmount: number | null;
}
