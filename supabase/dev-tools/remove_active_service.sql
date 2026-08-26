-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Borra los servicios que siembra `seed_active_service.sql`, que es el unico
-- archivo de `dev-tools/` que deja filas vivas en la base.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_active_service.sql
--
-- Conviene ejecutarlo al terminar de mirar el tablero: un servicio en
-- `searching` que nadie atiende deja al pasajero de prueba sin poder pedir otro,
-- porque la regla R6 solo admite uno vivo por persona.
-- =============================================================================

delete from public.ride_offers
where request_id in (
  'ad000000-0000-4000-8000-000000000001',
  'ad000000-0000-4000-8000-000000000002'
);

delete from public.rides
where request_id in (
  'ad000000-0000-4000-8000-000000000001',
  'ad000000-0000-4000-8000-000000000002'
);

delete from public.ride_requests
where id in (
  'ad000000-0000-4000-8000-000000000001',
  'ad000000-0000-4000-8000-000000000002'
);


-- Comprobacion: el tablero tiene que quedarse sin ninguno de estos.
select count(*) as servicios_de_prueba_que_quedan
from public.admin_list_active_services()
where request_id::text like 'ad000000%';
