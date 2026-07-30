import { Image } from 'expo-image';
import { Camera, Images, type LucideIcon } from 'lucide-react-native';
import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal';
import { Spinner } from '@/components/ui/spinner';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

import { getAvatarUrl, pickAvatar, uploadAvatar, type AvatarSource } from './avatar-service';

/**
 * Foto de perfil: la muestra y, si se puede editar, permite cambiarla.
 *
 * El bucket es privado, asi que no hay una direccion permanente que guardar. El
 * perfil guarda la ruta y este componente la firma cada vez que se monta. Por eso
 * recibe `avatarPath` y no una direccion.
 */

const SIZE = 80;

interface ProfileAvatarProps {
  userId: string;
  avatarPath: string | null;
  /** Icono cuando no hay foto. Distinto para pasajero y conductor. */
  fallbackIcon: LucideIcon;
  /** Sin esto es solo visualizacion, sin posibilidad de cambiarla. */
  editable?: boolean;
  /** Se llama tras un cambio correcto, para que la sesion relea el perfil. */
  onChanged?: () => void;
  /** Mensaje para mostrar arriba. Null limpia el anterior. */
  onError?: (message: string | null) => void;
}

export function ProfileAvatar({
  userId,
  avatarPath,
  fallbackIcon: FallbackIcon,
  editable = false,
  onChanged,
  onError,
}: ProfileAvatarProps) {
  const { colors } = useTheme();
  const [signed, setSigned] = useState<{ path: string; url: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [choosing, setChoosing] = useState(false);

  useEffect(() => {
    if (avatarPath === null) {
      return;
    }

    let active = true;

    void getAvatarUrl(avatarPath).then((result) => {
      // Si falla la firma no se muestra ningun error: el usuario no puede hacer
      // nada al respecto y se queda con el icono, que es un resultado aceptable.
      if (active && result.ok) {
        setSigned({ path: avatarPath, url: result.data });
      }
    });

    return () => {
      active = false;
    };
  }, [avatarPath]);

  // Derivado, no almacenado: la direccion firmada solo vale si corresponde a la
  // ruta actual. Sin esta comprobacion, al cambiar la foto se veria la anterior
  // hasta que llegara la nueva firma.
  const url = signed !== null && signed.path === avatarPath ? signed.url : null;

  async function change(source: AvatarSource) {
    setChoosing(false);
    onError?.(null);

    const picked = await pickAvatar(source);

    if (!picked.ok) {
      onError?.(picked.failure.message);
      return;
    }

    // Cerro la galeria sin elegir. No es un error y no se dice nada.
    if (picked.data === null) {
      return;
    }

    setBusy(true);
    const uploaded = await uploadAvatar(userId, picked.data.uri, avatarPath);
    setBusy(false);

    if (uploaded.ok) {
      onChanged?.();
    } else {
      onError?.(uploaded.failure.message);
    }
  }

  // La imagen va dentro de un contenedor con `overflow: hidden`, y no solo con
  // borderRadius. Sin recortar el contenedor, la foto se sale del circulo: el
  // borde redondeado de la propia imagen no basta.
  //
  // La insignia queda fuera de ese contenedor, para que pueda asomar por el borde
  // sin que el recorte se la coma.
  const content = (
    <View style={styles.wrapper}>
      <View style={[styles.circle, { backgroundColor: colors.brandSubtle }]}>
        {url === null ? (
          <FallbackIcon
            size={iconSize.xl}
            color={colors.brandStrong}
            strokeWidth={iconStrokeWidth}
          />
        ) : (
          <Image source={{ uri: url }} style={StyleSheet.absoluteFill} contentFit="cover" />
        )}

        {busy && (
          <View style={[styles.overlay, { backgroundColor: colors.surface }]}>
            <Spinner />
          </View>
        )}
      </View>

      {editable && !busy && (
        <View style={[styles.badge, { backgroundColor: colors.brand }]}>
          <Camera size={iconSize.sm} color={colors.onBrand} strokeWidth={iconStrokeWidth} />
        </View>
      )}
    </View>
  );

  if (!editable) {
    return content;
  }

  return (
    <>
      <Pressable
        onPress={() => setChoosing(true)}
        disabled={busy}
        accessibilityRole="button"
        accessibilityLabel={url === null ? 'Agregar foto de perfil' : 'Cambiar foto de perfil'}
      >
        {content}
      </Pressable>

      {/* Dos origenes, y la eleccion se pregunta en lugar de suponerse. Para una
          foto de perfil mucha gente espera hacerse una ahi mismo, y otra tanta
          prefiere una que ya tiene. */}
      <Modal
        visible={choosing}
        onRequestClose={() => setChoosing(false)}
        icon={Camera}
        title="Foto de perfil"
        description="Elige de dónde quieres tomarla."
        cancelLabel="Cancelar"
      >
        <View style={styles.choices}>
          <Button
            label="Tomar una foto"
            variant="primary"
            icon={Camera}
            fullWidth
            onPress={() => void change('camera')}
          />
          <Button
            label="Elegir de la galería"
            variant="secondary"
            icon={Images}
            fullWidth
            onPress={() => void change('library')}
          />
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    borderRadius: radius.full,
    bottom: 0,
    height: 28,
    justifyContent: 'center',
    position: 'absolute',
    right: 0,
    width: 28,
  },
  choices: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  circle: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: SIZE,
    justifyContent: 'center',
    overflow: 'hidden',
    width: SIZE,
  },
  overlay: {
    alignItems: 'center',
    borderRadius: radius.full,
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    opacity: 0.85,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  wrapper: {
    height: SIZE,
    width: SIZE,
  },
});
