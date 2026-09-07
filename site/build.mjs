// Genera el sitio estático de AmalfiGoApp en `site/dist/`. Fase 25, paso 5.
//
//   node site/build.mjs
//
// Los textos legales salen de `docs/legal/*.md`. Revisados por abogado y
// definitivos desde el 2026-09-07 (Fase 26): sin `noindex` ni aviso de
// borrador, para que Google pueda rastrear la política de privacidad -requisito
// para publicar en Play-.

import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(AQUI, '..');
const DIST = resolve(AQUI, 'dist');

const BRAND = {
  bg: '#2a323c',
  bgAlt: '#222933',
  fg: '#e8eaed',
  muted: '#9aa3ad',
  accent: '#ca852d',
};

/** Envuelve el cuerpo HTML en la plantilla del sitio. */
function pagina({ titulo, cuerpo, noindex = false }) {
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
${noindex ? '<meta name="robots" content="noindex">' : ''}
<title>${titulo} · AmalfiGoApp</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: ${BRAND.bg}; color: ${BRAND.fg};
    font: 16px/1.6 -apple-system, "Segoe UI", Roboto, system-ui, sans-serif;
  }
  main { max-width: 760px; margin: 0 auto; padding: 40px 20px 80px; }
  header { display: flex; align-items: center; gap: 12px; margin-bottom: 32px; }
  header img { width: 44px; height: 44px; border-radius: 10px; }
  header b { font-size: 18px; }
  a { color: ${BRAND.accent}; }
  h1 { font-size: 26px; line-height: 1.25; margin: 0 0 8px; }
  h2 { font-size: 19px; margin: 36px 0 10px; }
  h3 { font-size: 16px; margin: 24px 0 8px; }
  table { border-collapse: collapse; width: 100%; margin: 16px 0; font-size: 14px; }
  th, td { border: 1px solid #3a434e; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: ${BRAND.bgAlt}; }
  code { background: ${BRAND.bgAlt}; padding: 1px 5px; border-radius: 4px; font-size: 90%; }
  footer { margin-top: 56px; color: ${BRAND.muted}; font-size: 13px; }
  .overflow { overflow-x: auto; }
</style>
</head>
<body>
<main>
  <header>
    <img src="/icon.png" alt="">
    <b>AmalfiGoApp</b>
  </header>
  ${cuerpo}
  <footer>AmalfiGoApp · Amalfi, Antioquia, Colombia</footer>
</main>
</body>
</html>
`;
}

/** Lee un .md de docs/legal, le quita el comentario de cabecera y lo pasa a HTML. */
function legalAHtml(archivo) {
  const md = readFileSync(resolve(RAIZ, 'docs/legal', archivo), 'utf8').replace(
    /^<!--[\s\S]*?-->\s*/,
    '',
  );
  return marked.parse(md);
}

rmSync(DIST, { recursive: true, force: true });
mkdirSync(DIST, { recursive: true });

writeFileSync(
  resolve(DIST, 'privacidad.html'),
  pagina({
    titulo: 'Política de privacidad',
    cuerpo: `<div class="overflow">${legalAHtml('politica-de-privacidad.md')}</div>`,
  }),
);
writeFileSync(
  resolve(DIST, 'terminos.html'),
  pagina({
    titulo: 'Términos de uso',
    cuerpo: `<div class="overflow">${legalAHtml('terminos-de-uso.md')}</div>`,
  }),
);

writeFileSync(
  resolve(DIST, 'index.html'),
  pagina({
    titulo: 'Inicio',
    cuerpo: `
    <h1>Muévete fácil, llega seguro.</h1>
    <p>AmalfiGoApp conecta a quien necesita un motorratón en Amalfi con los conductores disponibles. Pide el servicio, ve el valor antes de confirmar y sigue al conductor en el mapa mientras llega.</p>
    <p style="margin-top:32px">
      <a href="/privacidad">Política de privacidad</a> ·
      <a href="/terminos">Términos de uso</a> ·
      <a href="/eliminar-cuenta">Eliminar cuenta</a>
    </p>`,
  }),
);

// Eliminación de cuenta (Fase 26 paso 7b). Google Play exige, para apps con
// registro, una URL web que explique cómo borrar la cuenta y los datos. No lleva
// `noindex`: Google necesita rastrearla.
writeFileSync(
  resolve(DIST, 'eliminar-cuenta.html'),
  pagina({
    titulo: 'Eliminar tu cuenta',
    cuerpo: `
    <h1>Eliminar tu cuenta de AmalfiGoApp</h1>
    <p>Puedes borrar tu cuenta y tus datos personales desde la propia aplicación:</p>
    <ol>
      <li>Abre AmalfiGoApp e inicia sesión.</li>
      <li>Ve a <strong>Mi perfil</strong>.</li>
      <li>Toca <strong>Eliminar mi cuenta</strong> y confirma.</li>
    </ol>
    <h2>Qué se borra</h2>
    <p>Tu nombre, tu teléfono, tu correo y tu foto de perfil. La eliminación es
    inmediata y no se puede deshacer.</p>
    <h2>Qué se conserva</h2>
    <p>Los servicios que hiciste quedan en el registro operativo de la empresa de
    motorratones <strong>sin tu nombre ni tus datos de contacto</strong>, porque
    son parte de la contabilidad del conductor.</p>
    <h2>Si ya desinstalaste la aplicación</h2>
    <p>Escríbenos a <a href="mailto:soporte@amalfigo.app">soporte@amalfigo.app</a>
    desde el correo de tu cuenta y la eliminamos por ti.</p>`,
  }),
);

// Aterrizaje de los enlaces de los correos de la cuenta. Con la app instalada y
// el enlace de aplicación verificado, Android abre la app directamente y esta
// página no se llega a ver. Se ve cuando la app no está instalada o el enlace
// aún no está verificado: intenta pasar a la app por el esquema `motomoto://`
// -llevándose la query y el fragmento con el token_hash- y si no, explica qué
// hacer. Los enlaces nuevos traen `?token_hash=...&type=...` en la query.
mkdirSync(resolve(DIST, 'auth'), { recursive: true });
writeFileSync(
  resolve(DIST, 'auth/index.html'),
  pagina({
    titulo: 'Abrir en la app',
    noindex: true,
    cuerpo: `
    <h1>Abre AmalfiGoApp para continuar</h1>
    <p id="msg">Te estamos llevando a la aplicación…</p>
    <p style="margin-top:24px"><a id="manual" href="#">Abrir la aplicación</a></p>
    <script>
      (function () {
        var destino = 'motomoto://auth' + window.location.search + window.location.hash;
        document.getElementById('manual').setAttribute('href', destino);
        // Intento automático.
        window.location.replace(destino);
        // Si a los 2 s seguimos aquí, la app no está instalada.
        setTimeout(function () {
          document.getElementById('msg').textContent =
            'Si no se abrió sola, toca "Abrir la aplicación". Si no tienes AmalfiGoApp instalada, descárgala e intenta el enlace de nuevo.';
        }, 2000);
      })();
    </script>`,
  }),
);

// `/privacidad` y `/terminos` los sirve Cloudflare desde los `.html` por su
// manejo por defecto de HTML (auto-trailing-slash). No hacen falta copias.

// assetlinks.json y el icono.
//
// `co.amalfigo.app` con DOS huellas SHA-256: la del keystore de depuración
// (`FA:C6:...`, para los APK de prueba locales) y la del keystore de subida de
// EAS (`8C:59:...`, para el build de producción). Cuando se suba el primer AAB
// a Google Play y se active Play App Signing, Google da una TERCERA huella -la
// de su propia clave de firma- que hay que añadir aquí tambien.
// La entrada vieja `com.motomoto.app` se quitó al verificar el rename (paso 1).
mkdirSync(resolve(DIST, '.well-known'), { recursive: true });
cpSync(resolve(AQUI, '.well-known/assetlinks.json'), resolve(DIST, '.well-known/assetlinks.json'));
cpSync(resolve(RAIZ, 'assets/images/icon.png'), resolve(DIST, 'icon.png'));

console.log(
  'site/dist/ generado: index.html, privacidad.html, terminos.html, eliminar-cuenta.html, .well-known/assetlinks.json, icon.png',
);
