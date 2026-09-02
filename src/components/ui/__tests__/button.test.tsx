import { render, screen, fireEvent } from '@testing-library/react-native';

import { Button } from '../button';

describe('Button', () => {
  it('muestra su etiqueta y la expone como rol boton', () => {
    render(<Button label="Pedir servicio" onPress={() => {}} />);
    const boton = screen.getByRole('button', { name: 'Pedir servicio' });
    expect(boton).toBeTruthy();
    expect(screen.getByText('Pedir servicio')).toBeTruthy();
  });

  it('llama a onPress cuando esta activo', () => {
    const onPress = jest.fn();
    render(<Button label="Continuar" onPress={onPress} />);
    fireEvent.press(screen.getByRole('button', { name: 'Continuar' }));
    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('no llama a onPress cuando esta deshabilitado', () => {
    const onPress = jest.fn();
    render(<Button label="Continuar" onPress={onPress} disabled />);
    fireEvent.press(screen.getByRole('button', { name: 'Continuar' }));
    expect(onPress).not.toHaveBeenCalled();
  });

  it('mientras carga bloquea el toque y se anuncia como ocupado', () => {
    const onPress = jest.fn();
    render(<Button label="Guardando" onPress={onPress} loading />);
    const boton = screen.getByRole('button', { name: 'Guardando' });
    fireEvent.press(boton);
    expect(onPress).not.toHaveBeenCalled();
    expect(boton.props.accessibilityState).toMatchObject({ busy: true, disabled: true });
    // El texto se reemplaza por el indicador de carga.
    expect(screen.queryByText('Guardando')).toBeNull();
  });
});
