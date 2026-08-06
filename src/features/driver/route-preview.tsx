import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { Map, type MapMarker, type MapRoute } from '@/features/map/map';
import { regionContaining, type Coordinates } from '@/features/map/region';
import { fetchRouteGeometry } from '@/features/ride/route-service';
import { Spinner } from '@/components/ui/spinner';
import { Text } from '@/components/ui/text';
import { radius, spacing, useTheme } from '@/theme';

/**
 * El mapa que hace posible D161.
 *
 * La decision dice que quien juzga si una solicitud "queda de camino" es el
 * conductor, no el servidor. Eso solo funciona si puede verlo, y es la razon de
 * que parte de la Fase 14 se adelantara: sin este recuadro, D161 le pide una
 * decision a ciegas.
 *
 * Por eso dibuja DOS COSAS Y NO UNA. En naranja, la ruta que le estan
 * ofreciendo; en gris, las que ya lleva encima. Un mapa con solo la ruta nueva
 * seria bonito e inutil: la pregunta no es "por donde va este viaje", sino "por
 * donde va respecto de lo que ya tengo que hacer". Con las dos superpuestas se
 * responde de un vistazo.
 *
 * El mapa no se puede tocar (`interactive={false}`). Vive dentro de una lista
 * que se desplaza, y un mapa que se queda con el gesto es un mapa que atrapa al
 * conductor cuando solo queria bajar a ver el resto de la tarjeta.
 */

export interface RouteEnds {
  origin: Coordinates;
  destination: Coordinates;
}

export interface RoutePreviewProps {
  /** La ruta protagonista, la que se esta decidiendo. */
  route: RouteEnds;
  /** Los viajes que ya lleva. Se dibujan detras y en gris. */
  context?: RouteEnds[];
  height?: number;
}

type Estado =
  | { kind: 'cargando' }
  | {
      kind: 'listo';
      principal: Coordinates[];
      contexto: Coordinates[][];
      /**
       * Cuantas rutas en curso no se pudieron dibujar.
       *
       * Se cuenta y se avisa porque callarlo es lo peor que puede hacer esta
       * pantalla. Salio en la prueba de red lenta: la ruta ofrecida cargo, la del
       * servicio en curso no, y el resultado era un mapa con una sola linea
       * naranja que parecia completo. El conductor habria creido que la nueva
       * solicitud no se cruza con nada, cuando lo que pasaba es que la otra no
       * estaba dibujada. Un mapa incompleto que no se declara incompleto es peor
       * que no tener mapa.
       */
      contextoPerdido: number;
    }
  | { kind: 'sin-ruta' }
  | { kind: 'error' };

/** Identidad de una ruta por sus cuatro numeros, para no repetir peticiones. */
function clave(ends: RouteEnds): string {
  return (
    `${ends.origin.latitude},${ends.origin.longitude};` +
    `${ends.destination.latitude},${ends.destination.longitude}`
  );
}

export function RoutePreview({ route, context = [], height = 160 }: RoutePreviewProps) {
  const { colors } = useTheme();
  const [estado, setEstado] = useState<Estado>({ kind: 'cargando' });

  // Las dependencias son cadenas y no los objetos: las coordenadas llegan en
  // objetos nuevos en cada render, y depender de ellos volveria a pedir la ruta
  // indefinidamente. Cuatro numeros que no cambian son la misma ruta.
  const claveRuta = clave(route);
  const claveContexto = context.map(clave).join('|');

  useEffect(() => {
    // Una oferta caduca sola a los veinte segundos y su tarjeta desaparece con
    // la peticion todavia en el aire. Sin esta bandera, la respuesta llegaria a
    // un componente que ya no existe.
    let vigente = true;

    async function pedir() {
      setEstado({ kind: 'cargando' });

      const [principal, ...resto] = await Promise.all([
        fetchRouteGeometry(route.origin, route.destination),
        ...context.map((c) => fetchRouteGeometry(c.origin, c.destination)),
      ]);

      if (!vigente || principal === undefined) return;

      if (!principal.ok) {
        setEstado({ kind: 'error' });
        return;
      }

      if (principal.coordinates === null) {
        setEstado({ kind: 'sin-ruta' });
        return;
      }

      // Si una ruta en curso falla se dibuja el resto, pero se lleva la cuenta:
      // el mapa tiene que decir que esta incompleto.
      const contexto: Coordinates[][] = [];
      let perdidas = 0;

      for (const r of resto) {
        if (r.ok && r.coordinates !== null) {
          contexto.push(r.coordinates);
        } else {
          perdidas += 1;
        }
      }

      setEstado({
        kind: 'listo',
        principal: principal.coordinates,
        contexto,
        contextoPerdido: perdidas,
      });
    }

    void pedir();

    return () => {
      vigente = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [claveRuta, claveContexto]);

  const marco = { height, backgroundColor: colors.surfaceSubtle };

  if (estado.kind === 'cargando') {
    return (
      <View style={[styles.marco, marco]}>
        <Spinner label="Trazando la ruta" />
      </View>
    );
  }

  if (estado.kind !== 'listo') {
    return (
      <View style={[styles.marco, marco]}>
        <Text variant="caption" color="textSecondary" style={styles.aviso}>
          {/* Se distingue a proposito. "No hay ruta" y "no pudimos calcularla"
              llevan al conductor a decisiones distintas: en el primer caso el
              servicio es raro y conviene mirarlo, en el segundo el problema es
              nuestro y las direcciones de la tarjeta siguen siendo validas. */}
          {estado.kind === 'sin-ruta'
            ? 'No encontramos una ruta entre esos dos puntos.'
            : 'No pudimos dibujar la ruta. Las direcciones de arriba siguen siendo correctas.'}
        </Text>
      </View>
    );
  }

  const todos = [...estado.principal, ...estado.contexto.flat()];
  const region = regionContaining(todos);

  if (region === null) {
    return null;
  }

  const rutas: MapRoute[] = [
    // Las de contexto van primero para que la nueva quede encima. Donde se
    // solapan, que es justo lo que el conductor busca, gana la que decide.
    //
    // EL COLOR COSTO UN INTENTO. El primero fue `textTertiary`, por ser el tono
    // mas apagado del tema y parecer lo apropiado para algo secundario. Sobre el
    // mapa no se veia en absoluto: ese gris esta pensado para texto sobre fondo
    // blanco, y el mapa ya es gris claro. La captura parecia demostrar que las
    // rutas en curso no llegaban, cuando llegaban perfectamente.
    //
    // `textPrimary` si contrasta, y ademas sirve en los dos temas por
    // definicion: es el color con el que se lee todo lo demas. La jerarquia la
    // marca el grosor y no la palidez: lo que ya esta comprometido va fino, y lo
    // que se esta decidiendo va mas grueso y en color de marca.
    ...estado.contexto.map((coords) => ({
      coordinates: coords,
      color: colors.textPrimary,
      width: 4,
    })),
    { coordinates: estado.principal, color: colors.brand, width: 5 },
  ];

  const primero = estado.principal[0];
  const ultimo = estado.principal[estado.principal.length - 1];

  const marcas: MapMarker[] = [];
  if (primero !== undefined) {
    marcas.push({ coordinate: primero, color: colors.brand, filled: false });
  }
  if (ultimo !== undefined) {
    marcas.push({ coordinate: ultimo, color: colors.brand, filled: true });
  }

  return (
    <>
      <View style={[styles.marco, { height }]}>
        <Map
          initialRegion={region}
          userCoords={null}
          showUser={false}
          interactive={false}
          routes={rutas}
          markers={marcas}
        />
      </View>

      {estado.contextoPerdido > 0 && (
        <Text variant="caption" color="textSecondary" style={styles.incompleto}>
          {estado.contextoPerdido === 1
            ? 'No pudimos dibujar tu servicio en curso, así que no aparece en el mapa.'
            : `No pudimos dibujar ${estado.contextoPerdido} de tus servicios en curso, así que no aparecen en el mapa.`}
        </Text>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  aviso: {
    paddingHorizontal: spacing.md,
    textAlign: 'center',
  },
  incompleto: {
    marginTop: spacing.xs,
  },
  marco: {
    alignItems: 'center',
    borderRadius: radius.md,
    justifyContent: 'center',
    marginTop: spacing.md,
    overflow: 'hidden',
  },
});
