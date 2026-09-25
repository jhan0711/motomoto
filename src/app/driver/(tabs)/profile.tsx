import { useRouter } from 'expo-router';
import {
  Bike,
  ChevronRight,
  LogOut,
  Mail,
  MessageSquareWarning,
  Phone,
  ShieldCheck,
  Star,
} from 'lucide-react-native';
import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Header } from '@/components/ui/header';
import { Modal } from '@/components/ui/modal';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { BalanceCard } from '@/features/driver/balance-card';
import { fetchDriverState, type DriverState } from '@/features/driver/driver-service';
import { ProfileAvatar } from '@/features/profile/profile-avatar';
import { iconSize, iconStrokeWidth, radius, spacing, useTheme } from '@/theme';

/**
 * Driver profile.
 *
 * Drivers can see far less than passengers can edit. Their vehicle, their unit
 * number and their approval status are set by the company from the web panel,
 * per the Phase 0 rules, so those fields are read-only here by design.
 *
 * EL MOTOCARRO Y LA CALIFICACION ERAN MAQUETA HASTA LA FASE 13. Esta pantalla
 * nacio en la Fase 4 con datos escritos a mano, "Motocarro 12, placa ABC12", y
 * cuando la Fase 12 conecto la pantalla de inicio al servidor esta se quedo
 * atras. El resultado era que inicio y perfil ensenaban placas distintas del
 * mismo vehiculo, y la de aqui no existia en ninguna parte.
 *
 * No era un detalle cosmetico: la placa es lo que identifica la unidad y lo que
 * un pasajero comprobaria antes de subirse. Ademas el aviso del pie invita a
 * avisar a la empresa si algo no cuadra, asi que un dato falso aqui parecia un
 * error de la empresa y no nuestro.
 */
export default function DriverProfile() {
  const { colors } = useTheme();
  const router = useRouter();
  const { user, signOut } = useSession();
  const [confirmingSignOut, setConfirmingSignOut] = useState(false);

  const driverId = user?.id ?? null;
  const [estado, setEstado] = useState<DriverState | null>(null);

  const cargar = useCallback(async () => {
    if (driverId === null) return;

    const resultado = await fetchDriverState(driverId);
    if (resultado.ok) setEstado(resultado.data);
  }, [driverId]);

  useEffect(() => {
    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => clearTimeout(id);
  }, [cargar]);

  return (
    <Screen scroll header={<Header title="Mi perfil" />}>
      <View style={styles.identity}>
        {/* Solo visualizacion: la foto del conductor la sube el administrador
            desde el panel, igual que su vehiculo y su numero de unidad. */}
        {user !== null && (
          <ProfileAvatar userId={user.id} avatarPath={user.avatarPath} fallbackIcon={Bike} />
        )}
        <Text variant="heading">{user?.fullName ?? 'Conductor'}</Text>
        <View style={styles.rating}>
          <Star size={iconSize.sm} color={colors.warning} strokeWidth={iconStrokeWidth} />
          {/* Mientras no haya ninguna calificacion se dice tal cual, en lugar de
              pintar un cero: un conductor nuevo no tiene un cero, tiene una
              hoja en blanco, y ensenarle un cero le atribuye un mal servicio
              que nadie ha dado. */}
          <Text variant="caption" color="textSecondary">
            {estado === null || estado.ratingCount === 0
              ? 'Sin calificaciones todavía'
              : `${estado.ratingAverage.toFixed(1).replace('.', ',')} · ${
                  estado.ratingCount === 1
                    ? 'una calificación'
                    : `${estado.ratingCount} calificaciones`
                }`}
          </Text>
        </View>
      </View>

      {/* Solo aparece cuando la empresa enciende el cobro por saldo (D278). */}
      <BalanceCard />

      <Card variant="outlined" padding="md">
        <Text variant="caption" color="textTertiary">
          MOTOCARRO ASIGNADO
        </Text>
        {estado?.vehicle == null ? (
          <>
            <Text variant="title">Sin asignar</Text>
            <Text variant="caption" color="textSecondary">
              La empresa todavía no te asignó un motocarro.
            </Text>
          </>
        ) : (
          <>
            <Text variant="title">Motocarro {estado.vehicle.unitNumber}</Text>
            <Text variant="caption" color="textSecondary">
              Placa {estado.vehicle.plate} · Capacidad {estado.vehicle.maxPassengers} pasajeros
            </Text>
          </>
        )}
      </Card>

      <Card variant="outlined" padding="md">
        <View style={styles.row}>
          <Phone size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.rowCopy}>
            <Text variant="caption" color="textTertiary">
              Teléfono
            </Text>
            {/* Dato real de la sesion. Antes decia "Sin registrar" incluso cuando
                el telefono existia, que es peor que no mostrarlo. */}
            <Text variant="body" color={user?.phone == null ? 'textTertiary' : 'textPrimary'}>
              {user?.phone ?? 'Sin registrar'}
            </Text>
          </View>
        </View>
      </Card>

      <Card variant="outlined" padding="md">
        <View style={styles.row}>
          <Mail size={iconSize.md} color={colors.textSecondary} strokeWidth={iconStrokeWidth} />
          <View style={styles.rowCopy}>
            <Text variant="caption" color="textTertiary">
              Correo
            </Text>
            <Text variant="body" color={user?.email == null ? 'textTertiary' : 'textPrimary'}>
              {user?.email ?? 'Sin registrar'}
            </Text>
          </View>
        </View>
      </Card>

      {/* El conductor no edita sus datos, que los gestiona la empresa, pero su
          contrasena si es suya. La cuenta la crea el administrador con una
          contrasena inicial, asi que querra cambiarla el primer dia. */}
      <Card
        variant="outlined"
        padding="md"
        onPress={() => router.push('/change-password')}
        accessibilityLabel="Cambiar contraseña"
      >
        <View style={styles.row}>
          <ShieldCheck
            size={iconSize.md}
            color={colors.textSecondary}
            strokeWidth={iconStrokeWidth}
          />
          <View style={styles.rowCopy}>
            <Text variant="caption" color="textTertiary">
              Seguridad
            </Text>
            <Text variant="body">Cambiar contraseña</Text>
          </View>
          <ChevronRight
            size={iconSize.md}
            color={colors.textTertiary}
            strokeWidth={iconStrokeWidth}
          />
        </View>
      </Card>

      <Text variant="caption" color="textTertiary" align="center" style={styles.note}>
        Tu vehículo y tu número de unidad los gestiona la empresa. Si algún dato no es correcto,
        comunícalo a la administración.
      </Text>

      {/*
        EL ACCESO SUELTO, SIN VIAJE. Lo mismo que en el perfil del pasajero: aqui
        entra lo que no cuelga de ningun servicio concreto. Y para el conductor
        pesa mas, porque **su detalle de servicio no tiene todavia esta puerta**:
        el historial del conductor lleva al trabajo, no a una ficha con acciones.
      */}
      <Button
        label="Reportar un problema"
        variant="ghost"
        icon={MessageSquareWarning}
        fullWidth
        onPress={() => router.push('/driver/report')}
      />

      <Button
        label="Cerrar sesión"
        variant="secondary"
        icon={LogOut}
        fullWidth
        onPress={() => setConfirmingSignOut(true)}
      />

      <Modal
        visible={confirmingSignOut}
        onRequestClose={() => setConfirmingSignOut(false)}
        icon={LogOut}
        title="¿Cerrar sesión?"
        description="Dejarás de recibir solicitudes hasta que vuelvas a entrar."
        confirmLabel="Cerrar sesión"
        cancelLabel="Quedarme"
        onConfirm={() => {
          setConfirmingSignOut(false);
          signOut();
        }}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  avatar: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 80,
    justifyContent: 'center',
    width: 80,
  },
  identity: {
    alignItems: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.xl,
  },
  note: {
    marginBottom: spacing.lg,
    marginTop: spacing.md,
  },
  rating: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  rowCopy: {
    flex: 1,
  },
});
