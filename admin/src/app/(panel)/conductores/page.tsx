import { createClient } from '@/lib/supabase/server';
import { DriversList } from '@/features/drivers/drivers-list';

export const metadata = {
  title: 'Conductores - Panel administrativo',
};

/**
 * Se pregunta en el servidor -mismo patron que `administradores/page.tsx`- para
 * decidir si esta cuenta ve el boton "Saldo" (D278 toca dinero real: pedido del
 * usuario, 2026-09-29, restringirlo al super administrador). La autorizacion de
 * verdad la hace `admin_adjust_driver_balance` con `is_super_admin()`; esto solo
 * decide que se dibuja.
 */
export default async function ConductoresPage() {
  const supabase = await createClient();
  const { data: esSuperAdmin } = await supabase.rpc('is_super_admin');

  return <DriversList esSuperAdmin={esSuperAdmin === true} />;
}
