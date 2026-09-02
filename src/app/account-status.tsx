import { Redirect } from 'expo-router';
import { CircleAlert, Clock, Monitor, ShieldAlert, type LucideIcon } from 'lucide-react-native';

import { EmptyState } from '@/components/ui/empty-state';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { homeRouteFor, useSession, type SessionUser } from '@/features/auth/session';

/**
 * Cuenta con sesion abierta que todavia no puede usar la aplicacion.
 *
 * Existe porque cerrar la sesion sin mas seria peor: el usuario volveria a la
 * pantalla de bienvenida sin entender nada, intentaria entrar otra vez, y
 * llegaria a la misma pared sin que nadie le explique por que.
 *
 * Cuatro situaciones distintas, con textos distintos. Un mensaje generico del
 * tipo "no tienes acceso" obligaria al conductor a llamar a la empresa para
 * averiguar si esta pendiente de aprobacion o bloqueado, que son cosas muy
 * diferentes.
 */

interface Explanation {
  icon: LucideIcon;
  title: string;
  description: string;
}

function explain(user: SessionUser): Explanation {
  if (user.role === 'admin' || user.role === 'super_admin') {
    return {
      icon: Monitor,
      title: 'Esta cuenta es de administración',
      description:
        'Las cuentas de administración se usan desde el panel web, no desde la aplicación. Inicia sesión allí con este mismo correo.',
    };
  }

  if (user.status === 'blocked') {
    return {
      icon: ShieldAlert,
      title: 'Tu cuenta está bloqueada',
      description:
        'No puedes solicitar ni prestar servicios por ahora. Comunícate con la empresa para conocer el motivo.',
    };
  }

  if (user.approvalStatus === 'pending') {
    return {
      icon: Clock,
      title: 'Tu cuenta está en revisión',
      description:
        'La empresa está revisando tus datos y documentos. Cuando te aprueben podrás conectarte y recibir servicios.',
    };
  }

  if (user.approvalStatus === 'blocked') {
    return {
      icon: ShieldAlert,
      title: 'Tu cuenta de conductor está bloqueada',
      description:
        'No puedes recibir servicios por ahora. Comunícate con la empresa para conocer el motivo.',
    };
  }

  // Conductor con perfil pero sin ficha. Es una anomalia de datos, no un estado
  // normal, y se dice sin fingir que es otra cosa.
  return {
    icon: CircleAlert,
    title: 'Falta información de tu cuenta',
    description:
      'Tu cuenta de conductor está incompleta y no podemos activarla. Comunícate con la empresa.',
  };
}

export default function AccountStatus() {
  const { user, isLoading, canOperate, signOut } = useSession();

  if (isLoading) {
    return (
      <Screen>
        <Spinner size="large" centered label="Cargando" />
      </Screen>
    );
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  // Si la situacion se resolvio mientras la pantalla estaba abierta, por ejemplo
  // porque el administrador acaba de aprobar al conductor, no tiene sentido
  // seguir mostrandole una pared.
  if (canOperate) {
    return <Redirect href={homeRouteFor(user.role)} />;
  }

  const { icon, title, description } = explain(user);

  return (
    <Screen>
      <EmptyState
        icon={icon}
        title={title}
        description={description}
        actionLabel="Cerrar sesión"
        onAction={signOut}
      />
    </Screen>
  );
}
