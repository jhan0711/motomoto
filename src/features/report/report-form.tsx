import { useRouter } from 'expo-router';
import { Check } from 'lucide-react-native';
import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { FormError } from '@/components/ui/form-error';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { useSession } from '@/features/auth/session';
import { radius, spacing, useTheme } from '@/theme';
import { motivosDe } from './categories';
import { createReport, MAX_DESCRIPCION, MIN_DESCRIPCION } from './report-service';

interface Props {
  /**
   * El servicio del que se queja, si viene desde uno. **Opcional a proposito**:
   * no todos los problemas son con un viaje -"la aplicacion se cerro sola"- y
   * obligar a elegir uno haria que la gente escogiera cualquiera con tal de
   * poder enviar.
   */
  rideId?: string;
  /** Que servicio es, para que se vea de que se esta hablando. */
  rideLabel?: string;
}

/**
 * Reportar un problema (D204), el mismo formulario para los dos roles.
 *
 * **LO QUE CAMBIA ENTRE PASAJERO Y CONDUCTOR SON LOS MOTIVOS, NO LA PANTALLA.**
 * Duplicarla entera para cambiar una lista dejaria dos sitios que arreglar cada
 * vez. Las rutas de cada rol son de tres lineas y solo existen porque los
 * `_layout` protegen por rol.
 *
 * **EL AVISO DE QUE ALGUIEN LO VA A LEER NO ES ADORNO.** Durante toda la Fase 12
 * no hubo boton de reportar precisamente para no prometer una atencion que no
 * existia; ahora existe la bandeja, y decirlo es lo que hace que valga la pena
 * escribir.
 */
export function ReportForm({ rideId, rideLabel }: Props) {
  const router = useRouter();
  const { user } = useSession();
  const { colors } = useTheme();

  const motivos = motivosDe(user?.role);

  const [motivo, setMotivo] = useState<string | null>(null);
  const [descripcion, setDescripcion] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [enviado, setEnviado] = useState(false);

  const escritos = descripcion.trim().length;
  const faltan = MIN_DESCRIPCION - escritos;
  const puedeEnviar = motivo !== null && escritos >= MIN_DESCRIPCION && !enviando;

  async function enviar() {
    if (user === null || motivo === null) {
      return;
    }

    setError(null);
    setEnviando(true);
    const resultado = await createReport(user.id, motivo, descripcion, rideId);
    setEnviando(false);

    if (!resultado.ok) {
      setError(resultado.failure.message);
      return;
    }

    setEnviado(true);
  }

  /*
   * SE CONFIRMA EN LA MISMA PANTALLA EN VEZ DE VOLVER ATRAS SIN MAS. Quien
   * acaba de contar un problema necesita ver que llego; un regreso silencioso
   * deja dudando de si se envio, y lo normal seria volver a escribirlo.
   */
  if (enviado) {
    return (
      <Screen header={<Header title="Reporte enviado" onBack={() => router.back()} />}>
        <View style={styles.confirmacion}>
          <View style={[styles.marca, { backgroundColor: colors.success }]}>
            <Check size={28} color={colors.onSuccess} />
          </View>
          <Text variant="title">Ya lo recibimos</Text>
          <Text variant="body" color="textSecondary" style={styles.centrado}>
            La empresa va a revisar lo que nos contaste. Si hace falta, te avisamos por aquí mismo
            cuando lo hayan revisado.
          </Text>
          <Button label="Listo" variant="primary" fullWidth onPress={() => router.back()} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen scroll header={<Header title="Reportar un problema" onBack={() => router.back()} />}>
      <View style={styles.form}>
        <FormError message={error} />

        {rideLabel !== undefined && (
          <View style={[styles.servicio, { backgroundColor: colors.surfaceSubtle }]}>
            <Text variant="caption" color="textSecondary">
              Sobre este servicio
            </Text>
            <Text variant="body">{rideLabel}</Text>
          </View>
        )}

        <View>
          <Text variant="label">¿Qué pasó?</Text>
          <View style={styles.motivos}>
            {motivos.map((m) => {
              const elegido = motivo === m;
              return (
                <Pressable
                  key={m}
                  onPress={() => setMotivo(m)}
                  accessibilityRole="radio"
                  accessibilityState={{ selected: elegido }}
                  style={({ pressed }) => [
                    styles.motivo,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                    elegido && { backgroundColor: colors.action, borderColor: colors.action },
                    pressed && styles.motivoPulsado,
                  ]}
                >
                  <Text variant="body" color={elegido ? 'onAction' : 'textPrimary'}>
                    {m}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>

        <Input
          label="Cuéntanos qué pasó"
          placeholder="Escribe lo que pasó con el mayor detalle que puedas"
          multiline
          numberOfLines={5}
          maxLength={MAX_DESCRIPCION}
          value={descripcion}
          onChangeText={setDescripcion}
          /*
           * Se dice CUANTO FALTA, no "minimo 10 caracteres". Un minimo obliga a
           * contar lo escrito para saber si ya se puede enviar; el que falta se
           * lee de un vistazo y desaparece solo al llegar.
           */
          helperText={
            escritos === 0
              ? 'Entre más nos cuentes, más fácil es resolverlo'
              : faltan > 0
                ? `Escribe ${faltan} ${faltan === 1 ? 'letra' : 'letras'} más`
                : `${escritos} de ${MAX_DESCRIPCION}`
          }
        />

        <Text variant="caption" color="textTertiary">
          Lo va a leer la empresa. No lo ve la otra persona del servicio.
        </Text>
      </View>

      <View style={styles.acciones}>
        <Button
          label="Enviar reporte"
          variant="primary"
          fullWidth
          disabled={!puedeEnviar}
          loading={enviando}
          onPress={() => void enviar()}
        />
        <Button label="Cancelar" variant="ghost" fullWidth onPress={() => router.back()} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  acciones: {
    gap: spacing.sm,
    marginTop: spacing.xl,
  },
  centrado: {
    textAlign: 'center',
  },
  confirmacion: {
    alignItems: 'center',
    gap: spacing.md,
    marginTop: spacing.xxl,
  },
  form: {
    gap: spacing.lg,
    marginTop: spacing.lg,
  },
  /*
   * Los colores no estan en esta hoja porque salen del tema -claro u oscuro- y
   * `StyleSheet.create` se evalua una sola vez al cargar el modulo. Van en
   * linea, que es como lo hace el resto de la aplicacion.
   */
  marca: {
    alignItems: 'center',
    borderRadius: radius.full,
    height: 56,
    justifyContent: 'center',
    width: 56,
  },
  motivo: {
    borderRadius: radius.md,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  motivoPulsado: {
    opacity: 0.7,
  },
  motivos: {
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  servicio: {
    borderRadius: radius.md,
    gap: spacing.xxs,
    padding: spacing.md,
  },
});
