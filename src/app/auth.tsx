import { Redirect } from 'expo-router';
import { useEffect, useState } from 'react';

import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { useSession } from '@/features/auth/session';

/**
 * Aterrizaje de los enlaces de los correos de la cuenta.
 *
 * A esta ruta (`/auth`) llegan los enlaces de aplicacion de Android que Supabase
 * pone en los correos de recuperar contrasena -y, en la Fase 25, tambien los de
 * confirmar la cuenta y cambiar el correo-. La pantalla no hace nada por si
 * misma: `session.tsx` lee los parametros del enlace y marca el estado, y desde
 * aqui solo se espera y se redirige.
 *
 * No se llama `(auth)` -esa es la carpeta de bienvenida/login/registro-: es una
 * ruta suelta, `/auth`, que es la que declara el filtro de intenciones de
 * Android en `app.config.ts`.
 */
export default function AuthCallback() {
  const { isRecoveringPassword } = useSession();
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

  if (rendirse) {
    return <Redirect href="/" />;
  }

  return (
    <Screen>
      <Spinner size="large" centered label="Validando el enlace" />
    </Screen>
  );
}
