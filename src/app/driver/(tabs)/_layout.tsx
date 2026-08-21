import { Tabs } from 'expo-router';
import { History, House, UserRound } from 'lucide-react-native';

import { fontSize, fontWeight, iconSize, iconStrokeWidth, useTheme } from '@/theme';

/**
 * Las tres pestanas del conductor.
 *
 * A diferencia de la zona del pasajero, esta si tiene barra abajo: la pantalla
 * del conductor no lleva una hoja peleando por el borde inferior, y el conductor
 * salta entre "que esta pasando ahora" y "que hice antes" constantemente, que es
 * justo para lo que sirven las pestanas.
 *
 * El detalle de un servicio y la pantalla de calificar NO estan aqui: viven en
 * la pila de arriba (`driver/_layout.tsx`), y por eso volver atras desde ellas
 * devuelve a donde se estaba y no a otra pestana.
 */
export default function DriverTabsLayout() {
  const { colors } = useTheme();

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
