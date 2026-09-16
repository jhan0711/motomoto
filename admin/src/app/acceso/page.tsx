import { Suspense } from 'react';
import { LoginForm } from './login-form';

export const metadata = {
  title: 'Acceso - Panel administrativo',
};

/**
 * Acceso al panel.
 *
 * No hay registro publico, a proposito: las cuentas de administrador se crean
 * desde la base de datos. Es la misma regla que ya vale para los conductores
 * (seccion 6 del documento del proyecto), y con mas motivo aqui.
 */
export default function AccesoPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-[420px]">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-semibold text-text-primary">AmalfiGoApp</h1>
          <p className="mt-1 text-sm text-text-secondary">Panel administrativo</p>
        </div>

        <div className="rounded-xl border border-border bg-surface p-6 shadow-sm">
          <Suspense fallback={null}>
            <LoginForm />
          </Suspense>
        </div>

        <p className="mt-6 text-center text-xs text-text-tertiary">
          El acceso está limitado al personal autorizado de la empresa.
        </p>
      </div>
    </main>
  );
}
