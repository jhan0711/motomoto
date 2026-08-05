import { useEffect, useState } from 'react';

/**
 * Cuenta atras en segundos, arrancada desde un valor que da el servidor.
 *
 * Por que recibe el punto de partida en lugar de calcularlo. El servidor manda
 * cuantos segundos quedan, no la hora de caducidad, precisamente para no depender
 * del reloj del telefono: un aparato desajustado unos minutos ensenaria una
 * cuenta atras falsa, y en un aviso de "tu solicitud caduca en" eso es mentir.
 * A partir de ahi el descuento local es de fiar, porque mide tiempo transcurrido
 * y no compara relojes.
 *
 * Devuelve null cuando no hay nada que contar, que es distinto de devolver cero:
 * cero significa "se acabo el tiempo" y null significa "no se sabe". La pantalla
 * los pinta distinto y confundirlos ensenaria una expiracion que no ha ocurrido.
 *
 * `resetKey` es lo que identifica a que se esta contando, y no es opcional por
 * capricho. La primera version reiniciaba cuando cambiaba el numero de partida,
 * y eso esta mal: dos solicitudes seguidas arrancan las dos en los mismos
 * segundos, asi que el numero no cambiaba, la cuenta se quedaba en cero y la
 * pantalla seguia diciendo "expirado" sobre una solicitud recien creada. En
 * produccion habrian sido 300 y 300 siempre. El valor no sirve como identidad.
 */
export function useCountdown(from: number | null, resetKey: string | null): number | null {
  const [restantes, setRestantes] = useState<number | null>(from);

  // Reinicio en el render, no en un efecto. Con un efecto habria un fotograma
  // con la cuenta anterior, y en la fase 10 ya se aprendio que ese fotograma se
  // ve. Mismo patron que el modo de la hoja del pasajero.
  const [anterior, setAnterior] = useState({ from, resetKey });
  if (from !== anterior.from || resetKey !== anterior.resetKey) {
    setAnterior({ from, resetKey });
    setRestantes(from);
  }

  useEffect(() => {
    if (from === null) return;

    const id = setInterval(() => {
      setRestantes((actual) => {
        if (actual === null) return null;
        return actual <= 0 ? 0 : actual - 1;
      });
    }, 1000);

    return () => clearInterval(id);
  }, [from, resetKey]);

  return restantes;
}

/** Minutos y segundos, como se lee un cronometro: 4:07. */
export function formatCountdown(seconds: number): string {
  const seguros = Math.max(0, seconds);
  const minutos = Math.floor(seguros / 60);
  const resto = seguros % 60;
  return `${minutos}:${String(resto).padStart(2, '0')}`;
}
