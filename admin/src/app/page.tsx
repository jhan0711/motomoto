import { createClient } from '@/lib/supabase/server';
import { Dashboard } from '@/features/dashboard/dashboard';
import { LogoutButton } from './logout-button';

/**
 * El tablero: la pantalla de inicio del panel.
 *
 * La cabecera se dibuja en el servidor, que es donde se sabe quien entro sin
 * preguntarselo al navegador. El tablero en si es de cliente, porque se
 * refresca solo.
 */
export default async function InicioPage() {
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
    <main className="mx-auto w-full max-w-5xl px-6 py-8">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-text-primary">Panel administrativo</h1>
          <p className="mt-1 text-sm text-text-secondary">
            Sesión iniciada como <span className="font-medium">{profile?.full_name}</span>
          </p>
        </div>
        <LogoutButton />
      </div>

      <div className="mt-8">
        <Dashboard />
      </div>
    </main>
  );
}
