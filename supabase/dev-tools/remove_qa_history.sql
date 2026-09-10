-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Deshace `seed_qa_history.sql`: borra el historial sembrado de la pasajera de
-- prueba y devuelve los nombres originales a las tres cuentas QA.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_qa_history.sql
--
-- CUANDO CORRERLO: antes de la suite de pruebas. `prueba_historial.sql` y
-- `prueba_h15_telefono_contraparte.sql` esperan los nombres "Ana Gomez" /
-- "Conductor de prueba" y fallan mientras el seed esta puesto.
--
-- `purge_qa_accounts.sql` tambien limpia todo esto (borra las cuentas enteras),
-- asi que para el lanzamiento no hace falta correr este.
-- =============================================================================

begin;

delete from public.ride_requests
where passenger_id = 'ad000000-0000-4000-8000-0000000000f1';

update public.profiles set full_name = 'Ana Gomez'
where id = 'ad000000-0000-4000-8000-0000000000f1';
update public.profiles set full_name = 'Conductor de prueba'
where id = 'd0000000-0000-4000-8000-000000000001';
update public.profiles set full_name = 'Segundo conductor'
where id = 'd0000000-0000-4000-8000-000000000002';

select p.full_name,
  (select count(*) from public.ride_requests r where r.passenger_id = p.id) as viajes
from public.profiles p
where p.id in (
  'ad000000-0000-4000-8000-0000000000f1',
  'd0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002'
);

commit;
