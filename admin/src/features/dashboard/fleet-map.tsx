'use client';

import { useEffect, useRef } from 'react';
import mapboxgl from 'mapbox-gl';
// El CSS de mapbox-gl se importa una sola vez, desde app/layout.tsx: Next solo
// empaqueta con fiabilidad el CSS global importado desde el layout raiz.
import type { DriverLocation } from './use-driver-locations';

/** Parque principal de Amalfi. Misma coordenada que `AMALFI_CENTER` en la app
 * movil (`features/map/region.ts`): es donde opera el servicio, y donde tiene
 * sentido abrir el mapa antes de que se sepa donde esta cada conductor. */
const AMALFI_CENTER: [number, number] = [-75.074987, 6.907392];

/**
 * Color del punto de cada conductor, mismo criterio que la insignia de
 * `driver-row.tsx`: verde disponible, el naranja de la marca en viaje -mismo
 * tono que la notificacion del segundo plano, D271-, gris el resto.
 */
function colorDe(u: DriverLocation): string {
  if (u.hasActiveRide) return '#f27127';
  if (u.isAvailable) return '#0e9f6e';
  return '#a1a1aa';
}

function crearMarcadorEl(u: DriverLocation): HTMLDivElement {
  const el = document.createElement('div');
  el.style.width = '16px';
  el.style.height = '16px';
  el.style.borderRadius = '50%';
  el.style.border = '2px solid white';
  el.style.boxShadow = '0 1px 3px rgba(0,0,0,0.4)';
  el.style.backgroundColor = colorDe(u);
  el.style.cursor = 'pointer';
  return el;
}

function popupHtml(u: DriverLocation): string {
  const vehiculo =
    u.unitNumber !== null
      ? `Motocarro ${u.unitNumber}${u.plate ? ` · ${u.plate}` : ''}`
      : 'Sin motocarro asignado';
  const estado = u.hasActiveRide ? 'En viaje' : u.isAvailable ? 'Disponible' : 'No disponible';
  const antiguedad =
    u.ageSeconds < 60 ? `hace ${u.ageSeconds} s` : `hace ${Math.round(u.ageSeconds / 60)} min`;
  return `
    <div style="font-size:13px;line-height:1.4">
      <strong>${u.fullName}</strong><br/>
      ${vehiculo}<br/>
      ${estado} · posición ${antiguedad}
    </div>
  `;
}

export interface FleetMapProps {
  ubicaciones: DriverLocation[];
}

/**
 * Mapa de toda la flota (pedido de la empresa, 2026-09-16).
 *
 * NO ES TIEMPO REAL, a proposito: recibe `ubicaciones` ya consultadas por
 * `useDriverLocations` cada diez segundos, mismo motivo que el resto del
 * tablero (ver ese hook). Un mapa de flota sirve para saber donde esta cada
 * quien a grandes rasgos, no para seguir a un conductor en concreto -eso ya lo
 * hace el pasajero con su propio conductor, en tiempo real-.
 *
 * LOS MARCADORES SE ACTUALIZAN EN SITIO, sin recrear el mapa en cada
 * refresco: recrearlo perdería el zoom y el encuadre que el despachador ya
 * ajustó con la mano.
 */
export function FleetMap({ ubicaciones }: FleetMapProps) {
  const contenedorRef = useRef<HTMLDivElement>(null);
  const mapaRef = useRef<mapboxgl.Map | null>(null);
  const marcadoresRef = useRef<Map<string, mapboxgl.Marker>>(new Map());

  useEffect(() => {
    if (contenedorRef.current === null || mapaRef.current !== null) return;

    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN;
    if (token === undefined || token === '') return;

    mapboxgl.accessToken = token;
    mapaRef.current = new mapboxgl.Map({
      container: contenedorRef.current,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: AMALFI_CENTER,
      zoom: 13,
    });
    mapaRef.current.addControl(new mapboxgl.NavigationControl(), 'top-right');

    const marcadores = marcadoresRef.current;
    return () => {
      mapaRef.current?.remove();
      mapaRef.current = null;
      marcadores.clear();
    };
  }, []);

  useEffect(() => {
    const mapa = mapaRef.current;
    if (mapa === null) return;

    const vigentes = new Set(ubicaciones.map((u) => u.driverId));

    // Se quitan los marcadores de conductores que ya no traen posición -no
    // debería pasar con esta consulta, que siempre devuelve la última fila,
    // pero un conductor eliminado sí puede desaparecer de un refresco a otro.
    for (const [driverId, marcador] of marcadoresRef.current) {
      if (!vigentes.has(driverId)) {
        marcador.remove();
        marcadoresRef.current.delete(driverId);
      }
    }

    for (const u of ubicaciones) {
      const existente = marcadoresRef.current.get(u.driverId);
      if (existente) {
        existente.setLngLat([u.longitude, u.latitude]);
        existente.getElement().style.backgroundColor = colorDe(u);
        existente.getPopup()?.setHTML(popupHtml(u));
        continue;
      }

      const marcador = new mapboxgl.Marker({ element: crearMarcadorEl(u) })
        .setLngLat([u.longitude, u.latitude])
        .setPopup(new mapboxgl.Popup({ offset: 12 }).setHTML(popupHtml(u)))
        .addTo(mapa);
      marcadoresRef.current.set(u.driverId, marcador);
    }
  }, [ubicaciones]);

  return (
    <div
      ref={contenedorRef}
      className="mt-4 h-[420px] w-full overflow-hidden rounded-xl border border-border"
    />
  );
}
