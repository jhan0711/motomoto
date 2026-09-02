-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `get_active_request` extendida en
-- `20260826080000_active_request_includes_fare.sql` (bloque especial, paso 6).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_active_request_fare.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
-- =============================================================================

begin;

create temp table resultados (
  n integer, comprobacion text, esperado text, obtenido text, ok boolean
) on commit drop;

do $permisos$
begin
  execute format('grant usage on schema %I to authenticated',
    (select n.nspname from pg_namespace n where n.oid = pg_my_temp_schema()));
  execute 'grant insert, select on resultados to authenticated';
end
$permisos$;

do $prueba$
declare
  v_pas  uuid;
  v_org  extensions.geography;
  v_dst  extensions.geography;
  v_rq1  uuid;
  v_rq2  uuid;
  v_caja uuid;
  v_row  record;
  v_n    integer;
  v_ok   boolean;
begin
  select p.id into v_pas from public.profiles p
  where p.role = 'passenger' and p.status = 'active' order by p.created_at limit 1;

  select location into v_org from public.places order by sort_order, name limit 1;
  select location into v_dst from public.places order by sort_order desc, name limit 1;
  select id into v_caja from public.cargo_types where name = 'Caja pequeña';

  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 1. Un viaje de pasajeros normal, sin valor (como los 45 anteriores a D217).
  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count,
    origin, origin_label, destination, destination_label, contact_phone, expires_at
  ) values (
    gen_random_uuid(), v_pas, 'passenger', 1, v_org, 'A', v_dst, 'B',
    '3001234567', now() + interval '5 minutes'
  ) returning id into v_rq1;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  select * into v_row from public.get_active_request();

  insert into resultados values (1, 'Una solicitud sin valor sigue leyendose (D152 no se rompio)',
    'id igual y fare nulo',
    (v_row.id = v_rq1)::text || ' / fare=' || coalesce(v_row.fare_amount::text, 'nulo'),
    v_row.id = v_rq1 and v_row.fare_amount is null and v_row.service_type = 'passenger');

  execute 'reset role';
  execute 'reset request.jwt.claims';
  update public.ride_requests set status = 'expired' where id = v_rq1;

  -- 2. Una encomienda con valor y carga: se lee el desglose completo.
  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count, parcel_description,
    origin, origin_label, destination, destination_label, contact_phone, expires_at,
    fare_amount, fare_trip_amount, fare_cargo_amount, fare_is_night, fare_is_rural,
    fare_reference
  ) values (
    gen_random_uuid(), v_pas, 'parcel', 0, 'Caja con documentos',
    v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes',
    4900, 4000, 4900, false, false, null
  ) returning id into v_rq2;

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  select * into v_row from public.get_active_request();

  insert into resultados values (2, 'La encomienda trae su tipo, descripcion y desglose completo',
    'parcel / Caja con documentos / 4900',
    v_row.service_type::text || ' / ' || coalesce(v_row.parcel_description, 'nulo') || ' / ' ||
      coalesce(v_row.fare_amount::text, 'nulo'),
    v_row.service_type = 'parcel'
      and v_row.parcel_description = 'Caja con documentos'
      and v_row.fare_amount = 4900 and v_row.fare_trip_amount = 4000
      and v_row.fare_cargo_amount = 4900 and v_row.fare_is_night = false
      and v_row.fare_is_rural = false);

  -- Se devuelve el rol ANTES de insertar la carga. `ride_request_cargo` no
  -- tiene politica de insercion para nadie a proposito (esas filas solo nacen
  -- dentro de `request_ride`), asi que hacerlo suplantando al pasajero se
  -- habria rechazado por RLS y no habria probado lo que se queria probar.
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 3. El desglose de carga sigue vivo aparte, para quien lo necesite en detalle.
  insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
  values (v_rq2, v_caja, 1, 1700);

  select count(*) into v_n from public.ride_request_cargo where request_id = v_rq2;
  insert into resultados values (3, 'La carga sigue siendo consultable aparte, no viaja en la fila',
    '1', v_n::text, v_n = 1);

  -- 4. Otro pasajero no ve esta solicitud (RLS de siempre, sigue funcionando).
  declare v_otro uuid;
  begin
    select p.id into v_otro from public.profiles p
    where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
    order by p.created_at limit 1;

    execute 'set local role authenticated';
    execute format('set local request.jwt.claims to %L',
      json_build_object('sub', v_otro, 'role', 'authenticated')::text);

    select count(*) into v_n from public.get_active_request();
    insert into resultados values (4, 'Otro pasajero no ve esta encomienda',
      '0', v_n::text, v_n = 0);

    execute 'reset role';
    execute 'reset request.jwt.claims';
  end;

  -- 5. Permisos, sin sesion.
  select has_function_privilege('anon', 'public.get_active_request()', 'execute') into v_ok;
  insert into resultados values (5, 'Sin sesion no se puede leer la solicitud activa',
    'false', v_ok::text, v_ok = false);
end
$prueba$;

select r.n, case when r.ok then 'OK  ' else 'FALLA' end as estado,
  r.comprobacion, r.esperado, r.obtenido
from resultados r
union all
-- `coalesce` a proposito: un `ok` NULL es un fallo, no algo que el total ignore.
select 999, case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end, 'TOTAL',
  count(*) || ' comprobaciones', count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
