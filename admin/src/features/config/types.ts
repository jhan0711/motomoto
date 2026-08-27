import type { Database } from '@/lib/supabase/database.types';

export type UrbanFare =
  Database['public']['Functions']['admin_list_urban_fares']['Returns'][number];
export type CargoType =
  Database['public']['Functions']['admin_list_cargo_types']['Returns'][number];
export type Setting = Database['public']['Functions']['admin_list_settings']['Returns'][number];

export function formatearPesos(valor: number | null): string {
  if (valor === null) return '—';
  return '$' + valor.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/**
 * Como se presenta cada parametro.
 *
 * **La tabla `app_settings` mezcla dos cosas muy distintas**: precios y horarios
 * por un lado, y reglas de operacion por otro -los veinte segundos de R2, el
 * radio de llegada de R5-. Viven juntas porque comparten tabla, pero cambiar una
 * tarifa y cambiar el reparto de servicios no son la misma decision, asi que la
 * pantalla las separa.
 *
 * `aviso` no esta en todas: solo en las que tienen consecuencias que no se
 * deducen del nombre.
 */
export interface MetaParametro {
  etiqueta: string;
  grupo: 'tarifas' | 'operacion';
  unidad?: string;
  aviso?: string;
}

export const META: Record<string, MetaParametro> = {
  fare_timezone: {
    etiqueta: 'Zona horaria',
    grupo: 'tarifas',
    aviso: 'Decide a qué hora empieza el recargo nocturno. No es la hora del teléfono.',
  },
  night_fare_start_hour: { etiqueta: 'Empieza el recargo nocturno', grupo: 'tarifas', unidad: 'h' },
  night_fare_end_hour: { etiqueta: 'Termina el recargo nocturno', grupo: 'tarifas', unidad: 'h' },
  fare_center_lng: {
    etiqueta: 'Centro del pueblo, longitud',
    grupo: 'tarifas',
    aviso:
      'Desde aquí se mide todo. Moverlo cambia qué lugares necesitan tarifa propia y cuáles se pueden pedir.',
  },
  fare_center_lat: {
    etiqueta: 'Centro del pueblo, latitud',
    grupo: 'tarifas',
    aviso:
      'Desde aquí se mide todo. Moverlo cambia qué lugares necesitan tarifa propia y cuáles se pueden pedir.',
  },
  rural_snap_max_km: {
    etiqueta: 'Radio para cobrar la tarifa del lugar más cercano',
    grupo: 'tarifas',
    unidad: 'km',
    aviso:
      'Un punto suelto del mapa cobra la tarifa del lugar con nombre más cercano dentro de este radio.',
  },
  unpriced_destination_max_km: {
    etiqueta: 'Distancia máxima sin tarifa propia',
    grupo: 'tarifas',
    unidad: 'km',
    aviso:
      'Más allá de esto, un destino sin tarifa propia no se puede pedir. Es el mismo número que exige tarifa al crear un lugar.',
  },

  offer_response_seconds: {
    etiqueta: 'Tiempo para aceptar una oferta',
    grupo: 'operacion',
    unidad: 's',
    aviso: 'Si se queda corto, las ofertas caducan antes de que el conductor las vea.',
  },
  request_expiry_seconds: {
    etiqueta: 'Caducidad de una solicitud',
    grupo: 'operacion',
    unidad: 's',
  },
  max_passengers_per_request: {
    etiqueta: 'Máximo de pasajeros por servicio',
    grupo: 'operacion',
  },
  free_cancellation_seconds: {
    etiqueta: 'Cancelación sin penalización',
    grupo: 'operacion',
    unidad: 's',
  },
  driver_arrival_radius_m: {
    etiqueta: 'Distancia para confirmar la llegada',
    grupo: 'operacion',
    unidad: 'm',
    aviso: 'El conductor no puede confirmar que llegó si está más lejos que esto.',
  },
  driver_location_stale_seconds: {
    etiqueta: 'Cuándo caduca la posición del conductor',
    grupo: 'operacion',
    unidad: 's',
  },
  location_interval_available_seconds: {
    etiqueta: 'Cada cuánto envía posición estando libre',
    grupo: 'operacion',
    unidad: 's',
  },
  location_interval_in_ride_seconds: {
    etiqueta: 'Cada cuánto envía posición en servicio',
    grupo: 'operacion',
    unidad: 's',
  },
  location_min_distance_m: {
    etiqueta: 'Movimiento mínimo para registrar posición',
    grupo: 'operacion',
    unidad: 'm',
  },
  finished_summary_minutes: {
    etiqueta: 'Cuánto se muestra el resumen al terminar',
    grupo: 'operacion',
    unidad: 'min',
  },
  service_area_margin_m: {
    etiqueta: 'Margen del área de servicio',
    grupo: 'operacion',
    unidad: 'm',
  },
};

export function metaDe(clave: string): MetaParametro {
  return META[clave] ?? { etiqueta: clave, grupo: 'operacion' };
}
