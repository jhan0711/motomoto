-- =============================================================================
-- FASE 20, PASO 6b: tarifas urbanas, tipos de carga y parametros
-- =============================================================================
--
-- Cierra el paso 6 y, con el, **las tres ultimas politicas `_all_admin` que
-- quedaban abiertas**: `urban_fares`, `cargo_types` y `app_settings`. Con esto
-- se acaba el hueco que aparecio cuatro veces desde el paso 2 -en `profiles`,
-- `drivers`, `vehicles` mas `driver_vehicle_assignments`, y `places` mas
-- `rural_fares`-: **ninguna tabla del panel admite ya escritura directa sin
-- auditoria**.
--
-- LA REJILLA URBANA NO SE CREA NI SE BORRA, SOLO SE EDITA. Son seis filas fijas
-- -uno, dos o tres pasajeros, de dia o de noche- y esa forma la decidio la
-- empresa. `urban_fares` **no tiene `is_active` a proposito** (bloque especial):
-- apagar "dos pasajeros de noche" no significa nada y dejaria un servicio sin
-- precio a las once. Por eso aqui solo hay una funcion para cambiar el importe.
--
-- LOS PARAMETROS SON DE DOS CLASES Y SE DICE CUAL ES CUAL. Unos son precios y
-- horarios; otros son reglas de operacion -los veinte segundos de R2, el maximo
-- de pasajeros de R11, el radio de llegada de R5-. Se gestionan en la misma
-- pantalla porque viven en la misma tabla, pero **cada uno lleva su rango
-- valido comprobado en el servidor**: sin eso, un cero en
-- `offer_response_seconds` dejaria la aplicacion sin repartir un solo servicio.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- admin_list_urban_fares
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_urban_fares()
returns table (
  passenger_count smallint,
  is_night boolean,
  amount integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select uf.passenger_count, uf.is_night, uf.amount
  from public.urban_fares uf
  order by uf.is_night, uf.passenger_count;
$$;

comment on function public.admin_list_urban_fares() is
  'La rejilla de tarifas urbanas: pasajeros por franja horaria.';

revoke all on function public.admin_list_urban_fares() from public;
grant execute on function public.admin_list_urban_fares() to authenticated;


-- -----------------------------------------------------------------------------
-- admin_set_urban_fare
-- -----------------------------------------------------------------------------

create or replace function public.admin_set_urban_fare(
  p_passenger_count smallint,
  p_is_night boolean,
  p_amount integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before integer;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar tarifas'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'La tarifa debe estar entre 1 y 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'INVALID_FARE_AMOUNT';
  end if;

  select amount into v_before from public.urban_fares
  where passenger_count = p_passenger_count and is_night = p_is_night;

  if not found then
    raise exception 'Esa casilla de la rejilla no existe'
      using errcode = 'P0001', hint = 'URBAN_FARE_NOT_FOUND';
  end if;

  if v_before = p_amount then
    raise exception 'Esa tarifa ya vale eso'
      using errcode = 'P0001', hint = 'FARE_UNCHANGED';
  end if;

  update public.urban_fares
  set amount = p_amount, updated_at = now(), updated_by = (select auth.uid())
  where passenger_count = p_passenger_count and is_night = p_is_night;

  perform public.log_admin_action(
    'set_urban_fare', 'urban_fares',
    p_passenger_count::text || (case when p_is_night then '-noche' else '-dia' end),
    jsonb_build_object('amount', v_before),
    jsonb_build_object('amount', p_amount, 'passenger_count', p_passenger_count,
                       'is_night', p_is_night)
  );
end;
$$;

comment on function public.admin_set_urban_fare(smallint, boolean, integer) is
  'Cambia el importe de una casilla de la rejilla urbana. No crea ni borra filas.';

revoke all on function public.admin_set_urban_fare(smallint, boolean, integer) from public;
grant execute on function public.admin_set_urban_fare(smallint, boolean, integer) to authenticated;


-- -----------------------------------------------------------------------------
-- Tipos de carga
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_cargo_types()
returns table (
  cargo_type_id uuid,
  name text,
  amount integer,
  is_active boolean,
  sort_order smallint,
  -- Cuantos servicios lo han llevado. Decide si se puede apagar sin dejar
  -- historial colgando -y la respuesta siempre es que si, porque el precio se
  -- congela en el servicio (D225)-.
  usage_count integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    ct.id, ct.name, ct.amount, ct.is_active, ct.sort_order,
    (select count(*)::integer from public.ride_request_cargo rc
     where rc.cargo_type_id = ct.id)
  from public.cargo_types ct
  order by ct.sort_order, ct.name;
$$;

comment on function public.admin_list_cargo_types() is
  'Catalogo de tipos de carga con su uso.';

revoke all on function public.admin_list_cargo_types() from public;
grant execute on function public.admin_list_cargo_types() to authenticated;


create or replace function public.admin_upsert_cargo_type(
  -- Nulo crea uno nuevo; con identificador, edita el que sea.
  p_cargo_type_id uuid,
  p_name text,
  p_amount integer,
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
  v_before public.cargo_types;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede gestionar los tipos de carga'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'El nombre debe tener al menos 2 caracteres'
      using errcode = 'P0001', hint = 'INVALID_CARGO_NAME';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'El precio debe estar entre 1 y 1.000.000 de pesos'
      using errcode = 'P0001', hint = 'INVALID_FARE_AMOUNT';
  end if;

  -- El nombre se compara normalizado. `cargo_types` normaliza como `places`, y
  -- el hallazgo H10 ya se midio aqui en el bloque especial: "Caja  grande" con
  -- dos espacios convivia con "Caja grande". Se aprieta ahora, que es cuando
  -- alguien puede teclearlo desde una pantalla.
  if exists (
    select 1 from public.cargo_types
    where lower(regexp_replace(trim(name), '\s+', ' ', 'g'))
        = lower(regexp_replace(trim(p_name), '\s+', ' ', 'g'))
      and (p_cargo_type_id is null or id <> p_cargo_type_id)
  ) then
    raise exception 'Ya existe un tipo de carga con ese nombre'
      using errcode = 'P0001', hint = 'CARGO_NAME_TAKEN';
  end if;

  if p_cargo_type_id is null then
    insert into public.cargo_types (name, amount, is_active, sort_order)
    values (regexp_replace(trim(p_name), '\s+', ' ', 'g'), p_amount, p_is_active, p_sort_order)
    returning id into v_id;

    perform public.log_admin_action(
      'create_cargo_type', 'cargo_types', v_id::text, null,
      jsonb_build_object('name', trim(p_name), 'amount', p_amount)
    );
  else
    select * into v_before from public.cargo_types where id = p_cargo_type_id;

    if not found then
      raise exception 'No se encontro ese tipo de carga'
        using errcode = 'P0001', hint = 'CARGO_TYPE_NOT_FOUND';
    end if;

    update public.cargo_types
    set name = regexp_replace(trim(p_name), '\s+', ' ', 'g'),
        amount = p_amount,
        is_active = p_is_active,
        sort_order = p_sort_order
    where id = p_cargo_type_id;

    v_id := p_cargo_type_id;

    perform public.log_admin_action(
      'update_cargo_type', 'cargo_types', p_cargo_type_id::text,
      jsonb_build_object('name', v_before.name, 'amount', v_before.amount,
                         'is_active', v_before.is_active),
      jsonb_build_object('name', trim(p_name), 'amount', p_amount, 'is_active', p_is_active)
    );
  end if;

  return v_id;
end;
$$;

comment on function public.admin_upsert_cargo_type(uuid, text, integer, boolean, smallint) is
  'Crea o edita un tipo de carga. Nunca borra: los servicios pasados lo referencian.';

revoke all on function public.admin_upsert_cargo_type(uuid, text, integer, boolean, smallint) from public;
grant execute on function public.admin_upsert_cargo_type(uuid, text, integer, boolean, smallint) to authenticated;


-- -----------------------------------------------------------------------------
-- Parametros de configuracion
-- -----------------------------------------------------------------------------
--
-- `app_settings` guarda `jsonb`, pero el panel manda texto: no tiene por que
-- saber que "5" va sin comillas y "America/Bogota" con ellas. La conversion y la
-- validacion viven aqui, **por clave**, que es el unico sitio donde se sabe que
-- significa cada una.

create or replace function public.admin_list_settings()
returns table (
  key text,
  value text,
  description text
)
language sql
stable
security invoker
set search_path = public
as $$
  select s.key, s.value #>> '{}', s.description
  from public.app_settings s
  order by s.key;
$$;

comment on function public.admin_list_settings() is
  'Parametros de configuracion, con el valor ya desenvuelto del jsonb.';

revoke all on function public.admin_list_settings() from public;
grant execute on function public.admin_list_settings() to authenticated;


create or replace function public.admin_set_setting(
  p_key text,
  p_value text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before text;
  v_number numeric;
  v_new jsonb;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar la configuracion'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  select value #>> '{}' into v_before from public.app_settings where key = p_key;

  if not found then
    -- No se crean parametros desde el panel. Una clave nueva no la lee nadie:
    -- las claves las inventa el codigo, no la pantalla.
    raise exception 'No existe ese parametro'
      using errcode = 'P0001', hint = 'SETTING_NOT_FOUND';
  end if;

  if coalesce(v_before, '') = coalesce(p_value, '') then
    raise exception 'Ese parametro ya vale eso'
      using errcode = 'P0001', hint = 'SETTING_UNCHANGED';
  end if;

  -- ---------------------------------------------------------------------------
  -- Validacion por clave. **CADA RANGO TIENE SU MOTIVO**, no son numeros
  -- redondos: son los limites donde el sistema deja de funcionar.
  -- ---------------------------------------------------------------------------
  if p_key = 'fare_timezone' then
    -- Se comprueba contra el catalogo de PostgreSQL, no contra una lista propia.
    if not exists (select 1 from pg_timezone_names where name = p_value) then
      raise exception 'Esa zona horaria no existe'
        using errcode = 'P0001', hint = 'INVALID_TIMEZONE';
    end if;
    v_new := to_jsonb(p_value);
  else
    begin
      v_number := p_value::numeric;
    exception when others then
      raise exception 'Ese parametro tiene que ser un numero'
        using errcode = 'P0001', hint = 'SETTING_MUST_BE_NUMBER';
    end;

    case p_key
      -- Horas del reloj. Fuera de 0..23 la franja nocturna no se puede evaluar.
      when 'night_fare_start_hour', 'night_fare_end_hour' then
        if v_number < 0 or v_number > 23 or v_number <> floor(v_number) then
          raise exception 'La hora debe ser un entero entre 0 y 23'
            using errcode = 'P0001', hint = 'INVALID_HOUR';
        end if;

      -- R11. Cero dejaria la aplicacion sin poder pedir un solo viaje de
      -- pasajeros; mas de 10 choca contra `vehicles_capacity_range`.
      when 'max_passengers_per_request' then
        if v_number < 1 or v_number > 10 or v_number <> floor(v_number) then
          raise exception 'El maximo de pasajeros debe ser un entero entre 1 y 10'
            using errcode = 'P0001', hint = 'INVALID_PASSENGER_MAX';
        end if;

      -- R2. Cero segundos caduca la oferta antes de que el conductor la vea;
      -- mas de cinco minutos deja al pasajero esperando a uno solo.
      when 'offer_response_seconds' then
        if v_number < 5 or v_number > 300 or v_number <> floor(v_number) then
          raise exception 'La ventana de oferta debe estar entre 5 y 300 segundos'
            using errcode = 'P0001', hint = 'INVALID_OFFER_WINDOW';
        end if;

      -- R1. Menos de un minuto caduca solicitudes que aun se estan repartiendo.
      when 'request_expiry_seconds' then
        if v_number < 60 or v_number > 3600 or v_number <> floor(v_number) then
          raise exception 'La caducidad debe estar entre 60 y 3600 segundos'
            using errcode = 'P0001', hint = 'INVALID_EXPIRY';
        end if;

      -- Coordenadas del centro del pueblo. **Mover esto cambia que lugares
      -- necesitan tarifa (D229) y de donde se mide D219**, asi que al menos se
      -- comprueba que sea una coordenada posible.
      when 'fare_center_lng' then
        if v_number < -180 or v_number > 180 then
          raise exception 'La longitud debe estar entre -180 y 180'
            using errcode = 'P0001', hint = 'INVALID_COORDINATE';
        end if;
      when 'fare_center_lat' then
        if v_number < -90 or v_number > 90 then
          raise exception 'La latitud debe estar entre -90 y 90'
            using errcode = 'P0001', hint = 'INVALID_COORDINATE';
        end if;

      -- Radios en kilometros. El de D230 pegado a cero desactiva el redondeo al
      -- destino mas cercano; muy grande vuelve a encarecer el pueblo, que es
      -- justo el problema que D231 corrigio midiendo.
      when 'rural_snap_max_km', 'unpriced_destination_max_km' then
        if v_number <= 0 or v_number > 50 then
          raise exception 'El radio debe estar entre 0 y 50 kilometros'
            using errcode = 'P0001', hint = 'INVALID_RADIUS';
        end if;

      else
        -- Los demas son metros o segundos de operacion. Un negativo no
        -- significa nada en ninguno.
        if v_number < 0 then
          raise exception 'Ese parametro no puede ser negativo'
            using errcode = 'P0001', hint = 'SETTING_MUST_BE_POSITIVE';
        end if;
    end case;

    v_new := to_jsonb(v_number);
  end if;

  update public.app_settings
  set value = v_new, updated_at = now()
  where key = p_key;

  perform public.log_admin_action(
    'set_setting', 'app_settings', p_key,
    jsonb_build_object('value', v_before),
    jsonb_build_object('value', p_value)
  );
end;
$$;

comment on function public.admin_set_setting(text, text) is
  'Cambia un parametro validando su rango por clave. No crea claves nuevas.';

revoke all on function public.admin_set_setting(text, text) from public;
grant execute on function public.admin_set_setting(text, text) to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierran las tres ultimas politicas de escritura directa
-- -----------------------------------------------------------------------------
--
-- Con esto, **ninguna tabla que el panel gestione admite ya UPDATE directo sin
-- auditoria**. La lectura se conserva entera: la aplicacion movil lee tarifas,
-- tipos de carga y parametros en cada servicio.
--
-- `cargo_types_select_active` solo deja ver los activos, asi que el
-- administrador necesita la suya para poder reactivar uno apagado.
drop policy if exists "urban_fares_all_admin" on public.urban_fares;
drop policy if exists "cargo_types_all_admin" on public.cargo_types;
drop policy if exists "app_settings_all_admin" on public.app_settings;

create policy "cargo_types_select_admin"
  on public.cargo_types for select to authenticated
  using (public.is_admin());
