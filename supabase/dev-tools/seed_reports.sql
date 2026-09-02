-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Crea CUATRO reportes para poder mirar la bandeja del panel (Fase 20, paso
-- 10a) con contenido de verdad. Sin esto la bandeja se ve vacia: **nadie ha
-- reportado nunca nada**, porque la aplicacion no tiene todavia el boton -eso
-- es el paso 10b-.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/seed_reports.sql
--
-- **ESTE SI DEJA FILAS**, a diferencia de los `prueba_*.sql`. Para limpiarlas:
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_reports.sql
--
-- **LIMPIARLAS ANTES DE PASAR LA REGRESION.** Las pruebas se montan su propio
-- mundo y chocan con las filas que deja esto; paso el 2026-09-01 con
-- `seed_active_service.sql` y nueve archivos rotos por
-- `rr_one_active_per_passenger`.
--
-- Es idempotente: se puede ejecutar varias veces sin duplicar nada.
-- =============================================================================

do $semilla$
declare
  c_r1 constant uuid := 'ad000000-0000-4000-8000-0000000000f1';
  c_r2 constant uuid := 'ad000000-0000-4000-8000-0000000000f2';
  c_r3 constant uuid := 'ad000000-0000-4000-8000-0000000000f3';
  c_r4 constant uuid := 'ad000000-0000-4000-8000-0000000000f4';

  v_pas1  uuid;
  v_pas2  uuid;
  v_cond  uuid;
  v_admin uuid;
  v_ride  uuid;
begin
  select id into v_pas1 from public.profiles
   where role = 'passenger' and status = 'active' order by created_at limit 1;
  select id into v_pas2 from public.profiles
   where role = 'passenger' and status = 'active' and id <> v_pas1
   order by created_at limit 1;
  select id into v_cond from public.profiles
   where role = 'driver' and status = 'active' order by created_at limit 1;
  select id into v_admin from public.profiles
   where role = 'admin' order by created_at limit 1;

  -- **UN VIAJE TERMINADO Y LOS DOS QUE LO HICIERON.** No vale coger un viaje
  -- cualquiera y colgarle el reporte del primer pasajero que haya: si quien
  -- reporta no estuvo en ese viaje, la bandeja lo dice -y con razon-, pero
  -- entonces los datos de prueba no ensenan el caso normal. Se toman **el
  -- pasajero y el conductor de ese mismo viaje**.
  select r.id, r.driver_id, rq.passenger_id
    into v_ride, v_cond, v_pas1
  from public.rides r
  join public.ride_requests rq on rq.id = r.request_id
  where r.status = 'completed'
  order by r.completed_at desc limit 1;

  -- Si no hubiera ningun viaje terminado, se sigue con los perfiles sueltos y
  -- los reportes quedan sin servicio: la pantalla lo aguanta.
  if v_ride is null then
    select id into v_pas1 from public.profiles
     where role = 'passenger' and status = 'active' order by created_at limit 1;
    select id into v_cond from public.profiles
     where role = 'driver' and status = 'active' order by created_at limit 1;
  end if;

  if v_pas1 is null or v_cond is null then
    raise exception 'Faltan perfiles de prueba: no hay pasajero o conductor activo';
  end if;

  delete from public.reports where id in (c_r1, c_r2, c_r3, c_r4);

  -- CUATRO SITUACIONES DISTINTAS, que es lo que hace util mirar la pantalla:
  -- uno viejo sin atender, uno reciente, uno en revision y uno ya cerrado.
  insert into public.reports (id, reporter_id, ride_id, category, description, status, created_at)
  values
    (c_r1, v_pas1, v_ride, 'cobro',
     'El conductor me cobro 8.000 pesos y la aplicacion decia 6.200 cuando lo pedi.',
     'open', now() - interval '4 days'),

    (c_r2, v_pas1, null, 'aplicacion',
     'La aplicacion se cerro sola dos veces cuando iba a pedir el servicio desde el parque.',
     'open', now() - interval '3 hours'),

    (c_r3, v_cond, v_ride, 'trato',
     'El pasajero venia con tres personas y en la solicitud decia una sola.',
     'in_review', now() - interval '1 day');

  insert into public.reports (id, reporter_id, ride_id, category, description,
                              status, resolved_at, resolved_by, resolution_notes, created_at)
  values
    (c_r4, coalesce(v_pas2, v_pas1), null, 'objeto olvidado',
     'Deje una chaqueta azul en el motorraton, era el servicio de ayer en la tarde.',
     'resolved', now() - interval '6 hours', v_admin,
     'Se ubico al conductor, tenia la chaqueta y se entrego en la oficina.',
     now() - interval '2 days');
end
$semilla$;


select
  r.category as categoria,
  r.status as estado,
  p.full_name as lo_reporto,
  case when r.ride_id is null then '(sin servicio)' else 'con servicio' end as servicio,
  date_trunc('minute', now() - r.created_at)::text as lleva_esperando
from public.reports r
join public.profiles p on p.id = r.reporter_id
where r.id::text like 'ad000000%'
order by (r.status = 'resolved'), r.created_at;
