// =============================================================================
// Genera el "feature graphic" de Google Play (1024 x 500). Fase 26 paso 7.
//
//   node assets/brand/feature-graphic.mjs
//
// Sale en `assets/store/feature-graphic.png`. La marca viene de
// `assets/brand/logo.svg` (misma que el icono). Texto con fuente del sistema.
// =============================================================================

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const AQUI = dirname(fileURLToPath(import.meta.url));
const SALIDA = resolve(AQUI, '../store');

const W = 1024;
const H = 500;
const FONDO = '#2a323c';
const ACENTO = '#ca852d';

// La marca sola, sin el fondo del calco (dos formas con fill="#2a323c").
const svgMarca = readFileSync(resolve(AQUI, 'logo.svg'), 'utf8').replace(
  /<(rect|path)\b[^>]*fill="#2a323c"[^>]*\/>/gi,
  '',
);

// Se rasteriza la marca a un PNG cuadrado y se incrusta como data URI: mas
// simple que componer dos SVG con distinta escala.
const marcaPng = new Resvg(svgMarca, {
  fitTo: { mode: 'width', value: 512 },
  background: 'rgba(0,0,0,0)',
})
  .render()
  .asPng();
const marcaB64 = marcaPng.toString('base64');

const MARCA = 360; // alto/ancho de la marca en el lienzo
const MARCA_X = 96;
const MARCA_Y = (H - MARCA) / 2;
const TEXTO_X = MARCA_X + MARCA + 64;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="${FONDO}"/>
  <image x="${MARCA_X}" y="${MARCA_Y}" width="${MARCA}" height="${MARCA}"
         href="data:image/png;base64,${marcaB64}"/>
  <text x="${TEXTO_X}" y="238" font-family="Arial, Helvetica, sans-serif"
        font-size="76" font-weight="700" fill="#ffffff">AmalfiGoApp</text>
  <text x="${TEXTO_X}" y="296" font-family="Arial, Helvetica, sans-serif"
        font-size="34" font-weight="400" fill="${ACENTO}">Muévete fácil, llega seguro.</text>
</svg>`;

const png = new Resvg(svg, {
  fitTo: { mode: 'width', value: W },
  font: { loadSystemFonts: true },
})
  .render()
  .asPng();

mkdirSync(SALIDA, { recursive: true });
writeFileSync(resolve(SALIDA, 'feature-graphic.png'), png);
console.log(`feature-graphic.png  ${W}x${H}  ${(png.length / 1024).toFixed(0)} kB`);
