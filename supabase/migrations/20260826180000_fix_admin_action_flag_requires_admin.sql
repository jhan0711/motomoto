-- =============================================================================
-- CORRECCION DE UN ERROR DEL ASISTENTE, introducido horas antes en
-- 20260826170000_admin_audit_and_account_status.sql (Fase 20, paso 2).
-- =============================================================================
--
-- QUE ESTABA MAL. Esa migracion le quito a `protect_profile_columns` la exencion
-- de `is_admin()` y la sustituyo por una marca de transaccion
-- (`motomoto.admin_action`). El objetivo era bueno: que un UPDATE directo no
-- pudiera cambiar el estado de una cuenta sin dejar rastro. La ejecucion estaba
-- mal, porque la marca paso a ser la UNICA condicion.
--
-- Resultado: **cualquiera podia poner la marca y saltarse la proteccion
-- entera**. No solo el estado: tambien el rol. Un pasajero podia hacerse
-- administrador. La version de la Fase 5 era menos estricta con los
-- administradores pero MAS segura con todo el mundo, asi que el cambio
-- empeoro la seguridad en vez de mejorarla.
--
-- COMO SE ENCONTRO. Lo cazo la comprobacion 17 de
-- `supabase/dev-tools/prueba_auditoria.sql`, escrita a proposito como "el
-- intento mas fino": ponerse la marca a mano siendo pasajero. Esperaba `active`
-- y obtuvo `blocked`. **No lo encontro ninguna revision del codigo**: lo
-- encontro intentar romperlo, que es la regla 3 del proyecto.
--
-- LA CORRECCION, UNA SOLA. El disparador exige AHORA LAS DOS COSAS: la marca y
-- que quien actualiza sea administrador activo. Con eso:
--
--   - un pasajero con la marca puesta -> revertido, porque no es administrador
--   - un administrador con UPDATE directo y sin marca -> revertido, que es lo
--     que buscaba el paso 2: no se puede bloquear sin dejar rastro
--   - `admin_set_account_status` -> pasa, porque ya comprobo is_admin() antes de
--     poner la marca
--
-- La marca deja de ser una llave y pasa a ser lo que tenia que haber sido desde
-- el principio: la senal de que la accion viene por el camino auditado. La
-- autorizacion la sigue dando `is_admin()`.
-- =============================================================================

create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- LAS DOS CONDICIONES, y el orden importa poco pero la conjuncion mucho. La
  -- version anterior de esta funcion miraba solo la marca, y por eso se podia
  -- rodear; la de la Fase 5 miraba solo is_admin(), y por eso se podia bloquear
  -- sin auditoria.
  if coalesce(current_setting('motomoto.admin_action', true), '') = 'on'
     and public.is_admin() then
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
  'Revierte cambios de rol y estado salvo dentro de una accion administrativa auditada, que ademas exige administrador activo.';
