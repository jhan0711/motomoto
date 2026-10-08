// =============================================================================
// Capturas PROVISIONALES para la ficha de App Store. iOS, Fase B.
//
//   node assets/brand/store-ios-screenshots.mjs
//
// Toma las capturas de Play (`assets/store/capturas/`, 1080x2340) y las lleva a
// 1290x2796, el tamano de iPhone de 6,9" que App Store Connect acepta como unico
// obligatorio -el resto de tamanos los escala el propio App Store-. La
// proporcion es la misma (9:19,5), asi que solo se amplian, sin recortar.
//
// SON PROVISIONALES. Salen de una tablet/emulador Android: no llevan barra de
// estado ni marco, asi que no delatan la plataforma, pero Apple prefiere
// capturas de un iPhone de verdad. Se sustituyen por las reales cuando el
// build de TestFlight (fase E) permita tomarlas.
//
// Salen en `assets/store/capturas-ios/` como PNG RGB, sin alfa.
// =============================================================================

import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { crc32, deflateSync } from 'node:zlib';
import { Resvg } from '@resvg/resvg-js';

const AQUI = dirname(fileURLToPath(import.meta.url));
const ENTRADA = resolve(AQUI, '../store/capturas');
const SALIDA = resolve(AQUI, '../store/capturas-ios');

const ANCHO = 1290;
const ALTO = 2796;

/** PNG RGB (sin alfa) desde los pixeles RGBA de resvg. */
function pngSinAlfa(rgba, ancho, alto) {
  const fila = ancho * 3 + 1;
  const datos = Buffer.alloc(fila * alto);
  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < ancho; x++) {
      const o = (y * ancho + x) * 4;
      const d = y * fila + 1 + x * 3;
      datos[d] = rgba[o];
      datos[d + 1] = rgba[o + 1];
      datos[d + 2] = rgba[o + 2];
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
  cabecera[8] = 8;
  cabecera[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    bloque('IHDR', cabecera),
    bloque('IDAT', deflateSync(datos)),
    bloque('IEND', Buffer.alloc(0)),
  ]);
}

mkdirSync(SALIDA, { recursive: true });

for (const nombre of readdirSync(ENTRADA).filter((f) => f.endsWith('.png'))) {
  const b64 = readFileSync(resolve(ENTRADA, nombre)).toString('base64');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${ANCHO}" height="${ALTO}" viewBox="0 0 ${ANCHO} ${ALTO}">
    <image width="${ANCHO}" height="${ALTO}" preserveAspectRatio="none" href="data:image/png;base64,${b64}"/>
  </svg>`;
  const r = new Resvg(svg, {
    fitTo: { mode: 'width', value: ANCHO },
    background: '#ffffff',
  }).render();
  const salida = pngSinAlfa(r.pixels, r.width, r.height);
  writeFileSync(resolve(SALIDA, nombre), salida);
  console.log(`${nombre}\t${r.width}x${r.height}\t${(salida.length / 1024).toFixed(0)} kB`);
}
