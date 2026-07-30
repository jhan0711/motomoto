-- =============================================================================
-- Fotos de perfil: bucket privado y sus politicas
-- =============================================================================

-- -----------------------------------------------------------------------------
-- El bucket
-- -----------------------------------------------------------------------------
-- Privado a proposito. Las politicas de la Fase 5 restringen quien puede ver el
-- nombre de un pasajero: solo el mismo, el conductor de su viaje y el
-- administrador. Un bucket publico dejaria su cara accesible a cualquiera que
-- tuviera la direccion, mientras su nombre sigue protegido. Esa incoherencia no
-- tiene sentido, y Amalfi es un municipio pequeno.
--
-- El limite de tamano es una segunda barrera: la aplicacion ya comprime antes de
-- subir, pero un cliente modificado no lo haria.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = 1048576,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];


-- -----------------------------------------------------------------------------
-- La columna guarda una ruta, no una direccion
-- -----------------------------------------------------------------------------
-- Se renombra avatar_url a avatar_path porque es lo que va a contener: la ruta
-- dentro del bucket, del tipo '<uuid>/avatar.jpg'.
--
-- No puede guardar una direccion: en un bucket privado las direcciones se firman
-- y caducan, asi que una guardada en la base de datos estaria muerta al poco
-- tiempo. La aplicacion firma la ruta cada vez que necesita mostrar la foto.
--
-- Se renombra ahora, con la columna vacia y sin una sola linea de codigo que la
-- lea, porque una columna llamada `_url` que contiene una ruta es exactamente la
-- clase de detalle que hace perder una tarde dentro de seis meses.

alter table public.profiles rename column avatar_url to avatar_path;

comment on column public.profiles.avatar_path is
  'Ruta dentro del bucket avatars, no una direccion. Se firma al mostrarla.';


-- -----------------------------------------------------------------------------
-- Politicas
-- -----------------------------------------------------------------------------
-- La primera carpeta de la ruta es el identificador del dueno. Eso es lo que
-- permite decidir de quien es cada archivo con una comparacion.

-- Quien puede ver una foto: su dueno, un administrador, y la contraparte de un
-- viaje. Exactamente los mismos que pueden ver el nombre de esa persona, que era
-- el motivo de hacer el bucket privado.
create policy "avatars_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
      or public.shares_ride_with(((storage.foldername(name))[1])::uuid)
    )
  );

-- Subir, reemplazar y borrar: solo en la propia carpeta. Sin esto, cualquiera
-- podria escribir en la carpeta de otro y cambiarle la foto.
create policy "avatars_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "avatars_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "avatars_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
