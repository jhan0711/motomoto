-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Borra los reportes de prueba que deja `seed_reports.sql`.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_reports.sql
--
-- **PASAR ESTO ANTES DE LA REGRESION.** Las pruebas se montan su propio mundo y
-- las filas sembradas les estorban.
--
-- Borra solo por identificador conocido: no toca ningun reporte de verdad.
-- =============================================================================

delete from public.reports
where id in (
  'ad000000-0000-4000-8000-0000000000f1',
  'ad000000-0000-4000-8000-0000000000f2',
  'ad000000-0000-4000-8000-0000000000f3',
  'ad000000-0000-4000-8000-0000000000f4'
);

-- Y las notificaciones que hubiera disparado cerrarlos desde la pantalla.
delete from public.notifications
where type = 'report_resolved'
  and data->>'reportId' in (
    'ad000000-0000-4000-8000-0000000000f1',
    'ad000000-0000-4000-8000-0000000000f2',
    'ad000000-0000-4000-8000-0000000000f3',
    'ad000000-0000-4000-8000-0000000000f4'
  );

select count(*) as reportes_de_prueba_que_quedan
from public.reports where id::text like 'ad000000%';
