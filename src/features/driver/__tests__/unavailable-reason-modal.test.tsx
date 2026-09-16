import { fireEvent, render, screen } from '@testing-library/react-native';

import { UnavailableReasonModal } from '../unavailable-reason-modal';

/**
 * Cubre el flujo de D270: elegir un motivo de la lista confirma directo;
 * "Otro" abre un detalle y necesita un segundo toque; cancelar no confirma
 * nada.
 */
describe('UnavailableReasonModal', () => {
  it('confirma directo al elegir un motivo del catalogo', () => {
    const onConfirm = jest.fn();
    render(
      <UnavailableReasonModal
        visible
        confirming={false}
        onCancel={() => {}}
        onConfirm={onConfirm}
      />,
    );

    fireEvent.press(screen.getByText('Almuerzo'));

    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(onConfirm).toHaveBeenCalledWith({ code: 'almuerzo' });
  });

  it('"Otro" pide un segundo toque, con el detalle escrito', () => {
    const onConfirm = jest.fn();
    render(
      <UnavailableReasonModal
        visible
        confirming={false}
        onCancel={() => {}}
        onConfirm={onConfirm}
      />,
    );

    // Elegir "Otro" todavia no confirma nada: abre el campo de detalle.
    fireEvent.press(screen.getByText('Otro'));
    expect(onConfirm).not.toHaveBeenCalled();

    fireEvent.changeText(
      screen.getByPlaceholderText('Cuéntanos qué pasó (opcional)'),
      'Se pinchó la llanta',
    );
    fireEvent.press(screen.getByText('Desconectarme'));

    expect(onConfirm).toHaveBeenCalledWith({ code: 'otro', detail: 'Se pinchó la llanta' });
  });

  it('cancelar no confirma ningun motivo', () => {
    const onCancel = jest.fn();
    const onConfirm = jest.fn();
    render(
      <UnavailableReasonModal
        visible
        confirming={false}
        onCancel={onCancel}
        onConfirm={onConfirm}
      />,
    );

    fireEvent.press(screen.getByText('Cancelar'));

    expect(onCancel).toHaveBeenCalledTimes(1);
    expect(onConfirm).not.toHaveBeenCalled();
  });
});
