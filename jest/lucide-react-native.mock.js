/**
 * Mock de `lucide-react-native` para Jest.
 *
 * La librería son ~1.500 iconos en un solo barril ESM; cargarla de verdad añadía
 * ~1 minuto por suite de componente. Aquí cada icono es un elemento vacío que
 * conserva sus props (basta para render y accesibilidad).
 *
 * `__esModule: true` en el proxy hace que el interop de Babel devuelva el objeto
 * tal cual, así `import { Check } from 'lucide-react-native'` cae en el `get` del
 * proxy y recibe el componente.
 *
 * Enchufado por `moduleNameMapper` en la config de Jest (package.json).
 */
const { createElement } = require('react');

const handler = {
  get(_target, name) {
    if (name === '__esModule') {
      return true;
    }
    const Icono = (props) => createElement('lucide-icon', props);
    Icono.displayName = String(name);
    return Icono;
  },
};

module.exports = new Proxy({}, handler);
