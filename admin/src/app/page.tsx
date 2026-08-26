import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from './logout-button';

/**
 * Marcador de posicion del panel.
 *
 * El contenido de verdad -servicios en curso, conductores, tarifas- llega en
 * los pasos siguientes de la Fase 20. De momento esta pantalla existe para una
 * sola cosa: comprobar que el acceso funciona y que quien entro es quien dice
 * ser, leido del servidor y no de la sesion del navegador.
 */
export default async function InicioPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, role, status')
    .eq('id', user!.id)
    .single();

  return (
    <main className="mx-auto w-full max-w-5xl px-6 py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-text-primary">Panel administrativo</h1>
          <p className="mt-1 text-sm text-text-secondary">
            Sesión iniciada como <span className="font-medium">{profile?.full_name}</span>
          </p>
        </div>
        <LogoutButton />
      </div>

      <div className="mt-8 rounded-xl border border-border bg-surface p-6">
        <h2 className="text-sm font-semibold tracking-wide text-text-secondary uppercase">
          Sesión verificada contra el servidor
        </h2>
        <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
          <div>
            <dt className="text-text-secondary">Correo</dt>
            <dd className="mt-0.5 text-text-primary">{user?.email}</dd>
          </div>
          <div>
            <dt className="text-text-secondary">Rol</dt>
            <dd className="mt-0.5 text-text-primary">{profile?.role}</dd>
          </div>
          <div>
            <dt className="text-text-secondary">Estado de la cuenta</dt>
            <dd className="mt-0.5 text-text-primary">{profile?.status}</dd>
          </div>
        </dl>
      </div>

      <p className="mt-6 text-sm text-text-tertiary">
        Las pantallas de gestión se construyen en los pasos siguientes de la Fase 20.
      </p>
    </main>
  );
}
