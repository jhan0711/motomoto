-- =============================================================================
-- La ruta de la foto tiene que estar en la carpeta del propio usuario
-- =============================================================================
-- Detectado probando en la Fase 7.5: un usuario podia apuntar su `avatar_path` a
-- un archivo de la carpeta de otro. No era una fuga de datos, y se comprobo: las
-- politicas del bucket le impiden firmar y descargar ese archivo, asi que solo
-- habria visto el icono por defecto.
--
-- Pero era un dato incoherente que el modelo permitia, y esas incoherencias se
-- convierten en errores raros mas adelante, cuando el panel de la Fase 20 o el
-- conductor de la Fase 13 intenten mostrar esa foto y no entiendan por que falla.
--
-- La comprobacion es la misma que hacen las politicas del bucket: la primera
-- carpeta de la ruta es el identificador del dueno.

alter table public.profiles
  add constraint profiles_avatar_path_owned
  check (avatar_path is null or avatar_path like (id::text || '/%'));

comment on constraint profiles_avatar_path_owned on public.profiles is
  'La foto debe estar en la carpeta del propio usuario, igual que exigen las politicas del bucket.';
