// =============================================================================
// HERRAMIENTA DE DESARROLLO. NO ES UNA MIGRACION.
// =============================================================================
//
// Corredor de todas las pruebas de `supabase/dev-tools/`: los `prueba_*.sql`
// contra el servidor enlazado y los `prueba_*.mjs` con Node. Imprime un resumen
// y sale con codigo distinto de 0 si algo falla, para que sirva en CI.
//
//   node supabase/dev-tools/run-tests.mjs            (todo)
//   node supabase/dev-tools/run-tests.mjs recorrido  (solo los que contienen eso)
//   node supabase/dev-tools/run-tests.mjs --sql      (solo SQL)
//   node supabase/dev-tools/run-tests.mjs --mjs      (solo Node)
//
// POR QUE HACE FALTA UN PARSER. `supabase db query` solo sale con error si el
// SQL revienta; una comprobacion en rojo dentro de una transaccion que se
// deshace le da igual. Asi que hay que leer la fila TOTAL de cada script
// -`n = 999`, `estado`, `obtenido = 'N fallando'`- y decidir a partir de ahi.
// Los `.mjs` ya salen con su propio codigo, pero se les parsea igual la linea
// TOTAL para el recuento.
//
// LO QUE NO HACE: no monta ni limpia nada. Cada `prueba_*.sql` vive dentro de su
// `begin; ... rollback;` y los `.mjs` restauran lo que tocan. El unico que deja
// huella temporal es `prueba_cambio_contrasena_sesiones.mjs`, que cambia y
// devuelve la contrasena del pasajero de prueba.
// =============================================================================

import { readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(AQUI, '../..');
const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';

const args = process.argv.slice(2);
const soloSql = args.includes('--sql');
const soloMjs = args.includes('--mjs');
const filtros = args.filter((a) => !a.startsWith('--'));

function coincide(nombre) {
  return filtros.length === 0 || filtros.some((f) => nombre.includes(f));
}

const archivos = readdirSync(AQUI)
  .filter((f) => /^prueba_.*\.(sql|mjs)$/.test(f))
  .filter(coincide)
  .filter((f) => (soloSql ? f.endsWith('.sql') : soloMjs ? f.endsWith('.mjs') : true))
  .sort();

if (archivos.length === 0) {
  console.error('No hay pruebas que coincidan con', args.join(' ') || '(todo)');
  process.exit(2);
}

// --- Lectura de la fila TOTAL -------------------------------------------------

const RX_COMPROB = /(\d+)\s+comprobaciones/;
const RX_FALLAN = /(\d+)\s+fallando/;

// De la salida JSON de `supabase db query`.
function leerSql(stdout) {
  let json;
  try {
    json = JSON.parse(stdout);
  } catch {
    return { ok: false, total: 0, fallando: 0, nota: 'salida no era JSON' };
  }
  if (json?._tag === 'Error') {
    const msg = String(json.error?.message ?? 'error de SQL').split('\n')[0];
    return { ok: false, total: 0, fallando: 0, nota: msg.slice(0, 120) };
  }
  const filas = json.rows ?? [];
  const total = filas.find((r) => r.n === 999 || r.comprobacion === 'TOTAL');
  if (!total) {
    // Sin fila TOTAL: se cae a la fuerza bruta sobre la columna de estado.
    const rojas = filas.filter((r) => String(r.estado ?? r.ok ?? '').trim() === 'FALLA');
    return {
      ok: filas.length > 0 && rojas.length === 0,
      total: filas.length,
      fallando: rojas.length,
      nota: filas.length === 0 ? 'sin filas' : 'sin fila TOTAL',
    };
  }
  const estado = String(total.estado ?? '').trim();
  const nComprob = Number(RX_COMPROB.exec(total.esperado ?? '')?.[1] ?? 0);
  const nFallan = Number(RX_FALLAN.exec(total.obtenido ?? '')?.[1] ?? (estado === 'OK' ? 0 : 1));
  return { ok: estado === 'OK' && nFallan === 0, total: nComprob, fallando: nFallan, nota: '' };
}

// De la salida por lineas de un `.mjs` (linea `999\t...\tTOTAL\t...`).
function leerMjs(stdout, code) {
  const linea = stdout.split('\n').find((l) => l.startsWith('999\t'));
  const total = Number(RX_COMPROB.exec(linea ?? '')?.[1] ?? 0);
  const fallando = Number(RX_FALLAN.exec(linea ?? '')?.[1] ?? (code === 0 ? 0 : 1));
  return { ok: code === 0 && fallando === 0, total, fallando, nota: linea ? '' : `exit ${code}` };
}

// --- Ejecucion -------------------------------------------------------------

const inicio = Date.now();
const resultados = [];

for (const archivo of archivos) {
  const t0 = Date.now();
  let r;
  const rel = join('supabase/dev-tools', archivo);
  const opciones = { cwd: RAIZ, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, shell: true };
  if (archivo.endsWith('.sql')) {
    const proc = spawnSync(npx, ['supabase', 'db', 'query', '--linked', '-f', rel], opciones);
    if (proc.error) {
      r = { ok: false, total: 0, fallando: 0, nota: proc.error.message.slice(0, 120) };
    } else {
      r = leerSql(proc.stdout ?? '');
      if (proc.status !== 0 && r.ok) r = { ...r, ok: false, nota: r.nota || `cli exit ${proc.status}` };
    }
  } else {
    const proc = spawnSync('node', [rel], opciones);
    r = proc.error
      ? { ok: false, total: 0, fallando: 0, nota: proc.error.message.slice(0, 120) }
      : leerMjs(proc.stdout ?? '', proc.status ?? 1);
  }
  const seg = ((Date.now() - t0) / 1000).toFixed(1);
  resultados.push({ archivo, ...r, seg });
  const marca = r.ok ? 'OK  ' : 'FALLA';
  const detalle = r.ok
    ? `${r.total} comprobaciones`
    : `${r.fallando} fallando${r.nota ? ` (${r.nota})` : ''}`;
  console.log(`${marca}  ${archivo.padEnd(38)} ${detalle}  ${seg}s`);
}

// --- Resumen -------------------------------------------------------------

const fallidos = resultados.filter((r) => !r.ok);
const sumaComprob = resultados.reduce((s, r) => s + r.total, 0);
const sumaFallan = resultados.reduce((s, r) => s + r.fallando, 0);
const seg = ((Date.now() - inicio) / 1000).toFixed(1);

console.log('');
console.log('='.repeat(64));
console.log(
  `${fallidos.length === 0 ? 'OK  ' : 'FALLA'}  ${resultados.length} scripts, ` +
    `${sumaComprob} comprobaciones, ${sumaFallan} fallando, ${fallidos.length} scripts en rojo  ${seg}s`,
);
if (fallidos.length > 0) {
  console.log('');
  for (const f of fallidos) console.log(`  - ${f.archivo}: ${f.nota || `${f.fallando} fallando`}`);
}

process.exit(fallidos.length === 0 ? 0 : 1);
