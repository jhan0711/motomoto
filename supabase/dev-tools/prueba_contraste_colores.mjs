// =============================================================================
// HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
// =============================================================================
//
// Prueba de la Fase 22, paso 5: contraste de los colores de estado (hallazgo
// H14). Lee los tokens reales de `src/theme/colors.ts` y comprueba que cada
// combinacion que se pinta llega a su umbral WCAG.
//
//   node supabase/dev-tools/prueba_contraste_colores.mjs
//
// NO ES SQL: es el sistema de diseño, no la base de datos. Existe para que un
// retoque futuro de la paleta que baje un par por debajo del minimo se note.
//
// LOS UMBRALES, y por que cada uno:
//   - 4,5:1 para TEXTO (`dangerText`, `onDangerSubtle`): WCAG 1.4.3, texto normal.
//   - 3,0:1 para GRAFICO CON SIGNIFICADO (los iconos de estado, las estrellas):
//     WCAG 1.4.11. El color del estado vive en el icono desde D202, nunca en el
//     texto, asi que este es el umbral que aplica de verdad.
// =============================================================================

import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, resolve } from 'node:path';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const { lightColors, darkColors } = await import(
  pathToFileURL(resolve(raiz, 'src/theme/colors.ts')).href
);

// --- Contraste WCAG 2.x -------------------------------------------------------

function canal(v) {
  const c = v / 255;
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function luminancia(hex) {
  const h = hex.replace('#', '');
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
  return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b);
}

function contraste(a, b) {
  const l1 = luminancia(a);
  const l2 = luminancia(b);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

// --- Que se comprueba -------------------------------------------------------
//
// Cada entrada: [primerPlano, fondo, umbral, descripcion]. Las superficies son
// las que de verdad hay debajo de cada cosa: `background` (la pantalla) y
// `surface` (una tarjeta). `surfaceSubtle` se deja fuera a proposito: ningun
// icono de estado se pinta encima de ella.

const paresTexto = (T) => [
  ['dangerText', 'background', 4.5, 'texto de error de campo, sobre la pantalla'],
  ['dangerText', 'surface', 4.5, 'texto de error de campo, sobre una tarjeta'],
  ['onDangerSubtle', 'dangerSubtle', 4.5, 'texto del aviso de error, sobre el fondo teñido'],
  ['onDangerSubtle', 'surface', 4.5, 'texto del aviso de error, sobre una tarjeta (fare-row)'],
];

const paresGrafico = (T) => [
  ['success', 'background', 3.0, 'icono de exito sobre la pantalla'],
  ['success', 'surface', 3.0, 'icono de exito sobre una tarjeta'],
  ['warning', 'background', 3.0, 'estrella de calificacion sobre la pantalla'],
  ['warning', 'surface', 3.0, 'estrella de calificacion sobre una tarjeta'],
  ['info', 'background', 3.0, 'icono de informacion sobre la pantalla'],
  ['info', 'surface', 3.0, 'icono de informacion sobre una tarjeta'],
  ['danger', 'background', 3.0, 'icono de error de campo sobre la pantalla'],
  ['danger', 'surface', 3.0, 'icono de error de campo sobre una tarjeta'],
  ['onSuccess', 'success', 3.0, 'la palomita sobre el relleno verde'],
  ['onWarning', 'warning', 3.0, 'contenido sobre el relleno de aviso'],
  ['onInfo', 'info', 3.0, 'contenido sobre el relleno de informacion'],
];

const resultados = [];
let n = 0;

for (const [tema, T] of [
  ['claro', lightColors],
  ['oscuro', darkColors],
]) {
  for (const [fg, bg, umbral, desc] of [...paresTexto(T), ...paresGrafico(T)]) {
    n += 1;
    const ratio = contraste(T[fg], T[bg]);
    resultados.push({
      n,
      ok: ratio >= umbral,
      texto: `[${tema}] ${fg} sobre ${bg} (${desc})`,
      detalle: `${ratio.toFixed(2)}:1, minimo ${umbral}`,
    });
  }
}

let fallando = 0;
for (const r of resultados) {
  if (!r.ok) fallando += 1;
  console.log(`${r.n}\t${r.ok ? 'OK  ' : 'FALLA'}\t${r.texto}\t${r.detalle}`);
}
console.log(
  `999\t${fallando === 0 ? 'OK  ' : 'FALLA'}\tTOTAL\t${resultados.length} comprobaciones, ${fallando} fallando`,
);
process.exit(fallando === 0 ? 0 : 1);
