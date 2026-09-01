-- =============================================================================
-- FASE 20, PASO 4c: documentos de conductores y vehiculos
-- =============================================================================
--
-- Lo ultimo que le quedaba al bloque de la flota, y **lo ultimo que cierra el
-- hueco de las politicas `_all_admin`**: con esto, ninguna tabla que el panel
-- gestione admite ya escritura directa sin auditoria.
--
-- ESTADO AL EMPEZAR, medido y no supuesto: `document_types` con **2 filas** -el
-- documento de identidad y la matricula-, `documents` con **cero**, y un solo
-- bucket, `avatars`. La tabla existe desde la Fase 5 y **nunca se ha usado**.
--
-- EL BUCKET ES PRIVADO, y con mas motivo que el de las fotos. Un documento de
-- identidad es un dato personal de los que no se recuperan si se filtran: una
-- foto de perfil sale en la calle, una cedula no. El limite de tamano y los tipos
-- permitidos son la segunda barrera, la que sigue en pie aunque alguien use un
-- cliente modificado.
--
-- LOS ARCHIVOS NO PASAN POR SQL, y eso obliga a decidir el orden. El panel sube
-- el archivo a Storage con su propia API y **despues** registra la fila con
-- `admin_register_document`. Se eligio ese orden -y no al reves- porque **un
-- archivo sin fila es basura recuperable y una fila sin archivo es un documento
-- que la empresa cree tener y no tiene**. Si el registro falla, el panel borra
-- el archivo que acaba de subir; si esa limpieza tambien falla, queda un huerfano
-- en el bucket, que se puede encontrar y borrar. La otra forma deja mentiras en
-- la base de datos.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El bucket
-- -----------------------------------------------------------------------------
--
-- 5 MB: un documento escaneado con el telefono cabe de sobra, y el limite frena
-- que alguien suba un video por error. Se admiten PDF ademas de imagenes porque
-- las matriculas y los seguros suelen llegar asi.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];


-- -----------------------------------------------------------------------------
-- Politicas del bucket
-- -----------------------------------------------------------------------------
--
-- La ruta es `<owner>/<id-del-dueno>/<uuid>.<ext>`, por ejemplo
-- `driver/d0000000-.../a1b2c3.pdf`. Las dos primeras carpetas son las que
-- permiten decidir de quien es cada archivo con una comparacion, igual que en
-- `avatars`.

-- **Solo el administrador y el propio conductor.** El conductor ve los suyos
-- -son sus papeles-, pero **no los de su vehiculo si lo comparte** por doble
-- turno: eso es de la empresa, no suyo. Un pasajero no ve ninguno, ni el del
-- conductor que lo lleva.
create policy "documents_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'documents'
    and (
      public.is_admin()
      or (
        (storage.foldername(name))[1] = 'driver'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

-- **Escribe solo el administrador.** En el MVP los papeles los recoge la empresa
-- y los sube desde el panel; la aplicacion del conductor no tiene esa pantalla.
-- Cuando la tenga, esta politica se amplia, no se sustituye.
create policy "documents_insert_admin"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and public.is_admin());

create policy "documents_update_admin"
  on storage.objects for update to authenticated
  using (bucket_id = 'documents' and public.is_admin())
  with check (bucket_id = 'documents' and public.is_admin());

create policy "documents_delete_admin"
  on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and public.is_admin());


-- -----------------------------------------------------------------------------
-- Tipos de documento
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_document_types()
returns table (
  document_type_id uuid,
  code text,
  name text,
  owner public.document_owner,
  requires_expiry boolean,
  is_active boolean,
  sort_order smallint,
  usage_count integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    dt.id, dt.code, dt.name, dt.owner, dt.requires_expiry, dt.is_active, dt.sort_order,
    (select count(*)::integer from public.documents d where d.document_type_id = dt.id)
  from public.document_types dt
  order by dt.owner, dt.sort_order, dt.name;
$$;

comment on function public.admin_list_document_types() is
  'Catalogo de tipos de documento, con cuantos hay de cada uno.';

revoke all on function public.admin_list_document_types() from public;
grant execute on function public.admin_list_document_types() to authenticated;


create or replace function public.admin_upsert_document_type(
  p_document_type_id uuid,
  p_code text,
  p_name text,
  p_owner public.document_owner,
  p_requires_expiry boolean default false,
  p_is_active boolean default true,
  p_sort_order smallint default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_before public.document_types;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede gestionar los tipos de documento'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if coalesce(p_code, '') !~ '^[a-z0-9_]{2,40}$' then
    raise exception 'El codigo solo admite minusculas, numeros y guion bajo, de 2 a 40 caracteres'
      using errcode = 'P0001', hint = 'INVALID_DOCUMENT_CODE';
  end if;

  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'El nombre debe tener al menos 2 caracteres'
      using errcode = 'P0001', hint = 'INVALID_DOCUMENT_NAME';
  end if;

  if exists (
    select 1 from public.document_types
    where code = p_code and (p_document_type_id is null or id <> p_document_type_id)
  ) then
    raise exception 'Ya existe un tipo de documento con ese codigo'
      using errcode = 'P0001', hint = 'DOCUMENT_CODE_TAKEN';
  end if;

  if p_document_type_id is null then
    insert into public.document_types (code, name, owner, requires_expiry, is_active, sort_order)
    values (p_code, trim(p_name), p_owner, p_requires_expiry, p_is_active, p_sort_order)
    returning id into v_id;

    perform public.log_admin_action(
      'create_document_type', 'document_types', v_id::text, null,
      jsonb_build_object('code', p_code, 'name', trim(p_name), 'owner', p_owner)
    );
  else
    select * into v_before from public.document_types where id = p_document_type_id;

    if not found then
      raise exception 'No se encontro ese tipo de documento'
        using errcode = 'P0001', hint = 'DOCUMENT_TYPE_NOT_FOUND';
    end if;

    -- **EL DUENO NO SE PUEDE CAMBIAR SI YA HAY DOCUMENTOS.** `documents` duplica
    -- el propietario y lo ata con una clave foranea compuesta (Fase 5): cambiar
    -- el tipo de "conductor" a "vehiculo" dejaria filas que apuntan a un
    -- conductor con un tipo declarado de vehiculo. La base lo rechazaria, pero
    -- con un 23503 que no explica nada.
    if v_before.owner <> p_owner and exists (
      select 1 from public.documents where document_type_id = p_document_type_id
    ) then
      raise exception 'Ese tipo ya tiene documentos: no se puede cambiar de conductor a vehiculo'
        using errcode = 'P0001', hint = 'DOCUMENT_TYPE_IN_USE';
    end if;

    update public.document_types
    set code = p_code, name = trim(p_name), owner = p_owner,
        requires_expiry = p_requires_expiry, is_active = p_is_active,
        sort_order = p_sort_order
    where id = p_document_type_id;

    v_id := p_document_type_id;

    perform public.log_admin_action(
      'update_document_type', 'document_types', p_document_type_id::text,
      jsonb_build_object('code', v_before.code, 'name', v_before.name,
                         'is_active', v_before.is_active),
      jsonb_build_object('code', p_code, 'name', trim(p_name), 'is_active', p_is_active)
    );
  end if;

  return v_id;
end;
$$;

comment on function public.admin_upsert_document_type(uuid, text, text, public.document_owner, boolean, boolean, smallint) is
  'Crea o edita un tipo de documento. Nunca borra: los documentos lo referencian.';

revoke all on function public.admin_upsert_document_type(uuid, text, text, public.document_owner, boolean, boolean, smallint) from public;
grant execute on function public.admin_upsert_document_type(uuid, text, text, public.document_owner, boolean, boolean, smallint) to authenticated;


-- -----------------------------------------------------------------------------
-- Documentos
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_documents(
  p_owner public.document_owner,
  p_owner_id uuid
)
returns table (
  document_id uuid,
  document_type_id uuid,
  type_name text,
  requires_expiry boolean,
  file_path text,
  issued_at date,
  expires_at date,
  uploaded_at timestamptz,
  uploaded_by_name text,

  -- **Los dos avisos que hacen util esta pantalla.** Un documento vencido es lo
  -- que la empresa necesita ver antes de que se lo diga un policia en la calle.
  is_expired boolean,
  expires_soon boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    d.id,
    d.document_type_id,
    dt.name,
    dt.requires_expiry,
    d.file_path,
    d.issued_at,
    d.expires_at,
    d.created_at,
    p.full_name,
    d.expires_at is not null and d.expires_at < current_date,
    -- Treinta dias: da margen para renovar sin que el aviso salte tan pronto que
    -- se vuelva ruido.
    d.expires_at is not null
      and d.expires_at >= current_date
      and d.expires_at < current_date + 30
  from public.documents d
  join public.document_types dt on dt.id = d.document_type_id
  left join public.profiles p on p.id = d.uploaded_by
  where d.owner = p_owner
    and ((p_owner = 'driver' and d.driver_id = p_owner_id)
      or (p_owner = 'vehicle' and d.vehicle_id = p_owner_id))
  order by dt.sort_order, dt.name, d.created_at desc;
$$;

comment on function public.admin_list_documents(public.document_owner, uuid) is
  'Documentos de un conductor o de un vehiculo, con avisos de vencimiento.';

revoke all on function public.admin_list_documents(public.document_owner, uuid) from public;
grant execute on function public.admin_list_documents(public.document_owner, uuid) to authenticated;


create or replace function public.admin_register_document(
  p_document_type_id uuid,
  p_owner_id uuid,
  p_file_path text,
  p_issued_at date default null,
  p_expires_at date default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_type public.document_types;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede registrar documentos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_type from public.document_types where id = p_document_type_id;

  if not found then
    raise exception 'No se encontro ese tipo de documento'
      using errcode = 'P0001', hint = 'DOCUMENT_TYPE_NOT_FOUND';
  end if;

  if not v_type.is_active then
    raise exception 'Ese tipo de documento esta desactivado'
      using errcode = 'P0001', hint = 'DOCUMENT_TYPE_INACTIVE';
  end if;

  if length(trim(coalesce(p_file_path, ''))) = 0 then
    raise exception 'Falta la ruta del archivo'
      using errcode = 'P0001', hint = 'MISSING_FILE_PATH';
  end if;

  -- **LA CADUCIDAD ES OBLIGATORIA SI EL TIPO LA PIDE.** Es el motivo de que
  -- `requires_expiry` exista desde la Fase 5, y sin esta comprobacion ese campo
  -- seria decorativo: un seguro sin fecha de vencimiento no se puede vigilar.
  if v_type.requires_expiry and p_expires_at is null then
    raise exception 'Ese tipo de documento necesita fecha de vencimiento'
      using errcode = 'P0001', hint = 'EXPIRY_REQUIRED';
  end if;

  if p_expires_at is not null and p_issued_at is not null and p_expires_at <= p_issued_at then
    raise exception 'El vencimiento tiene que ser posterior a la fecha de expedicion'
      using errcode = 'P0001', hint = 'INVALID_EXPIRY_DATES';
  end if;

  -- Que el dueno exista y sea del tipo correcto. La clave foranea compuesta ya
  -- lo garantiza, pero con un mensaje que nadie puede leer.
  if v_type.owner = 'driver' then
    if not exists (select 1 from public.drivers where id = p_owner_id) then
      raise exception 'No se encontro ese conductor'
        using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
    end if;

    insert into public.documents (
      document_type_id, owner, driver_id, file_path, issued_at, expires_at, uploaded_by
    ) values (
      p_document_type_id, 'driver', p_owner_id, trim(p_file_path),
      p_issued_at, p_expires_at, (select auth.uid())
    )
    returning id into v_id;
  else
    if not exists (select 1 from public.vehicles where id = p_owner_id) then
      raise exception 'No se encontro ese vehiculo'
        using errcode = 'P0001', hint = 'VEHICLE_NOT_FOUND';
    end if;

    insert into public.documents (
      document_type_id, owner, vehicle_id, file_path, issued_at, expires_at, uploaded_by
    ) values (
      p_document_type_id, 'vehicle', p_owner_id, trim(p_file_path),
      p_issued_at, p_expires_at, (select auth.uid())
    )
    returning id into v_id;
  end if;

  perform public.log_admin_action(
    'register_document', 'documents', v_id::text, null,
    jsonb_build_object('type', v_type.name, 'owner', v_type.owner,
                       'owner_id', p_owner_id, 'expires_at', p_expires_at)
  );

  return v_id;
end;
$$;

comment on function public.admin_register_document(uuid, uuid, text, date, date) is
  'Registra un documento ya subido a Storage. Exige vencimiento si el tipo lo pide.';

revoke all on function public.admin_register_document(uuid, uuid, text, date, date) from public;
grant execute on function public.admin_register_document(uuid, uuid, text, date, date) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_delete_document
-- -----------------------------------------------------------------------------
--
-- **Este si borra la fila, al reves que casi todo en este proyecto.** Un
-- documento no es historial de una operacion: es un papel que puede estar mal
-- escaneado, ser el equivocado o haber caducado y sustituirse. Guardarlos todos
-- convertiria la ficha en un archivo inservible.
--
-- Devuelve la ruta **para que el panel borre tambien el archivo**. Si solo se
-- borrara la fila, el bucket acumularia cedulas de gente que ya no trabaja alli,
-- que es justo lo que no debe pasar con un dato personal.
create or replace function public.admin_delete_document(p_document_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc public.documents;
  v_type_name text;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede borrar documentos'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_doc from public.documents where id = p_document_id;

  if not found then
    raise exception 'No se encontro ese documento'
      using errcode = 'P0001', hint = 'DOCUMENT_NOT_FOUND';
  end if;

  select name into v_type_name from public.document_types where id = v_doc.document_type_id;

  delete from public.documents where id = p_document_id;

  -- El `before_data` guarda lo que habia, que es lo unico que quedara de ese
  -- documento cuando el archivo tambien desaparezca.
  perform public.log_admin_action(
    'delete_document', 'documents', p_document_id::text,
    jsonb_build_object('type', v_type_name, 'owner', v_doc.owner,
                       'file_path', v_doc.file_path, 'expires_at', v_doc.expires_at),
    null
  );

  return v_doc.file_path;
end;
$$;

comment on function public.admin_delete_document(uuid) is
  'Borra un documento y devuelve su ruta para que el panel borre el archivo.';

revoke all on function public.admin_delete_document(uuid) from public;
grant execute on function public.admin_delete_document(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierran las dos ultimas politicas de escritura directa
-- -----------------------------------------------------------------------------
--
-- **Con esto se acaba el hueco que aparecio cinco veces desde el paso 2.** Ya no
-- queda ninguna tabla del panel con `for all` para el administrador.
--
-- La lectura de `documents` se conserva y se amplia: `documents_all_admin` era
-- tambien lo que dejaba al administrador leerlos, asi que hace falta una politica
-- propia. Y se anade la del conductor sobre los suyos, que es coherente con la
-- politica del bucket: si puede descargar el archivo, tiene que poder ver que
-- existe.
drop policy if exists "document_types_all_admin" on public.document_types;
drop policy if exists "documents_all_admin" on public.documents;

create policy "document_types_select_admin"
  on public.document_types for select to authenticated
  using (public.is_admin());

create policy "documents_select_admin"
  on public.documents for select to authenticated
  using (public.is_admin());

create policy "documents_select_own_driver"
  on public.documents for select to authenticated
  using (owner = 'driver' and driver_id = (select auth.uid()));
