<!--
  Borrador de la ficha de Google Play. Fase 26 paso 7.
  Se rellena en Play Console cuando Google verifique la cuenta de desarrollador.
  No lo lee ninguna herramienta.
-->

# Ficha de Google Play — AmalfiGoApp

## 0. Bloqueadores antes de publicar

| Qué                                                                                                                                                         | Estado                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Eliminación de cuenta** (paso 7b) — camino en la app + URL web + función.                                                                                 | **HECHO** (2026-09-04). En la app: Perfil → "Eliminar mi cuenta". Web: `amalfigo.app/eliminar-cuenta`. Falta desplegar el sitio y verlo en el dispositivo (paso 5). |
| **Política de privacidad publicada** — la URL `amalfigo.app/privacidad` está con `noindex` y aviso de borrador. Google la rechaza si no es una página real. | **FALTA.** Depende de la revisión de abogado (paso 3)                                                                                                               |
| **Verificación de identidad** de la cuenta de desarrollador                                                                                                 | En curso (Google, unos días)                                                                                                                                        |

En la sección 4 (Data Safety), la URL de eliminación de datos es
`https://amalfigo.app/eliminar-cuenta`.

---

## 1. Detalles de la app (App content → Store listing)

| Campo                  | Valor                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------ |
| Nombre de la app       | `AmalfiGoApp` (máx. 30)                                                                          |
| Descripción breve      | `Pide un mototaxi en Amalfi. Ve el precio antes y sigue al conductor en el mapa.` (máx. 80 → 79) |
| Categoría de la app    | **Mapas y navegación**                                                                           |
| Etiquetas              | mototaxi, transporte, Amalfi, motorratón                                                         |
| Correo de contacto     | `soporte@amalfigo.app`                                                                           |
| Sitio web              | `https://amalfigo.app`                                                                           |
| Teléfono               | (opcional)                                                                                       |
| Política de privacidad | `https://amalfigo.app/privacidad`                                                                |

### Descripción completa (máx. 4000)

```
AmalfiGoApp conecta a quien necesita un mototaxi en Amalfi, Antioquia, con los
conductores disponibles del municipio.

CÓMO FUNCIONA
• Escribe a dónde vas. La app reconoce las veredas y los sitios de Amalfi que
  ningún mapa tiene.
• Ve el valor del servicio ANTES de confirmar. La tarifa la fija la empresa de
  motorratones, no cambia al final.
• Cuando un conductor acepta, lo sigues en el mapa mientras llega y ves su placa
  y su número de unidad.
• Al terminar, califican los dos.

PAGO
El pago es en efectivo, directamente al conductor. La app no cobra ni procesa
pagos.

TAMBIÉN
• Encomiendas: manda un paquete sin ir tú.
• Historial de tus servicios.
• Para conductores: recibe solicitudes, acepta la que quieras y lleva el
  control de tu recaudo del día. La cuenta de conductor la crea la empresa.

AmalfiGoApp es para Amalfi, Antioquia. Hoy no funciona en otros municipios.
```

---

## 2. Gráficos (Store listing → Graphics)

| Recurso                                | Especificación                                                 | Estado                                                                                                                                                                                              |
| -------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Icono                                  | 512 × 512 PNG, 32 bits                                         | **Existe:** `assets/images/icon.png`                                                                                                                                                                |
| Gráfico de funciones (feature graphic) | 1024 × 500 PNG/JPG, sin texto crítico en los bordes            | **HECHO:** `assets/store/feature-graphic.png` (lo genera `assets/brand/feature-graphic.mjs`)                                                                                                        |
| Capturas de teléfono                   | 2 a 8, PNG/JPG, lado mín. 320 px, máx. 3840, ratio 16:9 o 9:16 | **7 hechas y uniformes** en `assets/store/capturas/` (1080×2340, sin barra de estado). 1-4: bienvenida, inicio, perfil, historial. 5-7: tarifa, conductor en camino, solicitud del conductor (viaje simulado del 2026-09-09). Nota: `2-inicio` saluda a "Ana Gomez" y `3-perfil` es de "Camila Restrepo" — inconsistencia de la cuenta de prueba, no bloquea |
| Capturas de tablet 7" / 10"            | Opcionales                                                     | —                                                                                                                                                                                                   |

**Las 3 capturas que faltaban — HECHAS (2026-09-09).** Viaje simulado
pasajero (tablet, vc 8) ↔ conductor (emulador), cuentas QA
`pasajero.prueba@` / `conductor.prueba@`, ruta Alto de la Virgen → El parque
($4.000):

1. `5-tarifa.png` — el resumen con la tarifa y "Confirmar servicio".
2. `6-conductor-en-camino.png` — "Un motorratón tomó tu servicio", con el
   motorratón en el mapa acercándose a la recogida.
3. `7-solicitud-conductor.png` — la tarjeta "Nueva solicitud" del conductor
   (Aceptar / Rechazar).

---

## 3. Clasificación de contenido (App content → Content rating)

Cuestionario IARC. Categoría: **Referencia, noticias o educación** → no; usar
**Todas las demás / Utilidad**.

| Pregunta                                                   | Respuesta                                                                                                                                       |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| ¿Violencia?                                                | No                                                                                                                                              |
| ¿Contenido sexual?                                         | No                                                                                                                                              |
| ¿Lenguaje soez?                                            | No                                                                                                                                              |
| ¿Sustancias controladas (drogas, alcohol, tabaco)?         | No                                                                                                                                              |
| ¿Juegos de azar / apuestas?                                | No                                                                                                                                              |
| ¿Miedo / terror?                                           | No                                                                                                                                              |
| ¿Los usuarios pueden interactuar o intercambiar contenido? | **Sí** — hay calificaciones con comentario entre pasajero y conductor, y reportes. Compartir el número de teléfono con la contraparte del viaje |
| ¿Comparte la ubicación del usuario con otros usuarios?     | **Sí** — durante un viaje, el conductor ve la ubicación del pasajero y viceversa                                                                |
| ¿Permite comprar productos digitales?                      | No                                                                                                                                              |

Resultado esperado: apto para todo público / PEGI 3, con el aviso de
"interacción entre usuarios" y "ubicación compartida".

---

## 4. Seguridad de los datos (App content → Data safety)

**Puntos generales:**

- ¿Se cifran los datos en tránsito? **Sí** (HTTPS / Supabase).
- ¿El usuario puede pedir que se borren sus datos? **Sí** (cuando exista el
  paso 7b). URL: `https://amalfigo.app/eliminar-cuenta`.
- ¿Se recopilan datos? **Sí.** ¿Se comparten con terceros? **No** (ver nota).

**Nota sobre "compartir":** el teléfono y la ubicación en viaje se muestran a la
**contraparte del viaje** (otro usuario de la app), no a un tercero. En el
formulario de Google eso es "los usuarios pueden ver estos datos de otros
usuarios", no "se comparte con terceros".

| Tipo de dato                                 | ¿Se recopila? | ¿Se comparte? | Propósito                                                       | ¿Opcional?              |
| -------------------------------------------- | ------------- | ------------- | --------------------------------------------------------------- | ----------------------- |
| Nombre                                       | Sí            | No            | Cuenta; el conductor ve el nombre del pasajero del viaje        | Obligatorio             |
| Correo electrónico                           | Sí            | No            | Cuenta, autenticación, recuperación                             | Obligatorio             |
| Número de teléfono                           | Sí            | No            | Que la contraparte del viaje coordine la recogida               | Obligatorio             |
| Foto de perfil                               | Sí            | No            | La contraparte del viaje identifica a quién recoge/sube         | **Opcional**            |
| Ubicación aproximada y precisa               | Sí            | No            | Mostrar en el mapa, calcular tarifa, emparejar, seguir el viaje | Obligatorio para operar |
| Historial de la app (viajes, calificaciones) | Sí            | No            | Historial del usuario, cálculo de tarifas y reputación          | Obligatorio             |
| ID de dispositivo (token de notificaciones)  | Sí            | No            | Enviar avisos del viaje (push)                                  | Obligatorio             |

**NO se recopila:** información financiera o de pago (el pago es en efectivo al
conductor, D8/D217), contactos, mensajes, historial de navegación, actividad de
otras apps, datos de salud, analítica de terceros, identificadores de
publicidad. **La app no tiene anuncios.**

---

## 5. Permisos y APIs sensibles (App content → Permissions)

| Permiso                                                 | Uso                                                                                                                                            |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`       | **Solo en primer plano.** Ubicar al pasajero en el mapa, fijar el punto de recogida, y seguir el viaje. **No hay ubicación en segundo plano.** |
| `POST_NOTIFICATIONS`                                    | Avisos del viaje (conductor asignado, en camino, llegó)                                                                                        |
| `CAMERA`                                                | Tomar la foto de perfil (opcional)                                                                                                             |
| `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` | Conexión con el servidor                                                                                                                       |
| `VIBRATE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`        | Notificaciones (los pone `expo-notifications`)                                                                                                 |

**Declaración de ubicación** (Google la exige aparte): la app usa ubicación en
primer plano para el servicio principal —pedir y seguir un mototaxi—. Sin
segundo plano. Aviso previo ("prominent disclosure") ya está en la pantalla de
permiso de ubicación (`src/features/map/location-gate.tsx`).

---

## 6. Público objetivo y contenido (App content → Target audience)

| Campo                  | Valor                                                                                           |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| Rango de edad objetivo | **18 años o más** (es un servicio de transporte con pago en efectivo y coordinación telefónica) |
| ¿Dirigida a niños?     | No                                                                                              |
| Anuncios               | No contiene                                                                                     |

---

## 7. Configuración de la tienda (Store settings)

| Campo               | Valor                   |
| ------------------- | ----------------------- |
| Tipo de app         | App (no juego)          |
| Precio              | Gratis                  |
| Países / regiones   | **Colombia** únicamente |
| ¿Contiene anuncios? | No                      |
| ¿Compras en la app? | No                      |

---

## 8. Plan de lanzamiento

La cuenta de desarrollador es **personal** y reciente, así que Google exige una
**prueba cerrada con ≥ 12 testers durante ≥ 14 días** antes de poder promover a
producción.

1. **Prueba interna** (internal testing): subir el primer AAB (paso 5), instalar
   en la tablet y en 1-2 teléfonos, verificar el ciclo completo.
2. **Prueba cerrada** (closed testing): añadir ≥ 12 testers -conductores de
   Amalfi + conocidos-. Mantenerla 14 días. Recoger fallos.
3. **Producción:** solicitar acceso, y cuando Google lo apruebe, publicar.
   Antes: correr `purge_qa_accounts.sql`.
