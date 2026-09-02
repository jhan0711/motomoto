// =============================================================================
// HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
// =============================================================================
//
// Prueba de punta a punta del canal de tiempo real de `driver_locations`, que la
// Fase 24 paso 3 acaba de adelgazar (`20260903120000_driver_locations_realtime_trim.sql`).
//
//   node supabase/dev-tools/prueba_posicion_realtime.mjs
//
// NO ES SQL: la publicacion, el filtro y las politicas RLS de tiempo real solo
// se ejercen de verdad con un cliente suscrito. Es el primer y unico test que
// mira ese camino, y existe para que un cambio futuro en la publicacion o en la
// RLS que rompa "el pasajero ve moverse al conductor" -el criterio de aceptacion
// 4- se note aqui y no en la calle.
//
// LO QUE MONTA Y DESHACE, todo por la API real y con cuentas @motomoto-qa.co:
//   - el conductor de prueba se pone disponible y publica su posicion en el parque
//   - el pasajero de prueba pide un servicio; el conductor lo acepta
//   - ahora el pasajero tiene un viaje activo con ese conductor, que es lo que
//     abre `driver_locations_select_active_passenger`
//   - el pasajero se suscribe; el conductor mueve su posicion dos veces
//   - se comprueba que el evento llega rapido y que trae lat/lng/heading/updated_at
//     listas para pintar el motorraton SIN una re-consulta (arreglo B, Fase 22 paso 7)
//   - al final el pasajero cancela y el conductor se marca no disponible
//
// NOTA sobre el payload: Supabase Realtime (wal2json) manda SIEMPRE la fila
// entera, aunque la publicacion tenga lista de columnas. El evento trae tambien
// `location`, `speed_kmh` y `accuracy_m`, que el cliente no usa. Adelgazar eso
// exige pasar a Broadcast, que es otra fase. Ver `20260903120000`.
// =============================================================================

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const env = readFileSync(resolve(raiz, '.env'), 'utf8');
const leer = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const URL = leer('EXPO_PUBLIC_SUPABASE_URL');
const KEY = leer('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY');

const PASAJERO = { email: 'pasajero.prueba@motomoto-qa.co', password: 'Pasajero.2026' };
const CONDUCTOR = { email: 'conductor.prueba@motomoto-qa.co', password: 'Conductor.2026' };

// El parque, dentro de la zona de servicio de Amalfi.
const PARQUE = { lng: -75.074987, lat: 6.907392 };

const nuevoCliente = () =>
  createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

const resultados = [];
const comprobar = (n, comprobacion, ok, detalle) =>
  resultados.push({ n, comprobacion, ok, detalle: detalle ?? '' });

const espera = (ms) => new Promise((r) => setTimeout(r, ms));

async function entrar(cliente, cred) {
  const { data, error } = await cliente.auth.signInWithPassword(cred);
  if (error) throw new Error(`no pude entrar como ${cred.email}: ${error.message}`);
  return data.user.id;
}

/** Sobrescribe la posicion del conductor, igual que hace `reportLocation` del cliente. */
async function moverConductor(conductorCli, driverId, lng, lat, heading) {
  const { error } = await conductorCli.from('driver_locations').upsert(
    {
      driver_id: driverId,
      location: `SRID=4326;POINT(${lng} ${lat})`,
      heading,
      speed_kmh: 18,
      accuracy_m: 5,
    },
    { onConflict: 'driver_id' },
  );
  if (error) throw new Error(`upsert de posicion: ${error.message}`);
}

async function limpiarPasajero(pasajeroCli) {
  const { data } = await pasajeroCli.rpc('get_active_request');
  const viva = (data ?? [])[0];
  if (viva) await pasajeroCli.rpc('cancel_request', { p_request_id: viva.id, p_reason: 'prueba' });
}

async function main() {
  const conductorCli = nuevoCliente();
  const pasajeroCli = nuevoCliente();

  const driverId = await entrar(conductorCli, CONDUCTOR);
  await entrar(pasajeroCli, PASAJERO);

  // --- Montaje ---------------------------------------------------------------

  await limpiarPasajero(pasajeroCli);

  // Cualquier viaje que el conductor arrastrara de una corrida anterior.
  const { data: activos } = await conductorCli.rpc('list_driver_active_rides');
  for (const v of activos ?? []) {
    await conductorCli.rpc('cancel_ride', { p_ride_id: v.ride_id, p_reason: 'prueba' });
  }

  await conductorCli.from('drivers').update({ is_available: true }).eq('id', driverId);
  await moverConductor(conductorCli, driverId, PARQUE.lng, PARQUE.lat, 90);

  // El pasajero pide; el conductor acepta.
  const { data: reqId, error: eReq } = await pasajeroCli.rpc('request_ride', {
    p_origin_lng: PARQUE.lng,
    p_origin_lat: PARQUE.lat,
    p_origin_label: 'El parque',
    p_destination_lng: PARQUE.lng,
    p_destination_lat: PARQUE.lat,
    p_destination_label: 'El parque',
    p_passenger_count: 1,
  });
  if (eReq) throw new Error(`request_ride: ${eReq.message} (${eReq.hint ?? ''})`);

  const { data: ofertas } = await conductorCli.rpc('list_driver_offers');
  const oferta = (ofertas ?? []).find((o) => o.request_id === reqId);
  if (!oferta) throw new Error('al conductor no le llego la oferta del servicio de prueba');

  const { error: eAcc } = await conductorCli.rpc('accept_ride_offer', { p_offer_id: oferta.offer_id });
  if (eAcc) throw new Error(`accept_ride_offer: ${eAcc.message} (${eAcc.hint ?? ''})`);

  comprobar(1, 'Montaje: el pasajero tiene un viaje activo con el conductor', true);

  // --- La suscripcion -------------------------------------------------------

  const recibidos = [];
  let suscrito = false;

  const canal = pasajeroCli
    .channel(`prueba-posicion-${driverId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'driver_locations',
        filter: `driver_id=eq.${driverId}`,
      },
      (payload) => recibidos.push({ t: Date.now(), payload }),
    )
    .subscribe((estado) => {
      if (estado === 'SUBSCRIBED') suscrito = true;
    });

  for (let i = 0; i < 50 && !suscrito; i++) await espera(100);
  comprobar(2, 'El canal de tiempo real se suscribe', suscrito);

  // --- Mover al conductor y medir ------------------------------------------

  const antes = recibidos.length;
  const t0 = Date.now();
  await moverConductor(conductorCli, driverId, PARQUE.lng + 0.001, PARQUE.lat + 0.001, 135);

  for (let i = 0; i < 60 && recibidos.length === antes; i++) await espera(100);
  const llego = recibidos.length > antes;
  const ms = llego ? recibidos[recibidos.length - 1].t - t0 : null;
  comprobar(3, 'Mover la posicion dispara un evento en el pasajero', llego,
    llego ? `${ms} ms` : 'no llego en 6 s');

  if (llego) {
    const fila = recibidos[recibidos.length - 1].payload.new;

    comprobar(4, 'El evento trae lat y lng utiles',
      typeof fila.lat === 'number' && typeof fila.lng === 'number',
      `lat=${fila.lat}, lng=${fila.lng}`);

    comprobar(5, 'lat/lng coinciden con la posicion recien enviada',
      Math.abs(fila.lat - (PARQUE.lat + 0.001)) < 1e-4 &&
        Math.abs(fila.lng - (PARQUE.lng + 0.001)) < 1e-4,
      `${fila.lat}, ${fila.lng}`);

    comprobar(6, 'El evento trae heading y updated_at',
      fila.heading === 135 && typeof fila.updated_at === 'string',
      `heading=${fila.heading}, updated_at=${fila.updated_at}`);

    // El pasajero pinta directo del evento (arreglo B): `updated_at` tiene que
    // ser una marca reciente y parseable, que es lo que `edadDesde` necesita.
    const edad = (Date.now() - Date.parse(fila.updated_at)) / 1000;
    comprobar(7, 'updated_at es una marca fresca y parseable',
      Number.isFinite(edad) && edad >= 0 && edad < 30,
      `${edad.toFixed(1)} s de antiguedad`);
  } else {
    for (let n = 4; n <= 7; n++) comprobar(n, 'omitida: no llego el evento', false);
  }

  // --- Un segundo movimiento, para ver que no fue casualidad ---------------

  const antes2 = recibidos.length;
  await moverConductor(conductorCli, driverId, PARQUE.lng + 0.002, PARQUE.lat, 200);
  for (let i = 0; i < 60 && recibidos.length === antes2; i++) await espera(100);
  comprobar(8, 'Un segundo movimiento tambien llega', recibidos.length > antes2);

  // --- Limpieza -----------------------------------------------------------

  await pasajeroCli.removeChannel(canal);
  await limpiarPasajero(pasajeroCli);
  await conductorCli.from('drivers').update({ is_available: false }).eq('id', driverId);
  await conductorCli.auth.signOut();
  await pasajeroCli.auth.signOut();
}

main()
  .then(() => {
    let fallando = 0;
    for (const x of resultados) {
      if (!x.ok) fallando++;
      console.log(
        `${x.n}\t${x.ok ? 'OK  ' : 'FALLA'}\t${x.comprobacion}${x.detalle ? '  -> ' + x.detalle : ''}`,
      );
    }
    console.log(
      `999\t${fallando === 0 ? 'OK  ' : 'FALLA'}\tTOTAL\t${resultados.length} comprobaciones, ${fallando} fallando`,
    );
    process.exit(fallando === 0 ? 0 : 1);
  })
  .catch((e) => {
    console.error('ERROR:', e.message);
    console.error('Puede que haya quedado un servicio de prueba a medias; revisar las cuentas @motomoto-qa.co.');
    process.exit(1);
  });
