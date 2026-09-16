import type { Metadata } from 'next';
import './globals.css';
// El mapa de la flota (D272) necesita este CSS para posicionar bien su canvas
// y sus controles. Importado desde una pantalla (`fleet-map.tsx`) nunca llego
// a incluirse en la pagina -Next solo empaqueta con fiabilidad el CSS global
// que se importa desde el layout raiz-, y sin el el contenedor del mapa se
// queda en `position: static` en vez del `absolute` que mapbox-gl necesita.
import 'mapbox-gl/dist/mapbox-gl.css';

export const metadata: Metadata = {
  title: 'Panel administrativo - AmalfiGoApp',
  description: 'Panel de administracion de la plataforma AmalfiGoApp',
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
