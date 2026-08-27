-- =============================================================================
-- FASE 20, PASO 6a: lugares y tarifas rurales
-- =============================================================================
--
-- El paso 6 son cinco areas -lugares, tarifas rurales, tarifas urbanas, tipos de
-- carga y parametros- y se parte en dos. Estas dos van juntas y no por comodidad:
-- **D229 las ata**. Las otras tres son catalogos pequenos y fijos, y van en 6b.
--
-- CUARTA APARICION DEL MISMO HUECO. `places_all_admin`, `rural_fares_all_admin`,
-- `urban_fares_all_admin`, `cargo_types_all_admin` y `app_settings_all_admin`
-- son `for all`: **se puede cambiar un precio con un UPDATE directo y sin dejar
-- rastro**. Aqui se cierran las dos primeras; las otras tres en 6b.
--
-- Y en estas tablas importa mas que en ninguna de las anteriores: **son las que
-- deciden cuanto paga la gente**. Un precio cambiado sin saber quien lo cambio
-- ni que valia antes es exactamente lo que la auditoria existe para evitar.
--
-- D229 SE APLICA CON EL DATO, NO CON EL CRITERIO. La decision decia que el panel
-- no dejara crear un lugar sin decidir su tarifa, para tapar el hueco de D219:
-- si el administrador agrega un destino lejano y se olvida del precio, ese
-- destino cobraria tarifa urbana en silencio y nadie se enteraria hasta que el
-- conductor volviera quejandose.
--
-- Aqui no se pregunta "¿es rural?" y se confia en la respuesta: **se mide la
-- distancia al centro del pueblo y se compara con `unpriced_destination_max_km`,
-- el mismo parametro que ya usa D219 para rebotar destinos sin precio**. Si el
-- lugar cae fuera de ese radio y no trae tarifa rural, no se crea. Asi la regla
-- del panel y la regla del servidor son **el mismo numero**, y afinar una afina
-- la otra.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_list_places
-- -----------------------------------------------------------------------------
--
-- `security invoker` (D242). La lectura de `places` esta limitada a los activos
-- para el publico -`places_select_active`- y abierta al administrador, asi que
-- siendo invoker un pasajero que llamara a esta funcion veria solo los lugares
-- que ya ve en su aplicacion.
create or replace function public.admin_list_places()
returns table (
  place_id uuid,
  name text,
  description text,
  lng double precision,
  lat double precision,
  is_active boolean,
  sort_order smallint,
  distance_from_center_m integer,
  rural_amount integer,
  rural_is_active boolean,
  needs_fare boolean,
  usage_count integer
)
language sql
stable
security invoker
set search_path = public
as $$
  with centro as (
    select
      extensions.st_setsrid(
        extensions.st_makepoint(
          (select (value #>> '{}')::double precision from public.app_settings
           where key = 'fare_center_lng'),
          (select (value #>> '{}')::double precision from public.app_settings
           where key = 'fare_center_lat')
        ), 4326)::extensions.geography as punto,
      (select (value #>> '{}')::double precision from public.app_settings
       where key = 'unpriced_destination_max_km') as max_km
  )
  select
    p.id,
    p.name,
    p.description,
    extensions.st_x(p.location::extensions.geometry),
    extensions.st_y(p.location::extensions.geometry),
    p.is_active,
    p.sort_order,
    round(extensions.st_distance(p.location, c.punto))::integer,
    rf.amount,
    rf.is_active,
    extensions.st_distance(p.location, c.punto) > c.max_km * 1000
      and coalesce(rf.is_active, false) = false,
    (select count(*)::integer from public.ride_requests rr
     where rr.origin_place_id = p.id or rr.destination_place_id = p.id)
  from public.places p
  cross join centro c
  left join public.rural_fares rf on rf.place_id = p.id
  order by p.sort_order, p.name;
$$;

comment on function public.admin_list_places() is
  'Lugares con su distancia al centro, su tarifa rural y si les falta uno (D229).';

revoke all on function public.admin_list_places() from public;
grant execute on function public.admin_list_places() to authenticated;


-- -----------------------------------------------------------------------------
-- admin_create_place
-- -----------------------------------------------------------------------------

create or replace function public.admin_create_place(
  p_name text,
  p_lng double precision,
  p_lat double precision,
  p_description text default null,
  p_sort_order smallint default 0,
  -- Nulo significa "cobra tarifa urbana". Un numero crea ademas su fila en
  -- `rural_fares`, en la misma transaccion.
  p_rural_amount integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_center extensions.geography;
  v_max_km double precision;
  v_distance double precision;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede crear lugares'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if length(trim(coalesce(p_name, ''))) not between 2 and 120 then
    raise exception 'El nombre debe tener entre 2 y 120 caracteres'
      using errcode = 'P0001', hint = 'INVALID_PLACE_NAME';
  end if;

  -- Sobre el nombre normalizado, igual que el indice unico: sin esto, "EL
  -- PARQUE" pasaria la comprobacion y chocaria despues con un 23505 sin
  -- explicacion. Es el hallazgo H10 otra vez.
  if exists (select 1 from public.places where lower(trim(name)) = lower(trim(p_name))) then
    raise exception 'Ya existe un lugar con ese nombre'
      using errcode = 'P0001', hint = 'PLACE_NAME_TAKEN';
  end if;

  if p_lng is null or p_lat is null then
    raise exception 'El lugar necesita una coordenada'
      using errcode = 'P0001', hint = 'PLACE_NEEDS_LOCATION';
  end if;

  -- Fuera del municipio no se crea. La zona de servicio ya existe desde la
  -- Fase 11 y es la misma que valida `request_ride`: si un lugar cayera fuera,
  -- seria un destino que la aplicacion nunca dejaria pedir.
  if not public.is_within_service_area(
       extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography
     ) then
    raise exception 'Ese punto esta fuera del area de servicio del municipio'
      using errcode = 'P0001', hint = 'PLACE_OUTSIDE_SERVICE_AREA';
  end if;

  if p_rural_amount is not null and (p_rural_amount <= 0 or p_rural_amount > 1000000) then
    raise exception 'La tarifa debe estar entre 1 y 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'INVALID_FARE_AMOUNT';
  end if;

  -- ---------------------------------------------------------------------------
  -- D229: no se crea un lugar lejano sin decidir su tarifa
  -- ---------------------------------------------------------------------------
  select
    extensions.st_setsrid(
      extensions.st_makepoint(
        (select (value #>> '{}')::double precision from public.app_settings
         where key = 'fare_center_lng'),
        (select (value #>> '{}')::double precision from public.app_settings
         where key = 'fare_center_lat')
      ), 4326)::extensions.geography,
    (select (value #>> '{}')::double precision from public.app_settings
     where key = 'unpriced_destination_max_km')
  into v_center, v_max_km;

  v_distance := extensions.st_distance(
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    v_center
  );

  if v_distance > v_max_km * 1000 and p_rural_amount is null then
    -- El mensaje **da el numero**, no solo la negativa: quien lo lee tiene que
    -- poder decidir si pone tarifa o si movio mal la chincheta.
    raise exception 'Ese lugar esta a % km del centro. Necesita una tarifa rural, o la aplicacion no dejara pedir viajes hasta alli',
      round((v_distance / 1000)::numeric, 1)
      using errcode = 'P0001', hint = 'DISTANT_PLACE_NEEDS_FARE';
  end if;

  insert into public.places (name, description, location, sort_order)
  values (
    trim(p_name),
    nullif(trim(coalesce(p_description, '')), ''),
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
    p_sort_order
  )
  returning id into v_id;

  if p_rural_amount is not null then
    insert into public.rural_fares (place_id, amount, updated_by)
    values (v_id, p_rural_amount, (select auth.uid()));
  end if;

  perform public.log_admin_action(
    'create_place', 'places', v_id::text, null,
    jsonb_build_object('name', trim(p_name), 'lng', p_lng, 'lat', p_lat,
                       'distance_from_center_m', round(v_distance),
                       'rural_amount', p_rural_amount)
  );

  return v_id;
end;
$$;

comment on function public.admin_create_place(text, double precision, double precision, text, smallint, integer) is
  'Crea un lugar. Exige tarifa rural si cae fuera del radio de D219 (D229).';

revoke all on function public.admin_create_place(text, double precision, double precision, text, smallint, integer) from public;
grant execute on function public.admin_create_place(text, double precision, double precision, text, smallint, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_update_place
-- -----------------------------------------------------------------------------

create or replace function public.admin_update_place(
  p_place_id uuid,
  p_name text,
  p_description text,
  p_is_active boolean,
  p_sort_order smallint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.places;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede editar lugares'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_before from public.places where id = p_place_id;

  if not found then
    raise exception 'No se encontro ese lugar'
      using errcode = 'P0001', hint = 'PLACE_NOT_FOUND';
  end if;

  if length(trim(coalesce(p_name, ''))) not between 2 and 120 then
    raise exception 'El nombre debe tener entre 2 y 120 caracteres'
      using errcode = 'P0001', hint = 'INVALID_PLACE_NAME';
  end if;

  if exists (
    select 1 from public.places
    where lower(trim(name)) = lower(trim(p_name)) and id <> p_place_id
  ) then
    raise exception 'Ya existe otro lugar con ese nombre'
      using errcode = 'P0001', hint = 'PLACE_NAME_TAKEN';
  end if;

  -- LA COORDENADA NO SE EDITA AQUI, y es deliberado. Mover un lugar cambia su
  -- distancia al centro, y con ella puede cambiar si necesita tarifa rural
  -- (D229) y a que destino se pega un punto suelto (D230). Es una operacion con
  -- consecuencias sobre los precios, no un campo mas de un formulario: si hace
  -- falta, se dara de baja el lugar y se creara otro, que ademas conserva el
  -- historial de los viajes que usaron el sitio viejo.
  update public.places
  set name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      is_active = p_is_active,
      sort_order = p_sort_order
  where id = p_place_id;

  perform public.log_admin_action(
    'update_place', 'places', p_place_id::text,
    jsonb_build_object('name', v_before.name, 'is_active', v_before.is_active,
                       'sort_order', v_before.sort_order),
    jsonb_build_object('name', trim(p_name), 'is_active', p_is_active,
                       'sort_order', p_sort_order)
  );
end;
$$;

comment on function public.admin_update_place(uuid, text, text, boolean, smallint) is
  'Edita nombre, descripcion, estado y orden de un lugar. La coordenada no se toca.';

revoke all on function public.admin_update_place(uuid, text, text, boolean, smallint) from public;
grant execute on function public.admin_update_place(uuid, text, text, boolean, smallint) to authenticated;


-- -----------------------------------------------------------------------------
-- admin_set_rural_fare
-- -----------------------------------------------------------------------------
--
-- Pone, cambia, enciende o apaga la tarifa rural de un lugar. Una sola funcion
-- para las cuatro cosas porque son la misma decision: **cuanto cuesta ir a este
-- sitio**, y `null` significa "lo que cueste el pueblo".
create or replace function public.admin_set_rural_fare(
  p_place_id uuid,
  -- Nulo apaga la tarifa; un numero la pone o la cambia y la deja activa.
  p_amount integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_place public.places;
  v_before public.rural_fares;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar tarifas'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select * into v_place from public.places where id = p_place_id;

  if not found then
    raise exception 'No se encontro ese lugar'
      using errcode = 'P0001', hint = 'PLACE_NOT_FOUND';
  end if;

  if p_amount is not null and (p_amount <= 0 or p_amount > 1000000) then
    raise exception 'La tarifa debe estar entre 1 y 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'INVALID_FARE_AMOUNT';
  end if;

  select * into v_before from public.rural_fares where place_id = p_place_id;

  if p_amount is null then
    -- APAGAR, NO BORRAR. La fila se conserva con su precio por si el destino se
    -- reactiva, que es justo lo que dice el comentario de la tabla en la
    -- migracion del bloque especial.
    if v_before.place_id is null then
      raise exception 'Ese lugar no tiene tarifa rural que quitar'
        using errcode = 'P0001', hint = 'NO_RURAL_FARE';
    end if;

    if not v_before.is_active then
      raise exception 'Esa tarifa ya esta apagada'
        using errcode = 'P0001', hint = 'FARE_UNCHANGED';
    end if;

    update public.rural_fares
    set is_active = false, updated_at = now(), updated_by = (select auth.uid())
    where place_id = p_place_id;
  else
    if v_before.place_id is null then
      insert into public.rural_fares (place_id, amount, updated_by)
      values (p_place_id, p_amount, (select auth.uid()));
    else
      if v_before.amount = p_amount and v_before.is_active then
        raise exception 'Esa tarifa ya vale eso'
          using errcode = 'P0001', hint = 'FARE_UNCHANGED';
      end if;

      update public.rural_fares
      set amount = p_amount, is_active = true, updated_at = now(),
          updated_by = (select auth.uid())
      where place_id = p_place_id;
    end if;
  end if;

  perform public.log_admin_action(
    case when p_amount is null then 'disable_rural_fare' else 'set_rural_fare' end,
    'rural_fares', p_place_id::text,
    case when v_before.place_id is null then null
         else jsonb_build_object('amount', v_before.amount, 'is_active', v_before.is_active) end,
    jsonb_build_object('place_name', v_place.name, 'amount', p_amount,
                       'is_active', p_amount is not null)
  );
end;
$$;

comment on function public.admin_set_rural_fare(uuid, integer) is
  'Pone, cambia o apaga la tarifa rural de un lugar. Nulo la apaga, no la borra.';

revoke all on function public.admin_set_rural_fare(uuid, integer) from public;
grant execute on function public.admin_set_rural_fare(uuid, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierra la escritura directa de lugares y tarifas rurales
-- -----------------------------------------------------------------------------
--
-- La lectura se conserva tal cual: `places_select_active` y
-- `rural_fares_select_active` para la aplicacion, y se anade la del
-- administrador, que necesita ver tambien los apagados para poder reactivarlos.
drop policy if exists "places_all_admin" on public.places;
drop policy if exists "rural_fares_all_admin" on public.rural_fares;

create policy "places_select_admin"
  on public.places for select to authenticated
  using (public.is_admin());

create policy "rural_fares_select_admin"
  on public.rural_fares for select to authenticated
  using (public.is_admin());
