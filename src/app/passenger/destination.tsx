import { useLocalSearchParams, useRouter } from 'expo-router';
import { LocateFixed, MapPin, Map as MapIcon, Search, Star } from 'lucide-react-native';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';

import { Card } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { Header } from '@/components/ui/header';
import { Input } from '@/components/ui/input';
import { Screen } from '@/components/ui/screen';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import {
  newSessionToken,
  retrieveSuggestion,
  searchAddresses,
  type Suggestion,
} from '@/features/destination/mapbox-service';
import type { ChosenPoint, Place } from '@/features/destination/types';
import { usePlaces } from '@/features/destination/use-places';
import { useRideDraft } from '@/features/ride/ride-draft';
import { iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

/**
 * Cuanto se espera tras la ultima tecla antes de preguntarle a Mapbox.
 *
 * No es un adorno de rendimiento: es lo que mantiene el gasto bajo control. Sin
 * esperar, "hospital" son ocho peticiones; con esperar, una.
 */
const TYPING_PAUSE_MS = 400;

/** A partir de aqui tiene sentido buscar. Con una letra sobran los resultados. */
const MIN_QUERY = 3;

type Row =
  | { kind: 'current' }
  | { kind: 'map' }
  | { kind: 'place'; place: Place }
  | { kind: 'suggestion'; suggestion: Suggestion };

/**
 * Eleccion del destino.
 *
 * Tres caminos, en el orden en que sirven de verdad en Amalfi (D10):
 *
 *   1. La lista de la empresa, que es la unica que conoce "el comando" o
 *      "la bomba". Se muestra completa antes de escribir nada.
 *   2. El punto en el mapa, para lo que no esta en la lista.
 *   3. El buscador de direcciones, que en la evaluacion acerto 22 de 39 y por
 *      eso va tercero y no primero.
 *
 * Pantalla completa y no un panel dentro del mapa: aqui hay teclado y lista, y
 * es el patron que el pasajero ya conoce de otras aplicaciones de movilidad.
 */
export default function DestinationScreen() {
  const router = useRouter();
  const { colors } = useTheme();
  const { setDestination, setOrigin } = useRideDraft();

  /**
   * La misma pantalla sirve para el origen y para el destino. Elegir un sitio
   * es el mismo gesto en los dos casos, y duplicarla significaria arreglar cada
   * fallo dos veces.
   */
  const params = useLocalSearchParams<{ for?: string }>();
  const paraOrigen = params.for === 'origin';
  const guardar = paraOrigen ? setOrigin : setDestination;

  const [query, setQuery] = useState('');
  const { places, loading: loadingPlaces, error: placesError } = usePlaces();
  const [choiceError, setChoiceError] = useState<string | null>(null);

  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  const [choosing, setChoosing] = useState(false);

  /**
   * Un solo testigo para toda la busqueda. Mapbox factura por sesion, y una
   * sesion abarca todo lo que se teclea hasta elegir un resultado.
   */
  const session = useRef(newSessionToken());

  /** Filtrado local de la lista curada. Instantaneo y sin gastar busquedas. */
  const placesFiltrados = useMemo(() => {
    const texto = query.trim().toLowerCase();
    if (texto === '') return places;
    return places.filter(
      (p) =>
        p.name.toLowerCase().includes(texto) ||
        (p.description !== null && p.description.toLowerCase().includes(texto)),
    );
  }, [places, query]);

  // Busqueda con pausa. El temporizador se reinicia con cada tecla.
  useEffect(() => {
    const texto = query.trim();

    if (texto.length < MIN_QUERY) {
      const limpiar = setTimeout(() => {
        setSuggestions([]);
        setSearchError(null);
        setSearching(false);
      }, 0);
      return () => clearTimeout(limpiar);
    }

    let vivo = true;
    const temporizador = setTimeout(() => {
      setSearching(true);
      void searchAddresses(texto, session.current).then((resultado) => {
        if (!vivo) return;
        if (resultado.ok) {
          setSuggestions(resultado.data);
          setSearchError(null);
        } else {
          // Vaciar la lista y callarse seria mentir: el pasajero leeria "no
          // encontramos ese sitio" cuando lo que pasa es que el buscador no
          // respondio. Buscaria otro nombre, fallaria igual, y concluiria que la
          // aplicacion no sirve.
          setSuggestions([]);
          setSearchError(resultado.failure.message);
        }
        setSearching(false);
      });
    }, TYPING_PAUSE_MS);

    return () => {
      vivo = false;
      clearTimeout(temporizador);
    };
  }, [query]);

  const elegir = useCallback(
    (punto: ChosenPoint) => {
      guardar(punto);
      router.back();
    },
    [guardar, router],
  );

  const elegirLugar = useCallback(
    (place: Place) => {
      elegir({
        latitude: place.latitude,
        longitude: place.longitude,
        label: place.name,
        detail: place.description,
        source: 'place',
        placeId: place.id,
      });
    },
    [elegir],
  );

  const elegirSugerencia = useCallback(
    async (suggestion: Suggestion) => {
      setChoosing(true);
      const resultado = await retrieveSuggestion(suggestion.id, session.current);
      // La sesion se cierra al recuperar. La siguiente busqueda empieza otra.
      session.current = newSessionToken();
      setChoosing(false);

      if (!resultado.ok) {
        setChoiceError(resultado.failure.message);
        return;
      }

      elegir({
        latitude: resultado.data.latitude,
        longitude: resultado.data.longitude,
        label: suggestion.name,
        detail: suggestion.detail,
        source: 'search',
        placeId: null,
      });
    },
    [elegir],
  );

  const filas = useMemo<Row[]>(
    () => [
      // VOLVER A "MI UBICACION" SOLO EXISTE PARA EL ORIGEN, y solo mientras no
      // se este buscando otra cosa.
      //
      // Faltaba, y dejaba al pasajero encerrado: el origen empieza en null, que
      // significa "donde estoy" (D137), pero en cuanto elegia un sitio concreto
      // no habia ninguna forma de deshacerlo. Ni siquiera pidiendo otro viaje,
      // porque el borrador conserva lo elegido. Lo reporto el usuario.
      //
      // No aparece para el destino: "voy a donde estoy" no es un viaje.
      ...(paraOrigen && query.trim().length === 0 ? [{ kind: 'current' } as Row] : []),
      { kind: 'map' },
      ...placesFiltrados.map((place): Row => ({ kind: 'place', place })),
      ...suggestions.map((suggestion): Row => ({ kind: 'suggestion', suggestion })),
    ],
    [paraOrigen, query, placesFiltrados, suggestions],
  );

  // "No encontramos ese sitio" solo cuando de verdad no hay nada. Si el
  // buscador fallo, el aviso de arriba ya explica lo que pasa, y anadir un
  // "no encontramos" al lado convertiria un problema tecnico en una conclusion
  // falsa sobre el sitio que el pasajero busca.
  const sinNada =
    !loadingPlaces &&
    !searching &&
    searchError === null &&
    placesFiltrados.length === 0 &&
    suggestions.length === 0;

  return (
    <Screen
      header={
        <Header
          title={paraOrigen ? '¿Dónde te recogemos?' : '¿A dónde vas?'}
          onBack={() => router.back()}
        />
      }
      padded={false}
    >
      <View style={styles.buscador}>
        <Input
          placeholder="Escribe un sitio o una dirección"
          icon={Search}
          value={query}
          onChangeText={setQuery}
          autoFocus
          autoCorrect={false}
          returnKeyType="search"
        />
      </View>

      {choosing && <Spinner label="Ubicando el sitio" />}

      {loadingPlaces ? (
        <Spinner centered label="Cargando lugares" />
      ) : (
        <FlatList
          data={filas}
          keyExtractor={(fila) => {
            if (fila.kind === 'current') return 'current';
            if (fila.kind === 'map') return 'map';
            if (fila.kind === 'place') return `place:${fila.place.id}`;
            return `sug:${fila.suggestion.id}`;
          }}
          contentContainerStyle={styles.lista}
          // 'always' y no 'handled'. Con 'handled', el primer toque sobre un
          // resultado se gasta en cerrar el teclado y no elige nada: el pasajero
          // tiene que tocar dos veces el mismo sitio, y la segunda vez la lista
          // ya se movio porque el teclado desaparecio. Detectado probando en la
          // tablet, no leyendo el codigo.
          keyboardShouldPersistTaps="always"
          ListHeaderComponent={
            (placesError ?? choiceError ?? searchError) != null ? (
              <View style={styles.aviso}>
                <Text variant="caption" color="danger">
                  {placesError ?? choiceError ?? searchError}
                </Text>
              </View>
            ) : null
          }
          ListEmptyComponent={
            sinNada ? (
              <EmptyState
                icon={Search}
                title="No encontramos ese sitio"
                description="Prueba con otro nombre, o márcalo directamente en el mapa."
              />
            ) : null
          }
          ListFooterComponent={
            searching ? (
              <View style={styles.buscando}>
                <Spinner size="small" label="Buscando direcciones" />
              </View>
            ) : null
          }
          renderItem={({ item }) => {
            if (item.kind === 'current') {
              return (
                <Fila
                  icon={LocateFixed}
                  destacado
                  titulo="Tu ubicación actual"
                  subtitulo="Te recogemos donde estás ahora"
                  onPress={() => {
                    // Null es exactamente lo que significa "mi ubicacion" en el
                    // borrador, asi que volver al valor inicial es toda la
                    // operacion. La pantalla de inicio resuelve la coordenada
                    // cuando hace falta, con la posicion de ese momento y no con
                    // la de ahora.
                    setOrigin(null);
                    router.back();
                  }}
                />
              );
            }

            if (item.kind === 'map') {
              return (
                <Fila
                  icon={MapIcon}
                  destacado
                  titulo="Elegir en el mapa"
                  subtitulo="Marca el punto exacto con el dedo"
                  onPress={() =>
                    router.push({
                      pathname: '/passenger/pick-on-map',
                      params: paraOrigen ? { for: 'origin' } : {},
                    })
                  }
                />
              );
            }

            if (item.kind === 'place') {
              return (
                <Fila
                  icon={Star}
                  titulo={item.place.name}
                  subtitulo={item.place.description}
                  onPress={() => elegirLugar(item.place)}
                />
              );
            }

            return (
              <Fila
                icon={MapPin}
                titulo={item.suggestion.name}
                subtitulo={item.suggestion.detail}
                onPress={() => void elegirSugerencia(item.suggestion)}
              />
            );
          }}
          ItemSeparatorComponent={() => (
            <View style={[styles.separador, { backgroundColor: colors.border }]} />
          )}
        />
      )}
    </Screen>
  );
}

interface FilaProps {
  icon: typeof MapPin;
  titulo: string;
  subtitulo: string | null;
  onPress: () => void;
  /** Lo pinta con el color de marca. Solo para "Elegir en el mapa". */
  destacado?: boolean;
}

function Fila({ icon: Icon, titulo, subtitulo, onPress, destacado = false }: FilaProps) {
  const { colors } = useTheme();

  return (
    <Card
      variant="filled"
      padding="md"
      onPress={onPress}
      accessibilityLabel={titulo}
      style={styles.fila}
    >
      <View style={styles.filaContenido}>
        <View
          style={[
            styles.filaIcono,
            { backgroundColor: destacado ? colors.brandSubtle : colors.surfacePressed },
          ]}
        >
          <Icon
            size={iconSize.md}
            color={destacado ? colors.brandStrong : colors.textSecondary}
            strokeWidth={iconStrokeWidth}
          />
        </View>

        <View style={styles.filaTextos}>
          <Text variant="bodyStrong" numberOfLines={1}>
            {titulo}
          </Text>
          {subtitulo !== null && subtitulo !== '' && (
            <Text variant="caption" color="textSecondary" numberOfLines={1}>
              {subtitulo}
            </Text>
          )}
        </View>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  aviso: {
    paddingBottom: spacing.md,
  },
  buscador: {
    paddingBottom: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  buscando: {
    paddingVertical: spacing.lg,
  },
  fila: {
    backgroundColor: 'transparent',
  },
  filaContenido: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
  filaIcono: {
    alignItems: 'center',
    borderRadius: 999,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  filaTextos: {
    flex: 1,
    gap: spacing.xxs,
  },
  lista: {
    paddingBottom: spacing.xxl,
    paddingHorizontal: spacing.lg,
  },
  separador: {
    height: StyleSheet.hairlineWidth,
  },
});
