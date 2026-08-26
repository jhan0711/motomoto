import path from 'node:path';
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  turbopack: {
    /*
     * El panel vive dentro de la carpeta de la aplicacion movil, y las dos
     * tienen su propio package-lock.json. Sin esta linea, Next elige como raiz
     * la carpeta de arriba -lo avisa al arrancar- y pasaria a vigilar el
     * proyecto movil entero, node_modules incluido.
     */
    root: path.resolve(__dirname),
  },
};

export default nextConfig;
