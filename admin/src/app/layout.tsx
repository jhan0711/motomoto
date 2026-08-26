import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Panel administrativo - MotoMoto',
  description: 'Panel de administracion de la plataforma MotoMoto',
};

/*
 * Sin fuente empaquetada, igual que la aplicacion movil (D46): se usa la del
 * sistema. La plantilla de Next traia Geist desde Google Fonts, que ademas
 * obliga a una descarga en cada compilacion.
 */
export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="es" className="h-full antialiased">
      <body className="flex min-h-full flex-col font-sans">{children}</body>
    </html>
  );
}
