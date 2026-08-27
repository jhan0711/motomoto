'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, MapPin, SlidersHorizontal, Truck, Users } from 'lucide-react';

/*
 * Las secciones del panel, en el orden en que se van construyendo. Las que
 * faltan -pasajeros, servicios, reportes- se anaden aqui segun llegan
 * sus pasos, y la navegacion no hay que volver a tocarla.
 */
const SECCIONES = [
  { href: '/', etiqueta: 'Tablero', icono: LayoutDashboard },
  { href: '/conductores', etiqueta: 'Conductores', icono: Users },
  { href: '/motorratones', etiqueta: 'Motorratones', icono: Truck },
  { href: '/lugares', etiqueta: 'Lugares', icono: MapPin },
  { href: '/tarifas', etiqueta: 'Tarifas', icono: SlidersHorizontal },
] as const;

export function PanelNav() {
  const ruta = usePathname();

  return (
    <nav className="mt-6 flex gap-1 border-b border-border">
      {SECCIONES.map(({ href, etiqueta, icono: Icono }) => {
        const activa = ruta === href;
        return (
          <Link
            key={href}
            href={href}
            /*
             * La seccion activa se marca con el color de marca Y con un borde
             * inferior, no solo con el color: misma regla que los estados
             * (D202), el color nunca es la unica senal.
             */
            className={`-mb-px flex items-center gap-2 border-b-2 px-3 py-2.5 text-sm font-medium transition-colors duration-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-(--color-brand) ${
              activa
                ? 'border-brand text-brand-strong'
                : 'border-transparent text-text-secondary hover:border-border-strong hover:text-text-primary'
            }`}
            aria-current={activa ? 'page' : undefined}
          >
            <Icono size={16} />
            {etiqueta}
          </Link>
        );
      })}
    </nav>
  );
}
