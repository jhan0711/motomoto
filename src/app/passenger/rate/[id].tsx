import { useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Text } from '@/components/ui/text';
import { MAX_COMMENT, rateRide } from '@/features/rating/rating-service';
import { StarPicker } from '@/features/rating/star-picker';
import { RIDE_ERROR_CODES } from '@/features/ride/errors';
import { spacing } from '@/theme';

/**
 * Calificar un servicio, desde el lado del pasajero.
 *
 * PANTALLA Y NO UNA HOJA DENTRO DEL MAPA. Calificar es lo ultimo del ciclo y no
 * compite con nada: una pantalla propia deja sitio para cinco objetivos tactiles
 * grandes y un comentario, y se puede volver a abrir desde el historial sin
 * duplicar nada (paso 4).
 *
 * LAS ESTRELLAS SON OBLIGATORIAS Y EL COMENTARIO NO, que es lo que dice el flujo
 * 7.1. "Obligatorias" aqui significa que el boton no se activa hasta elegir, no
 * que la aplicacion secuestre al pasajero: siempre puede volver atras sin
 * calificar, y el servicio le sigue esperando en el historial.
 *
 * SE ENTRA CON EL IDENTIFICADOR DEL VIAJE, no con el de la solicitud. Quien se
 * califica es la persona con la que se compartio el vehiculo, y eso lo sabe el
 * viaje.
 */
export default function RatePassengerScreen() {
  const router = useRouter();
  const { id, name } = useLocalSearchParams<{ id: string; name?: string }>();

  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function enviar() {
    if (stars === 0 || enviando) return;

    setEnviando(true);
    setError(null);

    const resultado = await rateRide(id, stars, comment);

    if (resultado.ok) {
      router.back();
      return;
    }

    // Que ya estuviera calificado no es un fallo que el pasajero pueda corregir,
    // y tampoco es una perdida: lo que queria dejar dicho ya estaba dicho. Se
    // cierra igual que si acabara de enviarlo, sin ensenarle nada en rojo.
    if (resultado.failure.code === RIDE_ERROR_CODES.alreadyRated) {
      router.back();
      return;
    }

    setError(resultado.failure.message);
    setEnviando(false);
  }

  return (
    <Screen
      header={<Header title="Calificar el viaje" onBack={() => router.back()} />}
      padded
      scroll
    >
      <View style={styles.cuerpo}>
        <Card padding="xl">
          <Text variant="subheading" align="center">
            {name !== undefined && name !== ''
              ? `¿Cómo te fue con ${name}?`
              : '¿Cómo estuvo tu viaje?'}
          </Text>

          <View style={styles.estrellas}>
            <StarPicker value={stars} onChange={setStars} />
          </View>

          <Text variant="caption" color="textSecondary" align="center">
            {ETIQUETAS[stars] ?? 'Toca una estrella para calificar'}
          </Text>
        </Card>

        <Input
          label="Comentario (opcional)"
          value={comment}
          onChangeText={setComment}
          placeholder="¿Algo que quieras contar del servicio?"
          multiline
          // El servidor corta en 1000 caracteres. Cortar aqui evita que alguien
          // escriba un parrafo largo y lo pierda al enviar; la regla sigue
          // siendo la del servidor.
          maxLength={MAX_COMMENT}
          autoCapitalize="sentences"
          editable={!enviando}
        />

        <FormError message={error} />

        <Button
          label="Enviar calificación"
          variant="brand"
          fullWidth
          disabled={stars === 0}
          loading={enviando}
          onPress={() => void enviar()}
        />

        <Text variant="caption" color="textTertiary" align="center">
          Una calificación por servicio, y no se puede cambiar después.
        </Text>
      </View>
    </Screen>
  );
}

/**
 * Que significa cada cantidad de estrellas.
 *
 * El numero solo no dice lo mismo a todo el mundo: para alguien tres estrellas
 * son "bien" y para otro "regular". La palabra lo fija, y ademas es lo que lee
 * un lector de pantalla al confirmar la eleccion.
 */
const ETIQUETAS: Record<number, string> = {
  1: 'Muy mal',
  2: 'Mal',
  3: 'Regular',
  4: 'Bien',
  5: 'Excelente',
};

const styles = StyleSheet.create({
  cuerpo: { gap: spacing.lg, paddingBottom: spacing.xxl, paddingTop: spacing.lg },
  estrellas: { alignItems: 'center', paddingVertical: spacing.md },
});
