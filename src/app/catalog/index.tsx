import { useRouter } from 'expo-router';
import {
  CircleAlert,
  CircleCheck,
  History,
  Lock,
  MapPin,
  Navigation,
  PanelBottom,
  Phone,
  Search,
  Star,
  TriangleAlert,
  Users,
} from 'lucide-react-native';
import { useEffect, useState, type ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

import { supabase } from '@/lib/supabase';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { Screen } from '@/components/ui/screen';
import { Skeleton } from '@/components/ui/skeleton';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import {
  iconSize,
  iconStrokeWidth,
  radius,
  spacing,
  useTheme,
  type TextVariant,
  type ThemeColors,
} from '@/theme';

/**
 * TEMPORARY design system preview.
 *
 * This route exists only to validate tokens and primitives on a real device.
 * Step 3.8 replaces it with the full catalog, and the catalog is removed once
 * the first real screen ships.
 */

const TEXT_VARIANTS: TextVariant[] = [
  'display',
  'title',
  'heading',
  'subheading',
  'body',
  'bodyStrong',
  'button',
  'label',
  'caption',
];

const SWATCHES: (keyof ThemeColors)[] = [
  'brand',
  'brandStrong',
  'brandSubtle',
  'action',
  'success',
  'warning',
  'danger',
  'info',
];

/**
 * TEMPORAL. Comprueba que la aplicacion alcanza el backend de verdad.
 *
 * Sin sesion iniciada somos el rol anonimo, asi que las politicas dirigidas a
 * usuarios autenticados no aplican y la consulta devuelve cero filas. Eso NO es
 * un fallo: significa que el servidor respondio y que la seguridad esta
 * filtrando. Un fallo de conexion daria un error de red, no una lista vacia.
 */
function EstadoConexion() {
  const { colors } = useTheme();
  const [estado, setEstado] = useState<'probando' | 'ok' | 'error'>('probando');
  const [detalle, setDetalle] = useState('');

  useEffect(() => {
    let activo = true;

    void supabase
      .from('app_settings')
      .select('key')
      .then(({ data, error }) => {
        if (!activo) return;
        if (error) {
          setEstado('error');
          setDetalle(`${error.code ?? 'sin código'}: ${error.message}`);
        } else {
          setEstado('ok');
          setDetalle(`El servidor respondió. ${data.length} filas visibles sin sesión.`);
        }
      });

    return () => {
      activo = false;
    };
  }, []);

  if (estado === 'probando') {
    return <Spinner label="Contactando con el servidor" />;
  }

  return (
    <Card variant={estado === 'ok' ? 'filled' : 'outlined'} padding="md">
      <View style={styles.skeletonRow}>
        {estado === 'ok' ? (
          <CircleCheck size={iconSize.lg} color={colors.success} strokeWidth={iconStrokeWidth} />
        ) : (
          <CircleAlert size={iconSize.lg} color={colors.danger} strokeWidth={iconStrokeWidth} />
        )}
        <View style={styles.skeletonLines}>
          <Text variant="bodyStrong">{estado === 'ok' ? 'Conectado' : 'Sin conexión'}</Text>
          <Text variant="caption" color="textSecondary">
            {detalle}
          </Text>
          <Text variant="caption" color="textTertiary">
            {process.env.EXPO_PUBLIC_SUPABASE_URL?.replace('https://', '') ?? 'sin URL'}
          </Text>
        </View>
      </View>
    </Card>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  const { colors } = useTheme();

  return (
    <View style={styles.section}>
      <Text variant="label" color="textTertiary">
        {title.toUpperCase()}
      </Text>
      <View style={[styles.sectionBody, { borderColor: colors.border }]}>{children}</View>
    </View>
  );
}

export default function DesignSystemPreview() {
  const { colors, scheme } = useTheme();
  const router = useRouter();
  const [modalVisible, setModalVisible] = useState(false);

  return (
    <Screen
      scroll
      padded={false}
      header={<Header title="Sistema de diseño" subtitle={`Tema activo: ${scheme}`} />}
      contentContainerStyle={styles.content}
    >
      <Section title="Conexión con Supabase">
        <EstadoConexion />
      </Section>

      <Section title="Tipografía">
        {TEXT_VARIANTS.map((variant) => (
          <View key={variant} style={styles.row}>
            <Text variant={variant}>Motorratón</Text>
            <Text variant="caption" color="textTertiary">
              {variant}
            </Text>
          </View>
        ))}
      </Section>

      <Section title="Color de marca y estados">
        <View style={styles.swatches}>
          {SWATCHES.map((token) => (
            <View key={token} style={styles.swatchItem}>
              <View
                style={[
                  styles.swatch,
                  { backgroundColor: colors[token], borderColor: colors.border },
                ]}
              />
              <Text variant="caption" color="textSecondary">
                {token}
              </Text>
            </View>
          ))}
        </View>
      </Section>

      <Section title="Botones por variante">
        <Button label="Solicitar servicio" variant="primary" fullWidth />
        <Button label="Buscar conductor" variant="brand" fullWidth icon={Navigation} />
        <Button label="Ver en el mapa" variant="secondary" fullWidth icon={MapPin} />
        <Button label="Cambiar destino" variant="ghost" fullWidth />
        <Button label="Cancelar servicio" variant="danger" fullWidth />
      </Section>

      <Section title="Tamaños">
        <Button label="Pequeño" size="sm" icon={Users} />
        <Button label="Mediano" size="md" icon={Users} />
        <Button label="Grande" size="lg" icon={Users} />
      </Section>

      <Section title="Estados">
        <Button label="Buscando conductor" variant="brand" fullWidth loading />
        <Button label="No disponible" variant="primary" fullWidth disabled />
        <Button label="Calificar viaje" variant="secondary" icon={Star} iconPosition="right" />
      </Section>

      <Section title="Tarjetas">
        <Card variant="outlined">
          <Text variant="bodyStrong">Parque principal</Text>
          <Text variant="caption" color="textSecondary">
            Amalfi, Antioquia
          </Text>
        </Card>
        <Card variant="filled">
          <Text variant="bodyStrong">Hospital San Juan de Dios</Text>
          <Text variant="caption" color="textSecondary">
            Lugar frecuente
          </Text>
        </Card>
        <Card variant="elevated">
          <Text variant="label" color="textTertiary">
            CONDUCTOR ASIGNADO
          </Text>
          <Text variant="title">Motorratón 12</Text>
          <Text variant="caption" color="textSecondary">
            Placa ABC12 - Capacidad 3 pasajeros
          </Text>
        </Card>
        <Card variant="outlined" onPress={() => {}} accessibilityLabel="Ver historial">
          <Text variant="bodyStrong">Tarjeta pulsable</Text>
          <Text variant="caption" color="textSecondary">
            Mantener pulsado para ver el estado
          </Text>
        </Card>
      </Section>

      <Section title="Campos">
        <Input label="Buscar destino" placeholder="¿A dónde vas?" icon={Search} />
        <Input
          label="Teléfono"
          placeholder="300 000 0000"
          icon={Phone}
          keyboardType="phone-pad"
          helperText="Lo usará el conductor para coordinar la recogida"
        />
        <Input
          label="Contraseña"
          placeholder="Mínimo 8 caracteres"
          icon={Lock}
          secureTextEntry
          defaultValue="clave-de-prueba"
        />
        <Input
          label="Correo"
          placeholder="correo@ejemplo.com"
          defaultValue="correo-invalido"
          errorText="Introduce un correo válido"
        />
        <Input label="Cantidad de pasajeros" defaultValue="3" editable={false} />
      </Section>

      <Section title="Carga">
        <View style={styles.skeletonRow}>
          <Skeleton width={44} height={44} radius="full" />
          <View style={styles.skeletonLines}>
            <Skeleton width="70%" height={16} />
            <Skeleton width="45%" height={12} />
          </View>
        </View>
        <Skeleton height={72} radius="lg" />
        <Spinner label="Buscando conductor cercano" />
      </Section>

      <Section title="Estado vacío">
        <EmptyState
          icon={History}
          title="Todavía no tienes viajes"
          description="Cuando solicites tu primer motorratón, aparecerá aquí."
          actionLabel="Solicitar un viaje"
          onAction={() => {}}
        />
      </Section>

      <Section title="Estado de error">
        <ErrorState onRetry={() => {}} />
        <ErrorState offline onRetry={() => {}} />
      </Section>

      <Section title="Modal">
        <Button
          label="Confirmar cancelación"
          variant="secondary"
          icon={TriangleAlert}
          fullWidth
          onPress={() => setModalVisible(true)}
        />
      </Section>

      <Section title="Bottom sheet">
        <Text variant="caption" color="textSecondary">
          Se abre en pantalla completa porque el panel se superpone al mapa.
        </Text>
        <Button
          label="Abrir demostración"
          variant="brand"
          icon={PanelBottom}
          fullWidth
          onPress={() => router.push('/catalog/sheet')}
        />
      </Section>

      <Modal
        visible={modalVisible}
        onRequestClose={() => setModalVisible(false)}
        icon={TriangleAlert}
        tone="danger"
        title="¿Cancelar el servicio?"
        description="El conductor ya va en camino. Cancelar ahora puede afectar tu historial."
        confirmLabel="Sí, cancelar"
        cancelLabel="No, esperar"
        onConfirm={() => setModalVisible(false)}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: spacing.xl,
    padding: spacing.lg,
    paddingBottom: spacing.xxxl,
  },
  row: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'space-between',
  },
  section: {
    gap: spacing.sm,
  },
  sectionBody: {
    borderRadius: radius.lg,
    borderWidth: StyleSheet.hairlineWidth * 2,
    gap: spacing.md,
    padding: spacing.lg,
  },
  swatch: {
    borderRadius: radius.md,
    borderWidth: StyleSheet.hairlineWidth * 2,
    height: 44,
    width: 44,
  },
  swatchItem: {
    alignItems: 'center',
    gap: spacing.xs,
    width: 72,
  },
  skeletonLines: {
    flex: 1,
    gap: spacing.sm,
  },
  skeletonRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  swatches: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.md,
  },
});
