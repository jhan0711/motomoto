/**
 * Color tokens.
 *
 * The `palette` object below is the ONLY place in the app where a literal color
 * value may appear. Everything else consumes the semantic names exported from
 * `lightColors` / `darkColors`.
 *
 * Why: a component that hardcodes '#F27127' cannot be re-themed, cannot support
 * dark mode, and cannot be audited for contrast. A component that uses
 * `colors.brand` gets all three for free.
 */

/** Raw palette. Not consumed directly by components. */
const palette = {
  // Brand: amber orange. Chosen for visibility over map tiles, which are
  // predominantly gray, green and blue. No map surface uses orange.
  brand50: '#FEF3EC',
  brand100: '#FDE3D1',
  brand200: '#FAC5A3',
  brand300: '#F7A575',
  brand400: '#F58B4E',
  brand500: '#F27127',
  brand600: '#D95A16',
  brand700: '#B4470F',
  brand800: '#8F380C',
  brand900: '#6B2A09',

  // Neutrals. Carry most of the interface.
  white: '#FFFFFF',
  neutral50: '#FAFAFA',
  neutral100: '#F4F4F5',
  neutral200: '#E4E4E7',
  neutral300: '#D4D4D8',
  neutral400: '#A1A1AA',
  neutral500: '#71717A',
  neutral600: '#52525B',
  neutral700: '#3F3F46',
  neutral800: '#27272A',
  neutral900: '#18181B',
  black: '#000000',

  // Feedback
  success500: '#0E9F6E',
  success600: '#0B7F58',
  success100: '#D7F5E9',

  warning500: '#F59E0B',
  warning600: '#C77C05',
  // El 700 es el que hace legible el icono de aviso -las estrellas- sobre fondo
  // claro: el 500 se queda en 2,15:1 sobre blanco, por debajo del 3:1 que exige
  // un grafico con significado (hallazgo H14, cerrado en la Fase 22).
  warning700: '#BE7004',
  warning100: '#FDF0D5',

  // El rojo tiene mas escalones que sus hermanos porque es el unico que se usa
  // como texto sobre un fondo teñido, y ahi el 500 no da contraste suficiente ni
  // en claro ni en oscuro (hallazgo H14). El 300 y el 900 son los que hacen
  // legible el aviso de error en el tema oscuro.
  danger300: '#FCA5A5',
  danger500: '#DC2626',
  danger600: '#B01B1B',
  danger900: '#3A1010',
  danger100: '#FBDDDD',

  // El 400 es el escalon claro para el tema oscuro, mismo criterio que `brand400`:
  // el 500 sobre la superficie oscura da 2,88:1, por debajo del 3:1 de un icono
  // con significado (hallazgo H14, cerrado en la Fase 22).
  info400: '#60A5FA',
  info500: '#2563EB',
  info600: '#1D4FD1',
  info100: '#DBE6FD',

  // Scrims. Alpha values are intentional: overlays must let the map show through.
  overlayLight: 'rgba(0, 0, 0, 0.45)',
  overlayDark: 'rgba(0, 0, 0, 0.65)',
} as const;

/**
 * Semantic color contract. Both themes must implement every key, so a screen
 * built against this type is guaranteed to render in light and dark mode.
 */
export interface ThemeColors {
  /** Screen background. */
  background: string;
  /** Cards, sheets, anything sitting on top of the background. */
  surface: string;
  /** A surface that needs to read as raised without a shadow. */
  surfaceSubtle: string;
  /** Pressed state for surfaces. */
  surfacePressed: string;

  /** Hairline dividers and input outlines. */
  border: string;
  /** Borders that need to be noticed, such as a focused input. */
  borderStrong: string;

  /** Body copy and headings. */
  textPrimary: string;
  /** Supporting copy, labels, metadata. */
  textSecondary: string;
  /** Placeholders and disabled text. */
  textTertiary: string;
  /** Text placed on a dark or brand-filled surface. */
  textInverse: string;

  /** Brand fill. Markers, routes, active states. */
  brand: string;
  /** Darker brand, for text and borders that need contrast on light surfaces. */
  brandStrong: string;
  /** Tinted background for brand-flavored containers. */
  brandSubtle: string;
  /** Text and icons placed on top of `brand`. */
  onBrand: string;

  /** Primary action fill. Near-black, per the Phase 0 visual direction. */
  action: string;
  /** Primary action pressed state. */
  actionPressed: string;
  /** Primary action when disabled. */
  actionDisabled: string;
  /** Text and icons placed on top of `action`. */
  onAction: string;

  success: string;
  successSubtle: string;
  onSuccess: string;

  warning: string;
  warningSubtle: string;
  onWarning: string;

  danger: string;
  dangerSubtle: string;
  /**
   * Texto de error sobre una superficie normal, no sobre el fondo teñido: el
   * mensaje que cuelga de un campo de formulario.
   *
   * Separado de `danger` porque ese, sobre `surface` en el tema oscuro, da
   * 3,08:1 —por debajo del 4,5:1 que exige un texto (hallazgo H14)—. En claro
   * es un rojo mas oscuro que `danger`; en oscuro, uno mas claro.
   */
  dangerText: string;
  /** Contenido sobre `danger` en solido: el texto de un boton destructivo. */
  onDanger: string;
  /**
   * Contenido sobre `dangerSubtle`: el texto y el icono de un aviso de error.
   *
   * Existe porque `danger` hacia dos trabajos incompatibles. Servia de fondo de
   * boton y a la vez de color de texto sobre el fondo teñido, y un mismo tono no
   * puede cumplir las dos cosas: en el tema oscuro daba un contraste de 1,44:1,
   * es decir, un mensaje de error que no se podia leer (H14).
   */
  onDangerSubtle: string;

  info: string;
  infoSubtle: string;
  onInfo: string;

  /** Dimming layer behind modals and sheets. */
  overlay: string;
  /** Base color for skeleton loaders. */
  skeleton: string;
  /** Highlight sweep for skeleton loaders. */
  skeletonHighlight: string;
}

export const lightColors: ThemeColors = {
  background: palette.white,
  surface: palette.white,
  surfaceSubtle: palette.neutral50,
  surfacePressed: palette.neutral100,

  border: palette.neutral200,
  borderStrong: palette.neutral400,

  textPrimary: palette.neutral900,
  textSecondary: palette.neutral600,
  textTertiary: palette.neutral400,
  textInverse: palette.white,

  brand: palette.brand500,
  brandStrong: palette.brand700,
  brandSubtle: palette.brand50,
  onBrand: palette.white,

  action: palette.neutral900,
  actionPressed: palette.neutral700,
  actionDisabled: palette.neutral300,
  onAction: palette.white,

  success: palette.success500,
  successSubtle: palette.success100,
  onSuccess: palette.white,

  warning: palette.warning700,
  warningSubtle: palette.warning100,
  onWarning: palette.neutral900,

  danger: palette.danger500,
  dangerSubtle: palette.danger100,
  dangerText: palette.danger600,
  onDanger: palette.white,
  // Un escalon mas oscuro que `danger` a proposito: sobre el rosa palido, el 500
  // se queda en 3,79:1 y el 600 sube a 5,46:1.
  onDangerSubtle: palette.danger600,

  info: palette.info500,
  infoSubtle: palette.info100,
  onInfo: palette.white,

  overlay: palette.overlayLight,
  skeleton: palette.neutral200,
  skeletonHighlight: palette.neutral100,
};

export const darkColors: ThemeColors = {
  background: palette.neutral900,
  surface: palette.neutral800,
  surfaceSubtle: palette.neutral700,
  surfacePressed: palette.neutral600,

  border: palette.neutral700,
  borderStrong: palette.neutral500,

  textPrimary: palette.neutral50,
  textSecondary: palette.neutral400,
  textTertiary: palette.neutral500,
  textInverse: palette.neutral900,

  // Lighter brand step in dark mode: brand500 on a near-black surface reads as
  // muddy, while brand400 keeps the same hue and stays legible.
  brand: palette.brand400,
  brandStrong: palette.brand300,
  brandSubtle: palette.brand900,
  onBrand: palette.neutral900,

  // The primary action inverts in dark mode: a near-black button would vanish
  // into a near-black background.
  action: palette.white,
  actionPressed: palette.neutral200,
  actionDisabled: palette.neutral600,
  onAction: palette.neutral900,

  success: palette.success500,
  successSubtle: palette.success600,
  onSuccess: palette.white,

  warning: palette.warning500,
  warningSubtle: palette.warning600,
  onWarning: palette.neutral900,

  danger: palette.danger500,
  // Mismo criterio que `brandSubtle` unas lineas mas arriba, que si se hizo asi
  // en la Fase 3: en un tema oscuro el fondo teñido tiene que ser el escalon
  // hondo, no uno intermedio. Con el 600 el aviso quedaba en 1,44:1.
  dangerSubtle: palette.danger900,
  dangerText: palette.danger300,
  onDanger: palette.white,
  onDangerSubtle: palette.danger300,

  info: palette.info400,
  infoSubtle: palette.info600,
  // Mismo criterio que `onWarning`: con `info` claro en el tema oscuro, el
  // contenido encima tiene que ser oscuro. Blanco sobre `info400` da 2,54:1.
  onInfo: palette.neutral900,

  overlay: palette.overlayDark,
  skeleton: palette.neutral700,
  skeletonHighlight: palette.neutral600,
};
