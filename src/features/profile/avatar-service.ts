import { File } from 'expo-file-system';
import * as ImageManipulator from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';

import { toAuthFailure } from '@/features/auth/errors';
import { supabase } from '@/lib/supabase';

import type { Result } from '@/features/auth/auth-service';

/**
 * Foto de perfil: elegir, comprimir, subir y mostrar.
 *
 * Vive fuera de `features/auth` porque esto es almacenamiento, no
 * autenticacion. Comparte el tipo `Result` para que las pantallas traten todos
 * los errores igual.
 */

const BUCKET = 'avatars';

/** Lado maximo de la imagen guardada, en pixeles. */
const MAX_SIZE = 512;

/**
 * Calidad JPEG. 0,7 es el punto donde una foto de perfil de 512 px deja de
 * mejorar de forma apreciable y sigue pesando poco.
 */
const QUALITY = 0.7;

/** Duracion de la direccion firmada. Se firma de nuevo cada vez que hace falta. */
const SIGNED_URL_SECONDS = 3600;

function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

function fail<T = never>(error: unknown): Result<T> {
  return { ok: false, failure: toAuthFailure(error) };
}

function failWith<T = never>(code: string, message: string): Result<T> {
  return { ok: false, failure: { code, message } };
}

/** De donde sale la foto. */
export type AvatarSource = 'camera' | 'library';

/**
 * Toma o elige una foto, deja recortarla en cuadrado y la devuelve ya reducida.
 *
 * El recorte y la reduccion se hacen aqui, en el dispositivo, y no en el
 * servidor. En Amalfi la conectividad es irregular: subir la foto original de
 * cuatro megabytes que hace un movil actual seria friccion real, no teorica, y
 * ademas gastaria los datos del usuario.
 *
 * Devuelve null cuando la persona cierra la camara o la galeria sin elegir nada.
 * Eso no es un error y no debe mostrar ningun mensaje.
 *
 * Los dos origenes comparten el mismo procesado a proposito: si se duplicara,
 * cualquier ajuste futuro de tamano o calidad se aplicaria a uno y no al otro.
 */
export async function pickAvatar(source: AvatarSource): Promise<Result<{ uri: string } | null>> {
  const options: ImagePicker.ImagePickerOptions = {
    mediaTypes: ['images'],
    allowsEditing: true,
    aspect: [1, 1],
    quality: 1,
  };

  let picked: ImagePicker.ImagePickerResult;

  if (source === 'camera') {
    const permission = await ImagePicker.requestCameraPermissionsAsync();

    if (!permission.granted) {
      return failWith(
        'CAMERA_PERMISSION_DENIED',
        'Necesitamos permiso para usar la cámara. Puedes darlo desde los ajustes del teléfono.',
      );
    }

    picked = await ImagePicker.launchCameraAsync(options);
  } else {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();

    if (!permission.granted) {
      return failWith(
        'MEDIA_PERMISSION_DENIED',
        'Necesitamos permiso para ver tus fotos. Puedes darlo desde los ajustes del teléfono.',
      );
    }

    picked = await ImagePicker.launchImageLibraryAsync(options);
  }

  if (picked.canceled) {
    return ok(null);
  }

  const asset = picked.assets[0];

  if (asset === undefined) {
    return failWith('NO_IMAGE_SELECTED', 'No pudimos leer la imagen. Inténtalo de nuevo.');
  }

  try {
    const context = ImageManipulator.ImageManipulator.manipulate(asset.uri);
    const rendered = await context.resize({ width: MAX_SIZE, height: MAX_SIZE }).renderAsync();
    const result = await rendered.saveAsync({
      compress: QUALITY,
      format: ImageManipulator.SaveFormat.JPEG,
    });

    return ok({ uri: result.uri });
  } catch (error) {
    return fail(error);
  }
}

/**
 * Sube la foto y guarda su ruta en el perfil.
 *
 * La carpeta es siempre el identificador del usuario. No es una convencion
 * decorativa: las politicas del bucket comparan esa primera carpeta con quien
 * hace la peticion, y es lo que impide escribir en la carpeta de otro.
 *
 * El nombre del archivo lleva la hora, asi que cada foto tiene una ruta nueva.
 * La primera version usaba un nombre fijo, `avatar.jpg`, y reemplazaba el archivo.
 * Parecia mas limpio y estaba mal: al no cambiar la ruta, la pantalla no pedia
 * una direccion firmada nueva y seguia mostrando la foto anterior desde la cache.
 * Verificado en el emulador: el servidor tenia la foto nueva y la app la vieja.
 *
 * Con la hora en el nombre, la ruta es la version. La anterior se borra despues
 * de guardar la nueva, en ese orden: si se borrara antes y fallara la subida, el
 * usuario se quedaria sin foto.
 */
export async function uploadAvatar(
  userId: string,
  uri: string,
  previousPath: string | null,
): Promise<Result<string>> {
  const path = `${userId}/${Date.now()}.jpg`;

  let body: Uint8Array;

  try {
    // Se lee con expo-file-system y no con fetch. El `fetch` de React Native no
    // sabe leer una direccion `file://`: no falla, devuelve un cuerpo vacio, y el
    // resultado es una subida de catorce bytes que el servidor acepta sin
    // protestar. Detectado en la Fase 7 mirando el tamano real del archivo subido.
    body = await new File(uri).bytes();
  } catch (error) {
    return fail(error);
  }

  // Guarda contra ese mismo fallo si alguien cambia la forma de leer el archivo.
  // Una imagen de 512 px comprimida nunca baja de unos pocos kilobytes.
  if (body.byteLength < 1024) {
    return failWith(
      'EMPTY_IMAGE',
      'No pudimos leer la imagen completa. Inténtalo de nuevo con otra foto.',
    );
  }

  const { error: uploadError } = await supabase.storage.from(BUCKET).upload(path, body, {
    contentType: 'image/jpeg',
    upsert: true,
  });

  if (uploadError) {
    return fail(uploadError);
  }

  // Se guarda la ruta despues de subir, nunca antes. Al reves, un fallo de subida
  // dejaria el perfil apuntando a un archivo que no existe.
  const { error: profileError } = await supabase
    .from('profiles')
    .update({ avatar_path: path })
    .eq('id', userId);

  if (profileError) {
    return fail(profileError);
  }

  // La anterior ya no la referencia nadie. Si el borrado falla queda un archivo
  // huerfano, que es molesto pero inofensivo, y no es motivo para decirle al
  // usuario que su foto no se guardo: si se guardo.
  if (previousPath !== null && previousPath !== path) {
    await supabase.storage.from(BUCKET).remove([previousPath]);
  }

  return ok(path);
}

/**
 * Direccion firmada para mostrar una foto.
 *
 * El bucket es privado, asi que no hay direccion permanente. Por eso la base de
 * datos guarda la ruta y no la direccion: una direccion firmada guardada estaria
 * caducada al poco tiempo.
 */
export async function getAvatarUrl(path: string): Promise<Result<string>> {
  const { data, error } = await supabase.storage
    .from(BUCKET)
    .createSignedUrl(path, SIGNED_URL_SECONDS);

  if (error) {
    return fail(error);
  }

  return ok(data.signedUrl);
}

/** Quita la foto: borra el archivo y limpia la ruta del perfil. */
export async function removeAvatar(userId: string, path: string): Promise<Result> {
  const { error: storageError } = await supabase.storage.from(BUCKET).remove([path]);

  if (storageError) {
    return fail(storageError);
  }

  const { error: profileError } = await supabase
    .from('profiles')
    .update({ avatar_path: null })
    .eq('id', userId);

  return profileError ? fail(profileError) : ok(undefined);
}
