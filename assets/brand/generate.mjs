// =============================================================================
// Genera los PNG de icono y splash desde el logo en SVG. Fase 25, paso 3.
//
//   node assets/brand/generate.mjs
//
// La fuente es `assets/brand/logo.svg` -el que envio el usuario, un calco
// automatico con 183 trazos y un `<rect>` de fondo `#2a323c`-. De ahi salen:
//
//   assets/images/icon.png                       1024, logo entero sobre su fondo
//   assets/images/ios-icon.png                   1024x1024 cuadrado, RGB sin alfa (App Store)
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
import { crc32, deflateSync } from 'node:zlib';
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

/**
 * El icono de iOS: el logo entero sobre su fondo, CUADRADO y SIN canal alfa.
 *
 * App Store Connect rechaza un icono de 1024 con canal alfa o que no sea
 * cuadrado. `icon.png` no cumple ninguna de las dos -sale de `png(svgEntero)`
 * con ancho fijo, asi que mide 1024x1020 por la proporcion del SVG, y trae RGBA-.
 * Aqui se compone sobre un lienzo cuadrado del color del fondo y se codifica
 * como RGB. iOS recorta las esquinas solo: el fondo va a sangre, sin margen.
 */
function pngSinAlfa(rgba, ancho, alto) {
  const fila = ancho * 3 + 1;
  const datos = Buffer.alloc(fila * alto); // el primer byte de cada fila (filtro 0) queda en 0
  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < ancho; x++) {
      const origen = (y * ancho + x) * 4;
      const destino = y * fila + 1 + x * 3;
      datos[destino] = rgba[origen];
      datos[destino + 1] = rgba[origen + 1];
      datos[destino + 2] = rgba[origen + 2];
    }
  }
  const bloque = (tipo, contenido) => {
    const t = Buffer.from(tipo, 'ascii');
    const largo = Buffer.alloc(4);
    largo.writeUInt32BE(contenido.length);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([t, contenido])) >>> 0);
    return Buffer.concat([largo, t, contenido, crc]);
  };
  const cabecera = Buffer.alloc(13);
  cabecera.writeUInt32BE(ancho, 0);
  cabecera.writeUInt32BE(alto, 4);
  cabecera[8] = 8; // 8 bits por canal
  cabecera[9] = 2; // color verdadero RGB, sin alfa
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    bloque('IHDR', cabecera),
    bloque('IDAT', deflateSync(datos)),
    bloque('IEND', Buffer.alloc(0)),
  ]);
}

function iconoIos() {
  const entero = png(svgEntero, 1024);
  const alto = Math.round((1024 * 1996) / 2003); // lo que mide `entero`
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    <rect width="1024" height="1024" fill="${FONDO}"/>
    <image x="0" y="${Math.round((1024 - alto) / 2)}" width="1024" height="${alto}" href="data:image/png;base64,${entero.toString('base64')}"/>
  </svg>`;
  const r = new Resvg(svg, { fitTo: { mode: 'width', value: 1024 }, background: FONDO }).render();
  return pngSinAlfa(r.pixels, r.width, r.height);
}

const marca1024 = png(svgMarca, 1024);
const mono1024 = png(svgMono, 1024);

const salidas = {
  // Icono principal: el logo entero sobre su fondo, sin recortar.
  'icon.png': png(svgEntero, 1024),
  // iOS: cuadrado y sin alfa (ver `iconoIos`).
  'ios-icon.png': iconoIos(),
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
