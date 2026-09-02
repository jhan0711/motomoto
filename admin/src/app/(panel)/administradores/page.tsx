import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';
import { AdminsList } from '@/features/admins/admins-list';

export const metadata = {
  title: 'Administradores - Panel administrativo',
};

/**
 * Pantalla del dueno: solo el super admin.
 *
 * La guardia `proxy.ts` ya bloquea la ruta para un administrador normal; esto es
 * la segunda capa, por si se llega aqui por otra via. Igual que en el servidor,
 * la autorizacion de verdad la hacen las funciones -todas comprueban
 * `is_super_admin()`-, esto solo decide que se dibuja (D72).
 */
export default async function AdministradoresPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: esSuperAdmin } = await supabase.rpc('is_super_admin');

  if (esSuperAdmin !== true) {
    redirect('/');
  }

  return <AdminsList miId={user!.id} />;
}
