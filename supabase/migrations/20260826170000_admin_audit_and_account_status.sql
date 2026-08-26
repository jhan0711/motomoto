-- =============================================================================
-- FASE 20, PASO 2: la auditoria deja de ser una tabla vacia
-- =============================================================================
--
-- `admin_audit_logs` existe desde la Fase 5, con sus dos indices y su politica
-- de lectura. Al empezar esta fase se comprobo contra el servidor: CERO FILAS, y
-- ninguna migracion del proyecto escribe en ella. Es decir que el registro de
-- acciones administrativas que pide la seccion 5 estaba declarado pero no
-- existia.
--
-- Y habia un hueco peor detras. `profiles_update_admin` permite a un
-- administrador cambiar el estado de cualquier cuenta con un UPDATE directo, asi
-- que el panel podria bloquear a un usuario **sin dejar rastro**: la auditoria
-- seguiria en cero y nadie sabria quien lo hizo. Lo mismo valdria para
-- cualquiera con la clave publicable y una sesion de administrador, que puede
-- llamar a la API a mano sin pasar por el panel.
--
-- LA DECISION (D240, tomada con el usuario el 2026-08-26): las acciones
-- administrativas se hacen por FUNCIONES QUE AUDITAN EN LA MISMA TRANSACCION.
-- No es una convencion que haya que recordar: si la auditoria falla, el cambio
-- tampoco pasa, porque son la misma transaccion. Es la misma idea con la que el
-- bloque especial garantizo la formula de la tarifa con restricciones en vez de
-- con codigo: la regla deja de ser algo que hay que acordarse de cumplir.
--
-- Este paso construye la base y la primera accion. Las demas -aprobar un
-- conductor, cambiar una tarifa, asignar un vehiculo- llegan en sus pasos y ya
-- se apoyan en esto.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- log_admin_action
-- -----------------------------------------------------------------------------
--
-- El unico camino por el que se escribe en la auditoria.
--
-- Es `security definer` porque `admin_audit_logs` no tiene politica de INSERT
-- para nadie, ni siquiera para el administrador, y eso es a proposito: si el
-- panel pudiera insertar filas de auditoria directamente, tambien podria
-- inventarlas. Una auditoria que el auditado puede escribir a mano no vale como
-- auditoria.
create or replace function public.log_admin_action(
  p_action text,
  p_entity_type text,
  p_entity_id text default null,
  p_before jsonb default null,
  p_after jsonb default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  -- Se comprueba aqui dentro y no se confia en quien llama. Esta funcion se
  -- ejecuta con privilegios, asi que tiene que ser su propia puerta.
  if not public.is_admin() then
    raise exception 'Solo un administrador puede registrar acciones administrativas'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  insert into public.admin_audit_logs (
    actor_id, action, entity_type, entity_id, before_data, after_data
  ) values (
    (select auth.uid()), p_action, p_entity_type, p_entity_id, p_before, p_after
  )
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.log_admin_action(text, text, text, jsonb, jsonb) is
  'Unico camino de escritura de admin_audit_logs. Exige administrador activo.';

revoke all on function public.log_admin_action(text, text, text, jsonb, jsonb) from public;
grant execute on function public.log_admin_action(text, text, text, jsonb, jsonb)
  to authenticated;


-- -----------------------------------------------------------------------------
-- Se cierra el camino directo al estado de una cuenta
-- -----------------------------------------------------------------------------
--
-- `profiles_protect_columns`, de la Fase 5, revierte cualquier cambio de rol o
-- estado... salvo cuando quien actualiza es administrador, que es justo el caso
-- que abre el agujero de arriba. Ahora tambien a un administrador se le revierte
-- en un UPDATE directo, y el unico camino para cambiar el estado pasa a ser la
-- funcion auditada de mas abajo.
--
-- La marca local es el mismo mecanismo que D87 uso para que el recalculo de la
-- calificacion pudiera distinguirse de un intento de fraude. Un cliente no puede
-- ponerla por su cuenta y colarse: `set_config` con ambito local muere al
-- terminar la transaccion, y la funcion que la pone ya comprobo is_admin() antes.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('motomoto.admin_action', true), '') = 'on' then
    return new;
  end if;

  -- Cualquier intento de cambiar rol o estado se revierte en silencio al valor
  -- anterior. Se revierte en lugar de fallar para que la aplicacion pueda enviar
  -- el objeto completo del perfil sin tener que excluir estos campos.
  new.role := old.role;
  new.status := old.status;
  return new;
end;
$$;

comment on function public.protect_profile_columns() is
  'Revierte cambios de rol y estado. Solo los cede a una accion administrativa auditada.';


-- -----------------------------------------------------------------------------
-- admin_set_account_status
-- -----------------------------------------------------------------------------
--
-- Bloquear o desbloquear una cuenta, sea de pasajero o de conductor. Es la
-- accion transversal de los pasos 4 y 7 del panel, y la mas sensible de las dos
-- listas: deja a alguien fuera del sistema.
--
-- El proyecto BLOQUEA EN LUGAR DE BORRAR desde la Fase 5, para conservar el
-- historial de viajes, que es informacion operativa de la empresa. Esta funcion
-- es la que hace efectiva esa regla desde el panel.
create or replace function public.admin_set_account_status(
  p_user_id uuid,
  p_status public.user_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before public.profiles;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar el estado de una cuenta'
      using errcode = 'P0001', hint = 'NOT_AN_ADMIN';
  end if;

  -- UN ADMINISTRADOR NO SE PUEDE BLOQUEAR A SI MISMO. No es una cortesia:
  -- is_admin() exige cuenta activa, asi que bloquearse seria perder el acceso al
  -- panel de forma irreversible desde el propio panel, y habria que entrar por
  -- SQL para recuperarlo. Si la empresa quiere retirar a un administrador, lo
  -- hace otro administrador.
  if p_user_id = (select auth.uid()) then
    raise exception 'No puedes cambiar el estado de tu propia cuenta'
      using errcode = 'P0001', hint = 'CANNOT_CHANGE_OWN_ACCOUNT';
  end if;

  select * into v_before from public.profiles where id = p_user_id;

  if not found then
    raise exception 'No se encontro esa cuenta'
      using errcode = 'P0001', hint = 'PROFILE_NOT_FOUND';
  end if;

  -- Sin cambio no hay accion que registrar. Se rechaza en vez de dejarlo pasar
  -- en silencio: una auditoria llena de entradas que no cambiaron nada es una
  -- auditoria que nadie lee.
  if v_before.status = p_status then
    raise exception 'Esa cuenta ya esta en ese estado'
      using errcode = 'P0001', hint = 'STATUS_UNCHANGED';
  end if;

  -- Ambito local: la marca se borra sola al terminar la transaccion, pase lo que
  -- pase, y se apaga a mano en cuanto deja de hacer falta.
  perform set_config('motomoto.admin_action', 'on', true);

  update public.profiles set status = p_status where id = p_user_id;

  perform set_config('motomoto.admin_action', 'off', true);

  -- La auditoria va en la MISMA transaccion que el cambio, y por eso no hace
  -- falta acordarse de escribirla: si esto falla, el update de arriba se deshace
  -- con ella.
  perform public.log_admin_action(
    case when p_status = 'blocked' then 'block_account' else 'unblock_account' end,
    'profiles',
    p_user_id::text,
    jsonb_build_object('status', v_before.status),
    jsonb_build_object('status', p_status, 'reason', p_reason)
  );
end;
$$;

comment on function public.admin_set_account_status(uuid, public.user_status, text) is
  'Bloquea o desbloquea una cuenta dejando registro. Unico camino desde el panel.';

revoke all on function public.admin_set_account_status(uuid, public.user_status, text) from public;
grant execute on function public.admin_set_account_status(uuid, public.user_status, text)
  to authenticated;
