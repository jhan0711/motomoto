import * as WebBrowser from 'expo-web-browser';
import { Wallet } from 'lucide-react-native';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FormError } from '@/components/ui/form-error';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { Text } from '@/components/ui/text';
import { formatAmount } from '@/features/fare/format-amount';
import {
  formatAmountInput,
  parseOfferAmount,
  sanitizeOfferText,
} from '@/features/fare/offer-amount';
import { radius, iconSize, iconStrokeWidth, spacing, useTheme } from '@/theme';

import {
  createTopup,
  fetchMyBalance,
  fetchMyLedger,
  type DriverBalance,
  type LedgerEntry,
} from './balance-service';

const ETIQUETA: Record<LedgerEntry['kind'], string> = {
  topup: 'Recarga',
  commission: 'Comisión de un servicio',
  adjustment: 'Ajuste de la empresa',
};

/** Con el signo delante: "+$10.000" / "-$200". `formatAmount` no pinta signos. */
function conSigno(valor: number): string {
  return `${valor < 0 ? '-' : '+'}${formatAmount(Math.abs(valor))}`;
}

/** Lo que se le sugiere recargar: el minimo y dos escalones por encima. */
function montosSugeridos(minimo: number): number[] {
  return [...new Set([minimo, Math.max(minimo, 20000), Math.max(minimo, 50000)])];
}

const ESPERAS_MS = [2500, 2500, 3000, 3000, 4000];

/**
 * Su saldo, sus ultimos movimientos y el boton de recargar.
 *
 * No pinta NADA mientras el cobro este apagado Y el conductor no tenga
 * movimientos (D278): quien ve "Saldo $0" sin que nadie le cobre pensaria que
 * algo esta mal. Si ya tiene movimientos -por ejemplo una recarga adelantada- se
 * muestra aunque el interruptor siga apagado.
 *
 * Recargar abre el pago de Wompi en el navegador. **Volver del navegador no
 * significa que el pago valio**: el saldo sube cuando Wompi avisa al servidor,
 * asi que al volver se relee unas cuantas veces hasta que aparezca el
 * movimiento, y si tarda mas se dice la verdad -"puede tardar unos minutos"- en
 * lugar de afirmar que se acredito.
 */
export function BalanceCard() {
  const { colors } = useTheme();
  const [saldo, setSaldo] = useState<DriverBalance | null>(null);
  const [movimientos, setMovimientos] = useState<LedgerEntry[]>([]);

  const [recargando, setRecargando] = useState(false);
  const [texto, setTexto] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [errorRecarga, setErrorRecarga] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const vivo = useRef(true);

  const cargar = useCallback(async (): Promise<DriverBalance | null> => {
    const s = await fetchMyBalance();
    if (!s.ok || s.data === null) return null;
    if (vivo.current) setSaldo(s.data);

    const m = await fetchMyLedger(10);
    if (m.ok && vivo.current) setMovimientos(m.data);
    return s.data;
  }, []);

  useEffect(() => {
    vivo.current = true;
    // Diferido fuera del cuerpo del efecto, como en el resto del proyecto.
    const id = setTimeout(() => void cargar(), 0);
    return () => {
      vivo.current = false;
      clearTimeout(id);
    };
  }, [cargar]);

  const minimo = saldo?.minTopup ?? 10000;
  const monto = parseOfferAmount(texto);
  const errorMonto =
    texto !== '' && (monto === null || monto < minimo)
      ? `La recarga mínima es de ${formatAmount(minimo)}.`
      : null;

  /** Espera a que el aviso de Wompi llegue al servidor y el saldo cambie. */
  const esperarAcreditacion = useCallback(
    async (saldoAntes: number) => {
      setAviso('Confirmando tu pago…');

      for (const espera of ESPERAS_MS) {
        await new Promise((r) => setTimeout(r, espera));
        if (!vivo.current) return;

        const actual = await cargar();
        if (actual !== null && actual.balance !== saldoAntes) {
          setAviso('¡Recarga recibida!');
          return;
        }
      }

      if (vivo.current) {
        setAviso(
          'Todavía no vemos tu pago. Si ya pagaste, puede tardar unos minutos en aparecer; si no, puedes intentarlo de nuevo.',
        );
      }
    },
    [cargar],
  );

  const recargar = useCallback(async () => {
    if (monto === null || monto < minimo || saldo === null) return;

    setEnviando(true);
    setErrorRecarga(null);
    const saldoAntes = saldo.balance;

    const creada = await createTopup(monto);
    setEnviando(false);

    if (!creada.ok) {
      setErrorRecarga(creada.failure.message);
      return;
    }

    setRecargando(false);
    setTexto('');
    setAviso(null);

    // Vuelve cuando el conductor cierra la pestana del pago.
    await WebBrowser.openBrowserAsync(creada.data.url);
    await esperarAcreditacion(saldoAntes);
  }, [esperarAcreditacion, minimo, monto, saldo]);

  if (saldo === null || (!saldo.enforced && movimientos.length === 0)) return null;

  return (
    <Card variant="outlined" padding="md">
      <View style={styles.cabecera}>
        <Wallet size={iconSize.md} color={colors.brand} strokeWidth={iconStrokeWidth} />
        <View style={styles.cabeceraTextos}>
          <Text variant="caption" color="textTertiary">
            SALDO
          </Text>
          <Text variant="title" color={saldo.canWork ? 'textPrimary' : 'danger'}>
            {saldo.balance < 0 ? `-${formatAmount(-saldo.balance)}` : formatAmount(saldo.balance)}
          </Text>
        </View>
        <Button label="Recargar" variant="brand" size="sm" onPress={() => setRecargando(true)} />
      </View>

      <Text variant="caption" color="textSecondary">
        {`La empresa descuenta el ${String(saldo.commissionPercent).replace('.', ',')}% de cada servicio terminado.`}
      </Text>

      {!saldo.canWork && (
        <Text variant="caption" color="danger" style={styles.aviso}>
          {`Tu saldo no alcanza para recibir servicios (mínimo ${formatAmount(saldo.minRequired)}). Recarga para volver a trabajar: la recarga mínima es de ${formatAmount(saldo.minTopup)}.`}
        </Text>
      )}

      {aviso !== null && (
        <Text variant="caption" color="textSecondary" style={styles.aviso}>
          {aviso}
        </Text>
      )}

      {movimientos.length > 0 && (
        <View style={styles.lista}>
          {movimientos.map((m) => (
            <View key={m.id} style={styles.movimiento}>
              <View style={styles.cabeceraTextos}>
                <Text variant="body">{ETIQUETA[m.kind]}</Text>
                <Text variant="caption" color="textTertiary">
                  {new Date(m.createdAt).toLocaleDateString('es-CO', {
                    day: 'numeric',
                    month: 'short',
                  })}
                  {m.reason !== null ? ` · ${m.reason}` : ''}
                </Text>
              </View>
              <Text variant="bodyStrong" color={m.amount < 0 ? 'textSecondary' : 'brand'}>
                {conSigno(m.amount)}
              </Text>
            </View>
          ))}
        </View>
      )}

      <Modal
        visible={recargando}
        onRequestClose={() => setRecargando(false)}
        title="Recargar saldo"
        description={`Elige cuánto quieres recargar. El mínimo es ${formatAmount(minimo)}. Pagas en la página segura de Wompi; AmalfiGoApp no ve los datos de tu tarjeta.`}
        confirmLabel="Ir a pagar"
        onConfirm={() => void recargar()}
        confirmLoading={enviando}
      >
        {/* El diálogo centra su contenido, y un campo sin ancho propio se encoge
            a lo que mide su texto: con el campo vacío quedaba del tamaño de su
            marcador de posición. Este contenedor le da todo el ancho. */}
        <View style={styles.cuerpo}>
          <View style={styles.montos}>
            {montosSugeridos(minimo).map((m) => (
              <Pressable
                key={m}
                accessibilityRole="button"
                accessibilityLabel={`Recargar ${formatAmount(m)}`}
                onPress={() => setTexto(String(m))}
                style={[
                  styles.monto,
                  {
                    borderColor: monto === m ? colors.brand : colors.border,
                    backgroundColor: monto === m ? colors.brandSubtle : 'transparent',
                  },
                ]}
              >
                <Text variant="bodyStrong">{formatAmount(m)}</Text>
              </Pressable>
            ))}
          </View>
          <Input
            value={formatAmountInput(texto)}
            onChangeText={(t) => setTexto(sanitizeOfferText(t))}
            placeholder="Otro valor en pesos"
            keyboardType="number-pad"
            errorText={errorMonto ?? undefined}
          />
          <FormError message={errorRecarga} />
        </View>
      </Modal>
    </Card>
  );
}

const styles = StyleSheet.create({
  aviso: {
    marginTop: spacing.sm,
  },
  cabecera: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
    marginBottom: spacing.xs,
  },
  cabeceraTextos: {
    flex: 1,
  },
  cuerpo: {
    width: '100%',
  },
  lista: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  monto: {
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    flex: 1,
    paddingVertical: spacing.sm,
  },
  montos: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  movimiento: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.md,
  },
});
