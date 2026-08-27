import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from './logout-button';
import { PanelNav } from './panel-nav';

/**
 * Marco comun de las pantallas del panel: cabecera, navegacion y quien entro.
 *
 * Vive en un grupo de rutas `(panel)` -entre parentesis, asi que no aparece en
 * la URL- para que la pantalla de acceso quede fuera: ahi no hay sesion todavia
 * y no tendria sentido dibujar una navegacion ni un boton de salir.
 *
 * La cabecera se dibuja en el servidor, que es donde se sabe quien entro sin
 * preguntarselo al navegador.
 */
export default async function PanelLayout({ children }: LayoutProps<'/'>) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('id', user!.id)
    .single();

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-8">
      <header className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-text-primary">Panel administrativo</h1>
          <p className="mt-1 text-sm text-text-secondary">
            Sesión iniciada como <span className="font-medium">{profile?.full_name}</span>
          </p>
        </div>
        <LogoutButton />
      </header>

      <PanelNav />

      <main className="mt-6">{children}</main>
    </div>
  );
}
