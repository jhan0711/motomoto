import { createBrowserClient } from '@supabase/ssr';
import type { Database } from './database.types';

/**
 * Cliente de Supabase para el navegador.
 *
 * Se usa solo en componentes de cliente, por ejemplo el formulario de acceso.
 * Todo lo que se pueda leer desde el servidor se lee desde el servidor.
 */
export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
