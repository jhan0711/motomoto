-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260825234500_service_type_and_cargo.sql` (bloque especial, paso
-- 2): el tipo de servicio, la descripcion de la encomienda, el cero pasajeros y
-- la lista de carga.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_encomiendas.sql
--
-- LA COMPROBACION 14 ES LA QUE JUSTIFICA D220 y la que mas facil se habria dado
-- por buena sin medirla: que un conductor con una encomienda encima siga
-- pudiendo aceptar sus tres pasajeros. Si `enforce_ride_capacity` contara la
-- encomienda como un puesto, la flota perderia un asiento por cada bulto y nadie
-- lo notaria hasta tener el motorraton parado.
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
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
-- El tipo de servicio, la descripcion y el cero pasajeros
-- -----------------------------------------------------------------------------

do $tipos$
declare
  c_enc  constant uuid := 'f1000000-0000-4000-8000-000000000001';
  v_pas  uuid;
  v_org  extensions.geography;
  v_dst  extensions.geography;
  v_n    integer;
begin
  select p.id into v_pas
  from public.profiles p
  where p.role = 'passenger' and p.status = 'active'
  order by p.created_at limit 1;

  select location into v_org from public.places order by sort_order, name limit 1;
  select location into v_dst from public.places order by sort_order desc, name limit 1;

  -- REGLA R6: un pasajero solo puede tener una solicitud viva. Si la trae de
  -- antes, todas las inserciones de aqui abajo chocan con el indice unico y la
  -- prueba sale roja sin haber probado nada, que es E12 otra vez.
  --
  -- LOS TRES ESTADOS VIVOS, no solo 'searching'. La primera version de este
  -- archivo caducaba unicamente las que estaban buscando, y el primer pasajero
  -- de la base tenia una 'in_progress': el script se cayo entero. Los tres
  -- estados son los que estan en el indice `rr_one_active_per_passenger`.
  --
  -- Se deshace con el rollback del final, asi que el servicio en curso de esa
  -- persona sigue en curso cuando la prueba termina.
  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  -- 1. El caso normal de siempre: pasajero, sin descripcion.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'passenger', 2, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (1, 'Viaje de pasajeros normal, como antes',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (1, 'Viaje de pasajeros normal, como antes',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  -- 2. Un viaje de pasajeros no lleva descripcion de encomienda. Para las
  --    aclaraciones ya esta `pickup_reference`.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'passenger', 1, 'Bulto de cafe',
      v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (2, 'Viaje de pasajeros CON descripcion de encomienda',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (2, 'Viaje de pasajeros CON descripcion de encomienda',
      'rechaza', sqlstate, true);
  end;

  -- 3. Una encomienda sin decir que es. El conductor no puede decidir a ciegas.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'parcel', 0, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (3, 'Encomienda SIN descripcion',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (3, 'Encomienda SIN descripcion',
      'rechaza', sqlstate, true);
  end;

  -- 4. Descripcion de dos letras: es como no decir nada.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'parcel', 0, 'ab', v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (4, 'Encomienda con descripcion de dos letras',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (4, 'Encomienda con descripcion de dos letras',
      'rechaza', sqlstate, true);
  end;

  -- 5. Y una que se pasa del techo.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'parcel', 0, repeat('x', 121),
      v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (5, 'Encomienda con descripcion de 121 caracteres',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (5, 'Encomienda con descripcion de 121 caracteres',
      'rechaza', sqlstate, true);
  end;

  -- 6. Una encomienda con pasajeros no es una encomienda: es un pasajero con
  --    carga. Los tres casos no se confunden, que es lo que pidio la empresa.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'parcel', 1, 'Caja con documentos',
      v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (6, 'Encomienda CON un pasajero a bordo',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (6, 'Encomienda CON un pasajero a bordo',
      'rechaza', sqlstate, true);
  end;

  -- 7. Y al reves: un viaje de pasajeros sin nadie.
  begin
    insert into public.ride_requests (
      passenger_id, service_type, passenger_count,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      v_pas, 'passenger', 0, v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (7, 'Viaje de pasajeros con CERO pasajeros',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (7, 'Viaje de pasajeros con CERO pasajeros',
      'rechaza', sqlstate, true);
  end;

  -- 8. La encomienda bien formada. Se queda para las pruebas de carga de abajo.
  --
  --    Se aparta antes la que dejo viva la comprobacion 1, por la misma R6.
  update public.ride_requests set status = 'expired'
  where passenger_id = v_pas and status in ('searching', 'assigned', 'in_progress');

  begin
    insert into public.ride_requests (
      id, passenger_id, service_type, passenger_count, parcel_description,
      origin, origin_label, destination, destination_label,
      contact_phone, expires_at
    ) values (
      c_enc, v_pas, 'parcel', 0, 'Caja con documentos',
      v_org, 'A', v_dst, 'B', '3001234567', now() + interval '5 minutes'
    );
    insert into resultados values (8, 'Encomienda bien formada: cero pasajeros y descripcion',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (8, 'Encomienda bien formada: cero pasajeros y descripcion',
      'entra', 'LA RECHAZO ' || sqlstate, false);
  end;

  -- 9. Las 45 solicitudes que ya existian tienen que haber quedado clasificadas
  --    como viajes de pasajeros. Un valor por defecto que no se aplicara a lo
  --    existente dejaria el historial entero sin tipo.
  select count(*) into v_n
  from public.ride_requests
  where service_type is null;
  insert into resultados values (9, 'Ninguna solicitud quedo sin tipo de servicio',
    '0', v_n::text, v_n = 0);
end
$tipos$;


-- -----------------------------------------------------------------------------
-- La capacidad: la encomienda no ocupa puesto
-- -----------------------------------------------------------------------------

do $capacidad$
declare
  c_enc  constant uuid := 'f1000000-0000-4000-8000-000000000001';
  c_via  constant uuid := 'f2000000-0000-4000-8000-000000000001';
  c_rq2  constant uuid := 'f1000000-0000-4000-8000-000000000002';
  c_via2 constant uuid := 'f2000000-0000-4000-8000-000000000002';
  c_rq3  constant uuid := 'f1000000-0000-4000-8000-000000000003';
  c_via3 constant uuid := 'f2000000-0000-4000-8000-000000000003';
  v_cond uuid;
  v_veh  uuid;
  v_cap  smallint;
  v_otro uuid;
  v_org  extensions.geography;
  v_dst  extensions.geography;
begin
  select d.id into v_cond from public.drivers d order by d.id limit 1;
  select v.id, v.max_passengers into v_veh, v_cap
  from public.vehicles v order by v.unit_number limit 1;
  select p.id into v_otro
  from public.profiles p
  where p.role = 'passenger' and p.status = 'active'
  order by p.created_at offset 1 limit 1;

  select location into v_org from public.places order by sort_order, name limit 1;
  select location into v_dst from public.places order by sort_order desc, name limit 1;

  -- EL CONDUCTOR Y EL MOTORRATON TIENEN QUE EMPEZAR VACIOS, y esto costo dos
  -- comprobaciones en rojo la primera vez que se ejecuto este archivo.
  --
  -- `enforce_ride_capacity` hace dos cosas y la primera no tiene nada que ver con
  -- los asientos: si el conductor ya lleva un viaje con OTRO motorraton, rechaza
  -- con DRIVER_VEHICLE_CONFLICT. El conductor 1 de la base de pruebas tenia un
  -- viaje vivo con la unidad 99 y este archivo elegia la 98 —la de numero mas
  -- bajo—, asi que saltaba ese conflicto y nunca se llegaba a medir la capacidad.
  --
  -- Se apartan los viajes vivos del conductor Y los del motorraton, porque son
  -- dos cuentas distintas: la del conflicto mira al conductor y la de los
  -- asientos mira al vehiculo. Todo se deshace con el rollback del final.
  update public.rides
  set status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin'
  where (driver_id = v_cond or vehicle_id = v_veh)
    and status in ('assigned', 'driver_on_the_way', 'driver_arrived', 'in_progress');

  -- 10. Un viaje con cero pasajeros: la encomienda circulando.
  begin
    insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count)
    values (c_via, c_enc, v_cond, v_veh, 'assigned', 0);
    insert into resultados values (10, 'Un viaje puede llevar cero pasajeros',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (10, 'Un viaje puede llevar cero pasajeros',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  -- 11. Once pasajeros no entran.
  --
  --     QUEDA DICHO QUE LO ATRAPA EL DISPARADOR Y NO LA RESTRICCION. La de
  --     `rides` admite hasta 10, pero `enforce_ride_capacity` es BEFORE y corre
  --     antes, asi que rechaza por capacidad (P0001) al comparar 11 contra los 3
  --     asientos del motorraton. La restriccion de 10 nunca llega a evaluarse
  --     mientras ningun vehiculo tenga mas de diez plazas. Se deja escrito para
  --     que nadie lea el 23514 que no aparece y crea que falta algo.
  begin
    insert into public.rides (request_id, driver_id, vehicle_id, status, passenger_count)
    values (c_enc, v_cond, v_veh, 'assigned', 11);
    insert into resultados values (11, 'Un viaje con once pasajeros',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (11, 'Un viaje con once pasajeros',
      'rechaza', sqlstate, true);
  end;

  -- LA COMPROBACION QUE JUSTIFICA D220.
  --
  -- El conductor ya lleva la encomienda del viaje de arriba, que suma cero
  -- puestos. Ahora se le da un viaje con el motorraton lleno. Si la encomienda
  -- ocupara sitio, este segundo viaje se rechazaria y la flota perderia un
  -- asiento por cada bulto.
  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, expires_at
  ) values (
    c_rq2, v_otro, 'passenger', v_cap, v_org, 'A', v_dst, 'B',
    '3009876543', now() + interval '5 minutes'
  );

  begin
    insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count)
    values (c_via2, c_rq2, v_cond, v_veh, 'assigned', v_cap);
    insert into resultados values (12,
      'Con una encomienda encima todavia caben los ' || v_cap || ' pasajeros',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (12,
      'Con una encomienda encima todavia caben los ' || v_cap || ' pasajeros',
      'entra', 'LO RECHAZO ' || sqlstate, false);
  end;

  -- 13. Y el limite sigue siendo el limite: uno mas ya no cabe. Sin esta, la
  --     anterior podria estar en verde porque el control de capacidad no
  --     funciona en absoluto, que seria un verde falso.
  update public.ride_requests set status = 'expired' where id = c_rq2;

  insert into public.ride_requests (
    id, passenger_id, service_type, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, expires_at
  ) values (
    c_rq3, v_otro, 'passenger', 1, v_org, 'A', v_dst, 'B',
    '3009876543', now() + interval '5 minutes'
  );

  begin
    insert into public.rides (id, request_id, driver_id, vehicle_id, status, passenger_count)
    values (c_via3, c_rq3, v_cond, v_veh, 'assigned', 1);
    insert into resultados values (13, 'Un pasajero mas por encima de la capacidad',
      'rechaza', 'LO ACEPTO', false);
  exception when others then
    insert into resultados values (13, 'Un pasajero mas por encima de la capacidad',
      'rechaza', sqlstate, true);
  end;
end
$capacidad$;


-- -----------------------------------------------------------------------------
-- La lista de carga
-- -----------------------------------------------------------------------------

do $carga$
declare
  c_enc   constant uuid := 'f1000000-0000-4000-8000-000000000001';
  v_caja  uuid;
  v_bici  uuid;
  v_monto integer;
  v_n     integer;
  v_msg   text;
begin
  select id, amount into v_caja, v_monto
  from public.cargo_types where name = 'Caja pequeña';
  select id into v_bici from public.cargo_types where name = 'Bicicleta';

  insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
  values (c_enc, v_caja, 2, v_monto);

  -- 14. Dos lineas del mismo tipo son una linea con cantidad dos.
  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, v_caja, 1, v_monto);
    insert into resultados values (14, 'Dos lineas del mismo tipo en la misma solicitud',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (14, 'Dos lineas del mismo tipo en la misma solicitud',
      'rechaza', sqlstate, true);
  end;

  -- 15. Un tipo distinto si entra: es el "agregar otra carga" de D224.
  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, v_bici, 1, 2300);
    insert into resultados values (15, 'Otra carga de tipo distinto en el mismo servicio',
      'entra', 'entro', true);
  exception when others then
    insert into resultados values (15, 'Otra carga de tipo distinto en el mismo servicio',
      'entra', 'LA RECHAZO ' || sqlstate, false);
  end;

  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, (select id from public.cargo_types where name = 'Caja grande'), 0, 2800);
    insert into resultados values (16, 'Carga con cantidad cero',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (16, 'Carga con cantidad cero',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, (select id from public.cargo_types where name = 'Caja grande'), 21, 2800);
    insert into resultados values (17, 'Carga con cantidad 21',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (17, 'Carga con cantidad 21',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, (select id from public.cargo_types where name = 'Caja grande'), 1, 0);
    insert into resultados values (18, 'Carga con precio congelado de cero',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (18, 'Carga con precio congelado de cero',
      'rechaza', sqlstate, true);
  end;

  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, '00000000-0000-4000-8000-000000000000', 1, 1700);
    insert into resultados values (19, 'Carga de un tipo que no existe',
      'rechaza', 'LA ACEPTO', false);
  exception when others then
    insert into resultados values (19, 'Carga de un tipo que no existe',
      'rechaza', sqlstate, true);
  end;

  -- 20. Un tipo de carga que ya viajo no se puede borrar. Para retirarlo esta
  --     `is_active`. Se comprueba que falle POR ESTO y no por otra cosa.
  begin
    delete from public.cargo_types where id = v_caja;
    insert into resultados values (20, 'Borrar un tipo de carga que ya viajo',
      'rechaza por ride_request_cargo', 'LO BORRO', false);
  exception when others then
    get stacked diagnostics v_msg = message_text;
    insert into resultados values (20, 'Borrar un tipo de carga que ya viajo',
      'rechaza por ride_request_cargo',
      sqlstate || ' ' || case when v_msg ilike '%ride_request_cargo%'
                         then 'ride_request_cargo' else v_msg end,
      sqlstate = '23503' and v_msg ilike '%ride_request_cargo%');
  end;

  -- 21. El precio congelado no sigue al catalogo. Se sube el precio del tipo y
  --     la linea ya guardada tiene que quedarse como estaba (D225).
  update public.cargo_types set amount = 9999 where id = v_caja;
  select unit_amount into v_n
  from public.ride_request_cargo
  where request_id = c_enc and cargo_type_id = v_caja;
  insert into resultados values (21, 'Subir el precio del catalogo NO cambia lo ya guardado',
    v_monto::text, v_n::text, v_n = v_monto);
  update public.cargo_types set amount = v_monto where id = v_caja;
end
$carga$;


-- -----------------------------------------------------------------------------
-- Las politicas
-- -----------------------------------------------------------------------------

do $rls$
declare
  c_enc   constant uuid := 'f1000000-0000-4000-8000-000000000001';
  v_pas   uuid;
  v_otro  uuid;
  v_cond1 uuid;
  v_cond2 uuid;
  v_n     integer;
begin
  select passenger_id into v_pas from public.ride_requests where id = c_enc;

  select p.id into v_otro
  from public.profiles p
  where p.role = 'passenger' and p.status = 'active' and p.id <> v_pas
  order by p.created_at limit 1;

  select d.id into v_cond1 from public.drivers d order by d.id limit 1;
  select d.id into v_cond2 from public.drivers d where d.id <> v_cond1 order by d.id limit 1;

  -- Al conductor 1 se le OFRECE la encomienda, sin aceptarla todavia. Es el caso
  -- que importa: tiene que ver que le proponen antes de decidir.
  insert into public.ride_offers (request_id, driver_id, expires_at)
  values (c_enc, v_cond1, now() + interval '20 seconds');

  -- ------------------------------------------------------------- el dueno
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);

  select count(*) into v_n from public.ride_request_cargo where request_id = c_enc;
  insert into resultados values (22, 'El pasajero ve las dos cargas de su encomienda',
    '2', v_n::text, v_n = 2);

  begin
    insert into public.ride_request_cargo (request_id, cargo_type_id, quantity, unit_amount)
    values (c_enc, (select id from public.cargo_types where name = 'Caja grande'), 1, 2800);
    insert into resultados values (23, 'El pasajero NO puede anadir carga por su cuenta',
      'rechaza', 'LA CREO', false);
  exception when others then
    insert into resultados values (23, 'El pasajero NO puede anadir carga por su cuenta',
      'rechaza', sqlstate, true);
  end;

  delete from public.ride_request_cargo where request_id = c_enc;
  get diagnostics v_n = row_count;
  insert into resultados values (24, 'El pasajero NO puede borrar su carga',
    '0 filas', v_n || ' filas', v_n = 0);

  -- ------------------------------------------------------------- otro pasajero
  execute 'reset role';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_otro, 'role', 'authenticated')::text);

  select count(*) into v_n from public.ride_request_cargo where request_id = c_enc;
  insert into resultados values (25, 'Otro pasajero NO ve la carga ajena',
    '0', v_n::text, v_n = 0);

  -- ------------------------------------------------- el conductor al que se ofrecio
  execute 'reset role';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond1, 'role', 'authenticated')::text);

  select count(*) into v_n from public.ride_request_cargo where request_id = c_enc;
  insert into resultados values (26, 'El conductor SI ve la carga antes de aceptar',
    '2', v_n::text, v_n = 2);

  -- ------------------------------------------------------------- conductor ajeno
  execute 'reset role';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond2, 'role', 'authenticated')::text);

  select count(*) into v_n from public.ride_request_cargo where request_id = c_enc;
  insert into resultados values (27, 'Un conductor sin oferta NO ve la carga',
    '0', v_n::text, v_n = 0);

  -- ------------------------------------------------------------------- sin sesion
  execute 'reset role';
  execute 'set local role anon';
  execute format('set local request.jwt.claims to %L', '{"role":"anon"}');

  select count(*) into v_n from public.ride_request_cargo;
  insert into resultados values (28, 'Sin sesion no se ve ninguna carga',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$rls$;


-- -----------------------------------------------------------------------------
-- El borrado en cascada
-- -----------------------------------------------------------------------------

do $cascada$
declare
  c_enc constant uuid := 'f1000000-0000-4000-8000-000000000001';
  v_n   integer;
begin
  delete from public.rides where request_id = c_enc;
  delete from public.ride_offers where request_id = c_enc;
  delete from public.ride_requests where id = c_enc;

  select count(*) into v_n from public.ride_request_cargo where request_id = c_enc;
  insert into resultados values (29, 'Borrar la solicitud se lleva su carga por delante',
    '0', v_n::text, v_n = 0);
end
$cascada$;


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
