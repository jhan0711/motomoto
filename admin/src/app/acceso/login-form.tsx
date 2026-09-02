'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { AlertCircle, Eye, EyeOff, LoaderCircle } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

/**
 * Formulario de acceso.
 *
 * El mensaje de error es deliberadamente el mismo para credenciales
 * equivocadas y para una cuenta que existe pero no es administradora. Decir
 * "esa cuenta no es de administrador" confirmaria que el correo existe, que es
 * el mismo criterio de D74 en la recuperacion de contrasena.
 */
export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [hasTried, setHasTried] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  /*
   * El middleware devuelve aqui a quien tenga sesion pero no sea administrador,
   * marcandolo en la URL. El mensaje se DERIVA en el render en vez de copiarse
   * a un estado dentro de un efecto: el compilador de React prohibe lo segundo,
   * y la solucion no es silenciar la regla (regla 6 de las aprendidas). En
   * cuanto el usuario intenta entrar, manda el resultado de ese intento.
   */
  const error = hasTried
    ? submitError
    : searchParams.get('error') === 'sin_permiso'
      ? 'Esa cuenta no tiene acceso al panel administrativo.'
      : null;

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setHasTried(true);
    setSubmitError(null);
    setIsSubmitting(true);

    const supabase = createClient();
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (signInError || !data.user) {
      setSubmitError('Correo o contraseña incorrectos.');
      setIsSubmitting(false);
      return;
    }

    // Se comprueba el rol ANTES de mandarlo al panel. El middleware lo haria de
    // todos modos, pero entonces el usuario veria un parpadeo hacia el panel y
    // una vuelta al acceso, sin entender que paso.
    const { data: profile } = await supabase
      .from('profiles')
      .select('role, status')
      .eq('id', data.user.id)
      .single();

    const esAdmin = profile?.role === 'admin' || profile?.role === 'super_admin';
    if (!esAdmin || profile?.status !== 'active') {
      await supabase.auth.signOut();
      setSubmitError('Correo o contraseña incorrectos.');
      setIsSubmitting(false);
      return;
    }

    router.replace('/');
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4" noValidate>
      <div className="flex flex-col gap-1.5">
        <label htmlFor="email" className="text-sm font-medium text-text-primary">
          Correo electrónico
        </label>
        <input
          id="email"
          type="email"
          autoComplete="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="h-12 rounded-lg border border-border bg-surface px-3 text-text-primary outline-none focus:border-brand"
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="password" className="text-sm font-medium text-text-primary">
          Contraseña
        </label>
        <div className="relative">
          <input
            id="password"
            type={showPassword ? 'text' : 'password'}
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="h-12 w-full rounded-lg border border-border bg-surface px-3 pr-12 text-text-primary outline-none focus:border-brand"
          />
          {/* Alternador de visibilidad: obligatorio en todo campo de contrasena (D53). */}
          <button
            type="button"
            onClick={() => setShowPassword((v) => !v)}
            aria-label={showPassword ? 'Ocultar la contraseña' : 'Mostrar la contraseña'}
            className="absolute top-0 right-0 flex h-12 w-12 items-center justify-center text-text-secondary"
          >
            {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
          </button>
        </div>
      </div>

      {error !== null && (
        <div
          role="alert"
          className="flex items-start gap-2 rounded-lg bg-danger-subtle px-3 py-2.5 text-sm text-on-danger-subtle"
        >
          <AlertCircle size={18} className="mt-px shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <button
        type="submit"
        disabled={isSubmitting}
        className="btn btn-primario h-12 w-full text-base"
      >
        {isSubmitting && <LoaderCircle size={18} className="animate-spin" />}
        {isSubmitting ? 'Entrando…' : 'Entrar'}
      </button>
    </form>
  );
}
