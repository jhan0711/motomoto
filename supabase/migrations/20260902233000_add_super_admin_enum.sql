-- =============================================================================
-- BLOQUE SUPER ADMIN, paso 1: el rol `super_admin` en el enum `user_role`.
-- =============================================================================
--
-- EN SU PROPIA MIGRACION A PROPOSITO. `alter type ... add value` y usar ese
-- valor nuevo en la misma transaccion no siempre esta permitido -depende de la
-- version de PostgreSQL y del contexto-, y `db push` envuelve cada archivo en
-- una transaccion. Las funciones que comparan contra `'super_admin'` van en la
-- migracion siguiente.
--
-- QUE ES `super_admin`. El dueno de la plataforma (D264). Puede todo lo que
-- puede un `admin` -`is_admin()` pasa a incluirlo en la migracion siguiente- y
-- ademas gestiona las cuentas de administrador. Es una cuenta de oficina: un
-- perfil no puede ser a la vez super admin y pasajero o conductor.
-- =============================================================================

alter type public.user_role add value if not exists 'super_admin';
