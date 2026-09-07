// =============================================================================
// Genera el icono de la ficha de Google Play (512 x 512, PNG de 32 bits, opaco).
// Fase 26, paso 7.
//
//   node assets/brand/play-icon.mjs
//
// Sale en `assets/store/play-icon.png`. Play exige EXACTAMENTE 512x512 y
// cuadrado; `assets/images/icon.png` sale 1024x1020 del calco del logo y no
// sirve. La marca viene de `assets/brand/logo.svg` (la misma del icono de la
// app y del feature graphic) y va centrada sobre el fondo de marca `#2a323c`,
// igual que el icono adaptativo de Android (`adaptiveIcon.backgroundColor`).
// =============================================================================

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const AQUI = dirname(fileURLToPath(import.meta.url));
const SALIDA = resolve(AQUI, '../store');

const LADO = 512;
const FONDO = '#2a323c';
// La marca ocupa el 68 % del lienzo: deja aire alrededor como el icono
// adaptativo, sin que se coma los bordes que Play recorta con esquinas.
const MARCA = Math.round(LADO * 0.68);
const OFFSET = Math.round((LADO - MARCA) / 2);

// La marca sola, sin el fondo del calco (dos formas con fill="#2a323c").
const svgMarca = readFileSync(resolve(AQUI, 'logo.svg'), 'utf8').replace(
  /<(rect|path)\b[^>]*fill="#2a323c"[^>]*\/>/gi,
  '',
);

const marcaB64 = new Resvg(svgMarca, {
  fitTo: { mode: 'width', value: MARCA },
  background: 'rgba(0,0,0,0)',
})
  .render()
  .asPng()
  .toString('base64');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${LADO}" height="${LADO}" viewBox="0 0 ${LADO} ${LADO}">
  <rect width="${LADO}" height="${LADO}" fill="${FONDO}"/>
  <image x="${OFFSET}" y="${OFFSET}" width="${MARCA}" height="${MARCA}"
         href="data:image/png;base64,${marcaB64}"/>
</svg>`;

const png = new Resvg(svg, { fitTo: { mode: 'width', value: LADO } }).render().asPng();

mkdirSync(SALIDA, { recursive: true });
writeFileSync(resolve(SALIDA, 'play-icon.png'), png);
console.log(`play-icon.png  ${LADO}x${LADO}  ${(png.length / 1024).toFixed(0)} kB`);
