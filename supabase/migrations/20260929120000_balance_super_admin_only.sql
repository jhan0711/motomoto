-- Pedido del usuario, 2026-09-29: tocar dinero real (D278/D279) queda reservado
-- al super administrador, no a cualquier admin.
--
--   * `admin_adjust_driver_balance`: mueve saldo de verdad -recargar a mano o
--     revertir una comision en disputa-, exigia `is_admin()` (admin O super
--     admin). Pasa a `is_super_admin()`.
--   * `admin_set_setting('driver_balance_enforced', ...)`: es el interruptor que
--     activa el cobro del 4% para TODOS los conductores a la vez. Se le anade el
--     mismo requisito, antes de la validacion de rango que ya tenia.
--
-- Los demas parametros de `admin_set_setting` (comision, recarga minima, y
-- todo lo que no sea este interruptor) siguen abiertos a cualquier admin, igual
-- que hoy: no se pidio restringirlos y no cambia nada mas.
--
-- LO QUE NO CAMBIA: `admin_list_driver_balances` y `admin_get_driver_ledger`
-- -ver el saldo y el libro- siguen abiertas a cualquier admin. Se pidio
-- restringir quien AJUSTA el dinero, no quien lo puede consultar.

create or replace function public.admin_adjust_driver_balance(
  p_driver uuid,
  p_amount integer,
  p_reason text,
  p_ride_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
begin
  if not public.is_super_admin() then
    raise exception 'Solo un super administrador puede ajustar un saldo'
      using errcode = 'P0001', hint = 'NOT_A_SUPER_ADMIN';
  end if;

  if not exists (select 1 from public.drivers where id = p_driver) then
    raise exception 'No encontramos a ese conductor'
      using errcode = 'P0001', hint = 'DRIVER_NOT_FOUND';
  end if;

  if p_amount is null or p_amount = 0 or abs(p_amount) > 10000000 then
    raise exception 'El ajuste debe ser un valor distinto de cero'
      using errcode = 'P0001', hint = 'INVALID_ADJUSTMENT_AMOUNT';
  end if;

  if p_reason is null or length(trim(p_reason)) < 5 or length(p_reason) > 300 then
    raise exception 'Explica el motivo del ajuste (entre 5 y 300 caracteres)'
      using errcode = 'P0001', hint = 'ADJUSTMENT_REASON_REQUIRED';
  end if;

  insert into public.driver_ledger (driver_id, kind, amount, ride_id, reason, created_by)
  values (p_driver, 'adjustment', p_amount, p_ride_id, trim(p_reason), (select auth.uid()));

  v_balance := public.driver_balance(p_driver);

  perform public.log_admin_action(
    'adjust_driver_balance', 'driver_ledger', p_driver::text,
    null,
    jsonb_build_object('amount', p_amount, 'reason', trim(p_reason), 'ride_id', p_ride_id,
                       'balance_after', v_balance)
  );

  return v_balance;
end;
$$;

-- ---------------------------------------------------------------------------
-- El interruptor de cobro, solo para super admin
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_setting(p_key text, p_value text)
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

  -- Este parametro en concreto activa el cobro del 4% para TODOS los
  -- conductores a la vez (D278): un admin normal puede tocar la tarifa
  -- nocturna, pero no encender que se le empiece a cobrar dinero real a la
  -- flota entera.
  if p_key = 'driver_balance_enforced' and not public.is_super_admin() then
    raise exception 'Solo un super administrador puede cambiar el cobro por saldo'
      using errcode = 'P0001', hint = 'NOT_A_SUPER_ADMIN';
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

      -- R9. El conductor manda su posicion cada tantos segundos: en viaje cada
      -- 7-10, disponible cada 30. Por debajo de 3 s el temporizador se dispara
      -- casi en bucle y llena `driver_locations` -la tabla mas caliente del
      -- sistema- sin ganar precision; por encima de 30 el pasajero ve el
      -- motocarro dando saltos y roza el umbral de "sin senal".
      when 'location_interval_in_ride_seconds' then
        if v_number < 3 or v_number > 30 or v_number <> floor(v_number) then
          raise exception 'El intervalo en viaje debe ser un entero entre 3 y 30 segundos'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_INTERVAL';
        end if;

      -- Estando solo disponible la posicion sirve para elegir a quien ofrecer un
      -- servicio, no para verlo moverse: por debajo de 10 s es gasto de bateria y
      -- datos para nada. El maximo tiene que quedar por debajo de
      -- `driver_location_stale_seconds` o el conductor caducaria entre un envio y
      -- el siguiente y `find_available_drivers` no lo veria.
      when 'location_interval_available_seconds' then
        if v_number < 10 or v_number > 45 or v_number <> floor(v_number) then
          raise exception 'El intervalo disponible debe ser un entero entre 10 y 45 segundos'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_INTERVAL';
        end if;

      -- El "filtro de distancia minima" de D14/D189: adelanta un envio cuando el
      -- conductor ya recorrio esa distancia, y marca el paso del rastro. En 0,
      -- cada lectura del GPS -que llega con ruido de varios metros- dispara un
      -- envio. Por encima de 500 m el acelerador no salta nunca y el rastro
      -- queda demasiado disperso.
      when 'location_min_distance_m' then
        if v_number < 10 or v_number > 500 or v_number <> floor(v_number) then
          raise exception 'La distancia minima debe ser un entero entre 10 y 500 metros'
            using errcode = 'P0001', hint = 'INVALID_LOCATION_DISTANCE';
        end if;

      -- Cuanto tiene que pasar sin noticias de un conductor para considerar su
      -- posicion caducada. `find_available_drivers` filtra por esto. En 0, nadie
      -- esta disponible nunca. Tiene que ser >= el maximo del intervalo
      -- disponible (45) con margen; por encima de 600 s un conductor que cerro la
      -- aplicacion hace diez minutos seguiria contando como disponible.
      when 'driver_location_stale_seconds' then
        if v_number < 90 or v_number > 600 or v_number <> floor(v_number) then
          raise exception 'La caducidad de la posicion debe ser un entero entre 90 y 600 segundos'
            using errcode = 'P0001', hint = 'INVALID_STALE_WINDOW';
        end if;

      -- Radio dentro del cual el conductor puede confirmar que llego al punto de
      -- recogida. En 0 no puede confirmar jamas -y el servicio se queda
      -- atascado-; por debajo de 20 m el error del GPS ya lo dejaria fuera
      -- estando encima. Por encima de 1 km "he llegado" pierde el sentido.
      when 'driver_arrival_radius_m' then
        if v_number < 20 or v_number > 1000 or v_number <> floor(v_number) then
          raise exception 'El radio de llegada debe ser un entero entre 20 y 1000 metros'
            using errcode = 'P0001', hint = 'INVALID_ARRIVAL_RADIUS';
        end if;

      -- Colchon alrededor del poligono de la zona de servicio. Cero es valido
      -- -exactamente el poligono-; por encima de 5 km el colchon se traga los
      -- municipios vecinos y se aceptarian viajes que no son de Amalfi.
      when 'service_area_margin_m' then
        if v_number < 0 or v_number > 5000 or v_number <> floor(v_number) then
          raise exception 'El margen del area debe ser un entero entre 0 y 5000 metros'
            using errcode = 'P0001', hint = 'INVALID_AREA_MARGIN';
        end if;

      -- Ventana de cancelacion sin penalizacion. Cero es una decision de negocio
      -- valida -se penaliza desde el primer segundo-; por encima de 600 s la
      -- penalizacion no existiria en la practica.
      when 'free_cancellation_seconds' then
        if v_number < 0 or v_number > 600 or v_number <> floor(v_number) then
          raise exception 'La ventana de cancelacion libre debe ser un entero entre 0 y 600 segundos'
            using errcode = 'P0001', hint = 'INVALID_FREE_CANCELLATION';
        end if;

      -- Cuanto se ensena el resumen del servicio recien terminado. En 0 no se
      -- ve; es una tarjeta de transicion, mas de una hora es estorbo.
      when 'finished_summary_minutes' then
        if v_number < 1 or v_number > 60 or v_number <> floor(v_number) then
          raise exception 'La ventana del resumen debe ser un entero entre 1 y 60 minutos'
            using errcode = 'P0001', hint = 'INVALID_SUMMARY_WINDOW';
        end if;

      -- R10 (D263). Cuanto lleva un conductor sin mandar posicion para que el
      -- tablero lo marque "sin senal". Por debajo de 60 s un hueco normal de GPS
      -- -un tunel, el pueblo- lo dispararia todo el rato; por encima de 900 s un
      -- conductor de verdad incomunicado pasaria un cuarto de hora sin que nadie
      -- lo note. La regla avisa, no cancela.
      when 'driver_signal_lost_seconds' then
        if v_number < 60 or v_number > 900 or v_number <> floor(v_number) then
          raise exception 'El umbral de senal perdida debe ser un entero entre 60 y 900 segundos'
            using errcode = 'P0001', hint = 'INVALID_SIGNAL_WINDOW';
        end if;

      -- D278. El interruptor solo admite 0 y 1: cualquier otro valor no seria ni
      -- apagado ni encendido y `balance_enforced` lo leeria como apagado sin
      -- avisar.
      when 'driver_balance_enforced' then
        if v_number not in (0, 1) then
          raise exception 'El interruptor solo puede ser 0 (apagado) o 1 (encendido)'
            using errcode = 'P0001', hint = 'INVALID_SWITCH';
        end if;

      -- D278. Por encima de 20% la comision se come el viaje; en 0 no hay
      -- negocio. Admite decimales (3,5).
      when 'commission_percent' then
        if v_number <= 0 or v_number > 20 then
          raise exception 'La comision debe estar entre 0 y 20 por ciento'
            using errcode = 'P0001', hint = 'INVALID_COMMISSION';
        end if;

      -- D278. Por debajo de mil pesos las comisiones de la pasarela se comen la
      -- recarga; por encima de un millon un conductor inmovilizaria mas plata de
      -- la que gana en un mes de servicios.
      when 'min_topup_amount' then
        if v_number < 1000 or v_number > 1000000 or v_number <> floor(v_number) then
          raise exception 'La recarga minima debe ser un entero entre 1.000 y 1.000.000'
            using errcode = 'P0001', hint = 'INVALID_MIN_TOPUP';
        end if;

      else
        -- Todas las claves que el panel deja editar tienen su rango arriba. Si
        -- una llega aqui es que se anadio al panel y se olvido su cota: se
        -- rechaza en vez de dejar guardar un valor sin validar.
        raise exception 'Ese parametro no tiene rango definido'
          using errcode = 'P0001', hint = 'SETTING_HAS_NO_RANGE';
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
