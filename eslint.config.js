// https://docs.expo.dev/guides/using-eslint/
const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');

module.exports = defineConfig([
  expoConfig,
  {
    // El panel administrativo (Fase 20) es un proyecto Next.js aparte, con su propia
    // configuracion de ESLint. Compartir esta, que es la de Expo, daria falsos avisos.
    ignores: [
      'dist/*',
      'example/**',
      'node_modules/**',
      'admin/**',
      // Edge Functions: corren en Deno, con imports npm: y globales que ESLint de Expo no conoce.
      'supabase/functions/*/index.ts',
    ],
  },
]);
