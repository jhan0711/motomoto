import { Redirect, Tabs } from 'expo-router';
import { History, House, UserRound } from 'lucide-react-native';

import { homeRouteFor, useSession } from '@/features/auth/session';
import { fontSize, fontWeight, iconSize, iconStrokeWidth, useTheme } from '@/theme';

/**
 * Driver zone guard and navigation.
 *
 * Unlike the passenger zone, this one uses a bottom tab bar. The driver screen
 * has no sheet competing for the bottom of the display, and a driver switches
 * between "what is happening now" and "what I did earlier" constantly, which is
 * exactly what tabs are for.
 *
 * As with the passenger guard: this decides what renders, not what is allowed.
 * Real authorization lives in the database policies from Phase 5.
 */
export default function DriverLayout() {
  const { colors } = useTheme();
  const { user, isLoading, canOperate, isRecoveringPassword } = useSession();

  if (isRecoveringPassword) {
    return <Redirect href="/reset-password" />;
  }

  if (isLoading) {
    return null;
  }

  if (user === null) {
    return <Redirect href="/welcome" />;
  }

  // Antes que el rol. Un conductor pendiente de aprobacion o bloqueado tiene rol
  // de conductor y no debe llegar a la pantalla de operacion (flujo 7.2, paso 2).
  if (!canOperate) {
    return <Redirect href="/account-status" />;
  }

  if (user.role !== 'driver') {
    return <Redirect href={homeRouteFor(user.role)} />;
  }

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.brandStrong,
        tabBarInactiveTintColor: colors.textTertiary,
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
        },
        tabBarLabelStyle: {
          fontSize: fontSize.xs,
          fontWeight: fontWeight.medium,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Inicio',
          tabBarIcon: ({ color }) => (
            <House size={iconSize.lg} color={color} strokeWidth={iconStrokeWidth} />
          ),
        }}
      />
      <Tabs.Screen
        name="history"
        options={{
          title: 'Servicios',
          tabBarIcon: ({ color }) => (
            <History size={iconSize.lg} color={color} strokeWidth={iconStrokeWidth} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Perfil',
          tabBarIcon: ({ color }) => (
            <UserRound size={iconSize.lg} color={color} strokeWidth={iconStrokeWidth} />
          ),
        }}
      />
    </Tabs>
  );
}
