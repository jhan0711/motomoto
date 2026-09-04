-- =============================================================================
-- ELIMINACION DE CUENTA (Fase 26 paso 7b)
-- =============================================================================
--
-- Google Play exige, para apps con registro, un camino DENTRO de la app para
-- borrar la cuenta y los datos, y una URL web equivalente. `delete_my_account`
-- cubre lo primero, para pasajeros: las cuentas de conductor las crea y
-- gestiona la empresa (D250), asi que un conductor que quiera salir lo pide a
-- la administracion.
--
-- QUE SE BORRA
--   - auth.users del que llama -> por cascada: profiles, notifications, reports.
--   - las calificaciones que dio o recibio (borrado explicito antes de tocar
--     auth.users, para que el disparador refresh_driver_rating recalcule el
--     promedio del conductor).
--   - el avatar: lo borra el CLIENTE antes de llamar a esta funcion. Tiene
--     permiso RLS sobre su propia carpeta del bucket, y una funcion
--     security definer no puede tocar storage.objects en el Supabase gestionado.
--
-- QUE SE ANONIMIZA (no se borra)
--   El historial de viajes TERMINADOS. Es registro operativo del conductor
--   -cuantos servicios hizo, su recaudo del dia-. `passenger_id` de esas
--   solicitudes pasa a apuntar al perfil marcador "Cuenta eliminada", y se
--   borra `pickup_reference` (texto libre que el pasajero escribio, puede tener
--   una direccion). El origen y el destino quedan como coordenadas sin nombre.
--
-- GUARDA
--   No se puede borrar la cuenta con un servicio en curso (`searching`,
--   `assigned`, `in_progress`): primero hay que terminarlo o cancelarlo, si no
--   un conductor quedaria yendo a recoger a un fantasma.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Perfil marcador "Cuenta eliminada"
-- -----------------------------------------------------------------------------
-- Una sola fila, con id fijo. Necesita su auth.users porque profiles.id tiene
-- FK a auth.users con ON DELETE CASCADE. Misma maniobra que las semillas: se
-- sustituye la fila del perfil en vez de actualizarla, porque
-- `profiles_protect_columns` revierte cualquier cambio de rol/estado y aqui no
-- hay sesion (hallazgo H5). Idempotente.
do $marcador$
declare
  c_id constant uuid := 'de1e7ed0-0000-4000-8000-000000000000';
begin
  if not exists (select 1 from auth.users where id = c_id) then
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      c_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'cuenta-eliminada@amalfigo.invalid',
      -- Hash bcrypt de una cadena aleatoria de 72 caracteres: valido, pero de
      -- una contrasena que nadie conoce ni puede teclear. Esta cuenta no inicia
      -- sesion nunca; solo existe para que las solicitudes anonimizadas tengan
      -- a donde apuntar.
      extensions.crypt(
        gen_random_uuid()::text || gen_random_uuid()::text,
        extensions.gen_salt('bf')
      ),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Cuenta eliminada"}',
      '', '', '', ''
    );
  end if;

  -- El disparador on_auth_user_created ya creo el perfil con rol passenger.
  delete from public.profiles where id = c_id;

  insert into public.profiles (id, full_name, phone, role, status)
  values (c_id, 'Cuenta eliminada', null, 'passenger', 'blocked')
  on conflict (id) do nothing;
end
$marcador$;


-- -----------------------------------------------------------------------------
-- delete_my_account
-- -----------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role public.user_role;
  c_marcador constant uuid := 'de1e7ed0-0000-4000-8000-000000000000';
begin
  if v_uid is null then
    raise exception 'No hay sesion' using errcode = 'P0001', hint = 'NOT_AUTHENTICATED';
  end if;

  select role into v_role from public.profiles where id = v_uid;

  if v_role is null then
    raise exception 'No se encontro tu perfil'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  -- Solo pasajeros. Un conductor o un administrador que quiera salir lo pide a
  -- la empresa: su cuenta tiene un vehiculo asignado, turnos, documentos.
  if v_role <> 'passenger' then
    raise exception 'Esta cuenta la gestiona la empresa. Comunicate con la administracion para darla de baja'
      using errcode = 'P0001', hint = 'ACCOUNT_DELETE_NOT_PASSENGER';
  end if;

  -- No con un servicio en curso.
  if exists (
    select 1 from public.ride_requests
    where passenger_id = v_uid
      and status in ('searching', 'assigned', 'in_progress')
  ) then
    raise exception 'Tienes un servicio en curso. Termínalo o cancélalo antes de eliminar tu cuenta'
      using errcode = 'P0001', hint = 'ACCOUNT_DELETE_ACTIVE_RIDE';
  end if;

  -- Anonimiza el historial terminado: se lo queda el perfil marcador y se borra
  -- la referencia de recogida (texto libre).
  update public.ride_requests
  set passenger_id = c_marcador,
      pickup_reference = null
  where passenger_id = v_uid;

  -- Calificaciones que dio o recibio. Borrado explicito -no por cascada- para
  -- que refresh_driver_rating recalcule el promedio de cada conductor afectado.
  delete from public.ratings where rater_id = v_uid or rated_id = v_uid;

  -- Y la cuenta. Por cascada de FK se van: profiles, notifications, reports,
  -- y las sesiones/identidades del esquema auth.
  delete from auth.users where id = v_uid;
end;
$$;

comment on function public.delete_my_account() is
  'Fase 26 paso 7b. Borra la cuenta del pasajero que llama (auth.users -> cascada). '
  'Anonimiza su historial de viajes terminados hacia el perfil marcador '
  'de1e7ed0-0000-4000-8000-000000000000. El cliente borra el avatar antes de llamar.';

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
