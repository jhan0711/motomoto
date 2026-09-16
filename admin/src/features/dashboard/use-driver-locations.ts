'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export interface DriverLocation {
  driverId: string;
  fullName: string;
  isAvailable: boolean;
  hasActiveRide: boolean;
  unitNumber: number | null;
  plate: string | null;
  latitude: number;
  longitude: number;
  ageSeconds: number;
}

/** Mismo intervalo que el resto del tablero (`useActiveServices`): un mapa
 * de flota no necesita tiempo real, y usar el mismo numero hace que todo lo
 * que hay en la pantalla se refresque junto. */
const INTERVALO_MS = 10_000;

interface Estado {
  ubicaciones: DriverLocation[];
  cargando: boolean;
  error: string | null;
}

/** Donde esta cada conductor con posicion conocida, para el mapa de la flota. */
export function useDriverLocations() {
  const [estado, setEstado] = useState<Estado>({ ubicaciones: [], cargando: true, error: null });

  const peticionRef = useRef(0);

  const consultar = useCallback(async () => {
    const miPeticion = ++peticionRef.current;
    const supabase = createClient();
    const { data, error } = await supabase.rpc('admin_list_driver_locations');

    if (miPeticion !== peticionRef.current) return;

    if (error) {
      setEstado((previo) => ({ ...previo, cargando: false, error: error.message }));
      return;
    }

    setEstado({
      ubicaciones: (data ?? [])
        // lat/lng son nulos solo si la columna geography llego vacia, que no
        // deberia pasar tras el disparador de la Fase 22 paso 7; se descartan
        // en vez de pintar un marcador en 0,0.
        .filter((f) => f.latitude !== null && f.longitude !== null)
        .map((f) => ({
          driverId: f.driver_id,
          fullName: f.full_name ?? 'Sin nombre',
          isAvailable: f.is_available ?? false,
          hasActiveRide: f.has_active_ride ?? false,
          unitNumber: f.unit_number,
          plate: f.plate,
          latitude: f.latitude as number,
          longitude: f.longitude as number,
          ageSeconds: f.age_seconds ?? 0,
        })),
      cargando: false,
      error: null,
    });
  }, []);

  useEffect(() => {
    const inicial = setTimeout(() => void consultar(), 0);
    const id = setInterval(() => void consultar(), INTERVALO_MS);
    return () => {
      clearTimeout(inicial);
      clearInterval(id);
    };
  }, [consultar]);

  return { ...estado, recargar: consultar };
}
