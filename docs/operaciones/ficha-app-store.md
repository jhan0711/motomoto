<!--
  Borrador de la ficha de App Store Connect. iOS, Fase B (2026-10-08).
  Se rellena en App Store Connect cuando la cuenta de Apple Developer este
  pagada y aprobada. No lo lee ninguna herramienta.

  Se adapta de `ficha-play-store.md`, pero NO es una copia: aquel documento se
  escribio cuando la app no cobraba ni usaba ubicacion en segundo plano, y hoy si
  hacen las dos cosas (D116, D271, D278, D279). Lo que diga la ficha de Apple
  tiene que coincidir con lo que hace la app: Apple lo comprueba al revisar.
-->

# Ficha de App Store — AmalfiGoApp

## 0. Antes de rellenar nada

| Qué                                                                                                                                                                                                                                                                         | Estado                                                                             |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Cuenta de Apple Developer pagada** (USD 99/año)                                                                                                                                                                                                                           | **FALTA** (Jhan)                                                                   |
| **Tipo de cuenta: individual u organización.** En individual, la tienda muestra tu nombre personal como vendedor. Organización exige una empresa con número D-U-N-S y es lo que ve el público como "Vendedor". Se decide ANTES de pagar y no se cambia después sin soporte. | **DECISIÓN TUYA**                                                                  |
| **Política de privacidad actualizada.** Hoy dice "La aplicación no procesa pagos" y no habla de Wompi ni de ubicación en segundo plano (D279). Apple abre la URL al revisar y compara con la sección "App Privacy" de abajo.                                                | **FALTA** — mismo pendiente que en Play, depende del abogado                       |
| **Titular del copyright** para el campo "Copyright" (`© 2026 <nombre>`).                                                                                                                                                                                                    | **FALTA** — depende del tipo de cuenta                                             |
| **Capturas reales de iPhone.** Las de `assets/store/capturas-ios/` son provisionales (ver sección 2).                                                                                                                                                                       | Se toman en la fase E, con TestFlight                                              |
| **Video del flujo completo** para el revisor (ver sección 6, riesgo 1).                                                                                                                                                                                                     | **FALTA** — se graba con la tablet (pasajero) y un teléfono o emulador (conductor) |

---

## 1. Información de la app

| Campo                   | Valor                                                                                                               | Límite       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------ |
| Nombre                  | `AmalfiGoApp`                                                                                                       | 30           |
| Subtítulo               | `Mototaxi en Amalfi, Antioquia`                                                                                     | 30 (usa 29)  |
| Texto promocional       | `Pide un motocarro en Amalfi, ve el valor antes de confirmar y sigue a tu conductor en el mapa.`                    | 170 (usa 94) |
| Palabras clave          | `mototaxi,motocarro,Amalfi,Antioquia,transporte,taxi,moto,encomienda,conductor,viaje,Colombia`                      | 100 (usa 92) |
| Idioma principal        | **Español (México)** — App Store Connect no tiene "Español (Colombia)"; es el que Apple usa para toda Latinoamérica | —            |
| Categoría principal     | **Viajes** (Travel)                                                                                                 | —            |
| Categoría secundaria    | **Navegación**                                                                                                      | —            |
| URL de soporte          | `https://amalfigo.app`                                                                                              | —            |
| URL de marketing        | `https://amalfigo.app`                                                                                              | opcional     |
| URL política privacidad | `https://amalfigo.app/privacidad`                                                                                   | —            |
| Correo de contacto      | `soporte@amalfigo.app`                                                                                              | —            |
| Copyright               | `© 2026 <titular>`                                                                                                  | **FALTA**    |
| Precio                  | Gratis                                                                                                              | —            |
| Disponibilidad          | **Colombia** únicamente                                                                                             | —            |

Las palabras clave no repiten el nombre ni la categoría (Apple ya los indexa) y
van sin espacios después de la coma: cada espacio gasta uno de los 100
caracteres.

### Descripción (máx. 4000)

```
AmalfiGoApp conecta a quien necesita un mototaxi en Amalfi, Antioquia, con los
conductores disponibles del municipio.

CÓMO FUNCIONA
• Escribe a dónde vas. La app reconoce las veredas y los sitios de Amalfi que
  ningún mapa tiene.
• Ve el valor oficial del servicio ANTES de confirmar. Si quieres, propón otro
  valor: el conductor decide si lo acepta.
• Cuando un conductor acepta, lo sigues en el mapa mientras llega y ves su placa
  y su número de unidad.
• Al terminar, califican los dos.

PAGO
El pasajero paga en efectivo, directamente al conductor. La app no cobra el
viaje.

TAMBIÉN
• Encomiendas: manda un paquete sin ir tú.
• Historial de tus servicios.

PARA CONDUCTORES
• Recibe solicitudes cerca de ti, ve el valor que ofrece el pasajero y acepta la
  que quieras.
• Sigue enviando tu ubicación aunque minimices la app, para que el pasajero te
  vea llegar.
• Recarga tu saldo desde la app para cubrir la comisión por servicio.
• La cuenta de conductor la crea la empresa.

AmalfiGoApp es para Amalfi, Antioquia. Hoy no funciona en otros municipios.
```

**Dos frases que dependen de cosas que aún no están encendidas:** la del saldo
y la comisión describe `driver_balance_enforced`, que hoy está apagado (D278).
Si la ficha se publica antes de encenderlo, se quita esa línea; si se publica
después, tiene que seguir ahí. Apple rechaza una ficha que prometa algo que la
app no hace, y también una app que cobra algo que la ficha no dice.

---

## 2. Capturas

| Tamaño                          | Especificación                | Estado                                                                                                     |
| ------------------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------- |
| iPhone 6,9" (único obligatorio) | 1290 × 2796 PNG/JPG, sin alfa | **Provisionales** en `assets/store/capturas-ios/` (7). Las genera `assets/brand/store-ios-screenshots.mjs` |
| 6,5" / 5,5" / iPad              | —                             | No hacen falta: App Store escala el de 6,9". iPad no aplica (`supportsTablet: false`)                      |

Son las 7 capturas de Play (1080 × 2340, la misma proporción) ampliadas, no
capturas de un iPhone. Sirven para dejar la ficha armada, pero hay dos motivos
para **reemplazarlas** antes del envío:

1. **Una está desactualizada.** `5-tarifa.png` es de antes de D277: no muestra
   el campo "¿Cuánto ofreces por el viaje?" que hoy tiene esa pantalla. Las
   otras seis habría que contrastarlas con la app actual.
2. **Apple prefiere (y a veces exige, regla 2.3.3) capturas del producto real en
   un iPhone.** No llevan barra de estado ni marco de Android, así que no
   delatan la plataforma, pero las de TestFlight no dejan duda.

Orden sugerido al rehacerlas: bienvenida, inicio, tarifa (con el precio
ofrecido), conductor en camino, historial, perfil, y la del conductor
("Nueva solicitud"). Apple muestra las tres primeras en los resultados de
búsqueda: que sean las más claras.

---

## 3. Privacidad de la app ("App Privacy")

Es el equivalente a "Data Safety" de Play, pero con categorías de Apple.
Respuesta a "¿recopilan datos?": **Sí.** Todos "vinculados a la identidad del
usuario" (tiene cuenta) y **ninguno se usa para rastrear** (no hay publicidad,
ni analítica de terceros, ni se cruzan datos con otras apps). Por eso en
"Tracking" la respuesta es **No**, y no hace falta el aviso de
`AppTrackingTransparency`.

| Categoría de Apple      | Tipo                       | Qué es en la app                                                                    | Uso                     |
| ----------------------- | -------------------------- | ----------------------------------------------------------------------------------- | ----------------------- |
| Información de contacto | Nombre                     | Cuenta; el conductor ve el nombre del pasajero                                      | Funcionalidad de la app |
| Información de contacto | Correo electrónico         | Cuenta, inicio de sesión, recuperación                                              | Funcionalidad de la app |
| Información de contacto | Número de teléfono         | La contraparte del viaje coordina la recogida                                       | Funcionalidad de la app |
| Ubicación               | Ubicación precisa          | Mapa, tarifa, emparejar y seguir el viaje; **en segundo plano** en conductores      | Funcionalidad de la app |
| Contenido del usuario   | Fotos o videos             | Foto de perfil, **opcional**                                                        | Funcionalidad de la app |
| Contenido del usuario   | Otro contenido del usuario | Comentario de la calificación, referencia de recogida, descripción de la encomienda | Funcionalidad de la app |
| Identificadores         | ID del dispositivo         | Token de notificaciones push                                                        | Funcionalidad de la app |
| Compras                 | Historial de compras       | Recargas de saldo del conductor y comisiones cobradas (D278, D279)                  | Funcionalidad de la app |
| Otros datos             | Otros tipos de datos       | Historial de viajes y calificaciones                                                | Funcionalidad de la app |

**NO se recopila:** número de tarjeta ni datos de pago (la recarga se paga en la
página de Wompi, que se abre en el navegador; el número de tarjeta nunca pasa
por la app ni por el servidor), contactos, mensajes, historial de navegación,
datos de salud, analítica de terceros, identificadores de publicidad.

**Dos filas para confirmar con el abogado antes de enviar:**

- **"Compras → Historial de compras"** es mi lectura de cómo encaja el saldo del
  conductor (el libro `driver_ledger`) en las categorías de Apple. Otra lectura
  razonable es "Información financiera → Otra información financiera". No hay
  una respuesta oficial; lo importante es que alguna de las dos esté marcada,
  porque marcar ninguna sería lo menos defendible.
- **Mapbox.** Su SDK en el teléfono puede enviar telemetría propia de uso
  (anónima). Hay que comprobar en el build real si está desactivada; si no lo
  está, hay que declararlo aquí o apagarla. Lo mismo para el "manifiesto de
  privacidad" (`PrivacyInfo.xcprivacy`) de las dependencias, que Apple pide
  desde 2024: es trabajo de la fase C/E, no de esta.

---

## 4. Clasificación por edad

Cuestionario nuevo de Apple (4+, 9+, 13+, 16+, 18+). Respuestas:

| Pregunta                                             | Respuesta                                                                                                  |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Violencia, contenido sexual, lenguaje soez, terror   | Ninguno                                                                                                    |
| Alcohol, tabaco o drogas; apuestas; contenido médico | Ninguno                                                                                                    |
| Acceso web sin restricciones                         | **No** (solo se abre la página de pago de Wompi y el enlace de ayuda, no un navegador libre)               |
| Contenido generado por usuarios                      | **Sí, mínimo:** comentario de calificación y referencia de recogida; no hay chat ni publicaciones públicas |
| Compras dentro de la app                             | **No** (no hay compra de productos digitales; ver riesgo 2 de la sección 6)                                |
| Ubicación compartida con otros usuarios              | **Sí**, durante un viaje                                                                                   |

Resultado esperado: **4+**. Si el cuestionario pide una edad mínima, la
recomendada por el producto es **18+ como público objetivo** (igual que en Play,
sección 6 de `ficha-play-store.md`), pero eso no es lo mismo que la
clasificación por contenido: no hay nada que justifique subirla de 4+.

---

## 5. Revisión de la app ("App Review Information")

| Campo                       | Valor                                                                                           |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| ¿Requiere inicio de sesión? | **Sí**                                                                                          |
| Cuenta de pasajero          | `pasajero.prueba@motomoto-qa.co` (contraseña: la de las notas del proyecto, no se escribe aquí) |
| Cuenta de conductor         | `conductor.prueba@motomoto-qa.co` (ídem)                                                        |
| Contacto                    | Nombre, teléfono y correo de Jhan                                                               |
| Eliminación de cuenta       | En la app: Perfil → "Eliminar mi cuenta". Web: `https://amalfigo.app/eliminar-cuenta`           |
| Sign in with Apple          | **No aplica**: no hay inicio de sesión con terceros, solo correo y contraseña                   |

Las dos cuentas **tienen que seguir existiendo** el día del envío: por eso
`purge_qa_accounts.sql` NO debe borrarlas (D285). Y la contraseña no se guarda
en este repositorio: se pega en el formulario de Apple en su momento.

### Texto para "Notes" (en inglés: lo lee un revisor de Apple)

```
AmalfiGoApp is a ride-hailing app for motorized tricycles ("motocarros") in a
single municipality: Amalfi, Antioquia, Colombia. It is not available elsewhere,
and the service area is enforced on our server, so a reviewer outside Colombia
cannot complete a real ride request by location alone.

To make the review possible we have attached a screen recording of the complete
flow (passenger requests a ride -> driver accepts -> passenger follows the driver
on the map -> both rate each other), and two demo accounts (passenger and
driver). Driver accounts can only be created by the company, there is no public
driver sign-up.

Location: the passenger app uses location while in use. The driver app also uses
location in the background while the driver is available or on a ride, so that
passengers can keep seeing the driver's position. The app shows a prominent
explanation before asking for that permission, and iOS shows its own indicator
while it is in use.

Payments: riders pay the driver in cash, outside the app. Drivers can top up a
prepaid balance inside the app to cover the company's per-ride commission. That
top-up opens Wompi's hosted checkout (a Colombian payment processor) in the
browser. It pays for a real-world transportation service that is delivered and
consumed outside the app, not for digital content or features, so we understand
guideline 3.1.3(e) applies and in-app purchase is not required.

Account deletion: Profile -> "Eliminar mi cuenta" (guideline 5.1.1(v)).
```

---

## 6. Riesgos de la revisión

1. **El revisor no puede probar el servicio por sí mismo.** Está fuera de
   Colombia, no hay conductor real esperando, y el área de servicio la valida el
   servidor (Fase 11A). Es el motivo más común de rechazo en apps de transporte
   locales. Mitigación: el video del flujo completo y las cuentas de demostración
   (sección 5). **Decisión pendiente, no tomada:** si el video no basta, la
   salida es una cuenta de demostración que omita la validación de área, lo que
   es cambio de backend y se discute aparte antes de hacerlo.
2. **Las recargas de Wompi (regla 3.1.1 / 3.1.3).** Apple obliga a usar sus
   compras dentro de la app para "funciones o contenido digital". Un saldo que
   solo sirve para pagar la comisión de un servicio real prestado fuera de la app
   cae, a mi entender, en la excepción 3.1.3(e) (bienes y servicios consumidos
   fuera de la app). Pero **la decisión es de Apple, no mía**, y es un riesgo
   real. Si lo rechazaran, la alternativa sin tocar la app es que el conductor
   recargue desde el panel web o directamente con la empresa, y que la app solo
   muestre el saldo.
3. **Contenido de usuarios (regla 1.2).** Pide filtrar, reportar y bloquear.
   La app tiene reportes (`passenger/report`, `driver/report`) pero **no tiene
   forma de bloquear a un usuario**: lo busqué en `src/` y en las migraciones y
   no existe. La regla apunta a apps con contenido público; aquí solo hay un
   comentario de calificación y una referencia de recogida entre las dos partes
   de un viaje, así que el argumento es que no aplica, pero un revisor podría
   pedirlo. Si lo pide, es trabajo nuevo.
4. **Capturas desactualizadas** (sección 2).
5. **Política de privacidad desactualizada** (sección 0): Apple la lee y la
   compara con "App Privacy".
