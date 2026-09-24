-- D278: las dos funciones de disparador de la migracion anterior nacieron con el
-- permiso de EJECUCION que PostgreSQL da por defecto a PUBLIC, y con el `anon`
-- las veia (el barrido de `prueba_barrido_seguridad.sql` lo atrapo). Un
-- disparador no necesita que nadie pueda ejecutar su funcion: se ejecuta por el
-- hecho de que ocurra el evento. Mismo criterio que la Fase 22, paso 1.

revoke all on function public.driver_ledger_append_only() from public, anon, authenticated;
revoke all on function public.turn_off_unfunded_drivers() from public, anon, authenticated;
