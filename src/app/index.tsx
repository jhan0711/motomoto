import { Redirect } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { ErrorState } from '@/components/ui/error-state';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { homeRouteFor, useSession } from '@/features/auth/session';
import { spacing } from '@/theme';

/**
 * Ruta de entrada.
 *
 * No dibuja nada propio: lee la sesion y manda a cada quien donde le
 * corresponde. Centralizarlo aqui evita que cada pantalla tenga que razonar
 * sobre si hay alguien dentro.
 *
 * La espera de carga importa mas de lo que parece. Restaurar la sesion guardada
 * es asincrono, y sin esperarla un usuario que ya tenia sesion veria un destello
 * de la pantalla de bienvenida en cada arranque.
 */
export default function Index() {
  const { user, isLoading, error, canOperate, isRecoveringPassword, refreshProfile, signOut } =
    useSession();

  if (isRecoveringPassword) {
    return <Redirect href="/reset-password" />;
  }

  if (isLoading) {
    return (
      <Screen>
        <Spinner size="large" centered label="Cargando" />
      </Screen>
    );
  }

  // Hay sesion pero el perfil no se pudo leer, casi siempre por falta de
  // conexion. Mandar a bienvenida seria mentir: la sesion existe. Se dice lo que
  // pasa y se ofrece reintentar.
  if (error !== null) {
    return (
      <Screen>
        <ErrorState description={error} onRetry={refreshProfile} />
        {/* Sin esta salida la pantalla es un callejon sin salida: si el perfil no
            existe, reintentar falla siempre y el usuario se queda encerrado con
            la unica opcion de borrar los datos de la aplicacion. Detectado
            probando con una cuenta borrada del servidor. */}
        <View style={styles.escape}>
          <Button label="Cerrar sesión" variant="ghost" fullWidth onPress={signOut} />
        </View>
      </Screen>
    );
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  if (!canOperate) {
    return <Redirect href="/account-status" />;
  }

  return <Redirect href={homeRouteFor(user.role)} />;
}

const styles = StyleSheet.create({
  escape: {
    marginTop: spacing.lg,
  },
});
