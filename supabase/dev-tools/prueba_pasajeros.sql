-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827220000_admin_passengers.sql` (Fase 20, paso 7: listado de
-- pasajeros con bloqueo).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_pasajeros.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- Se aisla por identificador propio -`b6000000`- y **toda comprobacion que
-- cuente filas filtra por ahi**: hay cuatro pasajeros reales en la base con su
-- historial, y contar sin filtrar es la forma de que esta prueba se ponga roja
-- el dia que alguien pida un viaje. Es la leccion que ya costo cinco veces.
-- =============================================================================

begin;

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated, anon',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated, anon';
end
$permisos$;


-- -----------------------------------------------------------------------------
-- Montaje: tres pasajeros con historiales distintos
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin  uuid := 'b6000000-0000-4000-8000-0000000000a1';
  v_bueno  uuid := 'b6000000-0000-4000-8000-0000000000b1';  -- termina sus viajes
  v_malo   uuid := 'b6000000-0000-4000-8000-0000000000b2';  -- cancela mucho
  v_activo uuid := 'b6000000-0000-4000-8000-0000000000b3';  -- va montado ahora
  v_cond   uuid;
  v_veh    uuid;
  v_lng double precision;
  v_lat double precision;
begin
  select d.id into v_cond from public.drivers d
  where d.approval_status = 'approved' order by d.id limit 1;
  select v.id into v_veh from public.vehicles v where v.status = 'active' limit 1;

  select extensions.st_x(location::extensions.geometry),
         extensions.st_y(location::extensions.geometry)
    into v_lng, v_lat
  from public.places limit 1;

  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.pas.admin@motomoto-qa.co', now(), now()),
    (v_bueno,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.pas.bueno@motomoto-qa.co', now(), now()),
    (v_malo,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.pas.malo@motomoto-qa.co', now(), now()),
    (v_activo, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.pas.activo@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_bueno, v_malo, v_activo);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin,  'Zz pas admin',   '3000000101', 'admin',     'active'),
    (v_bueno,  'Zz pas bueno',   '3000000102', 'passenger', 'active'),
    (v_malo,   'Zz pas malo',    '3000000103', 'passenger', 'active'),
    (v_activo, 'Zz pas activo',  '3000000104', 'passenger', 'active');

  -- Historial: el bueno termina dos, el malo cancela tres y termina uno, y el
  -- tercero tiene uno en curso.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count, origin, origin_label,
    destination, destination_label, contact_phone, requested_at, expires_at,
    service_type, fare_amount, fare_trip_amount, fare_cargo_amount,
    fare_is_night, fare_is_rural, cancelled_at, cancelled_by
  )
  select
    x.id, x.pas, x.est, 1,
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz origen',
    extensions.st_setsrid(extensions.st_makepoint(v_lng, v_lat), 4326)::extensions.geography,
    'Zz destino', '3000000102', x.pedido, x.pedido + interval '5 minutes',
    'passenger', 4000, 4000, 0, false, false,
    case when x.est = 'cancelled' then x.pedido + interval '1 minute' end,
    case when x.est = 'cancelled' then 'passenger'::public.actor_type end
  from (values
    ('b6000000-0000-4000-8000-000000000001'::uuid, v_bueno,  'completed'::public.ride_request_status, now() - interval '5 days'),
    ('b6000000-0000-4000-8000-000000000002'::uuid, v_bueno,  'completed'::public.ride_request_status, now() - interval '3 days'),
    ('b6000000-0000-4000-8000-000000000003'::uuid, v_malo,   'cancelled'::public.ride_request_status, now() - interval '6 days'),
    ('b6000000-0000-4000-8000-000000000004'::uuid, v_malo,   'cancelled'::public.ride_request_status, now() - interval '4 days'),
    ('b6000000-0000-4000-8000-000000000005'::uuid, v_malo,   'cancelled'::public.ride_request_status, now() - interval '2 days'),
    ('b6000000-0000-4000-8000-000000000006'::uuid, v_malo,   'completed'::public.ride_request_status, now() - interval '1 day'),
    ('b6000000-0000-4000-8000-000000000007'::uuid, v_malo,   'expired'::public.ride_request_status,   now() - interval '7 days'),
    ('b6000000-0000-4000-8000-000000000008'::uuid, v_activo, 'in_progress'::public.ride_request_status, now() - interval '5 minutes')
  ) as x(id, pas, est, pedido);

  -- Un viaje real del bueno, para poder calificarlo: `ratings` apunta a `rides`.
  -- LA LINEA DE TIEMPO COMPLETA Y EN ORDEN. `rides_timeline_order` no solo pide
  -- que las fechas avancen: **exige que `driver_arrived_at` exista si hay
  -- `started_at`**, porque un viaje no puede empezar antes de que el conductor
  -- llegue. Se leyo la restriccion en vez de adivinarla, despues de dos intentos
  -- fallidos.
  insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count,
                            accepted_at, driver_arrived_at, started_at, completed_at)
  values ('b6000000-0000-4000-8000-00000000c001',
          'b6000000-0000-4000-8000-000000000001', v_cond, v_veh, 'completed', 1,
          now() - interval '5 days',
          now() - interval '5 days' + interval '4 minutes',
          now() - interval '5 days' + interval '6 minutes',
          now() - interval '5 days' + interval '20 minutes');

  -- El conductor le pone cuatro estrellas. Es la nota que el panel tiene que
  -- ensenar y que **nunca se habia mirado**: solo la del conductor esta
  -- precalculada.
  insert into public.ratings (ride_id, rater_id, rated_id, stars, comment)
  values ('b6000000-0000-4000-8000-00000000c001', v_cond, v_bueno, 4, 'Zz puntual');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- El listado
-- -----------------------------------------------------------------------------

do $listado$
declare
  v_admin  constant uuid := 'b6000000-0000-4000-8000-0000000000a1';
  v_bueno  constant uuid := 'b6000000-0000-4000-8000-0000000000b1';
  v_malo   constant uuid := 'b6000000-0000-4000-8000-0000000000b2';
  v_activo constant uuid := 'b6000000-0000-4000-8000-0000000000b3';
  v_row record;
  v_n integer;
  -- Un `select ... into` de un solo valor NO se lee con `v_row.column1`: hay que
  -- meterlo en una variable escalar. Tercera vez que se comete en este proyecto.
  v_ocupacion text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Salen los tres pasajeros de la prueba.
  select count(*) into v_n from public.admin_list_passengers()
  where passenger_id::text like 'b6000000%';
  insert into resultados values (1, 'El listado trae los pasajeros',
    '3', v_n::text, v_n = 3);

  -- 2. **LOS DESENLACES VAN POR SEPARADO, no en un total.** Es el dato que hace
  --    util la pantalla: "veinte servicios" no dice si fueron bien.
  select completed_count, cancelled_count, expired_count into v_row
  from public.admin_list_passengers() where passenger_id = v_malo;
  insert into resultados values (2, 'Separa terminados, cancelados y caducados',
    '1, 3, 1',
    coalesce(v_row.completed_count::text, 'nulo') || ', ' ||
      coalesce(v_row.cancelled_count::text, 'nulo') || ', ' ||
      coalesce(v_row.expired_count::text, 'nulo'),
    v_row.completed_count = 1 and v_row.cancelled_count = 3 and v_row.expired_count = 1);

  -- 3. Y el que termina sus viajes se distingue del que cancela. Va con la 2
  --    vigilandola: sin esta, los conteos podrian estar saliendo iguales para
  --    todos.
  select completed_count, cancelled_count into v_row
  from public.admin_list_passengers() where passenger_id = v_bueno;
  insert into resultados values (3, 'El que termina sus viajes se distingue del que cancela',
    '2, 0',
    coalesce(v_row.completed_count::text, 'nulo') || ', ' ||
      coalesce(v_row.cancelled_count::text, 'nulo'),
    v_row.completed_count = 2 and v_row.cancelled_count = 0);

  -- 4. **LA CALIFICACION DEL PASAJERO, que nunca se habia mirado.** Existe en los
  --    dos sentidos desde la Fase 17, pero solo la del conductor esta
  --    precalculada; esta se calcula al vuelo.
  select rating_average, rating_count into v_row
  from public.admin_list_passengers() where passenger_id = v_bueno;
  insert into resultados values (4, 'Trae la calificacion que le ponen los conductores',
    '4.00, 1',
    coalesce(v_row.rating_average::text, 'nulo') || ', ' ||
      coalesce(v_row.rating_count::text, 'nulo'),
    v_row.rating_average = 4.00 and v_row.rating_count = 1);

  -- 5. Sin calificaciones la media es NULA, no cero. Un cero seria una nota
  --    malisima; nulo es "todavia no se sabe".
  select rating_average, rating_count into v_row
  from public.admin_list_passengers() where passenger_id = v_malo;
  insert into resultados values (5, 'Sin calificaciones la media es nula, no cero',
    'nulo, 0',
    coalesce(v_row.rating_average::text, 'nulo') || ', ' ||
      coalesce(v_row.rating_count::text, 'nulo'),
    v_row.rating_average is null and v_row.rating_count = 0);

  -- 6. Se sabe quien va montado ahora mismo.
  select
    (select has_active_request from public.admin_list_passengers() where passenger_id = v_activo)::text
    || ', ' ||
    (select has_active_request from public.admin_list_passengers() where passenger_id = v_bueno)::text
  into v_ocupacion;
  insert into resultados values (6, 'Distingue al que tiene un servicio en curso',
    'true, false', coalesce(v_ocupacion, 'nulo'), v_ocupacion = 'true, false');

  -- 7. Un conductor NO sale en el listado de pasajeros, aunque tenga perfil.
  select count(*) into v_n from public.admin_list_passengers() p
  join public.profiles pr on pr.id = p.passenger_id
  where pr.role <> 'passenger';
  insert into resultados values (7, 'Solo salen pasajeros, ningun conductor ni administrador',
    '0', v_n::text, v_n = 0);

  -- 8. El detalle trae los servicios del pasajero, y dice quien cancelo.
  select count(*) into v_n from public.admin_get_passenger_rides(v_malo, 20);
  insert into resultados values (8, 'El detalle trae los servicios del pasajero',
    '5', v_n::text, v_n = 5);

  select cancelled_by::text into v_row
  from public.admin_get_passenger_rides(v_malo, 20)
  where status = 'cancelled' limit 1;
  insert into resultados values (9, 'Y dice quien cancelo cada uno',
    'passenger', coalesce(v_row.cancelled_by, 'nulo'), v_row.cancelled_by = 'passenger');

  -- 10. El tope del servidor manda sobre lo que pida el cliente (D199): por la
  --     API cualquiera puede pedir sin techo.
  select count(*) into v_n from public.admin_get_passenger_rides(v_malo, 9999);
  insert into resultados values (10, 'El limite pedido no puede pasar del tope del servidor',
    '5', v_n::text, v_n = 5);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$listado$;


-- -----------------------------------------------------------------------------
-- El bloqueo
-- -----------------------------------------------------------------------------

do $bloqueo$
declare
  v_admin  constant uuid := 'b6000000-0000-4000-8000-0000000000a1';
  v_malo   constant uuid := 'b6000000-0000-4000-8000-0000000000b2';
  v_activo constant uuid := 'b6000000-0000-4000-8000-0000000000b3';
  v_estado text;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 11. A un pasajero SIN servicio en curso se le bloquea sin mas tramite.
  perform public.admin_set_account_status(v_malo, 'blocked', null);
  select status::text into v_estado from public.profiles where id = v_malo;
  insert into resultados values (11, 'Se bloquea a un pasajero sin servicio en curso',
    'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');

  -- 12. **LA REGLA DE D253.** Con un servicio en curso, el bloqueo exige motivo
  --     escrito: no se prohibe -puede haber una urgencia- pero deja de ser un
  --     clic distraido.
  begin
    perform public.admin_set_account_status(v_activo, 'blocked', null);
    insert into resultados values (12, 'Con servicio en curso, bloquear SIN motivo se rechaza',
      'ACTIVE_RIDE_NEEDS_REASON', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'Con servicio en curso, bloquear SIN motivo se rechaza',
      'ACTIVE_RIDE_NEEDS_REASON', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ACTIVE_RIDE_NEEDS_REASON');
  end;

  -- 13. Un motivo de tres palabras tampoco vale: "ok" no explica nada.
  begin
    perform public.admin_set_account_status(v_activo, 'blocked', 'porque si');
    insert into resultados values (13, 'Un motivo demasiado corto tampoco vale',
      'ACTIVE_RIDE_NEEDS_REASON', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Un motivo demasiado corto tampoco vale',
      'ACTIVE_RIDE_NEEDS_REASON', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'ACTIVE_RIDE_NEEDS_REASON');
  end;

  -- 14. **CON MOTIVO SI SE PUEDE.** Va con la 12 vigilandola: sin esta, la 12
  --     podria estar en verde porque el bloqueo esta roto para todo el mundo.
  perform public.admin_set_account_status(
    v_activo, 'blocked', 'Agredio al conductor durante el viaje');
  select status::text into v_estado from public.profiles where id = v_activo;
  insert into resultados values (14, 'Con motivo escrito SI se puede bloquear',
    'blocked', coalesce(v_estado, 'nulo'), v_estado = 'blocked');

  -- 15. Y **queda escrito que se hizo con un servicio vivo**, que es el dato que
  --     explicara la decision dentro de seis meses.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_activo::text and action = 'block_account'
    and after_data->>'had_active_request' = 'true'
    and after_data->>'reason' = 'Agredio al conductor durante el viaje';
  insert into resultados values (15, 'La auditoria guarda el motivo y que habia servicio vivo',
    '1', v_n::text, v_n = 1);

  -- 16. Desbloquear no pide motivo: devolver el acceso a alguien no necesita
  --     justificarse igual que quitarselo.
  perform public.admin_set_account_status(v_activo, 'active', null);
  select status::text into v_estado from public.profiles where id = v_activo;
  insert into resultados values (16, 'Desbloquear no exige motivo',
    'active', coalesce(v_estado, 'nulo'), v_estado = 'active');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$bloqueo$;


-- -----------------------------------------------------------------------------
-- Quien no es administrador
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_bueno constant uuid := 'b6000000-0000-4000-8000-0000000000b1';
  v_malo  constant uuid := 'b6000000-0000-4000-8000-0000000000b2';
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_bueno, 'role', 'authenticated')::text);

  -- 17. **UN PASAJERO NO VE LA LISTA DE PASAJEROS.** Es `security invoker`
  --     (D242): las politicas se aplican con su identidad, y `profiles` solo le
  --     deja verse a si mismo y a la contraparte de su viaje.
  select count(*) into v_n from public.admin_list_passengers()
  where passenger_id::text like 'b6000000%' and passenger_id <> v_bueno;
  insert into resultados values (17, 'Un pasajero NO ve a los demas pasajeros',
    '0', v_n::text, v_n = 0);

  -- 18. Ni los servicios de otro.
  select count(*) into v_n from public.admin_get_passenger_rides(v_malo, 20);
  insert into resultados values (18, 'Un pasajero NO ve los servicios de otro',
    '0', v_n::text, v_n = 0);

  -- 19. Pero SI los suyos, asi que la 18 no esta en verde por devolver cero a
  --     todo el mundo.
  select count(*) into v_n from public.admin_get_passenger_rides(v_bueno, 20);
  insert into resultados values (19, 'Pero SI ve los suyos',
    '2', v_n::text, v_n = 2);

  -- 20. Y no bloquea a nadie.
  begin
    perform public.admin_set_account_status(v_malo, 'blocked', 'Un motivo cualquiera largo');
    insert into resultados values (20, 'Un pasajero NO puede bloquear cuentas',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Un pasajero NO puede bloquear cuentas',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$privacidad$;


select
  r.n,
  case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion,
  r.esperado,
  r.obtenido
from resultados r
union all
select
  999,
  case when bool_and(x.ok) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not x.ok) || ' fallando'
from resultados x
order by 1;

rollback;
