-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Deja el historial de la pasajera de prueba (`pasajero.prueba@motomoto-qa.co`,
-- "Ana Gomez") con SEIS viajes terminados, limpios, para la captura 4 de la
-- ficha de Play Store (`assets/store/capturas/4-historial.png`).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_qa_history.sql
--
-- QUE HACE:
--   1. Renombra los dos conductores QA a nombres realistas (Luis Fernando Muñoz
--      / Andrés Zapata). `full_name` no lo protege `protect_profile_columns`
--      (solo cubre `role` y `status`).
--   2. Borra TODO el historial de Ana (`ride_requests` -> cascada a `rides`,
--      `ride_offers`, `ratings`, `ride_locations`).
--   3. Inserta seis solicitudes `completed` con su viaje y su oferta aceptada,
--      repartidas entre los dos conductores, con pares de lugares reales de
--      Amalfi leidos de `places` (nunca coordenadas a mano).
--
-- REVERSIBLE: `remove_qa_history.sql` deshace esto (borra el historial y
-- restaura los nombres). `purge_qa_accounts.sql` tambien lo limpia (borra las
-- cuentas enteras) antes del lanzamiento.
--
-- OJO CON LAS PRUEBAS: `prueba_historial.sql` y
-- `prueba_h15_telefono_contraparte.sql` esperan los nombres "Ana Gomez" /
-- "Conductor de prueba". Con este seed puesto fallan. Correr
-- `remove_qa_history.sql` antes de la suite.
--
-- IDEMPOTENTE: se puede correr varias veces; cada corrida borra y rehace.
-- =============================================================================

begin;

do $seed$
declare
  c_ana   constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_cond1 constant uuid := 'd0000000-0000-4000-8000-000000000001';
  c_cond2 constant uuid := 'd0000000-0000-4000-8000-000000000002';
  v_veh1  uuid;
  v_veh2  uuid;

  -- Pares de lugares (origen, destino) para los seis viajes. Se resuelven contra
  -- `places` mas abajo; si alguno falta, la corrida aborta y no toca nada.
  v_pares constant text[][] := array[
    ['El parque',          'El hospital'],
    ['Alto de la Virgen',  'El parque'],
    ['La bomba',           'El coliseo'],
    ['El parque',          'Alto de Maruchita'],
    ['La zona rosa',       'El parque'],
    ['El cementerio',      'Alto de la Virgen']
  ];

  -- Por viaje: minutos hacia atras del inicio, conductor, vehiculo, distancia,
  -- duracion en segundos.
  v_cond    uuid;
  v_veh     uuid;
  v_o_loc   extensions.geography;
  v_d_loc   extensions.geography;
  v_o_lbl   text;
  v_d_lbl   text;
  v_req     uuid;
  v_ride    uuid;
  v_start   timestamptz;
  v_dist    int;
  v_dur     int;
  i         int;
begin
  -- 1. Nombres realistas. La pasajera QA pasa a "Camila Restrepo" para que la
  --    captura de inicio (`2-inicio`) y la de perfil (`3-perfil`, hecha con una
  --    cuenta demo aparte con ese mismo nombre) muestren la misma persona.
  update public.profiles set full_name = 'Camila Restrepo'      where id = c_ana;
  update public.profiles set full_name = 'Luis Fernando Muñoz'  where id = c_cond1;
  update public.profiles set full_name = 'Andrés Zapata'        where id = c_cond2;

  select vehicle_id into v_veh1 from public.driver_vehicle_assignments
   where driver_id = c_cond1 and unassigned_at is null limit 1;
  select vehicle_id into v_veh2 from public.driver_vehicle_assignments
   where driver_id = c_cond2 and unassigned_at is null limit 1;

  if v_veh1 is null or v_veh2 is null then
    raise exception 'Falta vehiculo asignado: cond1=% cond2=%', v_veh1, v_veh2;
  end if;

  -- 2. Fuera el historial actual de Ana (cascada se lleva rides/offers/ratings).
  delete from public.ride_requests where passenger_id = c_ana;

  -- 3. Seis viajes terminados.
  for i in 1 .. array_length(v_pares, 1) loop
    v_o_lbl := v_pares[i][1];
    v_d_lbl := v_pares[i][2];

    select location into v_o_loc from public.places where name = v_o_lbl and is_active;
    select location into v_d_loc from public.places where name = v_d_lbl and is_active;
    if v_o_loc is null or v_d_loc is null then
      raise exception 'Lugar no encontrado en places: origen=% destino=%', v_o_lbl, v_d_lbl;
    end if;

    -- Alterna conductor, y escalona los viajes: el 1 hace ~3 h, el 6 hace ~4 dias.
    if i % 2 = 1 then v_cond := c_cond1; v_veh := v_veh1;
    else                 v_cond := c_cond2; v_veh := v_veh2;
    end if;
    v_start := now() - make_interval(hours => 3, days => (i - 1))
                     - make_interval(mins => (i * 7));
    v_dist  := 500 + i * 180;                 -- 680 .. 1580 m
    v_dur   := 120 + i * 45;                  -- 165 .. 390 s  (~2-6 min)

    v_req  := gen_random_uuid();
    v_ride := gen_random_uuid();

    insert into public.ride_requests (
      id, passenger_id, status, passenger_count,
      origin, origin_label, destination, destination_label,
      contact_phone, requested_at, expires_at, assigned_at, started_at, completed_at,
      fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural,
      service_type
    ) values (
      v_req, c_ana, 'completed', 1,
      v_o_loc, v_o_lbl, v_d_loc, v_d_lbl,
      '3001234567',
      v_start - interval '3 minutes', v_start + interval '2 minutes',
      v_start - interval '2 minutes', v_start,
      v_start + make_interval(secs => v_dur),
      4000, 4000, 0, false, false, 'passenger'
    );

    insert into public.rides (
      id, request_id, driver_id, vehicle_id, status, passenger_count,
      accepted_at, driver_arrived_at, started_at, completed_at, distance_m, duration_s
    ) values (
      v_ride, v_req, v_cond, v_veh, 'completed', 1,
      v_start - interval '2 minutes', v_start - interval '20 seconds',
      v_start, v_start + make_interval(secs => v_dur), v_dist, v_dur
    );

    insert into public.ride_offers (
      id, request_id, driver_id, offered_at, expires_at, response, responded_at, distance_m
    ) values (
      gen_random_uuid(), v_req, v_cond,
      v_start - interval '150 seconds', v_start - interval '120 seconds',
      'accepted', v_start - interval '120 seconds', 140
    );

    -- Ana califica al conductor en los viajes que no son de los ultimos dos
    -- dias: lo normal es que la calificacion mas reciente aun este pendiente.
    if i >= 3 then
      insert into public.ratings (id, ride_id, rater_id, rated_id, stars, comment)
      values (gen_random_uuid(), v_ride, c_ana, v_cond,
              case when i = 4 then 4 else 5 end, null);
    end if;
  end loop;

  raise notice 'Historial de Ana: 6 viajes terminados, 4 calificados. Conductores renombrados.';
end
$seed$;

-- Lo que quedo, para verlo en la salida.
select
  rr.status,
  to_char(rr.completed_at, 'DD Mon, HH12:MI a.m.') as cuando,
  rr.origin_label || ' -> ' || rr.destination_label as ruta,
  p.full_name as conductor,
  ri.duration_s / 60 || ' min' as duracion
from public.ride_requests rr
join public.rides ri on ri.request_id = rr.id
join public.profiles p on p.id = ri.driver_id
where rr.passenger_id = 'ad000000-0000-4000-8000-0000000000f1'
order by rr.requested_at desc;

commit;
