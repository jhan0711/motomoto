-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260827190000_admin_documents.sql` (Fase 20, paso 4c: documentos
-- de conductores y vehiculos).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_documentos.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- LO QUE ESTE ARCHIVO NO PRUEBA: la subida del archivo. Storage tiene su propia
-- API y sus politicas se evaluan alli, no en estas funciones. Aqui se comprueba
-- **el registro** -que es lo que decide si la empresa cree tener un papel- y las
-- reglas que lo rodean. Que el archivo suba y se descargue lo tiene que ver una
-- persona.
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


do $montaje$
declare
  v_admin uuid := 'b5000000-0000-4000-8000-0000000000a1';
  v_cond  uuid := 'b5000000-0000-4000-8000-0000000000d1';
  v_otro  uuid := 'b5000000-0000-4000-8000-0000000000d2';
  v_veh   uuid := 'b5000000-0000-4000-8000-0000000000e1';
begin
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.doc.admin@motomoto-qa.co', now(), now()),
    (v_cond,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.doc.cond@motomoto-qa.co', now(), now()),
    (v_otro,  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'zz.doc.otro@motomoto-qa.co', now(), now());

  delete from public.profiles where id in (v_admin, v_cond, v_otro);
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz doc admin', '3000000091', 'admin',  'active'),
    (v_cond,  'Zz doc cond',  '3000000092', 'driver', 'active'),
    (v_otro,  'Zz doc otro',  '3000000093', 'driver', 'active');

  insert into public.drivers (id, approval_status) values (v_cond, 'pending'), (v_otro, 'pending');

  insert into public.vehicles (id, unit_number, plate, max_passengers, status)
  values (v_veh, 9860, 'ZZD860', 3, 'active');
end
$montaje$;


-- -----------------------------------------------------------------------------
-- Tipos de documento
-- -----------------------------------------------------------------------------

do $tipos$
declare
  v_admin constant uuid := 'b5000000-0000-4000-8000-0000000000a1';
  v_id uuid;
  v_row record;
  v_n integer;
  v_h text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 1. Se crea un tipo nuevo, con vencimiento obligatorio.
  v_id := public.admin_upsert_document_type(null, 'zz_seguro', 'Zz seguro obligatorio',
                                            'vehicle', true, true, 5::smallint);
  select code, name, owner::text, requires_expiry into v_row
  from public.document_types where id = v_id;
  insert into resultados values (1, 'Crea un tipo de documento con vencimiento obligatorio',
    'zz_seguro, Zz seguro obligatorio, vehicle, true',
    coalesce(v_row.code, 'nulo') || ', ' || coalesce(v_row.name, 'nulo') || ', ' ||
      coalesce(v_row.owner, 'nulo') || ', ' || v_row.requires_expiry::text,
    v_row.code = 'zz_seguro' and v_row.owner = 'vehicle' and v_row.requires_expiry);

  -- 2. El codigo tiene formato: minusculas, numeros y guion bajo. Sin esto, un
  --    codigo con espacios o mayusculas chocaria despues con la restriccion de
  --    la tabla y con un mensaje que nadie entiende.
  begin
    perform public.admin_upsert_document_type(null, 'Codigo Con Espacios', 'Zz malo',
                                              'driver', false, true, 0::smallint);
    insert into resultados values (2, 'Un codigo con mayusculas y espacios se rechaza',
      'INVALID_DOCUMENT_CODE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (2, 'Un codigo con mayusculas y espacios se rechaza',
      'INVALID_DOCUMENT_CODE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'INVALID_DOCUMENT_CODE');
  end;

  -- 3. Y es unico.
  begin
    perform public.admin_upsert_document_type(null, 'zz_seguro', 'Zz otro seguro',
                                              'vehicle', false, true, 0::smallint);
    insert into resultados values (3, 'Un codigo repetido se rechaza',
      'DOCUMENT_CODE_TAKEN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (3, 'Un codigo repetido se rechaza',
      'DOCUMENT_CODE_TAKEN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'DOCUMENT_CODE_TAKEN');
  end;

  -- 4. Editar el mismo tipo no choca consigo mismo.
  perform public.admin_upsert_document_type(v_id, 'zz_seguro', 'Zz seguro renombrado',
                                            'vehicle', true, true, 5::smallint);
  select name into v_row from public.document_types where id = v_id;
  insert into resultados values (4, 'Editar el mismo tipo no choca consigo mismo',
    'Zz seguro renombrado', coalesce(v_row.name, 'nulo'),
    v_row.name = 'Zz seguro renombrado');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$tipos$;


-- -----------------------------------------------------------------------------
-- Registrar documentos
-- -----------------------------------------------------------------------------

do $documentos$
declare
  v_admin constant uuid := 'b5000000-0000-4000-8000-0000000000a1';
  v_cond  constant uuid := 'b5000000-0000-4000-8000-0000000000d1';
  v_veh   constant uuid := 'b5000000-0000-4000-8000-0000000000e1';
  v_tipo_seguro uuid;
  v_tipo_cedula uuid;
  v_doc uuid;
  v_row record;
  v_n integer;
  v_h text;
  v_ruta text;
  v_conteo text;
begin
  select id into v_tipo_seguro from public.document_types where code = 'zz_seguro';
  select id into v_tipo_cedula from public.document_types where code = 'identity_document';

  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 5. Se registra un documento de conductor sin vencimiento, porque su tipo no
  --    lo pide.
  v_doc := public.admin_register_document(
    v_tipo_cedula, v_cond, 'driver/' || v_cond || '/cedula.pdf', current_date - 100, null);
  select owner::text, driver_id, vehicle_id, uploaded_by into v_row
  from public.documents where id = v_doc;
  insert into resultados values (5, 'Registra un documento de conductor',
    'driver, con conductor, sin vehiculo, ' || v_admin::text,
    coalesce(v_row.owner, 'nulo') || ', ' ||
      case when v_row.driver_id is not null then 'con conductor' else 'sin conductor' end || ', ' ||
      case when v_row.vehicle_id is null then 'sin vehiculo' else 'con vehiculo' end || ', ' ||
      coalesce(v_row.uploaded_by::text, 'nulo'),
    v_row.owner = 'driver' and v_row.driver_id = v_cond and v_row.vehicle_id is null
      and v_row.uploaded_by = v_admin);

  -- 6. **LA COMPROBACION QUE HACE UTIL `requires_expiry`.** Sin ella ese campo
  --    seria decorativo: un seguro sin fecha de vencimiento no se puede vigilar.
  begin
    perform public.admin_register_document(
      v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/seguro.pdf', current_date, null);
    insert into resultados values (6, 'Un tipo que exige vencimiento lo exige de verdad',
      'EXPIRY_REQUIRED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (6, 'Un tipo que exige vencimiento lo exige de verdad',
      'EXPIRY_REQUIRED', coalesce(nullif(v_h, ''), sqlstate), v_h = 'EXPIRY_REQUIRED');
  end;

  -- 7. Con fecha si entra. Va con la 6 vigilandola.
  v_doc := public.admin_register_document(
    v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/seguro.pdf',
    current_date - 10, current_date + 200);
  select count(*) into v_n from public.documents where id = v_doc;
  insert into resultados values (7, 'Con fecha de vencimiento si se registra',
    '1', v_n::text, v_n = 1);

  -- 8. Las fechas tienen que tener sentido entre si.
  begin
    perform public.admin_register_document(
      v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/seguro2.pdf',
      current_date, current_date - 1);
    insert into resultados values (8, 'Un vencimiento anterior a la expedicion se rechaza',
      'INVALID_EXPIRY_DATES', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (8, 'Un vencimiento anterior a la expedicion se rechaza',
      'INVALID_EXPIRY_DATES', coalesce(nullif(v_h, ''), sqlstate), v_h = 'INVALID_EXPIRY_DATES');
  end;

  -- 9. **LOS AVISOS DE VENCIMIENTO, que son el motivo de esta pantalla.** Uno ya
  --    vencido y otro a punto: son lo que la empresa necesita ver antes de que se
  --    lo diga un policia en la calle.
  perform public.admin_register_document(
    v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/vencido.pdf',
    current_date - 400, current_date - 5);
  perform public.admin_register_document(
    v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/pronto.pdf',
    current_date - 300, current_date + 10);

  select
    count(*) filter (where is_expired) || ', ' ||
    count(*) filter (where expires_soon) || ', ' ||
    count(*) filter (where not is_expired and not expires_soon)
  into v_conteo
  from public.admin_list_documents('vehicle', v_veh);
  insert into resultados values (9, 'Distingue vencido, a punto de vencer y al dia',
    '1, 1, 1', coalesce(v_conteo, 'nulo'), v_conteo = '1, 1, 1');

  -- 10. Un documento sin fecha nunca se marca. Va con la 9: sin esta, el aviso
  --     podria estar encendiendose para todo.
  select is_expired, expires_soon into v_row
  from public.admin_list_documents('driver', v_cond) limit 1;
  insert into resultados values (10, 'Un documento sin vencimiento no se marca nunca',
    'false, false', v_row.is_expired::text || ', ' || v_row.expires_soon::text,
    not v_row.is_expired and not v_row.expires_soon);

  -- 11. Un tipo apagado no admite documentos nuevos: si la empresa dejo de pedir
  --     ese papel, no tiene sentido seguir guardandolo.
  perform public.admin_upsert_document_type(v_tipo_seguro, 'zz_seguro', 'Zz seguro renombrado',
                                            'vehicle', true, false, 5::smallint);
  begin
    perform public.admin_register_document(
      v_tipo_seguro, v_veh, 'vehicle/' || v_veh || '/otro.pdf',
      current_date, current_date + 100);
    insert into resultados values (11, 'Un tipo apagado no admite documentos nuevos',
      'DOCUMENT_TYPE_INACTIVE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (11, 'Un tipo apagado no admite documentos nuevos',
      'DOCUMENT_TYPE_INACTIVE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'DOCUMENT_TYPE_INACTIVE');
  end;
  perform public.admin_upsert_document_type(v_tipo_seguro, 'zz_seguro', 'Zz seguro renombrado',
                                            'vehicle', true, true, 5::smallint);

  -- 12. **NO SE CAMBIA EL DUENO DE UN TIPO QUE YA TIENE DOCUMENTOS.** `documents`
  --     duplica el propietario y lo ata con una clave foranea compuesta: pasar el
  --     tipo de vehiculo a conductor dejaria filas apuntando a un vehiculo con un
  --     tipo declarado de conductor.
  begin
    perform public.admin_upsert_document_type(v_tipo_seguro, 'zz_seguro', 'Zz seguro renombrado',
                                              'driver', true, true, 5::smallint);
    insert into resultados values (12, 'No se cambia el dueno de un tipo con documentos',
      'DOCUMENT_TYPE_IN_USE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (12, 'No se cambia el dueno de un tipo con documentos',
      'DOCUMENT_TYPE_IN_USE', coalesce(nullif(v_h, ''), sqlstate), v_h = 'DOCUMENT_TYPE_IN_USE');
  end;

  -- 13. Un conductor que no existe.
  begin
    perform public.admin_register_document(
      v_tipo_cedula, 'b5000000-0000-4000-8000-0000000000ff'::uuid, 'driver/x/y.pdf', null, null);
    insert into resultados values (13, 'Un conductor inexistente se rechaza',
      'DRIVER_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'Un conductor inexistente se rechaza',
      'DRIVER_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate), v_h = 'DRIVER_NOT_FOUND');
  end;

  -- 14. **BORRAR DEVUELVE LA RUTA**, que es lo que permite al panel borrar
  --     tambien el archivo. Si solo se borrara la fila, el bucket acumularia
  --     cedulas de gente que ya no trabaja alli.
  select id, file_path into v_row from public.documents
  where owner = 'driver' and driver_id = v_cond limit 1;
  v_ruta := public.admin_delete_document(v_row.id);
  insert into resultados values (14, 'Borrar devuelve la ruta del archivo',
    v_row.file_path, coalesce(v_ruta, 'nulo'), v_ruta = v_row.file_path);

  -- 15. Y la fila desaparece de verdad: este si borra, al reves que casi todo en
  --     el proyecto, porque un documento no es historial de una operacion.
  select count(*) into v_n from public.documents where id = v_row.id;
  insert into resultados values (15, 'La fila del documento se borra',
    '0', v_n::text, v_n = 0);

  -- 16. Pero la auditoria conserva lo que habia. Es lo unico que quedara de ese
  --     documento cuando el archivo tambien desaparezca.
  select count(*) into v_n from public.admin_audit_logs
  where entity_id = v_row.id::text and action = 'delete_document'
    and before_data->>'file_path' = v_row.file_path;
  insert into resultados values (16, 'La auditoria conserva lo que se borro',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$documentos$;


-- -----------------------------------------------------------------------------
-- Quien puede ver que
-- -----------------------------------------------------------------------------

do $privacidad$
declare
  v_cond constant uuid := 'b5000000-0000-4000-8000-0000000000d1';
  v_otro constant uuid := 'b5000000-0000-4000-8000-0000000000d2';
  v_veh  constant uuid := 'b5000000-0000-4000-8000-0000000000e1';
  v_admin constant uuid := 'b5000000-0000-4000-8000-0000000000a1';
  v_tipo uuid;
  v_n integer;
  v_h text;
begin
  select id into v_tipo from public.document_types where code = 'identity_document';

  -- Se le deja un documento al conductor para poder medir quien lo ve.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  perform public.admin_register_document(
    v_tipo, v_cond, 'driver/' || v_cond || '/cedula2.pdf', null, null);
  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 17. El conductor ve SUS documentos. Son sus papeles.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  select count(*) into v_n from public.documents
  where owner = 'driver' and driver_id = v_cond;
  insert into resultados values (17, 'Un conductor SI ve sus propios documentos',
    '1', v_n::text, v_n = 1);

  -- 18. **PERO OTRO CONDUCTOR NO.** Es la comprobacion que de verdad importa
  --     aqui: una cedula es un dato personal que no se recupera si se filtra.
  execute 'reset role';
  execute 'reset request.jwt.claims';
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_otro, 'role', 'authenticated')::text);
  select count(*) into v_n from public.documents
  where owner = 'driver' and driver_id = v_cond;
  insert into resultados values (18, 'Otro conductor NO ve los documentos ajenos',
    '0', v_n::text, v_n = 0);

  -- 19. Ni los del vehiculo, aunque lo comparta por doble turno: los papeles del
  --     motorraton son de la empresa, no de quien lo conduce.
  select count(*) into v_n from public.documents where owner = 'vehicle' and vehicle_id = v_veh;
  insert into resultados values (19, 'Un conductor NO ve los documentos del vehiculo',
    '0', v_n::text, v_n = 0);

  -- 20. Ni registra documentos.
  begin
    perform public.admin_register_document(v_tipo, v_otro, 'driver/x/falso.pdf', null, null);
    insert into resultados values (20, 'Un conductor NO puede registrar documentos',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (20, 'Un conductor NO puede registrar documentos',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 21. **NI BORRA LOS SUYOS.** Puede verlos, no quitarlos: si pudiera, se
  --     libraria de una licencia vencida antes de que la empresa la mirara.
  begin
    select id into v_tipo from public.documents
    where owner = 'driver' and driver_id = v_cond limit 1;
    perform public.admin_delete_document(v_tipo);
    insert into resultados values (21, 'Un conductor NO puede borrar sus documentos',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (21, 'Un conductor NO puede borrar sus documentos',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 22. Y LA ESCRITURA DIRECTA ESTA CERRADA, que es lo que faltaba para acabar
  --     con el hueco que aparecio cinco veces desde el paso 2.
  begin
    insert into public.documents (document_type_id, owner, driver_id, file_path)
    values ((select id from public.document_types where code = 'identity_document'),
            'driver', v_otro, 'driver/x/colado.pdf');
    insert into resultados values (22, 'Un INSERT directo de documento no pasa',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (22, 'Un INSERT directo de documento no pasa',
      'rechaza', sqlstate, true);
  end;

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 23. Ni siquiera para el administrador, que es la parte que se olvida.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  begin
    insert into public.document_types (code, name, owner)
    values ('zz_colado', 'Zz colado', 'driver');
    insert into resultados values (23,
      'Ni un administrador crea tipos de documento con INSERT directo',
      'rechaza', 'lo permitio', false);
  exception when others then
    insert into resultados values (23,
      'Ni un administrador crea tipos de documento con INSERT directo',
      'rechaza', sqlstate, true);
  end;

  -- 24. Pero sigue LEYENDO los tipos, que los necesita el panel. Va con la 23
  --     vigilandola: cerrar la escritura no puede llevarse la lectura.
  select count(*) into v_n from public.document_types;
  insert into resultados values (24, 'El administrador sigue leyendo los tipos',
    'mas de 0', v_n::text, v_n > 0);

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
  -- `coalesce` A PROPOSITO: una comprobacion cuyo `ok` salga NULL -pasa cuando se
  -- compara contra un `select ... into` que no encontro fila- se veia FALLA en su
  -- linea pero **no contaba en el total**, porque `bool_and` ignora los NULL. El
  -- total podia decir "0 fallando" con comprobaciones en rojo. Un NULL es un fallo.
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;

rollback;
