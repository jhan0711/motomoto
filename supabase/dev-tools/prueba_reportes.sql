-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Prueba de `20260901120000_admin_reports_inbox.sql` (Fase 20, paso 10a: la
-- bandeja de reportes y las calificaciones en conjunto, D204).
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_reportes.sql
--
-- Todo ocurre dentro de una transaccion que se deshace. No deja una fila.
--
-- **LA MITAD DE LAS COMPROBACIONES SON SOBRE QUE NO SE PUEDE HACER**, y no es
-- desconfianza: esta migracion **quita** una politica que dejaba al
-- administrador reescribir la queja de alguien. Lo que hay que demostrar es
-- justamente eso, que ya no puede.
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
-- Montaje
-- -----------------------------------------------------------------------------

do $montaje$
declare
  v_admin uuid := 'c1000000-0000-4000-8000-0000000000a1';
  v_pas   uuid := 'c1000000-0000-4000-8000-0000000000b1';
  v_otro  uuid := 'c1000000-0000-4000-8000-0000000000b2';
  v_cond  uuid := 'c1000000-0000-4000-8000-0000000000d1';

  v_veh   uuid := 'c1000000-0000-4000-8000-0000000000e1';
  v_req   uuid := 'c1000000-0000-4000-8000-000000000001';
  v_ride  uuid := 'c1000000-0000-4000-8000-00000000c001';

  v_rep_viejo  uuid := 'c1000000-0000-4000-8000-0000000000f1';
  v_rep_nuevo  uuid := 'c1000000-0000-4000-8000-0000000000f2';
  v_rep_cerrado uuid := 'c1000000-0000-4000-8000-0000000000f3';
  v_rep_ajeno   uuid := 'c1000000-0000-4000-8000-0000000000f4';

  v_origen  extensions.geography;
  v_destino extensions.geography;
begin
  select p.location into v_origen from public.places p where p.is_active order by p.sort_order, p.name limit 1;
  select p.location into v_destino from public.places p where p.is_active and p.location <> v_origen
   order by p.sort_order, p.name limit 1;

  -- Mismo patron que el resto de las pruebas: el alta en `auth.users` dispara el
  -- gatillo que crea el perfil, asi que se borran los que crea antes de poner
  -- los de la prueba con los datos que hacen falta.
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  select x.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         x.correo, now(), now()
  from (values
    (v_admin, 'zz.rep.admin@motomoto-qa.co'),
    (v_pas,   'zz.rep.pas@motomoto-qa.co'),
    (v_otro,  'zz.rep.otro@motomoto-qa.co'),
    (v_cond,  'zz.rep.cond@motomoto-qa.co')
  ) as x(id, correo);

  delete from public.profiles where id::text like 'c1000000%';
  insert into public.profiles (id, full_name, phone, role, status) values
    (v_admin, 'Zz rep admin',     '3000000201', 'admin',     'active'),
    (v_pas,   'Zz rep pasajera',  '3000000202', 'passenger', 'active'),
    (v_otro,  'Zz rep ajena',     '3000000204', 'passenger', 'active'),
    (v_cond,  'Zz rep conductor', '3000000203', 'driver',    'active');

  insert into public.drivers (id, approval_status, approved_at, is_available)
  values (v_cond, 'approved', now(), false);

  insert into public.vehicles (id, unit_number, plate, max_passengers, status)
  values (v_veh, 9871, 'ZRE871', 3, 'active');

  insert into public.driver_vehicle_assignments (driver_id, vehicle_id)
  values (v_cond, v_veh);

  -- Un servicio terminado, para colgarle un reporte y una calificacion.
  insert into public.ride_requests (
    id, passenger_id, status, passenger_count,
    origin, origin_label, destination, destination_label,
    contact_phone, requested_at, expires_at, assigned_at
  ) values (
    v_req, v_pas, 'completed', 1,
    v_origen, 'Origen de prueba', v_destino, 'Destino de prueba',
    '3000000202', now() - interval '2 hours', now() - interval '90 minutes',
    now() - interval '115 minutes'
  );

  -- El valor del servicio vive en `ride_requests`, no en `rides`: aqui solo van
  -- los tiempos y el estado.
  insert into public.rides (
    id, request_id, driver_id, vehicle_id, status, passenger_count,
    accepted_at, driver_arrived_at, started_at, completed_at
  ) values (
    v_ride, v_req, v_cond, v_veh, 'completed', 1,
    -- LA LINEA DE TIEMPO ENTERA, y no solo el principio y el final.
    -- `rides_timeline_order` exige que cada paso venga despues del anterior y
    -- **que no falte ninguno por el medio**: sin `driver_arrived_at` no puede
    -- haber `started_at`. Ademas `accepted_at` va explicito porque su valor por
    -- defecto es `now()`, que caeria despues de un viaje de hace dos horas.
    now() - interval '115 minutes', now() - interval '112 minutes',
    now() - interval '110 minutes', now() - interval '95 minutes'
  );

  -- TRES REPORTES EN ESTADOS DISTINTOS. El viejo y el nuevo sin resolver, para
  -- comprobar que la bandeja pone arriba **el que lleva mas esperando**, que es
  -- al reves que el resto de listados del panel.
  insert into public.reports (id, reporter_id, ride_id, category, description, status, created_at) values
    (v_rep_viejo, v_pas, v_ride, 'cobro',
     'Me cobraron mas de lo que decia la aplicacion al pedirlo',
     'open', now() - interval '5 days'),
    (v_rep_nuevo, v_pas, null, 'aplicacion',
     'La aplicacion se cierro sola cuando iba a pedir el servicio',
     'open', now() - interval '1 hour');

  -- **UN REPORTE SOBRE UN VIAJE EN EL QUE QUIEN REPORTA NO ESTUVO.** Nada lo
  -- impide: `reports_insert_own` solo comprueba que el reportante sea uno mismo.
  insert into public.reports (id, reporter_id, ride_id, category, description, status, created_at)
  values
    (v_rep_ajeno, v_otro, v_ride, 'otro',
     'Vi que ese motorraton iba con cuatro personas encima por el parque',
     'open', now() - interval '2 hours');

  insert into public.reports (id, reporter_id, ride_id, category, description,
                              status, resolved_at, resolved_by, resolution_notes, created_at)
  values
    (v_rep_cerrado, v_cond, v_ride, 'trato',
     'El pasajero me trato mal durante todo el recorrido',
     'resolved', now() - interval '2 days', v_admin,
     'Se hablo con el pasajero y quedo advertido', now() - interval '3 days');

  -- Dos calificaciones: una mala con comentario y una buena sin el.
  insert into public.ratings (ride_id, rater_id, rated_id, stars, comment) values
    (v_ride, v_pas, v_cond, 1, 'Llego tardisimo y sin avisar'),
    (v_ride, v_cond, v_pas, 5, null);
end
$montaje$;


-- -----------------------------------------------------------------------------
-- La bandeja
-- -----------------------------------------------------------------------------

do $bandeja$
declare
  v_admin constant uuid := 'c1000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'c1000000-0000-4000-8000-0000000000b1';
  v_rep_viejo   constant uuid := 'c1000000-0000-4000-8000-0000000000f1';
  v_rep_cerrado constant uuid := 'c1000000-0000-4000-8000-0000000000f3';
  v_rep_ajeno   constant uuid := 'c1000000-0000-4000-8000-0000000000f4';
  v_row record;
  v_n integer;
  v_t text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- **TODAS LAS QUE CUENTAN FILAS FILTRAN POR "Zz rep".** La bandeja ensena
  -- **todos** los reportes de la base, no solo los de esta prueba, y los datos
  -- sembrados con `seed_reports.sql` los descuadraban. Es la septima vez que una
  -- prueba de este proyecto da por supuesto un mundo vacio; el filtro por el
  -- nombre de los reportantes de la prueba la deja valer con la base como este.

  -- 1. **LO QUE LLEVA MAS ESPERANDO VA ARRIBA.** Una bandeja no se lee como un
  --    historial: lo urgente es lo mas viejo sin atender, no lo ultimo que entro.
  select report_id into v_row
  from public.admin_list_reports(null, null, null, 'Zz rep') limit 1;
  insert into resultados values (1, 'El reporte sin resolver mas viejo sale primero',
    'el de hace 5 dias', case when v_row.report_id = v_rep_viejo then 'el de hace 5 dias' else 'otro' end,
    v_row.report_id = v_rep_viejo);

  -- 2. Y los resueltos van al final, aunque sean mas recientes que los abiertos.
  select report_id into v_row from (
    select report_id, row_number() over () as pos
    from public.admin_list_reports(null, null, null, 'Zz rep')
  ) x where pos = 4;
  insert into resultados values (2, 'Los resueltos van al final de la bandeja',
    'el cerrado', case when v_row.report_id = v_rep_cerrado then 'el cerrado' else 'otro' end,
    v_row.report_id = v_rep_cerrado);

  -- 3. **LA CONTRAPARTE SE VE SIN ABRIR EL SERVICIO.** El pasajero se quejo, asi
  --    que lo que interesa es de que conductor habla.
  select counterpart_name into v_t from public.admin_list_reports()
  where report_id = v_rep_viejo;
  insert into resultados values (3, 'Se ve contra quien va el reporte',
    'Zz rep conductor', coalesce(v_t, 'nulo'), v_t = 'Zz rep conductor');

  -- 4. Y al reves: el reporte del conductor apunta a la pasajera.
  select counterpart_name into v_t from public.admin_list_reports()
  where report_id = v_rep_cerrado;
  insert into resultados values (4, 'La contraparte se calcula segun quien reporta',
    'Zz rep pasajera', coalesce(v_t, 'nulo'), v_t = 'Zz rep pasajera');

  -- 5. Un reporte sin servicio -la aplicacion se cerro- no tiene contraparte, y
  --    eso no es un fallo: no todos los problemas son con alguien.
  select counterpart_name, ride_route into v_row from public.admin_list_reports()
  where category = 'aplicacion';
  insert into resultados values (5, 'Un reporte sin servicio no inventa contraparte',
    'nulo, nulo',
    coalesce(v_row.counterpart_name, 'nulo') || ', ' || coalesce(v_row.ride_route, 'nulo'),
    v_row.counterpart_name is null and v_row.ride_route is null);

  -- 5b. **SI QUIEN REPORTA NO ESTUVO EN ESE VIAJE, NO SE INVENTA CONTRAPARTE.**
  --     Lo encontro el asistente mirando la pantalla antes de ensenarla: el
  --     `case` tenia un `else` que se tragaba este caso y **senalaba al pasajero
  --     del viaje como si fuera la contraparte**. Sobre esa linea se decide a
  --     quien se llama a pedir explicaciones, asi que un dato de mas que apunta
  --     a la persona equivocada es peor que no tenerlo.
  select counterpart_name, reporter_was_in_ride, ride_route into v_row
  from public.admin_list_reports() where report_id = v_rep_ajeno;
  insert into resultados values (31, 'Un reporte sobre un viaje ajeno no inventa contraparte',
    'sin contraparte, no participo, con recorrido',
    coalesce(v_row.counterpart_name, 'sin contraparte') || ', ' ||
    case when v_row.reporter_was_in_ride then 'participo' else 'no participo' end || ', ' ||
    case when coalesce(v_row.ride_route,'') <> '' then 'con recorrido' else 'sin recorrido' end,
    coalesce(v_row.counterpart_name is null and v_row.reporter_was_in_ride = false
             and coalesce(v_row.ride_route,'') <> '', false));

  -- 5c. Y en los normales sigue diciendo que si participo.
  select reporter_was_in_ride into v_row
  from public.admin_list_reports() where report_id = v_rep_viejo;
  insert into resultados values (32, 'En un reporte normal consta que si participo',
    'true', coalesce(v_row.reporter_was_in_ride::text, 'nulo'),
    coalesce(v_row.reporter_was_in_ride, false));

  -- 6. El total para paginar lo cuenta el servidor sobre lo filtrado.
  select total_count into v_n
  from public.admin_list_reports(null, null, null, 'Zz rep') limit 1;
  insert into resultados values (6, 'El total de la paginacion cuenta lo filtrado',
    '4', v_n::text, v_n = 4);

  -- 7. Filtrar por estado.
  select count(*) into v_n
  from public.admin_list_reports('resolved', null, null, 'Zz rep');
  insert into resultados values (7, 'Se puede filtrar por estado',
    '1', v_n::text, v_n = 1);

  -- 8. La busqueda mira tambien dentro de la descripcion, que es donde esta
  --    escrito el problema de verdad.
  select count(*) into v_n from public.admin_list_reports(null, null, null, 'cobraron mas');
  insert into resultados values (8, 'La busqueda entra en el texto del reporte',
    '1', v_n::text, v_n = 1);

  -- 9. Las categorias del filtro salen de los datos, no de una lista inventada.
  select count(*) into v_n from public.admin_list_report_categories()
  where category in ('cobro', 'aplicacion', 'trato', 'otro');
  insert into resultados values (9, 'Las categorias del filtro salen de los datos',
    '4', v_n::text, v_n = 4);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$bandeja$;


-- -----------------------------------------------------------------------------
-- Gestionar un reporte
-- -----------------------------------------------------------------------------

do $gestion$
declare
  v_admin constant uuid := 'c1000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'c1000000-0000-4000-8000-0000000000b1';
  v_rep_viejo   constant uuid := 'c1000000-0000-4000-8000-0000000000f1';
  v_rep_nuevo   constant uuid := 'c1000000-0000-4000-8000-0000000000f2';
  v_rep_cerrado constant uuid := 'c1000000-0000-4000-8000-0000000000f3';
  v_row record;
  v_n integer;
  v_h text;
  v_t text;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 10. Pasar a "lo estoy mirando" no pide explicacion.
  begin
    perform public.admin_set_report_status(v_rep_viejo, 'in_review');
    insert into resultados values (10, 'Se puede marcar un reporte como en revision',
      'lo permitio', 'lo permitio', true);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (10, 'Se puede marcar un reporte como en revision',
      'lo permitio', coalesce(nullif(v_h, ''), sqlstate), false);
  end;

  -- 11. **CERRAR SIN DECIR QUE SE HIZO NO VALE.** Un reporte resuelto sin una
  --     linea no le sirve ni a quien se quejo ni a la empresa dentro de un mes.
  begin
    perform public.admin_set_report_status(v_rep_nuevo, 'resolved', '   ');
    insert into resultados values (11, 'No se cierra un reporte sin escribir que se hizo',
      'RESOLUTION_NOTES_REQUIRED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (11, 'No se cierra un reporte sin escribir que se hizo',
      'RESOLUTION_NOTES_REQUIRED', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'RESOLUTION_NOTES_REQUIRED');
  end;

  -- 12. Con la nota, si.
  perform public.admin_set_report_status(v_rep_nuevo, 'resolved',
    'Se reviso con el pasajero, era un fallo de su telefono');
  select status, resolution_notes, resolved_by into v_row
  from public.reports where id = v_rep_nuevo;
  insert into resultados values (12, 'Al cerrarlo queda la nota y quien lo cerro',
    'resolved, con nota, el admin',
    coalesce(v_row.status::text, 'nulo') || ', ' ||
    case when coalesce(v_row.resolution_notes,'') <> '' then 'con nota' else 'sin nota' end || ', ' ||
    case when v_row.resolved_by = v_admin then 'el admin' else 'otro' end,
    coalesce(v_row.status = 'resolved' and coalesce(v_row.resolution_notes,'') <> ''
             and v_row.resolved_by = v_admin, false));

  -- 13. Repetir el mismo estado se rechaza: no es una accion, es un despiste, y
  --     dejaria una linea de auditoria que no dice nada.
  begin
    perform public.admin_set_report_status(v_rep_nuevo, 'resolved', 'otra vez');
    insert into resultados values (13, 'No se repite el estado que ya tiene',
      'REPORT_STATUS_UNCHANGED', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (13, 'No se repite el estado que ya tiene',
      'REPORT_STATUS_UNCHANGED', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'REPORT_STATUS_UNCHANGED');
  end;

  -- 14. **REABRIR BORRA LA FECHA DE CIERRE.** Si no, quedaria un reporte abierto
  --     que dice estar resuelto desde el martes, y la restriccion
  --     `reports_resolved_coherence` no lo permitiria.
  perform public.admin_set_report_status(v_rep_nuevo, 'open');
  select status, resolved_at into v_row from public.reports where id = v_rep_nuevo;
  insert into resultados values (14, 'Reabrir un reporte le quita la fecha de cierre',
    'open, sin fecha',
    coalesce(v_row.status::text, 'nulo') || ', ' ||
    case when v_row.resolved_at is null then 'sin fecha' else 'con fecha' end,
    coalesce(v_row.status = 'open' and v_row.resolved_at is null, false));

  -- 15. Un reporte que no existe se dice, no se ignora en silencio.
  begin
    perform public.admin_set_report_status(
      'c1000000-0000-4000-8000-00000000ffff', 'in_review');
    insert into resultados values (15, 'Un reporte inexistente da error claro',
      'REPORT_NOT_FOUND', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (15, 'Un reporte inexistente da error claro',
      'REPORT_NOT_FOUND', coalesce(nullif(v_h, ''), sqlstate), v_h = 'REPORT_NOT_FOUND');
  end;

  -- 16. Queda en la auditoria con el estado de antes y el de despues.
  select count(*) into v_n from public.admin_audit_logs
  where action = 'set_report_status' and entity_id = v_rep_viejo::text
    and before_data->>'status' = 'open' and after_data->>'status' = 'in_review';
  insert into resultados values (16, 'La gestion queda en la auditoria',
    '1', v_n::text, v_n = 1);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 17. **AL CERRARLO SE AVISA A QUIEN SE QUEJO**, que es la mitad que faltaba
  --     de D204: la queja se atiende y quien la puso se entera.
  --
  --     Se mira sin el rol del admin a proposito: `notifications` solo tiene
  --     `notifications_select_own`, asi que el admin no ve -ni debe ver- las
  --     notificaciones de otro. Lo mismo que en `prueba_asignacion`.
  select type into v_t from public.notifications
  where user_id = v_pas and type = 'report_resolved'
  order by created_at desc limit 1;
  insert into resultados values (17, 'Al cerrar el reporte se avisa a quien lo puso',
    'report_resolved', coalesce(v_t, 'nulo'), coalesce(v_t = 'report_resolved', false));

  -- 18. Y NO se avisa al marcarlo en revision: "lo estoy mirando" no es noticia.
  select count(*) into v_n from public.notifications
  where user_id = v_pas and data->>'reportId' = v_rep_viejo::text;
  insert into resultados values (18, 'Marcarlo en revision no manda ningun aviso',
    '0', v_n::text, v_n = 0);
end
$gestion$;


-- -----------------------------------------------------------------------------
-- Lo que NO se puede hacer
-- -----------------------------------------------------------------------------

do $prohibido$
declare
  v_admin constant uuid := 'c1000000-0000-4000-8000-0000000000a1';
  v_pas   constant uuid := 'c1000000-0000-4000-8000-0000000000b1';
  v_cond  constant uuid := 'c1000000-0000-4000-8000-0000000000d1';
  v_rep_viejo constant uuid := 'c1000000-0000-4000-8000-0000000000f1';
  v_n integer;
  v_h text;
begin
  -- 19. **EL ADMINISTRADOR NO PUEDE REESCRIBIR LA QUEJA.** Es lo que esta
  --     migracion vino a cerrar: antes `reports_update_admin` se lo permitia, y
  --     un reporte que se puede editar deja de ser evidencia de nada.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);
  --
  --     **SE MIRA EL EFECTO, NO LA EXCEPCION.** Un `update` que RLS no deja pasar
  --     no da error: **afecta cero filas y sigue adelante**. La primera version
  --     de esta comprobacion daba por bueno "no salto ninguna excepcion" y por
  --     eso decia FALLA teniendo el servidor razon. Lo que hay que preguntar es
  --     si la fila cambio.
  update public.reports set description = 'Aqui no paso nada' where id = v_rep_viejo;
  get diagnostics v_n = row_count;
  insert into resultados values (19, 'El admin NO puede reescribir la queja de alguien',
    '0 filas tocadas', v_n || ' filas tocadas', v_n = 0);

  -- 20. Ni cambiar el estado por la puerta de atras, saltandose la auditoria.
  update public.reports set status = 'resolved' where id = v_rep_viejo;
  get diagnostics v_n = row_count;
  insert into resultados values (20, 'El admin NO cambia el estado sin pasar por la funcion',
    '0 filas tocadas', v_n || ' filas tocadas', v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 20b. **Y EL DISPARADOR AGUANTA AUNQUE LA ESCRITURA VENGA CON PERMISOS.**
  --      Quitar la politica cierra la puerta del panel; el disparador cierra la
  --      de dentro, que es la que importa el dia que una funcion nueva escriba
  --      en `reports` sin darse cuenta. Se prueba con el rol privilegiado, que
  --      RLS no frena.
  begin
    update public.reports set description = 'Reescrito desde dentro' where id = v_rep_viejo;
    insert into resultados values (30, 'Ni con permisos se puede reescribir la queja',
      'REPORT_IS_IMMUTABLE', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (30, 'Ni con permisos se puede reescribir la queja',
      'REPORT_IS_IMMUTABLE', coalesce(nullif(v_h, ''), sqlstate),
      v_h = 'REPORT_IS_IMMUTABLE');
  end;

  -- 21. Un pasajero no ve la bandeja: los reportes de los demas no son suyos.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_pas, 'role', 'authenticated')::text);
  select count(*) into v_n from public.admin_list_reports();
  insert into resultados values (21, 'Un pasajero NO ve la bandeja de reportes',
    '0', v_n::text, v_n = 0);

  -- 22. Ni gestiona ninguno, ni el suyo propio.
  begin
    perform public.admin_set_report_status(v_rep_viejo, 'resolved', 'Ya esta');
    insert into resultados values (22, 'Un pasajero NO gestiona reportes',
      'NOT_AN_ADMIN', 'lo permitio', false);
  exception when others then
    get stacked diagnostics v_h = pg_exception_hint;
    insert into resultados values (22, 'Un pasajero NO gestiona reportes',
      'NOT_AN_ADMIN', coalesce(nullif(v_h, ''), sqlstate), v_h = 'NOT_AN_ADMIN');
  end;

  -- 23. Y tampoco ve las calificaciones de todos.
  select count(*) into v_n from public.admin_list_ratings();
  insert into resultados values (23, 'Un pasajero NO ve todas las calificaciones',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';

  -- 24. Un conductor tampoco ve la bandeja, aunque el mismo haya reportado.
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_cond, 'role', 'authenticated')::text);
  select count(*) into v_n from public.admin_list_reports();
  insert into resultados values (24, 'Un conductor NO ve la bandeja de reportes',
    '0', v_n::text, v_n = 0);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$prohibido$;


-- -----------------------------------------------------------------------------
-- Las calificaciones en conjunto
-- -----------------------------------------------------------------------------

do $calificaciones$
declare
  v_admin constant uuid := 'c1000000-0000-4000-8000-0000000000a1';
  v_cond  constant uuid := 'c1000000-0000-4000-8000-0000000000d1';
  v_row record;
  v_n integer;
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text);

  -- 25. **LAS PEORES PRIMERO.** Es la pregunta contraria a la del paso 8: no
  --     "que paso en este servicio" sino "donde estan los problemas".
  select stars, rated_name into v_row from public.admin_list_ratings()
  where rated_id = v_cond or rated_name like 'Zz rep%' limit 1;
  insert into resultados values (25, 'Las peores calificaciones salen primero',
    '1 estrella', coalesce(v_row.stars::text, 'nulo') || ' estrella',
    coalesce(v_row.stars = 1, false));

  -- 26. Se puede pedir solo las malas.
  select count(*) into v_n from public.admin_list_ratings(2::smallint)
  where rated_name like 'Zz rep%';
  insert into resultados values (26, 'Se puede filtrar por calificacion maxima',
    '1', v_n::text, v_n = 1);

  -- 27. Y solo las que traen comentario, que son las accionables: una estrella
  --     sin explicacion no dice que arreglar.
  select count(*) into v_n from public.admin_list_ratings(null, null, true)
  where rated_name like 'Zz rep%';
  insert into resultados values (27, 'Se pueden pedir solo las que traen comentario',
    '1', v_n::text, v_n = 1);

  -- 28. Se ve quien califico a quien, que es lo que permite actuar.
  select rater_name, rated_name, comment into v_row
  from public.admin_list_ratings(2::smallint) where rated_name like 'Zz rep%';
  insert into resultados values (28, 'Se ve quien califico, a quien y que dijo',
    'Zz rep pasajera, Zz rep conductor, con comentario',
    coalesce(v_row.rater_name, 'nulo') || ', ' || coalesce(v_row.rated_name, 'nulo') || ', ' ||
    case when coalesce(v_row.comment,'') <> '' then 'con comentario' else 'sin comentario' end,
    coalesce(v_row.rater_name = 'Zz rep pasajera' and v_row.rated_name = 'Zz rep conductor'
             and coalesce(v_row.comment,'') <> '', false));

  -- 29. Y el servicio del que salio, para poder ir a mirarlo.
  select ride_route into v_row from public.admin_list_ratings(2::smallint)
  where rated_name like 'Zz rep%';
  insert into resultados values (29, 'Cada calificacion dice de que servicio salio',
    'con recorrido',
    case when coalesce(v_row.ride_route,'') <> '' then 'con recorrido' else 'nulo' end,
    coalesce(v_row.ride_route,'') <> '');

  execute 'reset role';
  execute 'reset request.jwt.claims';
end
$calificaciones$;


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
