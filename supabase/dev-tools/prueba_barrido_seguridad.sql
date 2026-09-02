-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Fase 22, paso 8: barrido de cierre. Recorre toda la superficie del esquema
-- `public` -tablas, politicas, funciones, permisos- y comprueba que se cumplen
-- las reglas de seguridad que el proyecto ha ido fijando fase a fase.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/prueba_barrido_seguridad.sql
--
-- No monta datos: solo consulta los catalogos. Existe para que un descuido
-- futuro -una tabla nueva sin RLS, una politica abierta a `anon`, una funcion
-- `security definer` sin `search_path`- se note en la regresion y no en
-- produccion.
--
-- LAS REGLAS, y de que fase vienen:
--   1. Toda tabla de `public` tiene RLS activada.                    (Fase 5)
--   2. Ninguna politica nombra a `anon` ni a `public`.               (Fase 5)
--   3. Cero politicas `FOR ALL`.                                     (Fase 20, paso 4c)
--   4. Toda funcion `security definer` fija su `search_path`.        (Fase 5)
--   5. Cero funciones de `public` ejecutables por `anon`.            (Fase 22, pasos 1-2)
--   6. `anon` no tiene ningun privilegio de tabla en `public`.       (Fase 22, paso 8)
--   7. `anon` no tiene ningun privilegio de secuencia en `public`.   (Fase 22, paso 8)
--   8. `authenticated` conserva sus grants de tabla (no se paso el revoke).
-- =============================================================================

create temp table resultados (
  n integer,
  comprobacion text,
  esperado text,
  obtenido text,
  ok boolean
) on commit drop;

-- 1. RLS en todas las tablas -------------------------------------------------
with sin_rls as (
  select c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
)
insert into resultados
select 1, 'Toda tabla de public tiene RLS activada', '0 sin RLS',
  count(*) || coalesce(': ' || string_agg(relname, ', '), ''), count(*) = 0
from sin_rls;

-- 2. Politicas a anon o public ---------------------------------------------
with abiertas as (
  select tablename, policyname
  from pg_policies
  where schemaname = 'public'
    and (roles::text like '%anon%' or roles::text = '{public}' or roles::text = '{}')
)
insert into resultados
select 2, 'Ninguna politica apunta a anon ni a public', '0',
  count(*) || coalesce(': ' || string_agg(tablename || '.' || policyname, ', '), ''),
  count(*) = 0
from abiertas;

-- 3. Politicas FOR ALL -----------------------------------------------------
with todo as (
  select tablename, policyname from pg_policies
  where schemaname = 'public' and cmd = 'ALL'
)
insert into resultados
select 3, 'Cero politicas FOR ALL', '0',
  count(*) || coalesce(': ' || string_agg(tablename || '.' || policyname, ', '), ''),
  count(*) = 0
from todo;

-- 4. security definer con search_path -------------------------------------
with sin_path as (
  select p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef
    and not exists (
      select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) c where c like 'search_path=%'
    )
)
insert into resultados
select 4, 'Toda funcion security definer fija su search_path', '0',
  count(*) || coalesce(': ' || string_agg(proname, ', '), ''), count(*) = 0
from sin_path;

-- 5. Funciones ejecutables por anon --------------------------------------
with ejec_anon as (
  select p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'EXECUTE')
)
insert into resultados
select 5, 'Cero funciones de public ejecutables por anon', '0',
  count(*) || coalesce(': ' || string_agg(proname, ', '), ''), count(*) = 0
from ejec_anon;

-- 6. Privilegios de tabla de anon ---------------------------------------
insert into resultados
select 6, 'anon no tiene privilegios de tabla en public', '0',
  count(*)::text, count(*) = 0
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'anon';

-- 7. Privilegios de secuencia de anon ---------------------------------
insert into resultados
select 7, 'anon no tiene privilegios de secuencia en public', '0',
  count(*)::text, count(*) = 0
from information_schema.role_usage_grants
where object_schema = 'public' and grantee = 'anon';

-- 8. authenticated conserva sus grants (el revoke no se paso) --------
insert into resultados
select 8, 'authenticated conserva sus grants de tabla', '>= 100',
  count(*)::text, count(*) >= 100
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated';


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
  case when bool_and(coalesce(x.ok, false)) then 'OK  ' else 'FALLA' end,
  'TOTAL',
  count(*) || ' comprobaciones',
  count(*) filter (where not coalesce(x.ok, false)) || ' fallando'
from resultados x
order by 1;
