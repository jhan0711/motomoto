import { Redirect, useRouter } from 'expo-router';
import { MailWarning } from 'lucide-react-native';
import { useEffect, useState } from 'react';

import { EmptyState } from '@/components/ui/empty-state';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { useSession } from '@/features/auth/session';

/**
 * Aterrizaje de los enlaces de los correos de la cuenta.
 *
 * A esta ruta (`/auth`) llegan los enlaces de aplicacion de Android que Supabase
 * pone en los correos de recuperar contrasena y de confirmar la cuenta (Fase 25
 * pasos 6 y 7b). La pantalla no hace nada por si misma: `session.tsx` lee los
 * parametros del enlace y marca el estado, y desde aqui solo se espera y se
 * redirige.
 *
 *   - Recuperacion: se va a `/reset-password`.
 *   - Confirmacion correcta: queda sesion abierta y se va a `/`, que reparte por
 *     rol.
 *   - Confirmacion fallida (enlace caducado): se muestra el error.
 *
 * No se llama `(auth)` -esa es la carpeta de bienvenida/login/registro-: es una
 * ruta suelta, `/auth`, que es la que declara el filtro de intenciones de
 * Android en `app.config.ts`.
 */
export default function AuthCallback() {
  const router = useRouter();
  const { user, isRecoveringPassword, confirmationError } = useSession();
  const [rendirse, setRendirse] = useState(false);

  // Si en unos segundos nada ha pasado -un enlace que no reconocemos, o que
  // fallo en silencio-, se sale a la ruta de inicio, que sabe a donde mandar a
  // cada quien segun haya sesion o no.
  useEffect(() => {
    const id = setTimeout(() => setRendirse(true), 6000);
    return () => clearTimeout(id);
  }, []);

  if (isRecoveringPassword) {
    return <Redirect href="/reset-password" />;
  }

  if (confirmationError !== null) {
    return (
      <Screen>
        <EmptyState
          icon={MailWarning}
          tone="danger"
          title="No pudimos confirmar tu cuenta"
          description={confirmationError}
          actionLabel="Ir a iniciar sesión"
          onAction={() => router.replace('/login')}
        />
      </Screen>
    );
  }

  // Confirmacion correcta: la sesion ya esta abierta.
  if (user !== null) {
    return <Redirect href="/" />;
  }

  if (rendirse) {
    return <Redirect href="/" />;
  }

  return (
    <Screen>
      <Spinner size="large" centered label="Validando el enlace" />
    </Screen>
  );
}
