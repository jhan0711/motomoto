import { useRouter } from 'expo-router';
import { MapPin, Navigation, Search } from 'lucide-react-native';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { BottomSheet } from '@/components/ui/bottom-sheet';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Text } from '@/components/ui/text';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

/**
 * TEMPORARY bottom sheet demo.
 *
 * The gray background stands in for the map that will sit here from Phase 8.
 * The point of this route is to prove the sheet drags between snap points while
 * the surface behind it stays visible and untouched.
 */
export default function SheetDemo() {
  const { colors } = useTheme();
  const router = useRouter();
  const [index, setIndex] = useState(0);

  return (
    <View style={[styles.root, { backgroundColor: colors.surfaceSubtle }]}>
      <View style={styles.mapPlaceholder}>
        <MapPin size={iconSize.xxl} color={colors.textTertiary} strokeWidth={iconStrokeWidth} />
        <Text variant="caption" color="textTertiary" align="center">
          Aquí irá el mapa a partir de la Fase 8.{'\n'}
          Arrastra el panel: esta zona sigue visible.
        </Text>
        <Text variant="caption" color="brandStrong">
          Punto de anclaje activo: {index}
        </Text>
      </View>

      <View style={styles.floatingHeader}>
        <Header
          title="Solicitar servicio"
          subtitle="Amalfi, Antioquia"
          variant="floating"
          onBack={() => router.back()}
        />
      </View>

      <BottomSheet
        snapPoints={[0.3, 0.75]}
        index={index}
        onIndexChange={setIndex}
        header={<Text variant="subheading">¿A dónde vas?</Text>}
      >
        <Input placeholder="Buscar una dirección" icon={Search} />

        <Text variant="label" color="textTertiary">
          LUGARES FRECUENTES
        </Text>

        <Card
          variant="filled"
          padding="md"
          onPress={() => {}}
          accessibilityLabel="Parque principal"
        >
          <Text variant="bodyStrong">Parque principal</Text>
          <Text variant="caption" color="textSecondary">
            Centro de Amalfi
          </Text>
        </Card>

        <Card
          variant="filled"
          padding="md"
          onPress={() => {}}
          accessibilityLabel="Hospital San Juan de Dios"
        >
          <Text variant="bodyStrong">Hospital San Juan de Dios</Text>
          <Text variant="caption" color="textSecondary">
            Carrera 20
          </Text>
        </Card>

        <Button label="Confirmar destino" variant="brand" icon={Navigation} fullWidth />
      </BottomSheet>
    </View>
  );
}

const styles = StyleSheet.create({
  floatingHeader: {
    left: 0,
    position: 'absolute',
    right: 0,
    top: spacing.xxl,
  },
  mapPlaceholder: {
    alignItems: 'center',
    flex: 1,
    gap: spacing.md,
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
  },
  root: {
    flex: 1,
  },
});
