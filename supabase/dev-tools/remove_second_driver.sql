-- =============================================================================
-- HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
-- =============================================================================
--
-- Deshace lo que crea seed_second_driver.sql. Hermano de remove_test_driver.sql.
--
--   npx.cmd supabase db query --linked -f supabase/dev-tools/remove_second_driver.sql
--
-- El orden importa. Varias claves ajenas del esquema son on delete restrict a
-- proposito, para que borrar a alguien no se lleve por delante el historial
-- operativo de la empresa. Aqui se borra de dentro hacia fuera.
--
-- Si el segundo conductor llego a participar en un viaje, el borrado se detendra
-- en rides y lo dira. Eso no es un fallo: es la base protegiendo el historial.
-- En ese caso hay que decidir a mano que hacer con esos viajes de prueba.
-- =============================================================================

do $limpieza$
declare
  c_driver  constant uuid := 'd0000000-0000-4000-8000-000000000002';
  c_vehicle constant uuid := 'e0000000-0000-4000-8000-000000000002';
begin
  delete from public.ride_offers where driver_id = c_driver;
  delete from public.driver_locations where driver_id = c_driver;
  delete from public.driver_vehicle_assignments where driver_id = c_driver;

  delete from public.drivers where id = c_driver;
  delete from public.profiles where id = c_driver;
  delete from auth.users where id = c_driver;

  delete from public.vehicles where id = c_vehicle;
end;
$limpieza$;

select
  (select count(*) from auth.users where id = 'd0000000-0000-4000-8000-000000000002') as usuario,
  (select count(*) from public.drivers where id = 'd0000000-0000-4000-8000-000000000002') as conductor,
  (select count(*) from public.vehicles where id = 'e0000000-0000-4000-8000-000000000002') as vehiculo,
  (select count(*) from public.driver_locations where driver_id = 'd0000000-0000-4000-8000-000000000002') as ubicacion;
