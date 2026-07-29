-- =============================================================================
-- Correccion: el disparador de proteccion anulaba el recalculo de calificaciones
-- =============================================================================
--
-- Detectado al recorrer el ciclo completo de un servicio. Dos disparadores
-- escritos en migraciones distintas, ambos correctos por separado, se anulaban
-- entre si:
--
--   Ana llama a rate_ride
--     -> INSERT en ratings
--        -> disparador refresh_driver_rating (migracion 5)
--           -> UPDATE drivers SET rating_average = 4.00
--              -> disparador protect_driver_columns (migracion 6A)
--                 -> Ana no es administradora
--                    -> revierte rating_average a su valor anterior
--
-- El resultado: las calificaciones se guardaban pero el promedio del conductor
-- nunca cambiaba.
--
-- Solucion: una marca local a la transaccion que distingue "un usuario intenta
-- subirse la nota" de "el sistema esta recalculando". La pone la propia funcion
-- de recalculo justo antes de escribir y la retira despues.
--
-- Se usa una marca y no una comprobacion del rol de PostgreSQL porque las
-- funciones security definer se ejecutan siempre como el propietario, asi que
-- por el rol no se distingue quien origino la operacion.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- El recalculo se anuncia
-- -----------------------------------------------------------------------------

create or replace function public.refresh_driver_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid;
begin
  v_driver := coalesce(new.rated_id, old.rated_id);

  -- Marca local a la transaccion. El tercer parametro en true hace que se
  -- descarte al terminar, asi que no puede filtrarse a otra operacion.
  perform set_config('app.system_rating_update', 'on', true);

  update public.drivers d
  set rating_average = coalesce(s.promedio, 0),
      rating_count = coalesce(s.total, 0)
  from (
    select round(avg(stars), 2) as promedio, count(*) as total
    from public.ratings
    where rated_id = v_driver
  ) s
  where d.id = v_driver;

  perform set_config('app.system_rating_update', 'off', true);

  return null;
end;
$$;


-- -----------------------------------------------------------------------------
-- La proteccion reconoce la marca
-- -----------------------------------------------------------------------------

create or replace function public.protect_driver_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Un administrador puede cambiar cualquier cosa.
  if public.is_admin() then
    return new;
  end if;

  -- El recalculo del sistema puede tocar las columnas de calificacion, y solo
  -- esas. El estado de aprobacion sigue protegido incluso durante el recalculo:
  -- ninguna via legitima necesita cambiarlo desde aqui.
  if coalesce(current_setting('app.system_rating_update', true), 'off') = 'on' then
    new.approval_status := old.approval_status;
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    return new;
  end if;

  -- Cualquier otro caso: se revierte todo lo privilegiado.
  new.approval_status := old.approval_status;
  new.approved_at := old.approved_at;
  new.approved_by := old.approved_by;
  new.rating_average := old.rating_average;
  new.rating_count := old.rating_count;
  return new;
end;
$$;

comment on function public.protect_driver_columns() is
  'Impide que un conductor se apruebe o se suba la nota. Deja pasar el recalculo del sistema.';
