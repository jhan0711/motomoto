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
 * Calificar un servicio, desde el lado del conductor.
 *
 * Es la gemela de la del pasajero y comparte todo lo que importa: el selector de
 * estrellas, el servicio que envia y la regla de que solo se puede una vez. Lo
 * unico que cambia son las palabras, porque no se le pregunta lo mismo a quien
 * conduce que a quien va detras.
 *
 * SE ESCRIBIO APARTE Y NO COMPARTIDA CON UN PARAMETRO DE ROL. Son treinta lineas
 * de JSX contra un componente con condicionales por dentro que habria que leer
 * dos veces para saber que ve cada uno. El dia que las dos digan exactamente lo
 * mismo se juntan.
 */
export default function RateDriverScreen() {
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

    if (resultado.ok || resultado.failure.code === RIDE_ERROR_CODES.alreadyRated) {
      router.back();
      return;
    }

    setError(resultado.failure.message);
    setEnviando(false);
  }

  return (
    <Screen
      header={<Header title="Calificar al pasajero" onBack={() => router.back()} />}
      padded
      scroll
    >
      <View style={styles.cuerpo}>
        <Card padding="xl">
          <Text variant="subheading" align="center">
            {name !== undefined && name !== '' ? `¿Cómo te fue con ${name}?` : '¿Cómo te fue?'}
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
          placeholder="¿Algo que la empresa deba saber?"
          multiline
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

/** Las mismas cinco palabras que ve el pasajero, para que la escala sea una sola. */
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
