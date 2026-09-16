import { fireEvent, render, screen } from '@testing-library/react-native';

import { CargoPicker } from '../cargo-picker';
import type { CargoType } from '../types';

/**
 * Cubre el bug reportado: abrir "Agregar carga" justo despues de tocar
 * "Encomienda", antes de que el catalogo (`useCargoTypes`) resuelva, no debe
 * dejar el dialogo con una lista vacia sin explicacion.
 */
describe('CargoPicker', () => {
  const tipos: CargoType[] = [
    { id: 'caja', name: 'Caja', amount: 3000 },
    { id: 'bicicleta', name: 'Bicicleta', amount: 5000 },
  ];

  it('muestra un indicador de carga en vez de una lista vacia mientras el catalogo carga', () => {
    render(
      <CargoPicker
        visible
        onRequestClose={() => {}}
        cargoTypes={[]}
        loading
        error={null}
        onRetry={() => {}}
        items={[]}
        onChangeQuantity={() => {}}
      />,
    );

    // Mismo "Cargando..." que usa el catalogo hermano (usePlaces) en
    // destination.tsx: nada de tipos de carga todavia, pero tampoco una lista
    // vacia sin explicacion.
    expect(screen.getByText('Cargando tipos de carga')).toBeTruthy();
    expect(screen.queryByText('Caja')).toBeNull();
  });

  it('muestra el catalogo cuando ya cargo', () => {
    render(
      <CargoPicker
        visible
        onRequestClose={() => {}}
        cargoTypes={tipos}
        loading={false}
        error={null}
        onRetry={() => {}}
        items={[]}
        onChangeQuantity={() => {}}
      />,
    );

    expect(screen.getByText('Caja')).toBeTruthy();
    expect(screen.getByText('Bicicleta')).toBeTruthy();
  });

  it('ofrece reintentar si el catalogo fallo, en vez de una lista vacia', () => {
    const onRetry = jest.fn();
    render(
      <CargoPicker
        visible
        onRequestClose={() => {}}
        cargoTypes={[]}
        loading={false}
        error="No pudimos cargar el catálogo de carga."
        onRetry={onRetry}
        items={[]}
        onChangeQuantity={() => {}}
      />,
    );

    expect(screen.getByText('No pudimos cargar el catálogo de carga.')).toBeTruthy();
    // Por texto y no por `getByRole('button', { name: 'Reintentar' })': el
    // Pressable-scrim del propio `Modal` (etiquetado "Cerrar", ver modal.tsx)
    // envuelve toda la tarjeta y a esa consulta le hace ruido.
    fireEvent.press(screen.getByText('Reintentar'));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });
});
