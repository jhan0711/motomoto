// =============================================================================
// Genera los PNG de icono y splash desde el logo en SVG. Fase 25, paso 3.
//
//   node assets/brand/generate.mjs
//
// La fuente es `assets/brand/logo.svg` -el que envio el usuario, un calco
// automatico con 183 trazos y un `<rect>` de fondo `#2a323c`-. De ahi salen:
//
//   assets/images/icon.png                       1024, logo entero sobre su fondo
//   assets/images/android-icon-foreground.png    1024, solo la marca, centrada
//                                                en la zona segura, fondo transparente
//   assets/images/android-icon-monochrome.png    1024, la marca en blanco plano
//   assets/images/splash-icon.png                1024, solo la marca, transparente
//   assets/images/favicon.png                    48,  la marca, para web
//
// El fondo del icono adaptativo de Android NO es una imagen: es el color
// `#2a323c` en `app.config.ts` (`adaptiveIcon.backgroundColor`).
// =============================================================================

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const AQUI = dirname(fileURLToPath(import.meta.url));
const IMAGES = resolve(AQUI, '../images');

const FONDO = '#2a323c';
const svgEntero = readFileSync(resolve(AQUI, 'logo.svg'), 'utf8');

// La marca sola: se quita el fondo. El calco automatico lo dejo DOS veces, un
// `<rect>` y un `<path>` que traza el lienzo entero, los dos con `fill="#2a323c"`
// -que es el unico color que usa el fondo-.
const svgMarca = svgEntero.replace(/<(rect|path)\b[^>]*fill="#2a323c"[^>]*\/>/gi, '');

// La marca en blanco plano, para el icono monocromo (iconos con tema de Android
// 13+). Se pintan de blanco todos los rellenos y trazos menos el "none".
const svgMono = svgMarca
  .replace(/fill="#(?!none)[0-9a-fA-F]{3,8}"/g, 'fill="#ffffff"')
  .replace(/stroke="#(?!none)[0-9a-fA-F]{3,8}"/g, 'stroke="#ffffff"');

/** Renderiza `svg` a PNG de `size` px. `pad` deja aire alrededor (0..1). */
function png(svg, size, { fit = 'width' } = {}) {
  const r = new Resvg(svg, {
    fitTo: { mode: fit === 'width' ? 'width' : 'height', value: size },
    background: 'rgba(0,0,0,0)',
  });
  return r.render().asPng();
}

/**
 * Centra `pngBuffer` -que ya viene cuadrado- dentro de un lienzo de `canvas` px
 * ocupando `scale` de su ancho, sobre fondo transparente o `bg`.
 *
 * Se hace componiendo dos SVG: el lienzo y la imagen embebida como data URI. Es
 * mas simple que traer otra libreria de composicion solo para esto.
 */
function enmarcar(pngBuffer, canvas, scale, bg = null) {
  const inner = Math.round(canvas * scale);
  const offset = Math.round((canvas - inner) / 2);
  const b64 = pngBuffer.toString('base64');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${canvas}" height="${canvas}" viewBox="0 0 ${canvas} ${canvas}">
    ${bg ? `<rect width="${canvas}" height="${canvas}" fill="${bg}"/>` : ''}
    <image x="${offset}" y="${offset}" width="${inner}" height="${inner}" href="data:image/png;base64,${b64}"/>
  </svg>`;
  return png(svg, canvas);
}

const marca1024 = png(svgMarca, 1024);
const mono1024 = png(svgMono, 1024);

const salidas = {
  // Icono principal: el logo entero sobre su fondo, sin recortar.
  'icon.png': png(svgEntero, 1024),
  // Android adaptativo: la marca al 62 % del lienzo (dentro de la zona segura
  // del 66 %), fondo transparente -el color lo pone app.config.ts-.
  'android-icon-foreground.png': enmarcar(marca1024, 1024, 0.62),
  // Monocromo: misma marca, blanco plano.
  'android-icon-monochrome.png': enmarcar(mono1024, 1024, 0.62),
  // Splash: la marca sola; el fondo azul lo pone el plugin de splash.
  'splash-icon.png': enmarcar(marca1024, 1024, 0.9),
  // Web.
  'favicon.png': png(svgMarca, 48),
};

for (const [nombre, buffer] of Object.entries(salidas)) {
  writeFileSync(resolve(IMAGES, nombre), buffer);
  console.log(`${nombre}\t${(buffer.length / 1024).toFixed(0)} kB`);
}

// Un PNG de fondo por si se prefiere imagen a color plano en algun sitio.
writeFileSync(
  resolve(IMAGES, 'android-icon-background.png'),
  png(
    `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="${FONDO}"/></svg>`,
    1024,
  ),
);
console.log('android-icon-background.png\t(color plano ' + FONDO + ')');
