import { render, screen } from '@testing-library/react-native';

import { Text } from '../text';

describe('Text', () => {
  it('pinta su contenido', () => {
    render(<Text>Hola Amalfi</Text>);
    expect(screen.getByText('Hola Amalfi')).toBeTruthy();
  });

  it('reenvia props de react-native como numberOfLines y testID', () => {
    render(
      <Text testID="titulo" numberOfLines={1}>
        Un texto muy largo que se corta
      </Text>,
    );
    expect(screen.getByTestId('titulo').props.numberOfLines).toBe(1);
  });

  it('aplica el color semantico pedido, resuelto desde el tema', () => {
    render(
      <Text testID="aviso" color="danger">
        Cuidado
      </Text>,
    );
    const estilo = screen.getByTestId('aviso').props.style.flat(Infinity).filter(Boolean);
    // Algun fragmento del estilo lleva un color; con el tema claro no es undefined.
    expect(estilo.some((s: Record<string, unknown>) => typeof s.color === 'string')).toBe(true);
  });
});
