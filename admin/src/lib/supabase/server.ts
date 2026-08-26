import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

/**
 * Cliente de Supabase para el servidor: componentes de servidor, acciones y
 * manejadores de ruta.
 *
 * La sesion viaja en cookies y no en almacenamiento del navegador, que es lo
 * que permite que el servidor sepa quien esta pidiendo la pagina antes de
 * dibujarla. Sin esto, cada pantalla del panel tendria que comprobar la sesion
 * ya en el navegador, y el contenido llegaria antes que la comprobacion.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Un componente de servidor no puede escribir cookies. Aqui no es un
            // problema: el middleware refresca la sesion en cada peticion y es el
            // que si puede escribirlas.
          }
        },
      },
    },
  );
}
