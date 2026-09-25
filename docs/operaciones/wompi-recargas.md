# Recargas del conductor con Wompi: investigación y diseño (D278, punto 3)

Investigación hecha el 2026-09-24 contra la documentación pública de Wompi
Colombia. **Nada de esto está programado todavía.** La primera entrega del punto 3
(libro de movimientos, comisión del 4% y bloqueo por saldo) ya está en producción,
apagada; esta es la segunda: que el conductor recargue solo, sin que un
administrador acredite a mano.

## 1. Qué exige Wompi (lo que la empresa tiene que hacer)

- **Alta como comercio en `comercios.wompi.co`.** Persona jurídica: documento del
  representante legal, RUT actualizado y una cuenta bancaria a nombre del NIT.
  Solo atienden comerciantes domiciliados en Colombia. La activación llega por
  correo; hay que llenar formularios y esperar.
- **Cuatro llaves por ambiente** (sandbox y producción son independientes, no se
  mezclan): pública (`pub_test_` / `pub_prod_`), privada (`prv_...`), secreto de
  eventos (`test_events_` / `prod_events_`) e integridad (`test_integrity_` /
  `prod_integrity_`). Las de sandbox se pueden sacar antes de que la empresa esté
  activada, y con ellas se puede construir y probar todo.
- **Una URL de eventos por ambiente** (sandbox y producción), configurada en el
  panel de Wompi.

## 2. Cómo funciona el cobro (Web Checkout)

1. El servidor arma la URL del checkout con: llave pública, moneda `COP`, monto en
   **centavos** (`$10.000` = `1000000`), una **referencia única** y la **firma de
   integridad** = `SHA256(referencia + monto_en_centavos + "COP" + secreto_de_integridad)`.
   **La firma se calcula en el servidor**: si el secreto de integridad viaja en la
   app, cualquiera podría fabricarse un pago por el monto que quiera.
2. El conductor paga en la página de Wompi (tarjeta, PSE, Nequi, Bancolombia, QR,
   corresponsal...). Wompi lo devuelve a una `redirect-url`.
3. **La app NO decide si el pago valió.** Wompi manda un `POST` a nuestra URL de
   eventos (`transaction.updated`) con esta forma:
   `{ event, data: { transaction: {...} }, signature: { properties, checksum }, timestamp, sent_at }`.
4. Estados de una transacción: `PENDING`, `APPROVED`, `DECLINED`, `VOIDED` (solo
   tarjetas) y `ERROR`. Solo `APPROVED` acredita.

## 3. La parte que no se negocia: verificar el webhook

Cualquiera que conozca la URL puede mandarle un POST falso. Antes de acreditar:

1. **Verificar el checksum**: concatenar los valores que indica `signature.properties`
   (rutas dentro del evento, p. ej. `transaction.id`, `transaction.status`,
   `transaction.amount_in_cents`), añadir el `timestamp` y el **secreto de eventos**,
   aplicar SHA256 y comparar con `signature.checksum` (y con la cabecera
   `X-Event-Checksum`), en tiempo constante. **La lista de propiedades varía por
   evento: no se fija en el código, se lee del evento.**
2. **Doble comprobación**: con la llave privada, `GET /v1/transactions/{id}` y
   confirmar que el estado es `APPROVED` y que monto y referencia coinciden con la
   recarga que nosotros creamos. Es defensa en profundidad: aunque se filtrara el
   secreto de eventos, no se acredita nada que Wompi no confirme.
3. **Idempotencia**: `driver_ledger.external_ref` ya es único (D278). Wompi
   reintenta hasta 3 veces (a los 30 min, 3 h y 24 h) si no recibe un `200`, y un
   mismo pago puede llegar más de una vez: la segunda vez no puede acreditar.
4. Responder `200` siempre que el evento se haya procesado o descartado a
   propósito; un error sin sentido solo provoca reintentos.

## 4. Diseño propuesto

- **Tabla `topup_intents`**: `id`, `driver_id`, `reference` (única, alfanumérica con
  guiones, la que va a Wompi), `amount` (pesos), `status`
  (`pending` / `approved` / `declined` / `expired`), `wompi_transaction_id`,
  `created_at`. Cada recarga nace aquí, **antes** de que el conductor pague: así el
  monto acreditado sale de lo que nosotros creamos y nunca de lo que diga el pago.
- **Edge Function `create-topup`** (con la sesión del conductor): valida que sea un
  conductor, que el monto sea entero y ≥ `min_topup_amount`, crea la intención y
  devuelve la URL del checkout ya firmada. Es la primera Edge Function del proyecto.
- **Edge Function `wompi-webhook`** (sin JWT, porque la llama Wompi): verifica firma,
  consulta la transacción, y llama a una función SQL **`credit_driver_topup`**
  ejecutable solo por `service_role`, que anota el `topup` en el libro y marca la
  intención como aprobada, en una sola transacción.
- **App**: botón "Recargar" en la tarjeta de saldo (hoy no existe a propósito) →
  elegir monto → abrir el checkout con `expo-web-browser` (ya está instalado) →
  al volver, releer el saldo. Como el crédito llega por el webhook y no por el
  regreso del navegador, la pantalla tiene que tolerar unos segundos de retraso.
- **Secretos**: `WOMPI_PRIVATE_KEY`, `WOMPI_EVENTS_SECRET`, `WOMPI_INTEGRITY_SECRET`,
  `WOMPI_PUBLIC_KEY` y `WOMPI_ENV` como secretos de las Edge Functions
  (`supabase secrets set`), **nunca en el repositorio ni en la app**. Los pone quien
  tenga las llaves, no el asistente.
- **Página de retorno** en `amalfigo.app` ("Pago recibido, vuelve a la app").

## 5. Lo que cuesta

Plan Avanzado (el normal): **2,65% + $700 + IVA por transacción aprobada**, en
tarjetas, PSE, Nequi y Bancolombia; el **QR es 1%** más IVA. El dinero llega a la
cuenta bancaria al siguiente día hábil.

| Recarga                   | Comisión de Wompi (2,65% + $700 + IVA 19%) | % de la recarga |
| ------------------------- | ------------------------------------------ | --------------- |
| $10.000                   | $1.148                                     | 11,5%           |
| $20.000                   | $1.463                                     | 7,3%            |
| $50.000                   | $2.410                                     | 4,8%            |
| $10.000 por QR (1% + IVA) | $119                                       | 1,2%            |

Contexto: la comisión de la empresa por servicio mínimo es $160. Con recargas de
$10.000 la pasarela se lleva más de una décima parte del ingreso. Hay tres
palancas, y es decisión de la empresa: **subir la recarga mínima** (el ajuste
`min_topup_amount` ya existe), **cobrarle al conductor la comisión de la pasarela**
sumándola al valor del checkout, o **empujar el QR** de Bancolombia.

## 6. Riesgos y asuntos legales (no son código)

- **Contracargos.** En pagos con tarjeta sin presencia física, el riesgo de fraude y
  de que el titular desconozca el pago **lo asume la empresa como comercio**
  (Reglamento de Comercios de Wompi, 6.9.2). Si un conductor recarga con tarjeta
  ajena, gasta el saldo y el titular reclama, Wompi descuenta ese valor de los
  ingresos de la empresa (6.9.4) y puede retener ingresos hasta 180 días (6.7). El
  libro ya permite reversar con un ajuste en contra y motivo, pero el saldo ya
  gastado no se recupera. Mitigaciones posibles: recargar solo por PSE/Nequi/QR (sin
  contracargo de tarjeta), o un tope diario por conductor.
- **¿Es "saldo prepagado" un servicio que Wompi admite?** Wompi dice que no presta
  servicios financieros y que habilita pagos por "bienes o servicios que ofreces"
  (2.1.3, 2.1.7). Una recarga de saldo que solo se consume en comisiones de la
  propia plataforma se parece a un servicio prepagado, pero **hay que preguntárselo
  a Wompi por escrito al hacer el alta**, porque un saldo que el conductor pudiera
  retirar o transferir sí sería otra cosa. Hoy el diseño no permite retirar.
- **Contabilidad e impuestos.** Un saldo prepagado es dinero recibido por adelantado
  por servicios que aún no se prestan; la facturación electrónica y el IVA sobre la
  comisión deben verlos el contador de la empresa. **No es asesoría legal.**
- **Textos legales y tienda.** La política de privacidad y los términos tienen que
  decir que hay pagos y quién los procesa, y la declaración de "Seguridad de los
  datos" de Play Console, revisarse. La app no guardará datos de tarjeta: el pago
  ocurre en la página de Wompi.

## 7. Orden de trabajo sugerido

1. Sandbox: la empresa (o quien tenga la cuenta) crea el comercio de pruebas y
   entrega las cuatro llaves de sandbox **directamente como secretos de Supabase**.
2. Tabla `topup_intents` + función `credit_driver_topup` + pruebas SQL.
3. Edge Function `wompi-webhook`, con pruebas de firma válida, firma inválida,
   monto que no coincide y evento repetido.
4. Edge Function `create-topup` y el botón en la app.
5. Prueba de punta a punta en sandbox, con tarjetas de prueba de Wompi.
6. Alta de producción, llaves de producción, URL de eventos de producción, textos
   legales, y solo entonces encender `driver_balance_enforced`.
