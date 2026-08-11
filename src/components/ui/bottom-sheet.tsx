/* eslint-disable react-hooks/immutability --
 * The React Compiler treats any value handed to a hook as immutable. Reanimated
 * shared values are handed to `useAnimatedStyle` and `useAnimatedReaction`, and
 * are then written from worklets, which is their entire reason to exist.
 *
 * The two tools disagree by design, and no restructuring resolves it: rendering
 * an animated position requires passing the shared value to a hook, and driving
 * a gesture requires writing to it.
 *
 * Scope is deliberately narrow: this file only, this rule only. Everywhere else
 * in the project the rule stays on.
 */
import type { ReactNode } from 'react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Keyboard,
  StyleSheet,
  useWindowDimensions,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedReaction,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { MAX_CONTENT_WIDTH, radius, shadows, spacing, useTheme } from '@/theme';

/**
 * Una altura de reposo de la hoja.
 *
 * Un numero es una fraccion de la pantalla: `0.3` es el treinta por ciento.
 *
 * `'content'` es la altura que pide lo que hay dentro, medida al vuelo. Existe
 * porque las fracciones no saben nada del contenido: el mismo `0.3` da 240 dp en
 * la tablet y 274 dp en el telefono, mientras que un panel de confirmacion
 * necesita los que necesita. Con fracciones, o sobra sitio en un aparato o se
 * corta el boton en el otro, y la unica forma de acertar es ir probando numeros
 * en cada pantalla nueva.
 */
export type SnapPoint = number | 'content';

export interface BottomSheetProps {
  children: ReactNode;
  /**
   * Alturas de reposo, de menor a mayor. `[0.09, 'content']` es una hoja que se
   * puede bajar hasta dejar solo el asa y que en reposo mide lo que mide su
   * contenido.
   */
  snapPoints?: readonly SnapPoint[];
  /** Index of the active snap point. Controlled by the parent. */
  index?: number;
  onIndexChange?: (index: number) => void;
  /** Content pinned above the scrollable area, such as a title. */
  header?: ReactNode;
  style?: StyleProp<ViewStyle>;
}

const DEFAULT_SNAP_POINTS: readonly SnapPoint[] = [0.28, 0.68];

/**
 * Alto del asa con su espacio: `paddingTop` + la barra + `paddingBottom`.
 *
 * Se suma a mano al medir el contenido porque el asa vive fuera del bloque que
 * se mide, y sin ella la hoja se quedaria corta justo por esos pixeles.
 */
const GRABBER_BLOCK = spacing.md + 4 + spacing.sm;

/** Techo de seguridad: la hoja nunca se come la pantalla entera. */
const MAX_CONTENT_FRACTION = 0.85;

/** Tuned for a sheet that feels responsive without overshooting. */
const SPRING_CONFIG = {
  damping: 45,
  stiffness: 320,
  mass: 0.9,
} as const;

/**
 * Panel that slides up from the bottom of the screen.
 *
 * This is the primary surface of the passenger experience: choosing a
 * destination, confirming a ride, watching the driver approach. The map stays
 * visible and interactive behind it, which is why this is not a modal.
 *
 * Built on Reanimated and Gesture Handler instead of a third-party sheet
 * library. Both are already project dependencies, the gesture runs entirely on
 * the UI thread, and the component keeps working when the map behind it is
 * being panned.
 *
 * Deliberately out of scope: scrollable lists nested inside the sheet. That is
 * the genuinely hard part of a bottom sheet and nothing in the MVP needs it.
 * If that changes, the implementation swaps out behind this same API.
 */
export function BottomSheet({
  children,
  snapPoints = DEFAULT_SNAP_POINTS,
  index = 0,
  onIndexChange,
  header,
  style,
}: BottomSheetProps) {
  const { colors } = useTheme();
  const { height: screenHeight } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  /**
   * Height of the on-screen keyboard, or 0 when it is closed.
   *
   * This has to be tracked by hand. The manifest asks for `adjustResize`, which
   * used to shrink the window and would have solved this for free, but Android
   * ignores it once the app draws edge to edge, which Expo does by default from
   * SDK 54 on. The window keeps its full height and the keyboard is painted over
   * it, so a sheet anchored to the bottom edge ends up behind the keys.
   *
   * Screens whose content starts at the top never noticed. This one is anchored
   * to the bottom, which is exactly where the keyboard appears.
   */
  const [keyboardHeight, setKeyboardHeight] = useState(0);

  useEffect(() => {
    // 'Did' and not 'Will': Android does not fire the 'Will' variants.
    const shown = Keyboard.addListener('keyboardDidShow', (event) => {
      setKeyboardHeight(event.endCoordinates.height);
    });
    const hidden = Keyboard.addListener('keyboardDidHide', () => {
      setKeyboardHeight(0);
    });

    return () => {
      shown.remove();
      hidden.remove();
    };
  }, []);

  const isKeyboardVisible = keyboardHeight > 0;

  /**
   * Alto natural de la cabecera mas el contenido, medido cuando se dibuja.
   *
   * Empieza en cero y en el primer dibujado la hoja usa el techo de seguridad.
   * Dura un fotograma y nadie lo ve, pero es la razon de que este valor no
   * pueda ser un `useMemo`: no se sabe hasta que el sistema mide.
   */
  const [naturalHeight, setNaturalHeight] = useState(0);

  const medir = useCallback((height: number) => {
    // Redondear no bastaba, y costo un video del usuario descubrirlo.
    //
    // La idea era que una diferencia de medio pixel no provocara un render nuevo.
    // Pero redondear solo estabiliza una medida estable: si el sistema mide algo
    // que cae cerca de un valor y medio, por ejemplo 316,49 y 316,51, el redondeo
    // devuelve 316 y 317 alternativamente. La hoja cambia de alto un pixel, el
    // contenido se vuelve a medir, y la pantalla TIEMBLA.
    //
    // Se ve poco y se nota mucho: el panel del resumen saltaba arriba y abajo
    // una vez por segundo. Al medirlo entre dos fotogramas del video, todo el
    // bloque, de y=640 a y=959, se redibujaba desplazado un pixel.
    //
    // Con una tolerancia de dos pixeles, una oscilacion asi se ignora y un cambio
    // de verdad, que al anadir o quitar una fila son decenas de pixeles, sigue
    // pasando.
    setNaturalHeight((anterior) =>
      Math.abs(anterior - height) < 2 ? anterior : Math.round(height),
    );
  }, []);

  /** Cada punto de anclaje resuelto a pixeles, de menor a mayor. */
  const heights = useMemo(() => {
    const techo = screenHeight * MAX_CONTENT_FRACTION;

    return snapPoints
      .map((point) => {
        if (point !== 'content') return screenHeight * point;
        // Antes de la primera medida no hay nada que ajustar: se usa el techo,
        // que es preferible a una hoja de altura cero.
        if (naturalHeight === 0) return techo;
        return Math.min(naturalHeight + GRABBER_BLOCK + insets.bottom, techo);
      })
      .sort((a, b) => a - b);
  }, [snapPoints, screenHeight, naturalHeight, insets.bottom]);

  /** The sheet is always as tall as its largest snap point. */
  const sheetHeight = heights[heights.length - 1] ?? screenHeight * 0.7;

  /**
   * How tall the sheet actually is right now.
   *
   * Closed keyboard: always its full height, with `translateY` deciding how much
   * of it shows. Open keyboard: exactly as much as the active snap point was
   * already showing, lifted to rest on the keys.
   *
   * Sizing it to the largest snap point instead was the obvious move and looked
   * wrong: on a tablet the sheet swallowed the screen and left a slab of empty
   * white under three controls. Keeping the height the passenger already sees
   * means the sheet rises without changing size, and the map stays visible.
   *
   * The cap is still needed for a small screen with a large keyboard, where even
   * that height would push the header off the top.
   */
  const activeSnapHeight = heights[index] ?? heights[0] ?? screenHeight * 0.3;
  const visibleHeight = isKeyboardVisible
    ? Math.min(activeSnapHeight, screenHeight - keyboardHeight - insets.top)
    : sheetHeight;

  /**
   * Vertical offsets, in pixels, for each snap point. Offset 0 means fully
   * expanded; larger values push the sheet further down.
   */
  const offsets = useMemo(
    () => heights.map((height) => sheetHeight - height),
    [heights, sheetHeight],
  );

  const collapsedOffset = offsets[0] ?? 0;
  const translateY = useSharedValue(collapsedOffset);
  const dragStart = useSharedValue(0);
  const targetOffset = useSharedValue(collapsedOffset);

  // Two shared values instead of one, on purpose.
  //
  // `translateY` is the live position and is written only from worklets: the
  // pan gesture and the reaction below. `targetOffset` is the position React
  // asks for and is written only from this effect.
  //
  // Keeping them separate is what lets the controlled `index` prop coexist with
  // dragging. Writing to `translateY` from both React and the gesture is also
  // what the react-hooks/immutability rule forbids, and it is right to: a value
  // driven from two places is a race waiting to happen.
  useEffect(() => {
    // With the keyboard open the sheet goes fully up. Anything else would leave
    // the passenger typing into a field they cannot see.
    targetOffset.value = isKeyboardVisible ? 0 : (offsets[index] ?? collapsedOffset);
  }, [index, offsets, collapsedOffset, targetOffset, isKeyboardVisible]);

  useAnimatedReaction(
    () => targetOffset.value,
    (next, previous) => {
      if (next !== previous) {
        translateY.value = withSpring(next, SPRING_CONFIG);
      }
    },
  );

  const notifyIndexChange = useCallback(
    (nextIndex: number) => {
      if (nextIndex !== index) {
        onIndexChange?.(nextIndex);
      }
    },
    [index, onIndexChange],
  );

  const maxOffset = offsets[0] ?? 0;

  // Deliberately not wrapped in useMemo. The React Compiler is enabled for this
  // project and memoizes it automatically, and wrapping it manually trips the
  // react-hooks/immutability rule: a useMemo body must be pure, and these
  // callbacks write to shared values.
  const panGesture = Gesture.Pan()
    // Dragging is disabled while typing. The snap offsets are computed from the
    // sheet's normal height, which is not the height it has right now, so a drag
    // would land somewhere that does not correspond to any snap point.
    .enabled(!isKeyboardVisible)
    .onStart(() => {
      dragStart.value = translateY.value;
    })
    .onUpdate((event) => {
      const next = dragStart.value + event.translationY;
      // Clamp between fully expanded and the lowest snap point, so the sheet
      // can never be dragged off-screen or above its own height.
      translateY.value = Math.min(Math.max(next, 0), maxOffset);
    })
    .onEnd((event) => {
      // Project where the drag would land, so a flick reaches the next snap
      // point instead of falling back to the nearest one.
      const projected = translateY.value + event.velocityY * 0.12;

      let closestIndex = 0;
      let smallestDistance = Number.POSITIVE_INFINITY;

      for (let i = 0; i < offsets.length; i += 1) {
        const offset = offsets[i] ?? 0;
        const distance = Math.abs(projected - offset);
        if (distance < smallestDistance) {
          smallestDistance = distance;
          closestIndex = i;
        }
      }

      translateY.value = withSpring(offsets[closestIndex] ?? 0, SPRING_CONFIG);
      runOnJS(notifyIndexChange)(closestIndex);
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View
        style={[
          styles.sheet,
          shadows.lg,
          {
            backgroundColor: colors.surface,
            // Sits on top of the keyboard instead of behind it.
            bottom: keyboardHeight,
            borderTopLeftRadius: radius.xxl,
            borderTopRightRadius: radius.xxl,
            height: visibleHeight,
            // The gesture bar inset only applies when nothing else is down there.
            paddingBottom: isKeyboardVisible ? spacing.sm : insets.bottom,
          },
          animatedStyle,
          style,
        ]}
      >
        <View style={styles.grabberArea}>
          <View style={[styles.grabber, { backgroundColor: colors.border }]} />
        </View>

        {/* The sheet surface spans the full width, because it is anchored to the
            bottom edge of the display. Its contents do not: on a tablet an
            800dp-wide row of controls is as unusable inside a sheet as anywhere
            else. */}
        <View style={styles.inner}>
          {/* Este bloque es el que se mide, y por eso NO se estira. Con `flex: 1`
              siempre reportaria el alto de la hoja en vez del que pide su
              contenido, que es justo el dato que hace falta para 'content'. */}
          <View onLayout={(event) => medir(event.nativeEvent.layout.height)}>
            {header !== undefined && <View style={styles.header}>{header}</View>}

            <View style={styles.content}>{children}</View>
          </View>
        </View>
      </Animated.View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  content: {
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  grabber: {
    borderRadius: radius.full,
    height: 4,
    width: 40,
  },
  grabberArea: {
    alignItems: 'center',
    // A generous target: the grabber is the affordance users aim for.
    paddingBottom: spacing.sm,
    paddingTop: spacing.md,
  },
  header: {
    paddingBottom: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  inner: {
    alignSelf: 'center',
    flex: 1,
    maxWidth: MAX_CONTENT_WIDTH,
    width: '100%',
  },
  sheet: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
  },
});
