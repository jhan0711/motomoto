import { render, screen, fireEvent } from '@testing-library/react-native';

import { Text } from '../text';
import { Checkbox } from '../checkbox';

describe('Checkbox', () => {
  it('se expone como rol checkbox con su estado', () => {
    render(
      <Checkbox checked={false} onChange={() => {}} accessibilityLabel="Acepto">
        <Text>Acepto</Text>
      </Checkbox>,
    );
    const casilla = screen.getByRole('checkbox', { name: 'Acepto' });
    expect(casilla.props.accessibilityState).toMatchObject({ checked: false });
  });

  it('alterna el valor al tocarla', () => {
    const onChange = jest.fn();
    render(
      <Checkbox checked={false} onChange={onChange} accessibilityLabel="Acepto">
        <Text>Acepto</Text>
      </Checkbox>,
    );
    fireEvent.press(screen.getByRole('checkbox', { name: 'Acepto' }));
    expect(onChange).toHaveBeenCalledWith(true);
  });

  it('no responde al toque cuando está deshabilitada', () => {
    const onChange = jest.fn();
    render(
      <Checkbox checked={false} onChange={onChange} disabled accessibilityLabel="Acepto">
        <Text>Acepto</Text>
      </Checkbox>,
    );
    fireEvent.press(screen.getByRole('checkbox', { name: 'Acepto' }));
    expect(onChange).not.toHaveBeenCalled();
  });
});
