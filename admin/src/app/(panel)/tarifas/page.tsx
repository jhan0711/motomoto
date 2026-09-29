import { createClient } from '@/lib/supabase/server';
import { ConfigPage } from '@/features/config/config-page';

export const metadata = {
  title: 'Tarifas y configuración - Panel administrativo',
};

/**
 * Mismo patron que `conductores/page.tsx`: se pregunta en el servidor para
 * decidir si `driver_balance_enforced` -el interruptor que activa el cobro del
 * 4% para toda la flota (D278)- se ve editable. Pedido del usuario, 2026-09-29.
 */
export default async function TarifasPage() {
  const supabase = await createClient();
  const { data: esSuperAdmin } = await supabase.rpc('is_super_admin');

  return <ConfigPage esSuperAdmin={esSuperAdmin === true} />;
}
