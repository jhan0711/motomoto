# PROJECT_STATUS.md

Documento de continuidad del proyecto. Si se pierde el contexto de una conversacion,
este archivo contiene todo lo necesario para retomar el trabajo desde el ultimo punto estable.

- **Proyecto:** MotoMoto (nombre provisional)
- **Ultima actualizacion:** 2026-08-27
- **Fases completadas y aprobadas:** 0 definicion funcional, 1 preparacion del equipo,
  2 creacion del proyecto, 3 sistema de diseno, 4 navegacion, 5 base de datos,
  6 autenticacion, 7 perfil del pasajero, 8 mapa principal,
  9 seleccion de origen y destino, 10 seleccion de pasajeros,
  11 creacion de solicitud, 12 modulo del conductor, 13 asignacion en tiempo real,
  14 seguimiento del conductor, 15 ciclo completo del servicio, 16 historial,
  17 calificaciones, 18 cancelaciones y errores operativos (comprometida por el usuario el
  2026-08-21)
- **Ademas, terminado:** **D161, recoger pasajeros en ruta**, que no es una fase del plan
  original y sustituye a la regla R7. Con el se adelanto de la Fase 14 el dibujo de la ruta
- **Fase 15 terminada:** el servicio se mueve por sus cinco estados desde la pantalla del
  conductor, el pasajero ve en cual va y se despide al terminar, y el recorrido queda
  registrado. Detalle en la seccion 15.15
- **El mapa ya es Mapbox.** Se cambio justo despues de la Fase 15, fuera del plan de fases,
  para cerrar el hallazgo H18. Detalle en la seccion 15.16
- **Fase 16 terminada y aprobada:** las dos partes tienen historial. El
  pasajero ve sus servicios terminados, cancelados y caducados; el conductor ve sus ofertas
  con su desenlace, **incluidas las que rechazo**. Detalle en la seccion 15.17
- **Fase 17 terminada y aprobada:** las dos partes se califican, al terminar o
  despues desde el historial, y el promedio del conductor ya se ve en su perfil. Detalle en la
  seccion 15.18
- **HAY TABLET OTRA VEZ** desde el 2026-08-20, una Xiaomi con Android 15 y sin GPS. Lo que
  cambia y lo que no, en el bloque LEE ESTO PRIMERO
- **Fase 18 APROBADA Y COMPROMETIDA POR EL USUARIO EL 2026-08-21.** Cancelaciones de las dos
  partes, con confirmacion, sin el boton en `in_progress`, y D187 resuelto para las dos ramas
  de la cancelacion del conductor. Detalle en la seccion 15.19
- **Fase 19 terminada, aprobada y comiteada el 2026-08-25.** Notificaciones push para los dos
  avisos que pide el flujo, **los dos vistos llegar a la bandeja del sistema en aparatos
  distintos, sonando y flotando**. Hizo falta un proyecto de Firebase ademas del de Expo, y el
  canal de Android costo tres intentos. Detalle en la seccion 15.20
- **AHORA VIENE UN BLOQUE ESPECIAL ENTRE LA 19 Y LA 20**, pedido por los duenos de la empresa
  el 2026-08-25: encomiendas, pasajero con carga, tarifas, recaudo. **Cambia el alcance del
  MVP: la aplicacion pasa a calcular y mostrar valores** (D217, que modifica a D8). No empieza
  la Fase 20 hasta terminarlo. Alcance completo y matriz de auditoria en la seccion 15.21
- **El bloque especial esta TERMINADO, los ocho pasos.** Servidor, pantalla del pasajero,
  historial y recaudo del conductor, y la regresion de las fases 11 a 19, **HECHOS Y
  VERIFICADOS**, incluidas las correcciones D233/D234 encontradas probando con datos reales.
  **Once archivos de pruebas automaticas en verde**, y una prueba en vivo con la tablet real
  como pasajero y el emulador como conductor. Detalle en la seccion 15.21
- **La Fase 20 esta EMPEZADA. El paso 1 de once esta hecho y verificado:** existe el proyecto
  Next.js del panel en `admin/`, con su acceso administrativo, y **existe por fin un
  administrador de verdad** —no habia ninguno, comprobado contra el servidor—. Detalle en la
  seccion 15.22, con los once pasos acordados
- **El paso 2 tambien esta hecho y verificado:** la auditoria administrativa deja de ser una
  tabla vacia y el bloqueo de cuentas pasa por una funcion que registra quien lo hizo. **Un
  error del asistente en ese paso abrio un agujero por el que un pasajero podia hacerse
  administrador, y lo cazo la prueba de romper**, no la revision del codigo. Corregido y con
  280 comprobaciones automaticas en verde
- **El paso 3 tambien esta hecho y verificado:** el panel tiene su primera pantalla con contenido
  real, el tablero de servicios en curso, **visto funcionando por el usuario con dos servicios de
  verdad**. 291 comprobaciones automaticas en verde
- **El paso 4 resulto ser tres bloques y se partio.** **4a —gestionar los conductores que ya
  existen— esta hecho**, con 315 comprobaciones automaticas en verde y **el mismo hueco de
  seguridad del paso 2 encontrado y corregido en una segunda tabla**. **4b** —dar de alta un
  conductor— **necesita la clave `service_role`**, y **4c** —documentos— **necesita un bucket de
  Storage que no existe**
- **El 4a esta cerrado del todo**, con las pantallas probadas por el usuario y **la auditoria
  comprobada contra sus acciones reales**, no solo contra las sinteticas
- **El paso 5 tambien esta hecho y verificado**, pantallas incluidas: vehiculos y asignacion
  conductor-vehiculo. Con el aparecio **por tercera vez el mismo hueco de escritura directa sin
  auditoria**, ahora en `vehicles` y `driver_vehicle_assignments`
- **Y se hizo el DOBLE TURNO, que no estaba en el plan** (D246): un motorraton lo pueden llevar
  varias personas, con un solo conductor conectado a la vez. **Modifica una regla de la Fase 5.**
  Verificado en servidor con 16 comprobaciones; **falta que el usuario lo vea en pantalla**
- **Los botones del panel dejaron de ser planos**, tambien a peticion suya: hover, pulsacion y
  foco de teclado, centralizados en tres clases
- **El paso 6 entero esta hecho y verificado**, pantallas incluidas. **6a** —lugares y tarifas
  rurales, con D229 aplicada **midiendo la distancia** y no preguntando— **encontro un lugar roto
  en produccion**: "Vereda Guayabito", activa y sin tarifa desde la Fase 9, que quedo desactivada
  conservando sus coordenadas. **6b** —tarifas urbanas, tipos de carga y los 18 parametros—
  **destapo que la politica de escritura de `drivers` seguia abierta desde el paso 4a**, cerrada
  ya. **409 comprobaciones automaticas en verde**
- **El paso 4b esta hecho y verificado**, y con el **el panel ya puede incorporar personal sin
  tocar la base de datos a mano**. Se hizo con una funcion `security definer` y **sin meter la
  clave `service_role`** (D250). **La prueba que lo cierra la hizo el usuario: el conductor creado
  desde el panel entro de verdad en la aplicacion**, que es lo unico que valida E28 y que no se
  puede comprobar desde SQL
- **El paso 4c esta hecho y verificado**, subida de un archivo real incluida, y con el **se acabo
  el hueco de las politicas `_all_admin`**: cero `for all` en todo el esquema, comprobado
- **El paso 7 esta hecho y verificado**, pantallas incluidas. Aparecio de paso que **la
  calificacion del pasajero nunca se habia mirado**: existe desde la Fase 17 en los dos sentidos,
  pero solo la del conductor esta precalculada
- **El paso 8 esta hecho y verificado**, pantallas incluidas. Lo mas util no es el listado sino
  **las ofertas de cada servicio**: dicen a quien le llego, quien rechazo y quien dejo pasar el
  tiempo, que es lo que convierte "nadie lo tomo" en algo accionable
- **LOS 36 DESTINOS RURALES ESTAN COMPLETOS** desde el 2026-08-28. El usuario trajo las ocho
  coordenadas que faltaban y **el esquema no tuvo que cambiar ni una linea**. Comprobado que cada
  uno cobra lo suyo y que **los 33 lugares urbanos siguen en $4.000**
- **Trabajo siguiente:** el paso 9, la asignacion manual de conductor a una solicitud (D7)
- **Ultimo commit:** `2824b65`, "Fase 20 paso 5: motorratones, doble turno y estados de botones".
  Antes, `d6be25a` el paso 4a, `1690efb` el paso 3, `12bb3c2` el paso 2, `475214b` el paso 1 y
  `611e0e8` todo el bloque especial. **SIN COMITEAR: el paso 4c entero** —la migracion
  `20260827190000`; `supabase/dev-tools/prueba_documentos.sql`; el modulo
  `admin/src/features/documents/` y su enganche en las fichas de conductor y de motorraton; **las
  correcciones de los siete sitios que elegian "el primer conductor"** en `prueba_encomiendas`,
  `prueba_recaudo`, `prueba_solicitud_con_valor` y `prueba_tablero`; los tipos regenerados y este
  archivo—. **El commit del paso 3 costo dos intentos**: el primero no llego a hacerse y se
  detecto al verificarlo con `git log` antes de empezar el paso siguiente, que es justo para lo
  que se verifica. Lo que sigue de referencia historica: la nota que hubo aqui hasta el
  2026-08-26 decia que quedaban doce archivos del bloque especial sin comitear y **era falsa**,
  estaba fechada el 25 y el usuario comiteo despues. Lo que quedo comiteado en `475214b`: la
  carpeta `admin/` entera, `supabase/dev-tools/seed_admin.sql`, el aislamiento del panel en
  `tsconfig.json`, `eslint.config.js`, `.prettierignore` y `.gitignore`, y la actualizacion de
  este archivo**
- **Carpeta del proyecto:** C:\dev\motomoto
- **Repositorio:** https://github.com/jhan0711/motomoto (privado)

---

## LEE ESTO PRIMERO

Si eres un asistente que acaba de recibir este archivo, esto es lo que necesitas antes de
escribir una sola linea. El detalle completo esta en la seccion 17; esto es lo que no se
puede negociar.

**Quien es el usuario.** Nunca habia desarrollado una aplicacion movil. Su experiencia es
web y QA. Trabaja en Windows y desarrolla solo. **Prefiere respuestas cortas**: los mensajes
largos con muchas tablas y alternativas le confunden. Una cosa por mensaje.

**Como se trabaja aqui, en cinco reglas:**

1. **Estrictamente por fases.** No se empieza una fase sin que el la autorice de forma
   expresa, ni aunque parezca obvio. Cada fase termina en un checklist de validacion, nunca
   en la fase siguiente.
2. **Verificar, no suponer.** Nada se da por bueno porque el codigo compile o el SQL parezca
   correcto. Se comprueba contra el servidor, se ejecuta en el emulador y se toma captura.
   **Una captura no se juzga a ojo**: se contrasta contra el dato.
3. **Probar intentando romper.** Despues de cada migracion se escribe un script que intenta
   violar cada restriccion a proposito. Ese metodo ha encontrado fallos que ninguna revision
   de codigo habria visto.
4. **Ante un error, parar.** Se diagnostica la causa real, se aplica **una sola** correccion
   controlada y se verifica. No se cambian varias cosas a la vez, y no se deja puesto un
   cambio hecho sobre una hipotesis que resulto falsa.
5. **Reconocer los propios errores sin adornos.** Treinta errores registrados; la mayoria
   fueron del asistente. Estan escritos con su causa y su leccion, y varios los encontro el
   usuario, no las pruebas. Eso se dice tal cual.

**Antes de cada commit:** `npm.cmd run typecheck`, `npm.cmd run lint` y
`npm.cmd run format:check`, los tres en 0. **Los commits los hace el usuario** desde GitHub
Desktop; el asistente no ejecuta git salvo para consultar.

**Cosas del entorno que muerden si se olvidan:**

- En PowerShell, **siempre `npx.cmd` y `npm.cmd`**. Sin el sufijo fallan.
- **Ya no se usa Expo Go.** Hay un cliente de desarrollo propio, instalado en el emulador.
  Solo hay que recompilar si se toca codigo nativo o se anade una libreria.
- Los comandos de `adb` con rutas del dispositivo van por **PowerShell**, no por Git Bash.
- Nada de emojis en la interfaz. Iconos de `lucide-react-native`.
- Los textos que ve el usuario van en **espanol correcto, con tildes**. Los comentarios del
  codigo y de las migraciones van en ingles o sin tildes segun el archivo; mirar el vecino.
- **Indicar siempre la ruta exacta** de cada archivo que se crea o modifica.
- Mantener al final de cada respuesta el bloque **ESTADO DEL PROYECTO**.

**Por donde se sigue: la Fase 20, paso 2 de once.** El paso 1 —el proyecto Next.js del panel y
el acceso administrativo— **esta hecho y verificado**, y con el aparecieron dos cosas que este
documento decia mal: que quedaban doce archivos sin comitear (era falso, `git status` sale
limpio) y, sobre todo, que **no existia ni un solo administrador** pese a que el rol y todas sus
politicas RLS estan desde la Fase 5. Ahora existe: `admin.prueba@motomoto-qa.co` / `Admin.2026`,
creado por `supabase/dev-tools/seed_admin.sql`. **Los once pasos y todo lo verificado estan en la
seccion 15.22.** Tres cosas de ese paso que conviene saber ya:

- **El panel es un proyecto aparte dentro del mismo repositorio**, en `admin/` (D236), con Next
  16, Tailwind (D237) y su propia cadena de `typecheck`, `lint` y `format:check`. **El raiz lo
  ignora**: si se toca la configuracion del raiz, `admin` tiene que seguir excluido
- **Se comprobo que Metro sigue construyendo la aplicacion movil** con ese `node_modules` nuevo
  dentro: bundle de Android real, 200 y 6,59 MB, sin colisiones. **No hizo falta
  `metro.config.js`** y por eso no se puso
- **La guardia del panel esta en `admin/src/proxy.ts`**, no en `middleware.ts`: Next 16 deprecio
  ese nombre. Si al arrancar aparece un error de "falta el export" con el archivo correcto, es
  cache: borrar `admin/.next`

**El paso 1 esta cerrado, con sus dos pruebas de sesion real hechas por el usuario**: entrar como
administrador y ser rechazado usando la cuenta del pasajero. Las hace el usuario porque el
asistente no escribe contrasenas en formularios.

**TRES COSAS DE LA FASE 20 QUE CAMBIAN REGLAS VIEJAS Y HAY QUE SABER ANTES DE TOCAR NADA:**

1. **El mismo hueco de seguridad aparecio CINCO VECES**, en `profiles` (paso 2), `drivers`
   (paso 4a, mal cerrado y rematado en 6b), `vehicles` mas `driver_vehicle_assignments` (paso 5),
   `places` mas `rural_fares` (6a) y `urban_fares`, `cargo_types` y `app_settings` (6b): las
   politicas `_all_admin` de la Fase 5 son `for all`, asi que **un administrador podia cambiar
   cosas con un UPDATE directo y sin dejar rastro**. **Solo quedan abiertas `documents` y
   `document_types`**, que se cierran en el paso 4c. Si se toca alguna de las dos, esto es lo
   primero que hay que mirar.

   **Y ojo con la forma en que se cerro mal la de `drivers`:** en el paso 4a se apreto el
   disparador `protect_driver_columns` y se dio por hecho que bastaba. No bastaba —el disparador
   solo protege cinco columnas—, asi que quedo abierto cambiar `is_available` o borrar la ficha
   de un conductor. **El disparador y la politica protegen cosas distintas.** Lo destapo
   comprobar contra `pg_policies` una frase que el propio asistente acababa de escribir
2. **UN MOTORRATON LO PUEDEN LLEVAR VARIAS PERSONAS desde el 2026-08-27** (D246), porque la
   empresa tiene doble turno. **Se retiro el indice `dva_one_active_per_vehicle` de la Fase 5.**
   Lo que aquel indice protegia se protege ahora en `is_available`: **solo un conductor de los que
   comparten unidad puede estar disponible a la vez**. Un conductor sigue teniendo una sola unidad
3. **En el paso 2 el asistente abrio un agujero por el que un pasajero podia hacerse
   administrador**, al sustituir la comprobacion de `is_admin()` del disparador por una marca de
   transaccion. Lo cazo la prueba de romper. La leccion, en D241: **al apretar una tuerca se
   aflojo otra**, porque las dos protecciones cubrian cosas distintas y se sustituyo una por otra
   en vez de sumarlas

Lo que sigue valiendo del contexto anterior: las fases 0 a 19 estan terminadas,
aprobadas y comiteadas, y el **bloque especial pedido por los duenos de la empresa el
2026-08-25** -encomiendas, pasajero con carga, tarifas y recaudo, que iba antes del panel- **esta
TERMINADO, los ocho pasos, con verificacion en vivo incluida.** Incluye las correcciones D233 -la
tarifa rural cuenta en los dos sentidos- y D234 -"tu ubicacion actual" ya no se pega a un rural
vecino-, encontradas probando con datos reales, y la regresion de las fases 11 a 19 sin hallar
nada roto. El alcance completo, la matriz de auditoria, las decisiones y todo lo hecho estan en
la seccion 15.21, **y hay que leerla antes de empezar la Fase 20**, porque varias de las cosas
que construyo -tarifas, destinos rurales, tipos de carga, recaudo- son justo lo que el panel
tiene que gestionar.

Cuatro cosas de ese bloque que conviene saber ya:

- **Cambia una decision aprobada.** D217 modifica a D8 y al parrafo de la seccion 1: la
  aplicacion pasa a **calcular y mostrar** el valor del servicio. Lo que no cambia es que **no
  procesa pagos**: cobra el conductor, en efectivo, fuera de la aplicacion
- **Dos de los trece requisitos ya estaban hechos** —el historial del conductor (Fase 16) y
  las calificaciones con comentario en los dos sentidos (Fase 17)—, y **la auditoria contra el
  codigo lo confirmo**: no se vuelven a construir. El historial si necesita ampliarse con el
  valor y el tipo de servicio
- **Lo que hace rural a un destino es tener tarifa, no estar lejos** (D218). No hay perimetro
  urbano ni radio. Si el destino no tiene tarifa y esta lejos, no se deja pedir (D219)
- **28 de 36 destinos rurales ya estan cargados y verificados** (D230 a D232). Faltan 8, todos
  sin coordenada: Sorrento, Entrada a la Mina, Los Tanques, La Mina, La Aguacatera, Cajamarca,
  Palmitas, La Blanquita. El radio de D230 ya no es provisional: 3 km, medido contra la
  separacion real

Del historial del conductor, dos detalles que siguen valiendo: **sale de `ride_offers`, no de
`rides`**, porque las ofertas que rechazo tienen que estar; y **el nombre del pasajero y la
referencia del punto de recogida solo viajan si acepto**, aplicado dentro de las funciones y
no en la pantalla.

Antes de ella se hizo un trabajo fuera del plan de fases: **el mapa paso de Google a Mapbox**,
para cerrar el hallazgo H18. Esta terminado y verificado, con su registro en la seccion 15.16.
Lo que hay que saber al retomar:

- **Ya no se usa `react-native-maps`.** El mapa es `@rnmapbox/maps`, y sigue viviendo entero en
  `src/features/map/map.tsx` (D117). Ninguna pantalla importa la libreria
- **Mapbox trabaja en [longitud, latitud]**, al reves que el resto del proyecto. La traduccion
  ocurre solo dentro de `map.tsx`
- **Hay un token secreto mas en el `.env`**, `RNMAPBOX_MAPS_DOWNLOAD_TOKEN`, que solo se usa al
  compilar
- **Si se toca algo del mapa, hay que reiniciar la aplicacion en frio.** La recarga en caliente
  no aplico ninguno de los cambios del mapa en toda la sesion, tres veces seguidas

**La Fase 15 esta terminada y aprobada**, con su registro en la seccion 15.15.

**Cosas del entorno que conviene no redescubrir:**

- Hay **dos conductores de prueba**, los dos capaces de iniciar sesion, y **a los dos les
  caduca la ubicacion a los dos minutos**: hay que reejecutar su archivo justo antes de cada
  prueba. Paso varias veces durante las fases 11 y 12.
  - `supabase/dev-tools/seed_test_driver.sql` -> `conductor.prueba@motomoto-qa.co` /
    `Conductor.2026`, motorraton 99
  - `supabase/dev-tools/seed_second_driver.sql` -> `conductor2.prueba@motomoto-qa.co` /
    `Conductor2.2026`, motorraton 98. Creado en la Fase 13 y a 259 m del parque frente a los
    109 del primero, para poder comprobar el orden por cercania
- Hay tambien un **pasajero de prueba**: `pasajero.prueba@motomoto-qa.co` / `Pasajero.2026`,
  a nombre de Ana Gomez. Se creo en la Fase 13 para poder tener conductor y pasajero en dos
  aparatos a la vez. No tiene archivo de semilla; si se borra, se crea como los otros.
- **Esta instalado ffmpeg** (`winget install Gyan.FFmpeg`). Sirve para sacar fotogramas de un
  video y comparar pixel a pixel, que es como se encontro el temblor de la hoja en la Fase 13.
  Si el PATH no lo encuentra en una sesion recien abierta, esta en
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\ffmpeg-*-full_build\bin`.
- **Android pausa la aplicacion cuando su ventana pierde el foco**, y entonces deja de
  renderizar: dos capturas seguidas salen identicas byte a byte. Antes de concluir que algo
  no se mueve, comprobar con `dumpsys activity activities` que `topResumedActivity` es
  `com.motomoto.app/.MainActivity` y no el lanzador del cliente de desarrollo.

### Como abrir la aplicacion, paso a paso

Esto se redescubre cada vez y se pierde media hora. **El orden importa**: sin el paso 2 la
aplicacion arranca y muestra "Failed to connect to localhost:8081".

**1. Arrancar Metro**, una sola vez, desde `C:\dev\motomoto`. Se queda ocupando la ventana:

```powershell
npx.cmd expo start --dev-client
```

**2. Abrir el puente de puertos**, y **hay que repetirlo cada vez que se reinicia adb**:

```powershell
adb -s emulator-5554 reverse tcp:8081 tcp:8081
```

**3. Abrir la aplicacion.** Siempre con este intent, **no desde el icono del escritorio**: el
icono abre el lanzador del cliente de desarrollo, no el proyecto, y ademas puede quedarse con
el codigo anterior.

```powershell
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d "motomoto://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081" com.motomoto.app
```

Tarda **entre uno y dos minutos** la primera vez, mientras Metro compila. Si la aplicacion ya
estaba abierta con codigo viejo, `am force-stop com.motomoto.app` antes.

**Si algo va mal, en este orden:**

- `adb devices` -> si no sale nada, arrancar el emulador con
  `& "$env:ANDROID_HOME\emulator\emulator.exe" -avd motomoto_phone -gpu host`
- "Failed to connect to localhost:8081" -> falta el paso 2, o Metro no esta corriendo
- La pantalla no refleja un cambio de codigo -> `am force-stop com.motomoto.app` y repetir el
  paso 3. Comprobarlo ANTES de dudar del codigo
- Si el pasajero ve **"No conseguimos tu ubicacion"**, comprobar que Fake GPS esta activo y
  que la aplicacion tiene el permiso: `adb shell pm grant com.motomoto.app
  android.permission.ACCESS_FINE_LOCATION`. Con Fake GPS corriendo, la aplicacion si recibe
  una posicion de Amalfi al arrancar. La salida "Continuar sin ubicacion" sigue estando

**HAY TABLET OTRA VEZ, desde el 2026-08-20.** No es la de antes: es una **Xiaomi 25040RP0AL
con Android 15**, 1600x2560 a 360 dpi, o sea **711 dp de ancho en vertical y 1138 en
horizontal**. Se conecta por USB como `rk6xcyobpfwwrgnj`. Lo que hay que saber de ella:

- **NO TIENE GPS.** Tiene instalado **Fake GPS** (`com.lexa.fakegps`), igual que el emulador.
  Si eso alcanza para simular movimiento —lo que el emulador no logro— **esta sin comprobar**:
  la regla de los 50 metros de R9 y el rastro del recorrido siguen pendientes hasta que alguien
  lo mida.
- **Es Xiaomi, y MIUI bloquea instalar por USB.** `adb install` responde
  `INSTALL_FAILED_USER_RESTRICTED`. Dos salidas: activar "Instalar via USB" en las opciones de
  desarrollador —pide cuenta Mi— o copiar el APK con `adb push` a `/sdcard/Download` e
  instalarlo tocandolo en la tablet.
- **Es ARM, y el emulador es x86_64.** El APK del cliente de desarrollo hay que compilarlo para
  las dos: `.\gradlew.bat assembleDebug "-PreactNativeArchitectures=arm64-v8a,x86_64"`, con las
  comillas, porque PowerShell parte la coma. Tres minutos y medio. Sin arm64 la instalacion
  falla con `INSTALL_FAILED_NO_MATCHING_ABIS`.

**Lo que la tablet SI resuelve:** las dos partes a la vez. Conductor en el emulador y pasajero
en la tablet, sin alternar sesiones ni volver a escribir contrasenas, que es lo que hizo lento
todo el trabajo de las fases 14 a 17. Y el ancho de pantalla grande, por fin en una pantalla
grande de verdad.

**Lo que NO resuelve, hasta que se compruebe:** el movimiento. Y sigue sin haber SIM ni
conectividad de campo.

Con un solo aparato —si la tablet no esta a mano— la alternativa que funciono en las fases 14 a
17 es **manejar un lado desde SQL**: crear la solicitud, aceptarla o mover la posicion del
conductor con `supabase db query`, y mirar la otra mitad en pantalla.

**El emulador no puede producir movimiento, y esto se comprobo a fondo en la Fase 14.** Hay un
**Fake GPS instalado** que si le da una posicion de Amalfi a la aplicacion, pero **solo la
entrega cuando el vigilante arranca**: con la aplicacion corriendo, mover el punto en Fake GPS
no le llega. Verificado midiendo la posicion enviada al servidor antes y despues de moverla, y
reiniciando la aplicacion para ver el salto. Consecuencia: **nada que dependa de un aparato que
se mueve se puede probar en el emulador**, y eso incluye la regla de los 50 metros de R9 y el
marcador del pasajero moviendose de verdad.

**Y ojo con la posicion del conductor en el emulador:** la aplicacion envia la suya propia cada
pocos segundos y **pisa la que siembra `seed_test_driver.sql`**. La semilla lo deja a 109 m del
parque; con la aplicacion abierta, el conductor acaba donde diga Fake GPS, que en las pruebas
de la Fase 17 estaba a 1,3 km. Por eso "He llegado" no se puede tocar sin subir antes
`driver_arrival_radius_m`.

Otras dos cosas del entorno que siguen valiendo:

- **Los tiempos de R1 y R2 son cortos para probar a mano.** Veinte segundos de ventana de
  oferta se agotan entre una captura y el toque siguiente. Se suben temporalmente desde
  `app_settings` y se restauran al terminar.
- **El emulador estaba en Medellin antes de Fake GPS.** Aun asi recibia ofertas de Amalfi, y
  eso no es un fallo del entorno sino el hallazgo H16.

---

## 1. OBJETIVO

Plataforma movil para solicitar servicios de transporte en motorratones (vehiculos de tres
ruedas tipo tuk-tuk). Prueba piloto en el municipio de Amalfi, Antioquia, Colombia, con
expansion posterior a empresas de otros municipios mediante instalaciones separadas.

**La plataforma NO procesa pagos.** El cobro lo hace el conductor directamente al usuario,
fuera de la aplicacion. La arquitectura debe permitir incorporar pagos en el futuro sin
reconstruir el sistema.

**SI calcula y muestra el valor del servicio, desde el 2026-08-25 (D217).** Hasta esa fecha
este parrafo decia tambien "NO calcula tarifas", y era cierto: D8 dejaba el MVP sin ningun
dato monetario. Los duenos de la empresa pidieron la tarifa como funcion y el usuario lo
aprobo. Lo que no cambia es lo de arriba: **calcular y cobrar son dos cosas distintas**, y la
aplicacion sigue sin tocar dinero.

---

## 2. DECISIONES APROBADAS

| # | Decision | Valor |
|---|---|---|
| D1 | Nombre provisional | MotoMoto. Nombre comercial pendiente (Fase 25) |
| D2 | Plataforma del MVP | Android unicamente. iOS fuera del MVP |
| D3 | Arquitectura movil | Una sola aplicacion con navegacion segun rol |
| D4 | Tipo de vehiculo | Motorraton tipo tuk-tuk, hasta 3 pasajeros sin contar al conductor |
| D5 | Vehiculos por solicitud | Uno en el MVP. Modelo de datos preparado para varios |
| D6 | Autenticacion | Correo y contrasena mediante Supabase Auth |
| D7 | Asignacion de conductor | Automatica por cercania, con anulacion manual del administrador |
| D8 | Dinero | **MODIFICADA POR D217 el 2026-08-25.** Decia "ningun dato monetario en el MVP". Hoy la aplicacion calcula, muestra y registra el valor del servicio. Lo que sigue en pie es que **no procesa pagos**: cobra el conductor, en efectivo, fuera de la aplicacion |
| D9 | Multi-empresa | Instalaciones separadas por empresa. SIN columna company_id |
| D10 | Seleccion de destino | Lugares frecuentes, punto en el mapa, buscador de direcciones |
| D11 | Cobertura | Todo el municipio, sin radio de corte |
| D12 | Horario | Sin restriccion. Depende de los conductores conectados |
| D13 | Documentos | Tabla generica con tipos configurables desde el panel |
| D14 | Ubicacion | Posicion actual y recorrido historico en tablas separadas |
| D15 | Estados del servicio | Dos niveles. Transiciones validadas solo en servidor |
| D16 | Configuracion | Claves en variables de entorno. Esquema en migraciones versionadas |

### Decisiones de la Fase 1

| # | Decision | Valor |
|---|---|---|
| D17 | Version de Expo | SDK 57 |
| D18 | Node.js | v24.15.0 (LTS), gestionado con nvm-windows. Sin cambios |
| D19 | JDK | 17. Java 26 se conserva instalado pero JAVA_HOME apunta al 17 |
| D20 | Saltos de linea | core.autocrlf=false mas .gitattributes en la Fase 2 |
| D21 | Android Studio y emulador | Se instalan desde el inicio, no mas adelante, por la Fase 13 |
| D22 | Ruta del JDK | C:\Program Files\Java\jdk-17, ya presente en el equipo |
| D23 | Instalacion del SDK | Ruta por defecto sin espacios: %LOCALAPPDATA%\Android\Sdk |
| D24 | Imagen del emulador | x86_64 con Google Play. Nunca ARM |
| D25 | APIs descartadas | 37, Preview y CANARY |
| D26 | Dispositivo virtual | motomoto_phone, 2 GB RAM, GPU por hardware, teclado fisico |
| D27 | App de prueba | C:\dev\prueba-entorno, desechable, eliminada al cerrar la Fase 1 |
| D28 | PowerShell | Politica de ejecucion sin cambios. Se usan siempre npx.cmd y npm.cmd |
| D29 | Vulnerabilidades de npm | Nunca npm audit fix en proyectos Expo. Se usa expo install --check |
| D30 | Version de npm | Permanece en 11.12.1. No se actualiza a 12 durante la configuracion |
| D31 | Stack confirmado | Expo 57.0.8, React Native 0.86.0, React 19.2.3, TypeScript 6.0.3 |

### Decisiones de la Fase 2

| # | Decision | Valor |
|---|---|---|
| D32 | Repositorio | github.com/jhan0711/motomoto, privado |
| D33 | Flujo con GitHub | GitHub Desktop, por preferencia del usuario |
| D34 | Archivos de la plantilla | Se conservan AGENTS.md, CLAUDE.md y .claude/ |
| D35 | Git inicial | La plantilla ya inicializo el repositorio. Rama main |
| D36 | Organizacion del codigo | Por dominio, con src/features/ |
| D37 | Carpeta src/app | Contiene unicamente rutas y layouts de expo-router |
| D38 | Creacion de carpetas | Bajo demanda. No se crean directorios vacios |
| D39 | TypeScript | strict mas noUncheckedIndexedAccess, noUnusedLocals, noUnusedParameters y noFallthroughCasesInSwitch |
| D40 | eslint-config-prettier | No se instala. Se comprobo que no hay conflicto real entre ESLint y Prettier |
| D41 | Prettier | Comillas simples, comas finales, ancho 100, saltos LF |
| D42 | Carpeta example/ | Excluida de Git, TypeScript, ESLint y Prettier. Se borra al cerrar la Fase 3 |
| D43 | Licencia | Aviso de propiedad privada. Se retiro la licencia MIT heredada de la plantilla de Expo |

### Decisiones de la Fase 3

| # | Decision | Valor |
|---|---|---|
| D44 | Libreria de iconos | lucide-react-native, familia unica. Plan B: Feather dentro de @expo/vector-icons |
| D45 | Color de marca | Naranja ambar #F27127. Elegido por visibilidad sobre el mapa |
| D46 | Tipografia | Fuente del sistema (Roboto en Android). Sin fuente empaquetada |
| D47 | Colores | Paleta cruda separada de nombres semanticos. Los componentes solo usan los semanticos |
| D48 | Area tactil minima | 48dp. Los controles menores se amplian con hitSlop, no visualmente |
| D49 | Nombres | Archivos en kebab-case, componentes en PascalCase |
| D50 | Colores en props | Se pasan por nombre semantico tipado, nunca como cadena libre |
| D51 | Iconos en props | Se pasan sin instanciar. El componente contenedor decide tamano, color y trazo |
| D52 | Error en campos | Se deriva de la presencia del mensaje, no de un booleano independiente |
| D53 | Contrasenas | Siempre incluyen alternador de visibilidad |
| D54 | Foco en campos | El borde toma el color de marca |
| D55 | Numero de motorraton | Entero, obligatorio y unico por vehiculo. Se muestra destacado al pasajero, con la placa como apoyo |
| D56 | Textos de interfaz | Espanol correcto, con tildes, enyes y signos de apertura. Archivos en UTF-8 sin BOM. Verificado en Android |
| D57 | Cabecera nativa | Desactivada globalmente con headerShown: false. Se usa el componente Header propio |
| D58 | Header y navegacion | Header no importa el enrutador. Recibe onBack como funcion |
| D59 | Screen y cabecera | Screen recibe la cabecera como propiedad, para mantenerla fija fuera del area desplazable |
| D60 | Teclado en Android | KeyboardAvoidingView sin behavior. Android ya redimensiona la ventana |
| D61 | ErrorState | Compone EmptyState en lugar de duplicar su maquetacion |
| D62 | Iconos tipados | La propiedad icon se tipa como LucideIcon. Hace imposible pasar un emoji |
| D63 | Animaciones continuas | Reanimated, para que corran en el hilo de interfaz |
| D64 | Bottom sheet | Implementacion propia sobre Reanimated y gesture-handler. Se descarto @expo/ui por ser modal y bloquear el mapa, y @gorhom/bottom-sheet por su historial de rupturas con cada version mayor de Reanimated |
| D65 | Excepcion de linting | react-hooks/immutability desactivada solo en bottom-sheet.tsx. El compilador de React y los valores compartidos de Reanimated son incompatibles por diseno |
| D66 | Alcance del bottom sheet | Sin listas desplazables anidadas en el MVP |
| D67 | Confirmaciones | Componente Modal propio en lugar de Alert de React Native. Alert ignora el tema y se ve distinto en cada capa de personalizacion de Android |

### Decisiones de la Fase 4

| # | Decision | Valor |
|---|---|---|
| D68 | Estructura de rutas | passenger y driver en carpetas reales, no en grupos. Dos grupos con la misma hoja colisionarian en la misma URL |
| D69 | Sesion temporal | src/features/auth/session.tsx expone user, isLoading, signInAs y signOut. En la Fase 6 cambia el interior, no la forma |
| D70 | Guardias | Viven en los _layout.tsx, no en cada pantalla. Una pantalla nueva queda protegida sin que haya que acordarse |
| D71 | Navegacion inferior | Sin pestanas para el pasajero: el bottom sheet ocupa ese espacio. Con pestanas para el conductor |
| D72 | Alcance de las guardias | Deciden que se renderiza, no que se permite. La autorizacion real vive en las politicas RLS de la Fase 5 |
| D73 | Catalogo | Movido a /catalog. Se retira al terminar la Fase 7 |
| D74 | Recuperacion de contrasena | La confirmacion no revela si el correo existe, para no permitir enumerar cuentas |
| D75 | useSession fuera del proveedor | Lanza excepcion. Devolver null se confundiria con una sesion cerrada y produciria redirecciones en bucle dificiles de diagnosticar |
| D76 | Ancho maximo de contenido | 520 dp, centrado, en Screen y en el contenido del BottomSheet. Detectado al probar en una tablet de 800 dp de ancho logico. Las pantallas que deben ocupar todo el ancho, como el mapa, se excluyen con constrained={false} |

### Decisiones de la Fase 5

| # | Decision | Valor |
|---|---|---|
| D77 | Coordenadas | PostGIS, tipo geography SRID 4326, instalado en el esquema extensions. Los tipos se declaran cualificados |
| D78 | Estados | Tipos enumerados de PostgreSQL, en minusculas. La documentacion los escribe en mayusculas por ser notacion de maquina de estados |
| D79 | Calificacion del conductor | Precalculada en drivers, mantenida por disparador. Se recalcula entera, no de forma incremental |
| D80 | Entorno de desarrollo | Sin Docker. Se trabaja contra el proyecto en la nube con migraciones versionadas |
| D81 | CLI de Supabase | Dependencia del proyecto, version fijada en package.json |
| D82 | Variable de la clave | EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY, nomenclatura actual de Supabase |
| D83 | Escrituras | Los clientes solo leen. Solicitudes, viajes, ofertas y calificaciones se escriben por funciones controladas. Seis excepciones acotadas |
| D84 | Politicas que consultan otras tablas | Siempre a traves de funciones security definer. Una subconsulta directa provoca recursion infinita |
| D85 | Columnas privilegiadas | Protegidas por disparador, porque la seguridad de fila no restringe columnas |
| D86 | Vehiculos | Lectura abierta a usuarios autenticados. Numero y placa son visibles en la calle |
| D87 | Recalculo de calificacion | Marca local a la transaccion para que el disparador de proteccion lo distinga de un intento de fraude |
| D88 | Errores de las funciones | Mensaje en espanol para el usuario y codigo estable en el campo hint para la aplicacion |
| D89 | Tipos de TypeScript | Generados desde el esquema real con la CLI. Nunca escritos a mano. Se regeneran tras cada migracion |
| D90 | Renovacion de sesion | Escucha del estado de la aplicacion para arrancar y detener el temporizador de renovacion |

### Decisiones de la Fase 6

| # | Decision | Valor |
|---|---|---|
| D91 | Confirmacion de correo | Desactivada en el MVP. El correo integrado de Supabase tiene limites demasiado bajos para que cada registro dependa de el. Se reactiva en la Fase 25 con servidor de correo propio, que es un interruptor del panel, no una reescritura |
| D92 | Telefono | Obligatorio desde el registro. El backend lo exige para solicitar servicio, y pedirlo despues dejaria cuentas que existen pero no pueden usar la aplicacion. Movil colombiano de 10 digitos que empieza por 3, normalizado antes de guardar |
| D93 | Almacenamiento de la sesion | AsyncStorage, confirmando lo que ya implementaba el cliente. expo-secure-store tiene limite por entrada y la sesion de Supabase puede rozarlo: cambiaria un cifrado por un fallo silencioso de persistencia. Se revisa en la Fase 22 |
| D94 | Recuperacion de contrasena | Enlace profundo a la aplicacion. La direccion se genera con `createURL`, que produce `exp://` en Expo Go y `motomoto://` en la app instalada |
| D95 | Entrega del enlace de recuperacion | Se acepta el enlace profundo tal cual para el MVP. El navegador de Android no completa la redireccion de `https` a esquema propio (H7), y la solucion solida son los enlaces de aplicacion de Android, que exigen dominio propio. Se resuelve en la Fase 25 junto con el dominio y el correo propio |
| D96 | Mensajes de error de autenticacion | Codigo estable para comparar en el codigo y en las pruebas, mensaje en espanol solo para mostrar. Mismo criterio que D88. El codigo es lo que se compara, nunca el texto |
| D97 | Permiso de operar | Se calcula en un solo sitio, `canOperate` en la sesion, y no en cada pantalla. Repartir esa condicion garantiza que alguna pantalla se olvide de comprobarla |
| D98 | Cuenta bloqueada o pendiente | Mantiene la sesion abierta y ve una pantalla informativa. Cerrarle la sesion sin explicacion lo llevaria a intentar entrar otra vez y chocar con la misma pared sin entender por que |
| D99 | Administrador en la aplicacion movil | Se reconoce y se le explica que su cuenta se usa en el panel web. Fingir que su cuenta no existe seria peor |

### Decisiones de la Fase 7

| # | Decision | Valor |
|---|---|---|
| D100 | Bucket de fotos | Privado, con direcciones firmadas. Las politicas de la Fase 5 restringen quien ve el nombre de un pasajero; un bucket publico dejaria su cara accesible a cualquiera con la direccion mientras su nombre sigue protegido, y esa incoherencia no tiene sentido |
| D101 | Cambio de correo | No se permite en el MVP. Con la confirmacion desactivada (D91) seria inmediato y sin verificar, y quien tuviera el telefono desbloqueado un minuto podria apuntar la cuenta a su propio correo y quedarse con ella. Se habilita en la Fase 25 |
| D102 | Cambio de contrasena desde dentro | Exige la contrasena actual. Supabase no la pide, y aceptarlo significaria que un telefono desbloqueado es una cuenta perdida. Se comprueba intentando iniciar sesion con ella, que es la unica forma disponible |
| D103 | Procesado de la foto | Recorte cuadrado, 512 px de lado y calidad 0,7, hecho en el dispositivo antes de subir. Una foto de camara real queda en unos 40 KB. En Amalfi la conectividad es irregular y subir varios megabytes es friccion real |
| D104 | Columna de la foto | `avatar_url` renombrada a `avatar_path`. Guarda la ruta dentro del bucket, no una direccion: en un bucket privado las direcciones se firman y caducan. Se renombro con la columna vacia y sin una linea de codigo que la leyera |
| D105 | Nombre del archivo de la foto | Lleva marca de tiempo, asi que la ruta es la version. Un nombre fijo con reemplazo parecia mas limpio y estaba mal: al no cambiar la ruta la pantalla no pedia firma nueva y seguia mostrando la foto anterior desde la cache |
| D106 | Origen de la foto | Camara y galeria, con dialogo de eleccion. Los dos comparten el mismo procesado, para que un ajuste futuro de tamano o calidad no se aplique solo a uno |
| D107 | Integridad de la ruta | Restriccion `profiles_avatar_path_owned`: la foto debe estar en la carpeta del propio usuario, lo mismo que exigen las politicas del bucket |
| D108 | Cambio de contrasena, ubicacion | En la raiz y no dentro de `passenger/`. Un conductor tambien tiene que poder cambiar la suya: su cuenta la crea el administrador con una contrasena inicial |
| D109 | Edicion del perfil del conductor | No existe en la aplicacion. Sus datos los gestiona la empresa desde el panel. Lo unico suyo que puede cambiar es la contrasena |

### Decisiones de la Fase 8

| # | Decision | Valor |
|---|---|---|
| D110 | Quien dibuja el mapa | Google, con `react-native-maps` 1.27.2. Dentro de una app Android el mapa es gratis e ilimitado para siempre (SKU 6DE1-4D9C-5B67), y es la libreria mas rodada del ecosistema. Se descarto `expo-maps` por estar en alpha con rupturas frecuentes declaradas: es el componente central de la aplicacion y el proyecto dura meses |
| D111 | Quien resuelve las direcciones | Mapbox. Decidido probando 39 sitios reales de Amalfi y **verificando la coordenada de cada resultado**, no solo el nombre: Mapbox 22 aciertos, Google 13. Se implementa en la Fase 9 |
| D112 | Las dos decisiones son separadas | Dibujar el mapa y buscar direcciones son servicios distintos y se eligieron con criterios distintos. Mezclar proveedores cuesta una llamada HTTP en un archivo |
| D113 | Build de desarrollo | Local, con la cadena de la Fase 1. Sin cuenta de Expo, sin cola y sin conexion. EAS Build queda como plan B |
| D114 | Configuracion de la app | `app.json` sustituido por `app.config.ts`. La clave de Google Maps debe venir del `.env`, y un JSON estatico no puede leer variables de entorno: la clave habria acabado en un archivo que sube al repositorio |
| D115 | Nombre del paquete | `com.motomoto.app`. Necesario desde esta fase: es lo que identifica la app ante Google Maps y contra lo que se restringe la clave |
| D116 | Ubicacion | Solo primer plano. El segundo plano es de la Fase 14 y es del conductor; declararlo antes anade un permiso que Google Play exige justificar para algo que nada usa |
| D117 | El mapa va envuelto | Ninguna pantalla importa `react-native-maps`. Todo pasa por `src/features/map/map.tsx`, asi que D110 vive en un archivo y no en doce |
| D118 | Estados de la ubicacion | Union discriminada de siete casos, no un puñado de booleanos. Con booleanos, `isLoading && hasError && !hasPermission` es representable y no significa nada |
| D119 | Salida sin ubicacion | Todas las pantallas de fallo ofrecen "Continuar sin ubicacion", que muestra el mapa centrado en Amalfi. Es lo que cumple el criterio de aceptacion 6 |
| D120 | Precision del GPS | `Balanced`, no `BestForNavigation`. Unos metros de error son invisibles en el mapa del pasajero, y el modo de alta precision mantiene el chip ocupado sin parar |
| D121 | Espera del primer arreglo | 20 segundos. Bajo techo un arranque en frio tarda mas de un minuto, y un giro infinito se lee como una app colgada. El vigilante sigue activo: si el arreglo llega en el segundo 40, la pantalla se actualiza sola |
| D122 | Vista inicial del mapa | Parque de Amalfi (6,9047 / -75,0767) con zoom de municipio, y desliza a la posicion real cuando llega. Una pantalla en blanco no dice nada; el parque dice donde opera el servicio |
| D123 | Teclado | Lo gestiona `BottomSheet`, no las pantallas. Se corrige en el componente para que cualquier hoja futura lo herede |
| D124 | Altura de la hoja con el teclado | Conserva la altura del punto de anclaje activo y solo se eleva. Estirarla al maximo era lo obvio y quedaba mal: en tablet se comia la pantalla y dejaba una plancha de blanco bajo tres controles |
| D125 | Estilo del mapa | Propio en los dos esquemas, con los puntos de interes apagados. Compiten con nuestros marcadores y en Amalfi son en buena parte incorrectos, como demostro la evaluacion de proveedores |

### Decisiones de la Fase 9

| # | Decision | Valor |
|---|---|---|
| D126 | Que API de Mapbox usa el buscador | Search Box, pese a traer solo 500 busquedas gratis al mes frente a las 100.000 de la geocodificacion. Medido sobre los 39 sitios: Search Box acerto 22 y la geocodificacion 3. Las APIs de geocodificacion indexan direcciones y divisiones administrativas, no negocios ni puntos de referencia, y en Amalfi casi todo lo que la gente nombra es un punto de interes. Una API gratis que no encuentra nada no ahorra nada |
| D127 | Como se nombra un punto del mapa | Primero nuestra tabla, despues la direccion de Mapbox. A menos de 80 m el nombre del lugar; entre 80 y 250 m "Cerca de X" mas la direccion; mas lejos la direccion sola; y si no hay nada, se le pide una referencia al pasajero y no se deja confirmar sin ella |
| D128 | Que API hace el camino inverso | Geocoding v6, no Search Box. En los 12 puntos probados devolvieron **exactamente lo mismo**, asi que se usa la que trae 200 veces mas cupo |
| D129 | Umbral de 80 m para decir el nombre | Ensancharlo hacia que mas puntos tuvieran nombre bonito y era mentir: a 150 m del parque no estas en el parque, y el conductor va a donde le digan |
| D130 | Nombres de los lugares | Los que dice la gente, no los formales. En la lista pone "El comando", y "Estación de policía" va debajo como aclaracion |
| D131 | Lectura de los lugares | Por la funcion `list_places` y no por un select. La columna es geography y la API REST la devuelve como binario en hexadecimal, que habria que descifrar en el telefono |
| D132 | Lugar mas cercano | Se calcula en el telefono, no en el servidor. Son 36 filas que caben en memoria, y asi elegir destino sigue funcionando sin conexion. En Amalfi eso importa |
| D133 | Cache de los lugares | En el modulo, una vez por sesion de aplicacion. Tres pantallas necesitan la lista y sin cache cada navegacion la volveria a pedir |
| D134 | Resultados de otros municipios | Se filtran por municipio. El recuadro de busqueda cubre 25 km y a esa distancia caben pueblos vecinos enteros. Estrecharlo dejaria fuera las veredas, que si son destinos validos |
| D135 | Testigo de sesion de busqueda | Uno por busqueda, no por pulsacion. Es lo que hace viable el cupo de 500: teclear "hospital" y elegir es **una** sesion, no ocho |
| D136 | Pausa antes de buscar | 400 ms tras la ultima tecla. No es un adorno de rendimiento, es lo que mantiene el gasto bajo control |
| D137 | Donde vive el formulario a medio hacer | En memoria, no en disco. Es un formulario, no un viaje en curso. Si la aplicacion se cierra del todo, empezar otra vez es razonable y honesto: la ubicacion habra cambiado. Restaurar un viaje activo es de la Fase 15 |
| D138 | Origen y destino comparten pantalla | Elegir un sitio es el mismo gesto en los dos casos. Duplicar la pantalla significaria arreglar cada fallo dos veces |
| D139 | El campo de la hoja no es un campo | Es un boton con aspecto de campo que abre la pantalla de busqueda. Escribir dentro de la hoja obligaria a subirla por encima del teclado y meter los resultados en trescientos pixeles |

### Decisiones de la Fase 10

| # | Decision | Valor |
|---|---|---|
| D140 | Forma del selector | Control de menos y mas, no tres botones fijos con los numeros. Los fijos serian un toque mas rapido con el maximo actual de tres y dejarian de servir el dia que la empresa suba el limite. El maximo es un dato de la flota (R11), no una constante del programa |
| D141 | De donde sale el maximo | De `app_settings`, leido en cada arranque. Verificado cambiandolo a 4 en la base de datos: la aplicacion dejo elegir 4 y el mensaje se adapto solo |
| D142 | Si falla la lectura del maximo | Se sigue con 3, el valor de la flota actual. Quedarse sin poder pedir un servicio porque no se leyo un parametro seria desproporcionado, y la cantidad la valida el servidor de todos modos |
| D143 | El boton "+" en el maximo | Se atenua pero **no se deshabilita**. Pulsarlo es lo que muestra la explicacion de pedir dos servicios (R11), y un boton apagado no explica nada |
| D144 | Cuando aparece el aviso del limite | Solo al intentar pasarse, no siempre. Tenerlo fijo ocuparia sitio permanentemente para advertir de algo que casi nunca pasa: la mayoria de los viajes son de una persona |
| D145 | Alturas del bottom sheet | Ademas de fracciones de pantalla, acepta `'content'`: la altura que pide lo que hay dentro, medida al vuelo. Las fracciones no saben nada del contenido, y el mismo 0,5 sobraba en la tablet y cortaba el boton en el telefono |
| D146 | Punto de anclaje minimo | Toda hoja del mapa tiene un anclaje bajo que la reduce al asa, para apartarla y ver el mapa. No baja a cero: una hoja que desaparece del todo no deja nada que agarrar para subirla |
| D147 | Ruta y pasajeros | En una sola tarjeta y no en tres bloques sueltos. Son tres decisiones del mismo viaje, y separarlas gastaba dos huecos y un borde de mas en una hoja donde cada pixel se le quita al mapa |
| D148 | Donde se descarta el viaje elegido | Un aspa en la cabecera del resumen. Alto cero, porque la cabecera ya existia, y sigue a la vista con el panel bajado, que es cuando el pasajero mira el mapa y puede darse cuenta de que se equivoco. **No confundir con cancelar un viaje ya solicitado**, que es de la Fase 18 |

### Decisiones de la Fase 11

| # | Decision | Valor |
|---|---|---|
| D149 | Distancia y tiempo | Mapbox Directions, 100.000 peticiones gratis al mes. Se descarto la linea recta midiendo: en Amalfi un viaje de 16,8 km en recta son 37,0 km de carretera, mas del doble. Si la red falla no se muestra estimacion, en lugar de inventar un numero |
| D150 | Area de servicio | El poligono real del municipio (OpenStreetMap 1316177) mas 1 km de margen. El circulo se descarto por los numeros: cubrir el municipio exigiria 43 km de radio y eso se tragaria Anori, Campamento, Yolombo y Segovia. Simplificado a 0,0005 grados, 490 puntos, sin mover el area ni una decima |
| D151 | Quien caduca las solicitudes | pg_cron cada minuto, mas una limpieza dirigida dentro de `request_ride`. La primera deja los datos correctos aunque todos cierren la aplicacion; la segunda solo evita que el pasajero lea "ya tienes un servicio en curso" por algo que expiro hace cuarenta segundos |
| D152 | Al reabrir la aplicacion | Se restaura el estado de busqueda leyendolo del servidor, con los segundos que quedan de verdad. Tambien al volver de segundo plano: con el telefono bloqueado los temporizadores se frenan y la cuenta atras quedaria retrasada |
| D153 | Margen del area | En `app_settings`, no en el codigo. Existe porque el limite de OpenStreetMap en zona rural puede estar desviado y el GPS en zona de montana tambien. Un kilometro no alcanza el casco de ningun municipio vecino |
| D154 | Segundos restantes | Los calcula el servidor, no el telefono. Un reloj desajustado ensenaria una cuenta atras falsa. La pantalla arranca de ese numero y a partir de ahi descuenta sola, que es medir tiempo transcurrido y no comparar relojes |
| D155 | Errores de la base de datos | Se traducen en el cliente desde el codigo del `hint`, nunca se muestra el texto del servidor. Cierra el pendiente que venia de la Fase 6 y esquiva H8: los 21 mensajes sin tildes ya no llegan a ninguna pantalla |
| D156 | Color del aviso de error | Token propio `onDangerSubtle`, separado de `danger`. Un mismo tono no puede ser fondo de boton y texto sobre fondo teñido a la vez: en oscuro daba 1,44:1 y el mensaje no se leia (H14) |
| D157 | Navegacion giro a giro | Fuera del alcance. La ruta dibujada en el mapa si esta prevista (Fase 14). Para guiar al conductor la via razonable es abrir Google Maps o Waze con el destino puesto, que es un enlace y no un modulo. Se decide en la Fase 14 |

### Decisiones de la Fase 12

| # | Decision | Valor |
|---|---|---|
| D158 | Como le llegan las ofertas al conductor | Tiempo real de Supabase, adelantado desde la Fase 13. El motivo es la regla R2: con veinte segundos para responder, sondear cada diez se come la mitad de su tiempo. Medido: el aviso llega en poco mas de un segundo desde que el pasajero confirma. Se publico `ride_offers`, la primera tabla de la publicacion |
| D159 | Envio de posicion del conductor | Cada 30 segundos mientras esta disponible, y para al apagarlo. Solo en primer plano (D116). Sin esto un conductor real nunca apareceria en una busqueda, porque su posicion caduca a los dos minutos |
| D160 | A quien se ofrece una solicitud | A TODOS los conductores disponibles, no a los cinco mas cercanos. El cinco era el valor por defecto de un parametro y contradecia a la regla R4, aprobada en la Fase 0 |
| D161 | Recoger pasajeros en ruta | **IMPLEMENTADO. Sustituye a la regla R7**, que ya no existe como tal. Un conductor con asientos libres recibe y puede tomar otra solicitud; quien juzga si le queda de camino es el, mirando la ruta. Es como se trabaja en Amalfi. **No toca ninguna pantalla del pasajero**: no se le avisa, no puede negarse y el tiempo estimado se deja como esta |

### Decisiones de D161

| # | Decision | Valor |
|---|---|---|
| D162 | Como se hace cumplir la capacidad | Un disparador, no un indice unico. Un indice sabe decir "este valor ya esta" pero no sabe sumar, y la regla nueva es una suma contra `vehicles.max_passengers`. Perder el indice es perder la garantia del motor, asi que el disparador bloquea el conductor y despues su vehiculo, siempre en ese orden, antes de contar |
| D163 | Un conductor, un motorraton | Puede llevar varios viajes, pero todos en la misma unidad. Es lo que queda vivo del segundo indice: sin ello, reasignarle otro vehiculo a mitad de servicio le dejaria dos en la calle a la vez |
| D164 | La disponibilidad al aceptar | Se recalcula en lugar de apagarse. Sigue disponible mientras le queden asientos. **Aceptar puede apagarla, nunca encenderla**: quien apago el interruptor a mano no debe reaparecer disponible por aceptar una oferta que ya tenia viva |
| D165 | Que parte de la Fase 14 se adelanta | Solo el dibujo del recorrido en la pantalla del conductor. El seguimiento y el marcador en movimiento se quedan en su turno. Sin ver la ruta, D161 le pide al conductor una decision a ciegas |
| D166 | Que dibuja el mapa de una oferta | Dos rutas y no una: la ofrecida en color de marca y las que ya lleva en el color del texto. La pregunta no es "por donde va este viaje" sino "por donde va respecto de lo que ya tengo". **Si una ruta en curso no se puede dibujar, el mapa lo dice**: un mapa incompleto que no se declara incompleto es peor que no tener mapa |

### Decisiones de la Fase 13

| # | Decision | Valor |
|---|---|---|
| D167 | Que ve el pasajero de su conductor | Nombre, telefono, calificacion, numero de unidad y placa, y solo desde que alguien acepta. Es la misma linea de la Fase 12 en el otro sentido: los dos datos aparecen en el mismo instante y por el mismo motivo, que alguien se comprometio. **No hizo falta ninguna politica nueva**: las cuatro tablas ya dejaban pasar a un pasajero con servicio asignado, y `drivers_select_ride_counterpart` estaba escrita desde la Fase 5 sin que la usara nadie |
| D168 | Que tabla se publica para el pasajero | `ride_requests` y no `rides`. Al pasajero le importan tambien la expiracion, la cancelacion y el fin del viaje, y todo eso vive en la solicitud. Se acepta el coste que la Fase 12 dejo advertido, porque quien se suscribe es el pasajero mientras tiene una solicitud viva, una solicitud cambia de estado cuatro o cinco veces en toda su vida, y la suscripcion filtra por `passenger_id` antes de evaluar las politicas. **Sin `replica identity full`**, a diferencia de `ride_offers`: aqui basta el estado nuevo, y `full` escribe la fila entera en el registro de transacciones en cada actualizacion |
| D169 | Un solo hook de tiempo real para los dos lados | El pasajero y el conductor escuchan la misma tabla con el mismo hook. **Quien ve que no lo decide el codigo sino las politicas**, que se aplican tambien en tiempo real. Dos hooks casi iguales serian duplicar para acabar dependiendo igualmente de las mismas dos politicas |
| D170 | Calificacion cero | Un promedio de 0 se traduce a "sin calificaciones" antes de llegar a ninguna pantalla. El servidor guarda 0 cuando no hay ninguna, y una calificacion real nunca puede valer 0 porque el minimo es una estrella. Pintarle un 0,0 a un conductor nuevo le atribuiria un mal servicio que nadie ha dado |
| D171 | Geometria de las rutas | `overview=full` y no `simplified`. La simplificada trae 4 puntos para 659 metros, o sea tramos rectos de 220 metros que atraviesan tres manzanas y salen de las calles. La completa trae 10, de 73 metros. **La diferencia son 131 bytes por peticion**: el ahorro que justificaba lo otro no existia. Lo vio el usuario mirando la pantalla |

### Decisiones de la Fase 17

| # | Decision | Valor |
|---|---|---|
| D204 | Los reportes no entran en esta fase | "Reportar un problema" va a la **Fase 20**, con la bandeja que los gestiona. Un boton que envia un reporte que nadie puede leer todavia es peor que no tenerlo: promete atencion que no existe |
| D205 | La calificacion es una pantalla propia, y se abre por identificador de viaje | No un panel dentro de la despedida. Asi la misma pantalla sirve para calificar al terminar y para calificar desde el historial semanas despues, y funciona igual si se llega por un enlace o si la aplicacion se reabre encima |
| D206 | Estrellas obligatorias, comentario opcional | El boton de enviar no se activa sin estrellas. No existe el cero: el minimo del esquema es 1, y "sin calificar" ya se representa con la ausencia de fila, no con un cero |
| D207 | El atajo del conductor no sobrevive a cerrar la aplicacion | Los dos datos que hacen falta —que viaje y a quien llevo— los tiene la tarjeta que se acaba de cerrar, asi que no se le pregunta al servidor por algo que ya se sabe. Lo que quede sin calificar vive en el historial, que es donde se busca al dia siguiente |
| D208 | La calificacion que uno RECIBE no se ensena viaje por viaje | Es un dato de la otra parte sobre uno, y ensenarlo por viaje convierte el historial en un sitio donde mirar quien te puso tres estrellas. Lo que si se ve es el promedio, en el perfil del conductor, que existe desde la Fase 5 |
| D209 | `already_rated` se filtra siempre por quien califica | Nunca solo por viaje. `ratings_select_involved` deja ver las dos filas del mismo servicio, asi que sin el filtro un servicio calificado por la otra parte se veria como calificado por uno mismo. **Lo destapo la prueba 20**, no la revision |
| D210 | La zona del conductor es una pila por encima de las pestanas | Las tres pantallas viven en un grupo `(tabs)` que no cambia ninguna direccion. Antes el detalle y la calificacion colgaban de las pestanas con `href: null`, y **volver atras llevaba a otra pestana en lugar de a la pantalla anterior**: se calificaba desde el historial y se aterrizaba en Inicio |
| D211 | `anon` deja de poder ejecutar `rate_ride` | Estaba anunciado desde la Fase 15 y lo confirmo la prueba. Se cierra solo esta, que es la de esta fase y la unica que se puede volver a probar entera hoy; `accept_ride_offer`, `reject_ride_offer`, `cancel_request` y `cancel_ride` siguen en la Fase 22, para mirarlas una por una |

### Decisiones de la Fase 18

| # | Decision | Valor |
|---|---|---|
| D212 | Que ve el pasajero cuando el conductor cancela ANTES de recogerlo | Nada nuevo del servidor. `cancel_ride` ya devolvia la solicitud a `searching` y la reofrecia; lo unico que faltaba era decirselo. Se detecta en el cliente comparando el conductor que habia con el que hay: si tenia uno, ahora no tiene ninguno y la solicitud sigue viva, es que cancelo. Un aviso breve y no una pantalla propia, porque la de "buscando motorratón" ya es honesta |
| D213 | Que ve el pasajero cuando el conductor cancela CON EL A BORDO | Pantalla propia, `get_driver_cancelled_notice`, mismo patron que `get_finished_request` de la Fase 15/17: cero o una fila, solo importa si fue hace poco, y reusa el parametro `finished_summary_minutes` en lugar de inventar uno nuevo para la misma pregunta ("cuanto es hace poco"). Cierra el pendiente de D187. No ofrece calificar (R8 exige un viaje terminado) ni borra el viaje elegido: el pasajero seguia queriendo llegar a ese destino |
| D214 | El boton de cancelar del pasajero respeta el estado real | Antes se ofrecia en los cinco estados, incluido `in_progress`, donde el servidor ya lo rechazaba con `INVALID_STATE_TRANSITION`. **Lo dejo escrito D187** y lo confirmo el codigo: se oculta con el pasajero a bordo, y en los demas casos pide confirmacion primero (antes cancelaba al primer toque) |
| D215 | R10 (conductor sin senal, alerta al administrador) queda fuera de este paso | No hay panel todavia donde mostrar esa alerta (Fase 20). Implementarla ahora seria una alerta que nadie puede leer, mismo criterio que D204 con los reportes |
| D216 | La Fase 18 se cierra sin construir mas "errores operativos" | Decision del usuario, 2026-08-21. Lo unico que quedaba de la lista de la seccion 8 —R10 y que el administrador bloquee a un conductor a mitad de operacion— depende del panel entero, no de una funcion suelta. Escribirlo antes que el panel seria adivinar su forma dos veces. Se revisa en la Fase 20 |

### Decision del bloque especial entre la Fase 19 y la 20

| # | Decision | Valor |
|---|---|---|
| D217 | **La aplicacion calcula y muestra el valor del servicio. MODIFICA A D8** | Pedido de los duenos de la empresa, aprobado por el usuario el 2026-08-25. D8 dejaba el MVP sin ningun dato monetario y la seccion 1 decia "NO calcula tarifas"; las dos cosas quedan modificadas aqui en lugar de contradecirse en silencio, que es como se pudre un documento de continuidad. **Lo que NO cambia: la aplicacion no procesa pagos.** Cobra el conductor, en efectivo, fuera de la aplicacion. El sistema calcula el valor, se lo ensena al pasajero ANTES de que confirme, y lo registra con el servicio. Que el pasajero sepa cuanto va a pagar antes de pedir es justo lo que hoy se resuelve preguntando por telefono |
| D218 | **Que hace rural a un destino: tener tarifa, no estar lejos** | Decidido con el usuario el 2026-08-25. Un destino es rural si y solo si tiene fila activa en `rural_fares`. Se descarto dibujar un perimetro urbano y se descarto un radio desde el parque, **y no por gusto sino por un dato**: de los 36 lugares que ya estan en `places`, 34 caen a menos de 2 km del parque, o sea que la lista actual es practicamente toda urbana y un perimetro no separaria nada que la empresa no haya separado ya al ponerle precio. Ademas evita repetir el error que D150 ya habia razonado con el circulo |
| D219 | **Un destino sin tarifa y lejos no se deja pedir** | Decidido con el usuario el 2026-08-25. El destino puede venir de la lista, del buscador de Mapbox o de una chincheta en el mapa, y en los dos ultimos casos `destination_place_id` es nulo. Con D218 esos pagarian tarifa urbana, o sea que una chincheta a 20 km por una vereda mostraria $4.000. **Un valor falso en la pantalla es peor que no dejar pedir**, que es el fondo de D217. Si el destino no tiene tarifa y esta a mas de una distancia configurable, la aplicacion pide elegir uno de la lista. **El umbral NO aplica a los destinos de `places`**: los curo la empresa, y aplicarselo dejaria fuera a Vereda Guayabito, que esta a 6,3 km y hoy funciona |
| D220 | **Ni la carga ni la encomienda ocupan puesto** | Aclarado por el usuario el 2026-08-25. Se llego a proponer una columna de puestos por tipo de carga, razonando que lo delicado viaja dentro del motorraton. El usuario lo corrigio: los seis tipos van en la parrilla de arriba o en los huecos de adelante y de atras. Se retiro la columna antes de escribirla. **Consecuencia: una encomienda va con cero pasajeros**, asi que `rr_passenger_count_range` y `rides_passenger_count_range` tendran que admitir el cero **solo cuando el servicio sea encomienda**, y el conductor que lleva una podra seguir recogiendo sus tres pasajeros en ruta |
| D221 | **La formula del valor** | Cerrada con el usuario el 2026-08-25 tras seis reglas que entrego la empresa. Tarifa del viaje: rural, la fija del destino, **plana, sin importar cuantos van**; urbana, por cantidad de pasajeros. Valor: si va un pasajero, con carga o sin ella, **tarifa mas cargas**; si va solo la carga, **la mayor entre la tarifa y las cargas**. En encomienda urbana la tarifa base es la de una persona. **Pendiente de una sola respuesta:** si una encomienda urbana de noche cuesta $7.000, que es lo que se desprende de la formula, o se queda en $4.000 |
| D222 | **La franja nocturna sustituye, no se suma, y no llega al campo** | Confirmado por el usuario el 2026-08-25. De noche un pasajero paga $7.000 y no $4.000 mas $7.000. Y los destinos rurales cuestan lo mismo a cualquier hora: la empresa entrego valores nocturnos de uno, dos y tres pasajeros, que es la forma de la tarifa urbana, y para lo rural no dio ninguno. Inventar un recargo rural seria inventar un precio |
| D223 | **Las tarifas estrenan tablas; la trazabilidad no** | `app_settings` ya existe y fue la primera idea, pero es clave/valor jsonb, sin activo/inactivo y sin forma de decir "este destino ya no se atiende", y las 36 rurales no caben en una fila sin volverse un documento que nadie puede consultar por partes. Se crean `urban_fares`, `rural_fares` y `cargo_types`. **La auditoria NO estrena tabla**: ya existe `admin_audit_logs` con actor, entidad y estado anterior y posterior, y el panel escribira ahi en la Fase 20. Lo que si sigue en `app_settings` son la zona horaria y las dos horas de la franja, porque eso es parametro operativo y no precio |
| D224 | **La carga de un servicio es una lista, no un dato** | Pedido del usuario el 2026-08-25: tiene que existir "agregar otra carga", tanto en pasajero con carga como en encomienda sola, y las cargas pueden ser de tipos distintos. Por eso `cargo_types` es solo el catalogo de precios y lo que lleva cada servicio va en una tabla hija aparte. Decidirlo antes de la primera migracion evito tener que rehacerla |
| D226 | **La tarifa rural es la del destino mas cercano** | Lo pregunto el usuario el 2026-08-25 y destapo un hueco real: hasta entonces solo se sabia cobrar rural si el destino ERA EXACTAMENTE uno de los 36. Con sus palabras, "en la lista estan senalados el alto de Montanita y Guaico, en caso tal un pasajero vaya para un punto medio, como se calcularia el costo". Ese punto medio caia en tarifa urbana —$4.000 por un viaje de $20.000— o rebotaba por D219. **La regla la propuso el usuario y se aprobo**: se cobra la del destino rural mas cercano, si hay alguno dentro de un radio. Se eligio frente a redondear siempre al siguiente —que cobra de mas a quien se baja doscientos metros despues del punto— y frente a no cobrarlos —que devuelve ese pasajero al telefono— porque **usa unicamente tarifas que la empresa ya autorizo, sin inventar ninguna** |
| D227 | **El radio de D226 sale del dato, no del ojo** | La distancia se mide en LINEA RECTA y los 36 destinos salen del pueblo por vias distintas, asi que sin radio un punto a 15 km por un camino sin nombre se pegaria a algo que queda cerca en el mapa y lejos por carretera. **El valor esta provisionalmente en 2 km y esta puesto corto a proposito**: falta medir la separacion real entre los 36 destinos, y eso no se puede hacer hasta que lleguen las coordenadas. Corto es el lado seguro, porque lo que no alcanza a pegarse cae en D219 y se rechaza en vez de cobrarse barato. Es un UPDATE de una fila el dia que se afine, no una migracion |
| D228 | **El valor dice de donde salio** | Segunda mitad de D226. En lugar de "$15.000" a secas, "Tarifa de Montanita — $15.000". Cuesta una columna, `fare_reference`, y convierte un numero discutible en uno transparente: el pasajero ve de donde sale ANTES de confirmar y el conductor ve lo mismo, asi que una referencia equivocada se nota antes del viaje y no despues, con los dos discutiendo en la calle |
| D229 | **El panel no dejara crear un lugar sin decidir su tarifa** | Decidido con el usuario el 2026-08-25, **para la Fase 20**. Sale de un hueco que dejaba D219: si el administrador agrega un destino lejano a la lista y se olvida de ponerle tarifa, ese destino cobraria urbano en silencio y nadie se enteraria hasta que el conductor volviera quejandose. Se eligio atajarlo donde nace —al crear el lugar— en vez de detectarlo despues |
| D225 | **El precio de la carga se congela en el servicio** | Mismo criterio que `contact_phone` desde la Fase 5. Si la empresa sube el bulto de cafe manana, un servicio de hoy tiene que seguir diciendo lo que costo. Los valores se guardan como enteros en pesos, sin decimales: en Colombia nadie cobra centavos, y un entero no admite el error de redondeo que un decimal si permite |

| D230 | **MODIFICA A D226 Y D227: gana el punto nombrado mas cercano, no solo el rural mas cercano** | Error de interpretacion del asistente, corregido el 2026-08-26 con las coordenadas reales de la empresa. El usuario dijo "si esta mas cerca de un lugar que de el otro, se cobre el del lugar mas cerca" y D226 lo estrecho sin querer a "del destino RURAL mas cercano". Con las coordenadas reales se vio el costo: Alto del Rio queda a 1.432 m del parque y 32 de los 36 lugares urbanos caian dentro del radio de un rural. **Nunca estuvo en produccion**: se detecto midiendo antes de cargar ninguna tarifa. La regla nueva compara contra TODOS los lugares activos, no solo los que tienen precio rural; un lugar urbano nunca pierde contra si mismo, a cero metros |
| D231 | **El radio de D230 sube a 3 km, y esta vez con dato de verdad** | Medido contra las coordenadas reales: los 24 destinos rurales se separan 314 m como minimo, 979 m mediana, 4.273 m maximo. Un punto en mitad del tramo mas largo queda a 2,2 km de un extremo, asi que 3 km lo cubre con margen sin volver a caer en el problema de D227 (un radio grande que encarece el pueblo), porque con D230 pasarse de radio ya no le pone precio rural a un lugar urbano |
### Decisiones de la Fase 20

| # | Decision | Valor |
|---|---|---|
| D236 | **El panel vive en el mismo repositorio, en `admin/`** | Decidido con el usuario el 2026-08-26. Un solo historial de commits para las dos mitades del producto, que es lo que tiene sentido con un desarrollador solo: un cambio que toca el servidor y el panel a la vez queda en un commit y no en dos repositorios que hay que mantener sincronizados. El precio es que la configuracion del raiz veia la carpeta nueva, y hubo que aislarla en `tsconfig.json`, `eslint.config.js` y `.prettierignore`, igual que se hizo con `example/` en D42 |
| D237 | **Tailwind para los estilos del panel** | Decidido con el usuario el 2026-08-26, tras pedir recomendacion. El panel son unas diez pantallas de tablas, formularios y filtros; con CSS a mano se acaba reescribiendo la misma tabla en cada pantalla y descuadrandose entre ellas. **La paleta no se reinventa**: `admin/src/app/globals.css` declara los mismos nombres semanticos y los mismos valores crudos que `src/theme/colors.ts` (D47), asi que el naranja de marca sigue definido en un solo sitio conceptual. **El panel no lleva tema oscuro**, a diferencia de la aplicacion movil: se usa a plena luz en una oficina y dos temas duplican el trabajo de cada pantalla |
| D238 | **La guardia del panel vive en un solo archivo y no autoriza, solo dibuja** | `admin/src/proxy.ts`. Mismo criterio que D70 —una pantalla nueva queda protegida sin acordarse— y que D72 —la autorizacion de verdad son las politicas RLS de la Fase 5, que ya exigen `is_admin()`—. Comprueba el rol **leyendolo del servidor con `getUser()`, no de la cookie con `getSession()`**, porque la segunda se cree lo que el navegador diga. Verificado mandando una cookie falsificada: responde igual que sin sesion. Y a quien tiene sesion valida pero no es administrador **se le cierra la sesion** antes de devolverlo al acceso, para que no quede atrapado con una sesion que no sirve y sin forma de entrar con otra cuenta |
| D240 | **Las acciones administrativas van por funciones que auditan en la misma transaccion** | Decidido con el usuario el 2026-08-26, eligiendo entre esto, la escritura directa por RLS y un modelo mixto. El motivo de fondo es que la alternativa barata no era mas barata: con escritura directa, la auditoria hay que acordarse de escribirla desde el panel, y quien llame a la API a mano —cosa que puede hacer cualquiera con una sesion de administrador— no se acuerda nunca. Atado a la transaccion, si la auditoria falla el cambio tampoco pasa. **Es coherente con D83**, que ya decidio que los clientes solo leen, y el panel es un cliente |
| D241 | **La marca `motomoto.admin_action` no autoriza: solo dice por donde vino la accion** | Sale de un error del asistente del mismo dia, cazado por la comprobacion 17 de `prueba_auditoria.sql`. La primera version dejo la marca como unica condicion del disparador, y entonces cualquiera que la pusiera podia cambiar rol y estado: **un pasajero podia hacerse administrador**. El disparador exige ahora la marca **y** `is_admin()`. La leccion es mas amplia que la correccion: al apretar una tuerca se aflojo otra, porque la proteccion vieja y la nueva cubrian cosas distintas y se sustituyo una por otra en vez de sumarlas |
| D242 | **Las funciones de LECTURA del panel son `security invoker`, al reves que las de escritura** | Las que escriben son `security definer` porque tienen que poder tocar tablas que el cliente no toca, y comprueban `is_admin()` ellas mismas. Las que leen no: si `admin_list_active_services` fuera definer, **un pasajero que la llamara veria el tablero entero de la empresa**, porque la funcion esta concedida a `authenticated` como todas. Siendo invoker, las politicas RLS de la Fase 5 se aplican con la identidad de quien llama y cada uno ve lo que le toca. La comprobacion de administrador no hace falta escribirla: ya la hacen las politicas |
| D243 | **El tablero consulta cada diez segundos en vez de suscribirse a tiempo real** | La Fase 13 publico `ride_requests` y `rides` en realtime, asi que suscribirse era posible. Se eligio preguntar porque **tres de los datos que el tablero muestra —la espera, la antiguedad de la ultima posicion y las ofertas vivas— cambian con el paso del tiempo aunque no cambie ninguna fila**, asi que una suscripcion no ahorraria el refresco: haria falta igual un temporizador para que los minutos avanzaran. Ademas el tablero es una lista agregada y no un marcador moviendose, asi que diez segundos no cambian ninguna decision de un despachador. Es reversible: si hace falta inmediatez, la suscripcion se anade encima |
| D244 | **No se le retira la aprobacion a un conductor que va conduciendo** | Es la respuesta a lo que la Fase 18 dejo pendiente en D216. Dejar a un pasajero dentro de un motorraton cuyo conductor acaba de perder el permiso no arregla nada: lo que hay que hacer primero es resolver el servicio. El servidor responde `DRIVER_HAS_ACTIVE_RIDE` y el panel apaga el boton, **las dos cosas**, porque el boton apagado explica por que no se puede y la comprobacion del servidor es la que de verdad lo impide. Cancelar el servicio desde el panel llega en el paso 11. **Bloquear la CUENTA si se puede en cualquier momento**, que es la salida para una urgencia de verdad |
| D245 | **Aprobar a un conductor y bloquear su cuenta son dos acciones distintas** | Y por eso son dos funciones, no una con un parametro. Bloquear la cuenta deja a la persona sin poder entrar en la aplicacion; retirar la aprobacion la deja entrar pero no trabajar. La empresa usa las dos en momentos distintos: la primera ante un problema grave, la segunda cuando caduca un papel. Juntarlas obligaria a explicar en la pantalla una diferencia que los nombres ya dicen solos |
| D246 | **UN MOTORRATON LO PUEDEN LLEVAR VARIAS PERSONAS, PERO SOLO UNA CONECTADA A LA VEZ** | Pedido por el usuario el 2026-08-27 -"algunos tienen doble turno"- y decidido entre tres opciones. **Modifica una regla de la Fase 5**: se retira el indice `dva_one_active_per_vehicle`. Lo que aquel indice protegia -que dos conductores no aparezcan al volante de la misma unidad- se protege ahora donde de verdad se decide, en `is_available`, porque es la columna por la que filtra `find_available_drivers`: si dos companeros pudieran estar disponibles a la vez, **los dos recibirian ofertas y los dos podrian aceptar con un solo motorraton fisico**. Se descarto reasignar en cada cambio de turno -obliga a acordarse dos veces al dia- y se descarto quitar el limite sin mas -deja el hueco abierto-. Lo que NO cambia: `dva_one_active_per_driver` sigue en pie, un conductor tiene una sola unidad |
| D247 | **El mensaje del companero conectado usa el texto del servidor, no el catalogo** | Unica excepcion en el proyecto a traducir por `hint`. El servidor manda "Juan Perez ya esta conectado con el motorraton 99", y ese dato -quien y cual- no se puede tener en el cliente. **Con el nombre delante, el conductor resuelve llamando a su companero; sin el, tiene que llamar a la oficina.** Sigue siendo el `hint` el que decide que caso es (D88); el texto solo se muestra, y el catalogo conserva un respaldo generico por si llegara vacio |
| D248 | **La ubicacion de un lugar no se edita: se desactiva y se crea otro** | Mover un lugar cambia su distancia al centro, y con ella dos cosas que deciden precios: si necesita tarifa rural (D229) y a que destino se pega un punto suelto del mapa (D230). Un campo de coordenadas en el formulario invitaria a corregir "una chincheta mal puesta" sin ver que eso puede cambiar lo que paga la gente por viajes que no tienen nada que ver. Desactivar y crear otro **ademas conserva el historial** de los viajes que usaron el sitio viejo |
| D249 | **Los precios y los parametros se editan de uno en uno, no con un formulario y un boton** | Un formulario con veinte campos y un "Guardar" al final invita a tocar cuatro cosas a la vez; si una falla la validacion del servidor, quien lo usa no sabe cual de las cuatro, y las otras tres pueden haberse guardado o no. Editando en el sitio, **cada cambio lleva su propia respuesta y su propia linea de auditoria**, que es justo lo que se quiere de algo que decide cuanto paga la gente |
| D250 | **Las cuentas de conductor se crean con una funcion `security definer`, NO con la clave `service_role`** | Decidido con el usuario el 2026-08-27 entre las dos opciones. La `service_role` es la via oficial de Supabase, pero **salta toda la RLS para cualquier operacion**: quien la tenga puede leer y escribir cualquier cosa de cualquier usuario, y hay que custodiarla. La funcion corre con privilegios tambien, pero **acotada a una operacion y con `is_admin()` dentro**: un agujero aqui da de alta conductores, un agujero con la `service_role` da todo. Ademas el proyecto ya crea cuentas asi desde la Fase 12, en las semillas |
| D251 | **La contrasena inicial la genera el sistema y se muestra una sola vez** | El panel no deja elegirla: cuando las elige una persona para veinte conductores, acaban siendo todas parecidas. El formato es **dictable por telefono** —`Moto-XXXX-9999`, sin O, I, L ni S, que se confunden con 0, 1 y 5 al hablar—, porque asi es como llega al conductor. **Nunca se escribe en la auditoria**: un registro que la guardara seria un almacen de contrasenas en claro que cualquier administrador podria leer. Si se pierde, se genera otra |
| D252 | **Un documento se sube primero y se registra despues** | El archivo no pasa por SQL: Storage tiene su propia API. Se eligio ese orden y no el contrario porque **un archivo sin fila es basura recuperable, y una fila sin archivo es un documento que la empresa cree tener y no tiene**. Si el registro falla, el panel borra el archivo recien subido; si esa limpieza tambien falla, queda un huerfano en el bucket, que se puede encontrar y borrar. La otra forma deja mentiras en la base de datos |
| D253 | **Bloquear a un pasajero con un servicio en curso exige motivo escrito, pero no se prohibe** | Diferencia deliberada con D244. Alli, a un conductor conduciendo **si** se le impide retirarle la aprobacion, porque el perjudicado es un tercero: el pasajero que va dentro del motorraton. Aqui el afectado es el propio bloqueado, y **puede haber una urgencia que justifique dejarlo fuera ahora mismo**. Se piden diez caracteres de motivo y la auditoria guarda tanto el texto como el hecho de que habia un viaje vivo. Desbloquear no pide nada: devolver el acceso no necesita justificarse igual que quitarlo |
| D254 | **Los cuatro destinos de la zona de la mina se cargan tal cual, aunque queden a 98 metros** | Decidido con el usuario el 2026-08-28 tras medirlos. El Taparo, Los Tanques, Entrada a la Mina y La Mina caben en medio kilometro con hasta 13.000 pesos de diferencia, cuando la separacion minima entre los 28 anteriores era de 219 m. **Se cargan porque elegidos de la lista cobran exacto**, que es como se piden casi siempre; solo una coordenada suelta en esa zona se resolveria al vecino por D230. Sus precios reflejan la distancia **por carretera** y no en linea recta, asi que aplanarlos seria cobrar mal. Se descarto bajar el radio de D230, que habria afectado a los 36 destinos para arreglar una zona |
| D255 | **El recorrido del servicio se ensena como datos, no como mapa** | `ride_locations` tiene 12 puntos en 10 viajes: uno por viaje. No es la tabla, es que **el emulador no puede producir movimiento** -medido en la Fase 14- y nadie ha conducido de verdad con la aplicacion. Un mapa con un punto no ensena nada y ademas obligaria a montar Mapbox en el panel. Se muestran los puntos, la primera y la ultima hora y la distancia que calculo `complete_ride`. **El mapa se pone cuando haya rastros de verdad**, y entonces se vera si sirve |
| D239 | **El acceso no distingue "contrasena mala" de "cuenta sin permiso"** | Un pasajero que escriba bien sus credenciales lee exactamente el mismo mensaje que quien se equivoca de contrasena. Decir "esa cuenta no tiene acceso al panel" confirmaria que el correo existe y en que consiste, que es el mismo criterio de D74 en la recuperacion de contrasena. El unico caso que si se explica es el del usuario devuelto por la guardia con sesion ya abierta, porque ahi el correo ya se conoce |

### Decisiones de la Fase 16

| D232 | **Los dos nombres en duda se resuelven distinto, uno por uno** | Con las coordenadas exactas de la empresa, entregadas el 2026-08-26. **Manzanares SI es "Vereda Manzanares"**: la coordenada nueva cae a 288 m de la existente, que es ruido normal de GPS entre dos lecturas del mismo sitio; se le agrego la tarifa rural al lugar que ya habia, sin duplicar. **La Vibora NO es "La víbora"**: la coordenada nueva cae a 3.817 m de la existente, casi 4 km, son dos sitios distintos. Decidido por el usuario: el nombre "La víbora" pasa al sitio nuevo, y el urbano viejo se renombra a un nombre que no colisiona y se desactiva. No se borro: `places_name_unique` no tiene filtro por estado, asi que dos filas no pueden compartir nombre aunque una este apagada, y el proyecto no borra registros que puedan ser historial |
| # | Decision | Valor |
|---|---|---|
| D196 | De donde sale cada historial | El del pasajero de `ride_requests`; el del conductor de `ride_offers`. No son la misma lista: el pasajero tiene solicitudes y el conductor tiene ofertas. Una que el rechazo no existe en el historial del pasajero, porque desde su lado no paso nada, su solicitud siguio buscando |
| D197 | Cuantos desenlaces ve el conductor | Cinco, no cuatro. `taken_by_other` esta separado de `expired` porque cuando otro acepta primero la base de datos marca caducadas las ofertas pendientes (Fase 5), y sin distinguirlo la pantalla le diria "se agoto el tiempo" a quien no dejo pasar nada. **Es justo la cuenta que la empresa va a mirar en la Fase 20** |
| D198 | Quien ve el nombre del pasajero en el historial | Solo el conductor que acepto, y lo aplica la funcion, no la pantalla. Lo mismo con la referencia del punto de recogida (D172). La primera version lo dejaba en manos de la politica `profiles_select_ride_counterpart` y **la prueba lo tumbo**: esa politica mira a la persona, no al viaje, asi que el nombre salia tambien en las ofertas rechazadas de alguien a quien ya habia llevado |
| D199 | Como se pagina | Limite y desplazamiento, veinte por tanda, con tope de 50 en el servidor. No hay cursor: un historial es dato pasado y casi no cambia mientras se mira. El tope no es desconfianza del cliente, es que por la API cualquiera puede pedir sin techo |
| D200 | Como se abre el detalle | Por identificador, pidiendo la fila otra vez, y no pasando la fila ya cargada por parametro. Cuesta una consulta y a cambio la pantalla funciona igual desde un enlace directo, al reabrir la aplicacion encima de ella y el dia que haya notificaciones (Fase 19). **Comprobado por enlace directo con un identificador ajeno**: responde "no encontramos ese servicio" |
| D201 | Como se escriben las fechas | A mano, con los doce nombres de mes, sin `Intl`. Hermes trae Intl en Android pero el formato depende del idioma del aparato: un telefono en ingles pintaria "August 14, 3:40 PM" dentro de una pantalla en espanol. Doce horas y "a. m." / "p. m.", que es como se dice la hora en Colombia |
| D202 | Donde vive el color del estado | En el icono, nunca en el texto, y cada desenlace con su propia forma. Es H14 aplicado: los pares de color de estado no llegan al contraste minimo, asi que un "Terminado" en verde seria dificil de leer. Ademas el color nunca es la unica senal |
| D203 | Que se hace con H15 | Se cierra en la **Fase 22**, no ahora, y el plan queda escrito en la migracion `20260819223000_h15_comment_tells_the_truth.sql`. Hoy la base de datos deja de mentir sobre si misma: el comentario de la politica dice que el acceso al perfil de la contraparte **no caduca**. Arreglarlo de verdad obliga a que el telefono deje de ser una columna legible, y eso toca los caminos vivos de las fases 12 a 14, que no se pueden volver a verificar con un solo emulador y sin movimiento |

| D233 | **La tarifa rural cuenta en los dos sentidos** | Error del asistente, encontrado por el usuario probando la aplicacion de verdad el 2026-08-26: `quote_fare` solo miraba el DESTINO. Un viaje del parque a Vereda Manzanares cobraba bien, 12.000; el mismo viaje al reves, de Manzanares al parque, cobraba 4.000 urbano, porque el destino era el parque y el origen no se miraba en absoluto. El conductor recorre la misma distancia en los dos sentidos. **La regla nueva**: se calcula si el origen es rural y si el destino es rural, cada uno por separado con la logica de D230; si ninguno lo es, urbano; si uno lo es, esa es la tarifa, sea origen o destino; **si los dos son rurales y distintos, gana el mas caro** -no hay tarifa de la empresa para un trayecto entre dos veredas, y cobrar de menos seria peor que cobrar de mas-. D219 se volvio simetrico con el mismo cambio: un origen sin lugar y lejos tampoco se puede cobrar, con su propio codigo, `ORIGIN_NOT_PRICED`, para que el mensaje no le diga "el destino" a quien penso en el punto de recogida |
### Decisiones de la Fase 15

| D234 | **La busqueda del punto mas cercano vuelve a comparar contra TODOS los lugares** | Correccion de un error del asistente en D233, encontrado por el usuario probando en la tablet y en el emulador el 2026-08-26: al pedir un servicio con "Tu ubicacion actual" como origen -un punto sin `place_id`, a 800 m-1,4 km del parque, en pleno pueblo- la aplicacion cobraba tarifa rural (Alto del Rio, La vibora) en vez de urbana. La causa: D230 ya habia resuelto esto para el destino, comparando contra TODOS los lugares activos; al repartir esa logica entre origen y destino para D233, la funcion auxiliar nueva (`rural_fare_for_point`) volvio a buscar solo entre lugares que YA TIENEN tarifa rural, sin comparar contra los urbanos -deshizo D230 sin darse cuenta-. Con `place_id` -eligiendo de la lista- nunca fallaba, porque ese camino no busca nada. La correccion devuelve el `left join` de D230 dentro de la funcion compartida. De paso goteo un segundo hallazgo, no un error nuevo: la comprobacion 57 de `prueba_calculo_tarifa.sql` esperaba que apagar la tarifa del lugar mas cercano "cayera" al siguiente rural activo -eso nunca fue la regla real de D230, que dice "el mas cercano, punto", dejando a D219 (distancia al centro) la unica salida si el mas cercano se queda sin tarifa-. Se corrigio la expectativa de la prueba, no el codigo |
| # | Decision | Valor |
|---|---|---|
| D181 | Terminar un servicio NO enciende la disponibilidad | `complete_ride` y `cancel_ride` acababan con `set is_available = true`, escrito en la Fase 5 cuando un viaje equivalia a estar ocupado. **D161 y D164 lo dejaron obsoleto y nadie volvio a mirarlo**: un conductor que apagaba el interruptor porque paraba de trabajar reaparecia disponible al cerrar su ultimo servicio, y con varios viajes encima quedaba "disponible" con el motorraton lleno. Se quito la linea en vez de recalcular: para encender con criterio habria que saber **quien** apago el interruptor, y ese dato no existe. Entre encender a quien no queria (invisible, y contra una decision aprobada) y dejar apagado a quien si (visible en la tarjeta mas grande de su pantalla, y a un toque), el segundo error es mucho mas barato |
| D182 | Un solo boton por tarjeta, el que toca ahora | No los cuatro con tres apagados. El conductor mira la tarjeta de reojo, a veces en movimiento, y una fila de botones grises es ruido que hay que leer para descartar. Cual es lo decide el estado, y el estado lo decide el servidor |
| D183 | Confirmacion solo al finalizar | Es la unica transicion irreversible de las cuatro, y la Fase 0 la dejo escrita como situacion a cubrir: "el conductor termina accidentalmente un servicio". Pedir confirmacion en las cuatro convertiria el ciclo normal en ocho toques y ensenaria a confirmar sin leer |
| D184 | Se publica `rides` ademas de `ride_requests` | De las cuatro transiciones, **solo dos tocan la solicitud**: iniciar y finalizar. Salir hacia el punto y anunciar la llegada se quedaban sin que nadie las oyera, y **la llegada es justo el aviso que hace que el pasajero salga a la calle**. D168 no se equivoco: publico la tabla correcta para lo que existia entonces, cuando no habia transiciones. El pasajero se suscribe a SU viaje, filtrado por identificador |
| D185 | Que ve el pasajero al terminar | Un resumen breve que el cierra cuando quiera, no una pantalla que se va sola a los cinco segundos: puede estar bajandose, guardando el telefono o pagando. Sin estrellas, que son de la Fase 17. Antes de esto la solicitud desaparecia y la pantalla se quedaba diciendo "tu motorraton va en camino" con los botones de "Volver a pedirlo" debajo |
| D186 | Ventana del resumen | Cinco minutos, configurable en `app_settings`. Cubre "bajarse y guardar el telefono"; pasado ese rato, quien abre la aplicacion viene a otra cosa. Se probo con treinta y el resumen recibia al pasajero media hora despues |
| D187 | El resumen solo cubre servicios TERMINADOS | No los cancelados. Cuando cancela el pasajero ya lo sabe, y cuando cancela el conductor antes de empezar la solicitud vuelve a `searching` y sigue viva. Queda fuera el caso de que el conductor cancele con el pasajero a bordo, que es de la **Fase 18**, la que decide que ve el pasajero ante cada tipo de cancelacion |
| D188 | La distancia del viaje cuenta solo el viaje | `complete_ride` medi­a **todos** los puntos del rastro, y la politica de la Fase 5 deja al conductor insertar puntos tambien mientras va hacia la recogida. El cliente solo graba durante el recorrido, asi que en uso normal salia bien, pero por la API se podia inflar la distancia con el trayecto de aproximacion. Ahora solo cuentan los puntos desde `started_at` |
| D189 | El rastro se graba cada 50 metros, no cada diez segundos | La posicion actual ya va cada diez (R9) y con eso el pasajero ve moverse el motorraton. El rastro es otra cosa: es el registro del viaje, y un punto cada diez segundos llenaria la tabla de puntos identicos con el conductor parado en un semaforo. Es el "filtro de distancia minima" que D14 dejo escrito |
| D190 | La navegacion sigue al estado | Con el pasajero fuera lleva al punto de recogida; con el a bordo, al destino. Y la etiqueta dice a donde va, "Ir a la recogida" o "Ir al destino", en vez de un "Cómo llegar" que obliga a deducir el destino del estado de la tarjeta mientras se conduce. Cierra lo que D179 dejo pendiente: hasta que existieron los estados, la aplicacion no sabia quien iba dentro |
| D191 | Las paradas no se reordenan | Aparecen en el orden en que el conductor las acepto, que es el unico que no nos hemos inventado. Ordenarlas por cercania seria facil y seria mentir: la mas cercana en linea recta puede estar al otro lado de una quebrada, y quien sabe si algo le queda de camino es el conductor. Es D161 aplicado |
| D193 | El mapa lo dibuja Mapbox, no Google | **Sustituye a D110.** La ruta se calculaba con Mapbox y se dibujaba sobre un mapa de Google, y en Amalfi los dos no coinciden: la linea cruzaba manzanas vacias. Se demostro renderizando la MISMA ruta con las MISMAS coordenadas sobre el mapa de Mapbox, donde cada tramo cae sobre una calle. Encaja con la Fase 8: de 39 sitios reales, Mapbox acerto 22 y Google 13. Cambia el modelo de costo —el mapa de Google era gratis e ilimitado dentro de la app; Mapbox cobra por usuarios activos al mes, con franja gratuita muy por encima de un piloto municipal— y **cierra el pendiente de los terminos de Mapbox sobre mapa ajeno** |
| D194 | Donde van el logo y la atribucion | Lo decide cada pantalla con `logoOffset`, no el componente. Son obligatorios por los terminos de Mapbox, y su sitio por defecto queda tapado por el bottom sheet; arriba lo tapa la cabecera de "Marca el punto". Cada pantalla tapa un sitio distinto, asi que no hay una posicion buena para todas |
| D195 | La referencia del mapa conserva su forma | `animateToRegion` y `fitToCoordinates` siguen existiendo con la misma firma, traducidas por dentro a la camara de Mapbox. **Es lo que permitio que el cambio de proveedor no tocara ninguna pantalla**, que es justo para lo que se escribio D117 |
| D192 | Una parada por vez, sin ruta multiparada | Cada parada se navega por separado. Una ruta con paradas intermedias obliga a Google Maps, porque **Waze no las admite desde un enlace**, y eso dejaria sin efecto el selector de aplicaciones de D178 |

| D235 | **El historial gana el valor; el recaudo es pantalla nueva, propia, solo lo completado** | Paso 7 del bloque especial. Dos decisiones separadas. (1) `list_driver_history` y `get_driver_job` -que ya existian desde la Fase 16- ganan tipo de servicio, descripcion de encomienda y el valor calculado, sin rehacerse: Postgres no deja usar `create or replace` para anadir columnas a un `returns table`, asi que se borraron y se crearon de nuevo, mismo patron que D233 con `quote_fare`. (2) El recaudo -"servicios realizados, valor de cada uno, total acumulado, por periodo"- es una funcion y una pestana nuevas, `list_driver_earnings`, decidida con el usuario: **pestana propia**, no una tarjeta encima de "Servicios", porque esa pestana mezcla rechazos y expiraciones sin valor y el recaudo es dinero, no registro operativo. **Solo cuenta `rides.status = 'completed'`**, no reutiliza `list_driver_history`. **El periodo lo decide el servidor con su propio reloj (D154), nunca un rango de instantes que mande el telefono**: `'today'`/`'week'` se calculan con `fare_timezone` y medianoche local; un rango personalizado recibe FECHAS, no timestamptz, por el mismo motivo -una fecha no arrastra huso horario-. La pantalla de esta version solo ofrece "Hoy" y "Esta semana"; el servidor ya acepta `'custom'` para cuando haga falta un selector de rango, que no se construyo por no ser necesario todavia |
### Decisiones de la Fase 14

| # | Decision | Valor |
|---|---|---|
| D172 | Quien ve la referencia del punto de recogida | Solo el conductor que ya acepto. NO viaja en la oferta. Es la misma linea que la Fase 12 trazo para el nombre y el telefono: antes de aceptar nadie se ha comprometido con nadie, y "la casa azul de la esquina" situa a una persona con bastante mas precision que el nombre de un sector |
| D173 | Una funcion de ruta y no dos | `fetchRoute` devuelve distancia, tiempo y trazado en la misma respuesta. Habia dos, una con `overview=false` para el pasajero y otra con el dibujo para el conductor. Al dibujar la ruta tambien al pasajero, mantenerlas habria significado **dos peticiones a Mapbox por cada cambio de destino** en vez de una. El trazado cuesta unos cientos de bytes sobre la misma respuesta (D171) |
| D174 | De donde salen las coordenadas de la ruta del pasajero | De la solicitud enviada, no del borrador. El borrador vive en memoria (D137) y esta vacio al reabrir la aplicacion, que es justo cuando el pasajero mas mira la pantalla. **Verificado cerrando la aplicacion del todo**: la ruta se reconstruye sola y la cuenta atras sigue donde iba |
| D175 | Cuando envia posicion el conductor | Con el interruptor encendido **o con un servicio encima**, no solo lo primero. Era un fallo real: desde D164 aceptar puede apagar la disponibilidad porque el motorraton se lleno, y el conductor dejaba de enviar posicion **justo mientras iba a recoger a tres personas**. Medido: 10 s exactos con el interruptor apagado y un servicio activo |
| D176 | Como recibe el pasajero la posicion | Tiempo real, no sondeo. El criterio de aceptacion 4 pide menos de quince segundos de retraso; el conductor envia cada diez, asi que sondeando cada diez el peor caso son veinte. Se publico `driver_locations`, la tercera tabla de la publicacion y **la que mas se actualiza del sistema**: es lo primero que hay que mirar si algo va lento (Fase 24) |
| D177 | Cada cuanto se recalcula el tiempo de llegada | Como mucho cada 30 segundos, no en cada posicion. En cada una serian seis peticiones a Mapbox por minuto y por servicio para afinar un numero que se ensena en minutos. Entre medias el numero se queda quieto, que es mas honesto que uno que parpadea |
| D178 | Con que se abre la navegacion | El esquema `geo:`, que hace que Android muestre **su propio selector** con las aplicaciones de mapas instaladas. El primer intento usaba `waze://` y `google.navigation:`, que arrancan la guia por voz directamente, pero saber cual esta instalada exige `canOpenURL`, y **desde Android 11 eso responde que no salvo que el manifiesto declare los paquetes**: tocar codigo nativo y recompilar el cliente. Se paga un toque de mas y se gana no depender de una recompilacion. Reversible cuando la Fase 25 recompile |
| D179 | A donde navega el conductor | Al punto de recogida. El destino va en la Fase 15, junto a "iniciar recorrido": hasta que existan los estados, la aplicacion no sabe si ya recogio al pasajero, y dos botones sin ese dato pueden mandarlo al sitio equivocado |
| D180 | Las paradas con varios servicios | Se queda como esta, un boton por servicio y **el conductor elige a cual va**. Es D161 aplicado: quien juzga el orden es el. Una lista de paradas ordenada necesita saber quien va ya a bordo, y eso nace con los estados de la Fase 15. **Ademas, Waze no admite paradas intermedias desde un enlace**, asi que multiparada obligaria a Google Maps y dejaria sin efecto el selector de D178 |

**D179 y D180 cierran D157**, que quedo abierta en la Fase 11: la navegacion se resuelve con un
enlace y no con un modulo propio, como se habia razonado alli.

**D160 deja obsoleta a D7.** La asignacion deja de ser "automatica por cercania" y pasa a ser
del primero que acepte: con todas las ofertas creadas a la vez, gana quien toca antes y no
quien esta mas cerca. Se eligio a sabiendas, razonando que en un pueblo con pocos motorratones
se parece a la radio de toda la vida, donde todos oyen la llamada.

### Decisiones revertidas

- **company_id / multi-empresa en base de datos:** propuesto inicialmente y descartado tras
  confirmar que la expansion se hara con instalaciones separadas por empresa. Cada empresa
  tendra su propio proyecto Supabase. La aplicacion publicada debe ser una sola, con el
  backend configurable por variables de entorno, para no publicar una app por municipio.

---

## 3. ARQUITECTURA: UNA APP CON ROLES

Se descarta desarrollar dos aplicaciones moviles independientes.

Justificacion: se comparte cerca del 70% del codigo (autenticacion, cliente Supabase, sistema
de diseno, mapas, tipos, ubicacion, notificaciones). El proyecto lo desarrolla una sola
persona, y dos aplicaciones significan dos builds, dos configuraciones, dos firmas y dos
publicaciones. La separacion se realiza mediante navegadores independientes que se eligen
tras leer el rol del perfil. Separar la app del conductor mas adelante tiene costo bajo;
mantener dos apps desde hoy tiene costo alto e inmediato.

Riesgo aceptado: el binario incluye codigo de conductor para pasajeros. No es un problema de
seguridad siempre que el backend aplique Row Level Security correctamente.

---

## 4. STACK TECNOLOGICO

Versiones confirmadas en la Fase 1 contra la documentacion oficial de Expo:
Expo SDK 57.0.8, React Native 0.86.0, React 19.2.3, TypeScript 6.0.3.
La plantilla oficial de Expo SDK 57 ya incluye TypeScript y expo-router.

- **Movil:** React Native + Expo + TypeScript
- **Panel administrativo:** Next.js + TypeScript
- **Backend y base de datos:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Mapas:** Google, con `react-native-maps` (D110). **Buscador de direcciones:** Mapbox
  (D111). Decidido en la Fase 8 probando 39 sitios reales de Amalfi
- **Build:** cliente de desarrollo propio compilado en local. Ya no se usa Expo Go
- **Notificaciones:** Expo Notifications
- **Formularios:** React Hook Form
- **Validaciones:** Zod
- **Estado global:** solo si resulta necesario. Preferencia por React Context, luego Zustand
- **Iconos:** libreria profesional compatible con React Native. Prohibido el uso de emojis

---

## 5. ALCANCE DEL MVP

### Incluido

**Pasajero**
- Registro, login, logout, sesion persistente, recuperacion de contrasena
- Perfil: nombre, telefono obligatorio, foto opcional
- Mapa con ubicacion actual, manejo de permisos denegados y de GPS apagado
- Seleccion de origen (ubicacion actual o manual) y destino (lugares frecuentes, mapa, buscador)
- Selector de cantidad de pasajeros, de 1 a 3, con validacion de capacidad
- Creacion de solicitud, seguimiento en tiempo real, datos del conductor asignado
- Cancelacion segun reglas
- Seguimiento del conductor en el mapa
- Historial de servicios
- Calificacion con estrellas y comentario opcional
- Notificaciones push de los eventos del servicio

**Conductor**
- Login. Sin auto-registro; el administrador crea la cuenta
- Interruptor disponible / no disponible
- Recepcion de solicitudes compatibles con la capacidad de su vehiculo
- Aceptar o rechazar, con prevencion de aceptacion simultanea
- Datos del pasajero: nombre, telefono, origen, destino, cantidad de pasajeros
- Transiciones: en camino, llegue, iniciar, finalizar
- Envio de ubicacion durante el servicio
- Historial y calificacion promedio

**Administrador (panel web)**
- Login administrativo separado
- Dashboard con servicios en curso
- Gestion de conductores: alta, edicion, bloqueo, activacion, documentos
- Gestion de vehiculos y asignacion conductor-vehiculo
- Gestion de lugares frecuentes del municipio
- Listado de pasajeros con bloqueo
- Listado e inspeccion de servicios, con linea de tiempo y recorrido en mapa
- Asignacion manual de conductor a una solicitud en busqueda
- Reportes y calificaciones
- Registro de auditoria de acciones administrativas

**Transversal**
- Sistema de diseno propio, sin emojis, con iconografia profesional
- Row Level Security y validacion de transiciones en servidor
- Manejo de errores, estados de carga y estados vacios en toda pantalla
- Idioma: espanol unicamente

### Excluido del MVP

iOS. Pagos y tarifas. Asignacion de multiples vehiculos a una solicitud. Reservas
programadas. Chat y llamadas enmascaradas. Boton SOS, contactos de emergencia y compartir
recorrido. Promociones. Multi-empresa dentro de una misma instalacion. Analitica avanzada y
reporteria exportable. Aplicacion independiente para conductores. Verificacion automatica de
documentos.

---

## 6. ROLES

- **PASAJERO:** se registra libremente
- **CONDUCTOR:** no puede auto-registrarse. Alta exclusiva por el administrador
- **ADMINISTRADOR:** acceso unicamente al panel web. Sin registro publico

---

## 7. FLUJOS

### 7.1 Pasajero

1. Abre la app. Sin sesion: bienvenida, registro o login
2. Registro con validaciones y creacion del perfil con rol passenger
3. Mapa principal. Solicitud de permiso de ubicacion con pantalla explicativa previa
4. Ubicacion actual centrada. Bottom sheet con "A donde vas"
5. Seleccion de destino: lugares frecuentes, punto en el mapa, buscador de direcciones
6. Confirmacion del origen, por defecto la ubicacion actual, editable
7. Seleccion de cantidad de pasajeros, de 1 a 3
8. Pantalla de confirmacion con origen, destino, pasajeros, distancia y tiempo estimados.
   Sin ningun monto
9. Confirma. Estado SEARCHING con opcion de cancelar sin penalizacion
10. Un conductor acepta. Estado ASSIGNED. Tarjeta con el numero de motorraton destacado y,
    como apoyo, foto, nombre, calificacion, placa, modelo y telefono del conductor
11. Seguimiento del conductor en el mapa. Estado DRIVER_ON_THE_WAY
12. El conductor confirma llegada. Estado DRIVER_ARRIVED y notificacion push
13. El conductor inicia el recorrido. Estado IN_PROGRESS
14. El conductor finaliza. Estado COMPLETED y resumen del viaje
15. Pantalla de calificacion con estrellas obligatorias, comentario opcional y opcion de
    reportar un problema
16. Regreso al mapa. El viaje queda en el historial

Ramas de excepcion: nadie acepta en 5 minutos, se pasa a EXPIRED con opcion de reintentar.
El conductor cancela, vuelve a SEARCHING automaticamente. El pasajero cancela, pasa a
CANCELLED con motivo. Si cierra la app durante un viaje activo, al reabrir se restaura el
estado desde el servidor.

### 7.2 Conductor

1. Login. No existe pantalla de registro para conductores
2. Si la cuenta esta pendiente o bloqueada, ve una pantalla informativa y no puede operar
3. Pantalla principal: mapa, ubicacion, interruptor de disponibilidad, vehiculo asignado
   con la capacidad visible
4. Al ponerse disponible, comienza el envio de ubicacion y queda elegible para solicitudes
5. Llega una solicitud compatible: notificacion y tarjeta con origen, destino, distancia
   hasta el pasajero, cantidad de pasajeros y temporizador de 20 segundos
6. Acepta. El backend valida de forma atomica que la solicitud siga libre. Si otro conductor
   gano, recibe un mensaje claro, no un error
7. Rechaza o deja expirar. La solicitud se ofrece al siguiente conductor y el rechazo queda
   registrado para no volver a ofrecersela
8. Aceptada: navegacion al punto de recogida, datos y telefono del pasajero
9. Pulsa "He llegado", habilitado solo dentro de 150 metros del punto de recogida
10. Pulsa "Iniciar viaje", con confirmacion
11. Navega al destino. Su ubicacion alimenta el seguimiento del pasajero
12. Pulsa "Finalizar", con confirmacion explicita para evitar finalizaciones accidentales
13. Resumen, calificacion al pasajero, regreso a estado disponible
14. Consulta de historial y calificacion promedio

### 7.3 Administrador

1. Login en el panel web con cuenta de rol admin
2. Dashboard: servicios activos, conductores conectados, solicitudes sin asignar, alertas
3. Conductores: alta con creacion de la cuenta de acceso, edicion, documentos, aprobacion,
   bloqueo, reactivacion, historial y calificaciones
4. Vehiculos: alta con numero de unidad, placa, tipo, modelo y capacidad maxima. El numero
   de unidad es obligatorio y unico. Asignacion a un conductor
5. Pasajeros: listado, detalle, historial, bloqueo
6. Lugares frecuentes: alta y edicion de los puntos de referencia del municipio
7. Servicios: listado filtrable, detalle con linea de tiempo de estados y recorrido en mapa.
   Asignacion manual de conductor a una solicitud en busqueda
8. Reportes y calificaciones: bandeja de problemas con estado de gestion
9. Configuracion: parametros operativos
10. Auditoria: toda accion sensible queda registrada con actor, fecha y datos anteriores

---

## 8. MAQUINA DE ESTADOS

### Nivel solicitud (ride_requests.status)

```
SEARCHING  -->  ASSIGNED  -->  IN_PROGRESS  -->  COMPLETED
    |              |                |
    +--> EXPIRED   +--> CANCELLED <-+
    +--> CANCELLED
```

### Nivel viaje por vehiculo (rides.status)

```
ASSIGNED --> DRIVER_ON_THE_WAY --> DRIVER_ARRIVED --> IN_PROGRESS --> COMPLETED
                    |                    |                |
                    +--------------------+----------------+--> CANCELLED
```

Notas de diseno:

- REQUESTED y SEARCHING se fusionaron en SEARCHING. Entre ambos no ocurre nada observable
- EXPIRED es un terminal distinto de CANCELLED. "Nadie acepto" y "el usuario cancelo" son
  hechos operativos diferentes y mezclarlos arruina las estadisticas de cobertura de flota
- CANCELLED siempre va acompanado de cancelled_by (passenger, driver, admin, system) y de
  cancellation_reason
- Todas las transiciones se ejecutan mediante funciones de base de datos con validacion del
  estado origen y del actor. El cliente nunca hace UPDATE directo sobre el estado

### Situaciones a cubrir

Nadie acepta la solicitud. El conductor cancela. El pasajero cancela. El conductor pierde
conexion. El usuario cierra la aplicacion. El GPS deja de responder. Dos conductores
intentan aceptar simultaneamente. El conductor finaliza accidentalmente un servicio. El
administrador bloquea a un conductor durante una operacion.

---

## 9. REGLAS DE NEGOCIO

| # | Regla | Valor |
|---|---|---|
| R1 | Antes de crear la solicitud se verifica que haya al menos un conductor disponible. Si no hay ninguno, se informa de inmediato sin crear la solicitud. Si hay conductores pero ninguno acepta, la solicitud expira | 5 minutos |
| R2 | Tiempo para que un conductor responda una oferta | 20 segundos |
| R3 | Cancelacion del pasajero sin consecuencia despues de ASSIGNED | 2 minutos |
| R4 | Se ofrece la solicitud a todos los conductores disponibles del municipio, ordenados por cercania. Sin radio de corte | Sin radio |
| R5 | Distancia para habilitar "He llegado" | 150 metros |
| R6 | Solicitudes activas simultaneas por pasajero | 1 |
| R7 | **SUSTITUIDA POR D161.** Un conductor puede llevar varios viajes a la vez mientras la suma de sus pasajeros no pase de la capacidad de su motorraton, y todos en la misma unidad. Quien juzga si una solicitud le queda de camino es el, mirando la ruta | Por asientos, no por viajes |
| R8 | Calificaciones por servicio y por parte | 1, no editable |
| R9 | Frecuencia de envio de ubicacion del conductor | Disponible: 30 s. En viaje: 10 s o 50 m |
| R10 | Conductor sin senal durante un viaje activo | 3 min, alerta al admin, sin cancelacion automatica |
| R11 | Maximo de pasajeros por solicitud | 3, configurable por el admin |
| R12 | Un conductor no vuelve a recibir una solicitud que ya rechazo | Controlado por ride_offers |

Los grupos de mas de 3 personas quedan fuera del MVP. La app mostrara un mensaje indicando
que deben solicitar dos servicios por separado.

---

## 10. TABLAS DEL MODELO (IMPLEMENTADAS EN LA FASE 5)

Las 17 tablas existen en la base de datos. El detalle de migraciones, funciones y
como trabajar con ellas esta en la seccion 15.4.

```
profiles                    Datos comunes de todo usuario y su rol
drivers                     Datos especificos del conductor y su estado de aprobacion
vehicles                    Numero de unidad, placa, tipo, modelo y capacidad maxima
driver_vehicle_assignments  Que conductor opera que vehiculo y desde cuando
document_types              Tipos de documento configurables desde el panel
documents                   Documentos de conductores y vehiculos, con vencimiento opcional
places                      Lugares frecuentes del municipio, gestionados por el admin
ride_requests               Solicitud del grupo: origen, destino, cantidad de pasajeros
rides                       Viaje concreto de un vehiculo. Una solicitud puede tener 1..N
ride_offers                 A que conductor se ofrecio cada solicitud y que respondio
driver_locations            Una fila por conductor, actualizada. Posicion actual
ride_locations              Inserciones solo durante un viaje activo. Recorrido historico
ratings                     Calificaciones entre pasajero y conductor
reports                     Problemas reportados y su gestion
notifications               Registro de notificaciones enviadas
app_settings                Parametros operativos configurables
admin_audit_logs            Auditoria de acciones administrativas
```

Decisiones de modelado ya tomadas:

- La separacion entre ride_requests y rides es lo que permitira activar la asignacion de
  multiples vehiculos mas adelante sin rehacer la logica existente
- La capacidad es un atributo del vehiculo, nunca un numero fijo en el codigo
- Los tipos de documento son datos, no codigo. Anadir un documento nuevo sera agregar una
  fila desde el panel, no una migracion
- driver_locations se sobrescribe y no crece. ride_locations solo se alimenta durante un
  viaje activo y con filtro de distancia minima
- No se anaden columnas de tarifa ni de pago en el MVP. Anadirlas despues es una migracion
  aditiva trivial

---

## 11. CRITERIOS DE ACEPTACION DEL MVP

Verificables en emulador y en al menos un dispositivo Android fisico:

1. Un pasajero nuevo puede registrarse, iniciar sesion y su sesion persiste tras cerrar la app
2. Un pasajero puede completar el ciclo solicitud - calificacion sin intervencion manual en
   la base de datos
3. Dos conductores en sesiones simultaneas reciben la misma solicitud y solo uno logra
   aceptarla. El otro recibe un mensaje claro, no un error
4. El pasajero ve moverse al conductor en el mapa con un retraso menor a 15 segundos
5. Cerrar y reabrir la app durante un viaje activo restaura el estado correcto
6. Denegar el permiso de ubicacion no rompe la app. Ofrece seleccion manual
7. Un conductor bloqueado por el admin no puede operar. Inicia sesion y ve una pantalla
   informativa con el motivo. **Corregido en la Fase 6:** la redaccion anterior decia "no
   puede iniciar sesion ni operar", que contradecia al flujo 7.2 paso 2, donde la cuenta
   bloqueada ve una pantalla informativa, lo cual exige poder entrar. Las dos cosas no
   podian cumplirse a la vez. Se conserva el flujo 7.2, que es mas especifico y trata mejor
   al usuario: se le explica que pasa en lugar de darle un "credenciales incorrectas" falso.
   Ademas Supabase Auth no conoce `profiles.status`, asi que impedir el login exigiria un
   disparador sobre el inicio de sesion. Verificado por API: un bloqueado obtiene token y
   la base de datos le rechaza cualquier operacion con `ACCOUNT_BLOCKED`
8. Un pasajero no puede leer datos de otros pasajeros ni modificar el estado de un viaje
   mediante llamadas directas a la API
9. El admin puede dar de alta un conductor y un vehiculo, y ese conductor puede operar sin
   pasos manuales adicionales
10. Ninguna pantalla muestra emojis. Toda la iconografia proviene de la libreria elegida

### Criterio de "terminado" por funcionalidad

Una funcionalidad no esta terminada porque el codigo compile. Debe funcionar, tener
validaciones, manejar errores previsibles, tener estado de carga, tener estado vacio cuando
aplique, mantener coherencia visual, funcionar en emulador o dispositivo, no generar errores
importantes en consola, haber sido probada y estar documentada cuando corresponda.

---

## 12. PRINCIPIOS DE DISENO VISUAL

Minimalismo. Fondo principalmente blanco o neutro. Negro y tonos oscuros para acciones
principales. Un color propio de marca para estados importantes. Espaciado amplio. Bordes
moderadamente redondeados. Sombras discretas. Tipografia altamente legible. Mapa como
protagonista. Bottom sheets para acciones de viaje. Estados de carga profesionales y
skeleton loaders. Feedback visual inmediato. Diseno adaptable.

Prohibido el uso de emojis en la interfaz. Toda representacion visual mediante iconos de una
libreria profesional.

Inspiracion en aplicaciones premium de movilidad, con identidad propia. No se copian
identidad, logotipos ni recursos graficos de terceros.

---

## 13. SEGURIDAD

Autenticacion segura. Autorizacion por roles. Row Level Security en todas las tablas.
Validacion del lado servidor. Proteccion de datos personales. Control de acceso
administrativo. Manejo seguro de variables de entorno. Registro de acciones administrativas.
Proteccion contra manipulacion del estado de viajes. Validacion de asignacion del conductor.
Prevencion de aceptacion simultanea del mismo servicio.

Nunca confiar unicamente en validaciones del frontend.

---

## 14. PLAN DE FASES Y ESTADO

| Fase | Descripcion | Estado |
|---|---|---|
| 0 | Definicion funcional | COMPLETADA Y APROBADA |
| 1 | Preparacion del equipo | COMPLETADA Y APROBADA |
| 2 | Creacion y organizacion del proyecto | COMPLETADA |
| 3 | Sistema de diseno | COMPLETADA Y APROBADA |
| 4 | Navegacion | COMPLETADA Y APROBADA |
| 5 | Supabase y base de datos | COMPLETADA Y APROBADA |
| 6 | Autenticacion | COMPLETADA Y APROBADA |
| 7 | Perfil del pasajero | COMPLETADA Y APROBADA |
| 8 | Mapa principal | COMPLETADA Y APROBADA |
| 9 | Seleccion de origen y destino | COMPLETADA Y APROBADA |
| 10 | Seleccion de pasajeros | COMPLETADA Y APROBADA |
| 11 | Creacion de solicitud | COMPLETADA Y APROBADA |
| 12 | Modulo del conductor | COMPLETADA Y APROBADA |
| 13 | Asignacion en tiempo real | COMPLETADA Y APROBADA |
| 14 | Seguimiento del conductor | COMPLETADA Y APROBADA |
| 15 | Ciclo completo del servicio | COMPLETADA Y APROBADA |
| 16 | Historial | COMPLETADA Y APROBADA |
| 17 | Calificaciones | COMPLETADA Y APROBADA |
| 18 | Cancelaciones y errores operativos | COMPLETADA Y APROBADA |
| 19 | Notificaciones | COMPLETADA Y APROBADA |
| — | **BLOQUE ESPECIAL: tarifas, encomiendas y carga** (seccion 15.21) | **TERMINADO Y COMITEADO** |
| 20 | Panel administrativo | **EN CURSO.** Paso 1 de 11 hecho y verificado (seccion 15.22) |
| 21 | Gestion de conductores y vehiculos | Pendiente |
| 22 | Seguridad y auditoria | Pendiente |
| 23 | Pruebas | Pendiente |
| 24 | Optimizacion | Pendiente |
| 25 | Preparacion para produccion | Pendiente |
| 26 | Publicacion y despliegue | Pendiente |

---

## 15. ENTORNO DE DESARROLLO VERIFICADO

Equipo unico de desarrollo. Windows 11 Pro 64 bits. AMD Ryzen 5 5600G, 6 nucleos y
12 hilos. 15,8 GB de RAM. Virtualizacion por firmware habilitada e hipervisor presente,
requisito para la aceleracion del emulador en procesadores AMD.

| Herramienta | Version | Ubicacion o nota |
|---|---|---|
| Git | 2.53.0 | user.name, user.email, init.defaultBranch=main, core.autocrlf=false |
| Node.js | v24.15.0 | C:\nvm4w\nodejs, gestionado por nvm-windows |
| npm | 11.12.1 | Invocar siempre como npm.cmd desde PowerShell |
| JDK | 17 | JAVA_HOME=C:\Program Files\Java\jdk-17. Java 26 tambien instalado |
| Android Studio | Quail 2, 2026.1.2 | C:\Program Files\Android\Android Studio |
| Android SDK | 4,04 GB | ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk |
| Plataformas SDK | android-36 y android-36.1 | |
| Build-Tools | 36.0.0 | |
| Platform-Tools | 37.0.0 | adb funcional |
| cmdline-tools | latest, unica version | |
| Imagen de emulador | google_apis_playstore x86_64, API 36.1 | Unica imagen instalada |
| Emulador (AVD) | motomoto_phone | 2 GB RAM, GPU hardware, teclado fisico. Arranca en 93 s |
| Tablet fisica | Lenovo TB-X306X | **YA NO ESTA DISPONIBLE desde la Fase 14.** Fue el unico aparato real del proyecto: 800 dp de ancho logico frente a los 411 del emulador, y GPS por hardware. Todo lo que se probo en ella hasta la Fase 13 sigue valiendo; lo que venga despues no tiene donde probarse en hardware |
| Fake GPS | instalado en el emulador | Le da a la aplicacion una posicion de Amalfi **al arrancar el vigilante**. Con la aplicacion corriendo, mover el punto no le llega: comprobado en la Fase 14 |
| VS Code | 1.129.0 | ESLint, Prettier, Expo Tools, GitLens, Postgres ya instalados |

Rutas anadidas al PATH de usuario, preservando el tipo ExpandString:

```
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\emulator
%ANDROID_HOME%\cmdline-tools\latest\bin
```

Herramientas propias del usuario que conviven en el equipo y no deben romperse:
nvm-windows, Maven 3.9.16, Allure 2.42.1, PostgreSQL 18, GitHub Desktop, Python 3.14.4.
El PATH de usuario usa referencias del tipo %NVM_HOME% y %MAVEN_HOME%, por lo que
cualquier modificacion debe conservar el tipo de registro ExpandString.

### Aviso operativo importante

La politica de ejecucion de scripts de PowerShell esta en Restricted. Por decision del
usuario no se modifico. **Todos los comandos de Node deben invocarse con sufijo .cmd**:
npx.cmd, npm.cmd. Sin el sufijo fallan con PSSecurityException.

### Prueba de fuego superada

App Expo minima creada, ejecutada en el emulador mediante Expo Go y modificada en caliente.
El cambio de src/app/index.tsx se reflejo en el emulador sin reiniciar nada. Verificado por
captura de pantalla del emulador. La app de prueba fue eliminada al cerrar la fase.

---

## 15.2 PROYECTO Y HERRAMIENTAS (Fase 2)

Repositorio: https://github.com/jhan0711/motomoto — **privado**. Rama unica `main`.

### Comandos del proyecto

Recordatorio: en PowerShell hay que invocarlos siempre con sufijo `.cmd`.

| Comando | Que hace |
|---|---|
| `npm.cmd start` | Arranca el servidor de desarrollo |
| `npm.cmd run android` | Arranca y abre directamente en Android |
| `npm.cmd run typecheck` | Verifica tipos sin ejecutar. `tsc --noEmit` |
| `npm.cmd run lint` | ESLint mediante `expo lint` |
| `npm.cmd run format` | Formatea con Prettier |
| `npm.cmd run format:check` | Comprueba formato sin modificar |

**Antes de cada commit los tres controles deben salir en 0:** `typecheck`, `lint`,
`format:check`.

### Archivos de configuracion creados

```
tsconfig.json       strict mas 4 comprobaciones adicionales. Excluye node_modules y example
eslint.config.js    eslint-config-expo en formato plano. Ignora dist, example, node_modules
.prettierrc         Comillas simples, comas finales, ancho 100, endOfLine lf
.prettierignore     Excluye example, node_modules, salidas de compilacion y PROJECT_STATUS.md
.gitattributes      Normaliza a LF. CRLF en .bat, .cmd y .ps1. Binarios sin normalizar
.gitignore          Protege .env, .env.*, google-services.json. Rescata .env.example
.env.example        Documenta las variables y la advertencia sobre EXPO_PUBLIC_
.vscode/settings.json    Formateo al guardar con Prettier, EOL en LF
.vscode/extensions.json  Recomienda Expo Tools, ESLint y Prettier
LICENSE             Aviso de propiedad privada, sin nombre de titular todavia
```

### Nota operativa: conectar la app al servidor

**Desde la Fase 8 ya no se usa Expo Go.** El procedimiento vigente esta en la seccion 15.7 y
en los comandos de la seccion 17.

La redireccion de puerto por adb sigue siendo mas fiable que depender de la IP de la red
local, que desde dentro del emulador no siempre es alcanzable.

---

## 15.4 BASE DE DATOS (Fase 5)

Proyecto Supabase: **bosodjcehvqmmegxdmlu**, nombre `motomoto`, region us-east-1,
PostgreSQL 17.6, organizacion propia (no gestionada por Vercel). PostGIS 3.3.

### Migraciones aplicadas, en orden

```
20260729002339_initial_types_and_profiles          extensiones, 9 enums, profiles
20260729002949_fleet_drivers_vehicles_documents    drivers, vehicles, asignaciones, documentos
20260729004136_geography_places_and_driver_locations  places, driver_locations, find_available_drivers
20260729004853_operations_requests_rides_offers    ride_requests, rides, ride_offers, ride_locations
20260729005909_ratings_reports_settings_audit      ratings, reports, notifications, app_settings, auditoria
20260729011134_rls_policies                        46 politicas y disparadores de proteccion
20260729012123_fix_rls_policy_recursion            corrige recursion en 4 politicas
20260729013123_ride_state_transition_functions     10 funciones publicas, 3 internas
20260729014732_fix_rating_refresh_blocked_by_guard corrige el choque entre dos disparadores
20260801012726_seed_amalfi_places                  los 36 lugares frecuentes (Fase 9)
20260801015032_list_places_function                lectura con latitud y longitud (Fase 9)
20260804234258_service_area                        poligono de Amalfi, margen y validacion (Fase 11)
20260804235949_expire_requests_schedule            pg_cron y limpieza dirigida (Fase 11)
20260805000923_get_active_request                  la solicitud viva del pasajero (Fase 11)
20260805004304_fix_cancel_request_actor_cast       corrige E25 (Fase 11)
20260805150842_driver_offers_and_realtime          ofertas del conductor y tiempo real (Fase 12)
20260805153818_offer_to_all_available_drivers      D160, H12 y H13 (Fase 12)
20260805180658_driver_active_rides                 viajes en curso con datos del pasajero (Fase 12)
...
20260825223000_fare_tables                         urban_fares, rural_fares, cargo_types (bloque especial)
20260825234500_service_type_and_cargo              service_type, parcel_description, ride_request_cargo
20260826010000_fare_calculation                    quote_fare y las cinco columnas de valor
20260826024500_rural_fare_nearest_point            D226, la tarifa del destino rural mas cercano
20260826040000_request_ride_with_fare              request_ride con valor, carga y encomienda
20260826053000_nearest_place_wins                  D230, corrige D226: gana el nombre mas cercano
20260826060000_seed_rural_fares_batch1              24 de 36 destinos rurales, verificados
20260826070000_seed_rural_fares_batch2              La víbora, Manzanares, Cañada Honda, Finca Posada
```

**Esta lista no esta completa** y se quedo corta en la Fase 12; las 52 aplicadas se ven con
`npx.cmd supabase migration list`. Las ocho ultimas si estan puestas porque es donde se
sigue.

Totales, contados contra el servidor el 2026-08-26: **22 tablas, 54 politicas, 48 funciones,
63 lugares (62 activos mas 1 historico desactivado), 28 tarifas rurales cargadas**.
Antes del bloque especial eran 18, 47 y 47. Lo nuevo son las cuatro tablas de tarifas y carga,
sus siete politicas y `quote_fare`. **`request_ride` todavia no se ha tocado.**

**Tiempo real activo** sobre `ride_offers`, la unica tabla nuestra publicada. Cada suscriptor
recibe solo sus propias filas: las politicas de seguridad se aplican tambien ahi, comprobado
con dos sesiones simultaneas, una de conductor y otra de pasajero.

**pg_cron esta activo** con una tarea, `expire-stale-requests`, que corre cada minuto. Se
consulta con `select * from cron.job;` y su historial con `select * from cron.job_run_details;`.

### Funciones accesibles desde la aplicacion

```
request_ride(origen_lng, origen_lat, origen_label,
             destino_lng, destino_lat, destino_label,
             passenger_count, origin_place_id?, destination_place_id?) -> uuid
cancel_request(request_id, reason?)
accept_ride_offer(offer_id) -> uuid del viaje
reject_ride_offer(offer_id)
start_driving_to_pickup(ride_id)
confirm_driver_arrival(ride_id)
start_ride(ride_id)
complete_ride(ride_id)
cancel_ride(ride_id, reason?)
rate_ride(ride_id, stars, comment?) -> uuid
list_places() -> id, name, description, lat, lng
is_within_service_area(lng, lat) -> boolean                            (Fase 11)
list_driver_offers() -> ofertas vivas del conductor, sin datos del pasajero  (Fase 12)
list_driver_active_rides() -> viajes en curso, con nombre y telefono         (Fase 12)
get_active_request() -> id, status, passenger_count, coordenadas,
                        etiquetas, requested_at, expires_at,
                        seconds_remaining                              (Fase 11)
```

`list_places` es la unica **security invoker** de la lista, a proposito: se ejecuta con los
permisos de quien llama, asi que las politicas de `places` se siguen aplicando. Las demas son
security definer porque necesitan saltarselas para romper recursiones.

Internas, sin permiso para los roles publicos: `offer_request_to_drivers`,
`assert_ride_driver`, `expire_stale_requests`, `find_available_drivers`.

Auxiliares de politicas, todas security definer: `auth_role`, `is_admin`,
`participates_in_ride`, `has_active_ride_with_driver`, `owns_request`,
`driver_linked_to_request`, `shares_ride_with`, `is_active_driver_of_ride`,
`get_setting`.

### Errores de las funciones

Mensaje en espanol para mostrar al usuario, codigo estable en el campo `hint`:

```
PROFILE_NOT_FOUND      ACCOUNT_BLOCKED        NOT_A_PASSENGER
PHONE_REQUIRED         PASSENGER_COUNT_OUT_OF_RANGE
ACTIVE_REQUEST_EXISTS  NO_DRIVERS_AVAILABLE   OFFER_NOT_FOUND
OFFER_ALREADY_ANSWERED OFFER_EXPIRED          REQUEST_ALREADY_TAKEN
NO_VEHICLE_ASSIGNED    OFFER_NOT_AVAILABLE    RIDE_NOT_FOUND
INVALID_STATE_TRANSITION  TOO_FAR_FROM_PICKUP
REQUEST_NOT_FOUND      NOT_A_PARTICIPANT      RIDE_NOT_COMPLETED
ALREADY_RATED
```

### Reglas garantizadas por la base de datos, no por el codigo

Un conductor no aprobado no puede estar disponible. Dos conductores no pueden aceptar
la misma solicitud. Un pasajero no puede tener dos servicios activos. Nadie puede
calificar dos veces el mismo viaje. Un viaje no puede empezar antes de que el conductor
llegue. Un usuario no puede hacerse administrador. Un conductor no puede subirse la nota
ni aprobarse. Un vehiculo no puede tener dos conductores activos.

### Como trabajar con la base de datos

```powershell
npx.cmd supabase migration new <nombre>        # crea el archivo
npx.cmd supabase db push                       # aplica las pendientes
npx.cmd supabase migration list                # que hay aplicado
npx.cmd supabase db query --linked "<sql>"     # consulta el servidor
npx.cmd supabase db query --linked -f <ruta>   # ejecuta un archivo
npx.cmd supabase gen types typescript --linked # regenera los tipos
```

**Para regenerar los tipos sin BOM en Windows PowerShell 5.1**, donde `-Encoding utf8NoBOM`
no existe y `utf8` a secas escribe BOM:

```powershell
$tipos = npx.cmd supabase gen types typescript --linked | Out-String
[System.IO.File]::WriteAllText("C:\dev\motomoto\src\types\database.ts", $tipos,
  (New-Object System.Text.UTF8Encoding($false)))
```

**Sin `--linked` intenta conectarse a una base local que no existe.** El aviso sobre
Docker que aparece en `db push` es inocuo: solo afecta a una cache local del catalogo.

Los tipos se regeneran tras cada migracion y se escriben en `src/types/database.ts`
sin BOM. Nunca se editan a mano.

### Reglas aprendidas, no repetir estos errores

1. Toda politica que consulte otra tabla protegida debe hacerlo mediante una funcion
   security definer. Una subconsulta directa entre dos tablas que se referencian
   provoca recursion infinita, error 42P17.
2. `select a.*, b.col into var_fila, var_col` no funciona: PL/pgSQL asigna columna a
   columna. Hay que usar dos consultas.
3. Un disparador de proteccion de columnas puede anular a un disparador del sistema.
   Se distinguen con una marca local a la transaccion.
4. Probar suplantando roles reales, nunca con el rol privilegiado. Con el privilegiado
   las politicas ni se evaluan y todo parece correcto.

### Como probar suplantando un usuario

```sql
set local role authenticated;
set local request.jwt.claims to '{"sub":"<uuid>","role":"authenticated"}';
-- consultas como ese usuario
reset role;
reset request.jwt.claims;
```

Los scripts de prueba crean usuarios en `auth.users` con correos terminados en
`@motomoto.test` y los borran al final; el borrado en cascada arrastra el resto.

**`set local` solo funciona dentro de una transaccion, y la CLI no abre una por ti.** Pasado
como comando suelto a `db query`, no tiene efecto: la funcion acaba corriendo como postgres,
`auth.uid()` es nulo y la prueba sale mal por el motivo equivocado. Se perdio un rato con esto
en la Fase 14. La forma que si funciona es meterlo en un bloque `do $$ ... $$` dentro de un
archivo y ejecutarlo con `-f`:

```sql
do $suplantar$
begin
  execute 'set local role authenticated';
  execute format('set local request.jwt.claims to %L',
    '{"sub":"<uuid>","role":"authenticated"}');

  perform public.la_funcion_que_sea(...);

  execute 'reset role';
  execute 'reset request.jwt.claims';
end;
$suplantar$;
```

**Y la CLI solo devuelve el resultado de la ULTIMA consulta del archivo.** Si el script imprime
un resumen y un detalle, el detalle va al final o no se ve.

---

## 15.5 AUTENTICACION (Fase 6)

### Archivos

```
src/features/auth/schemas.ts        Validaciones con Zod. Replican las restricciones de la BD
src/features/auth/errors.ts         Traduccion de los errores de Supabase al espanol
src/features/auth/auth-service.ts   Unico punto que llama a supabase.auth
src/features/auth/session.tsx       Sesion real. Rol, estado y permiso de operar
src/features/auth/form-error.tsx    Error de formulario completo, anunciado como alerta
src/app/(auth)/login.tsx            Sirve a pasajero y conductor. El rol se lee despues
src/app/(auth)/register.tsx         Solo pasajeros. El rol lo pone la base de datos
src/app/(auth)/forgot-password.tsx  Confirmacion identica exista o no la cuenta (D74)
src/app/(auth)/reset-password.tsx   Contrasena nueva, al final del enlace del correo
src/app/account-status.tsx          Bloqueado, pendiente, admin o cuenta incompleta
```

Ninguna funcion del servicio lanza excepciones: todas devuelven un resultado que obliga a
comprobar si salio bien. Un `await` sin `try` es la forma mas comun de que un error de
autenticacion desaparezca sin dejar rastro.

### Lo que ya existia y no hubo que construir

`handle_new_user`, el disparador `on_auth_user_created` y `profiles_protect_columns` se
construyeron en la Fase 5. La Fase 6 solo los verifico. El perfil lo crea la base de datos y
no la aplicacion: si lo creara la app con un segundo INSERT, un corte de red entre las dos
llamadas dejaria un usuario sin perfil, en un limbo del que no se puede salir.

### Configuracion del proyecto Supabase, hecha desde el panel

- Authentication → Providers → Email: **habilitado**
- Confirm email: **desactivado** (D91)
- Authentication → URL Configuration → Redirect URLs: `motomoto://*` y
  `exp://127.0.0.1:8081/--/*`

Se comprueba sin entrar al panel, con una lectura sin efectos:

```powershell
# Debe devolver external.email = True y mailer_autoconfirm = True
Invoke-RestMethod -Uri "$url/auth/v1/settings" -Headers @{ apikey = $key }
```

### Como probar la recuperacion de contrasena en desarrollo

El navegador de Android no entrega el enlace a la app (H7), asi que en desarrollo se dispara
el enlace directamente. Con un par de tokens reales obtenidos por la API:

```powershell
adb shell "am start -a android.intent.action.VIEW -d 'exp://127.0.0.1:8081/--/reset-password#access_token=<t>&refresh_token=<r>&type=recovery' host.exp.exponent"
```

Y para el caso de enlace caducado, que es el mas frecuente en la vida real:

```powershell
adb shell "am start -a android.intent.action.VIEW -d 'exp://127.0.0.1:8081/--/reset-password#error=access_denied&error_code=otp_expired' host.exp.exponent"
```

### Reglas aprendidas, no repetir estos errores

1. `profiles_protect_columns` **no exime al rol privilegiado**, solo a un administrador con
   sesion, porque `is_admin()` depende de `auth.uid()`. Preparar un estado con el rol
   privilegiado no funciona: el disparador lo revierte igual. Consecuencia para la Fase 21:
   no existe forma de crear el primer administrador con un UPDATE. Hay que sustituir la fila,
   porque el disparador es BEFORE UPDATE y no cubre INSERT.
2. El rol `authenticated` no puede leer `auth.users`. Los identificadores se resuelven antes
   de suplantar, o con una tabla temporal con permiso concedido.
3. `set local` solo acepta literales. Para suplantar cuentas creadas por la API, con
   identificadores aleatorios, hay que usar `set_config(..., true)`.
4. La API de Auth **rechaza los correos `@motomoto.test`** con `email_address_invalid`. Esa
   convencion sirve insertando en SQL, no para registrarse por la API. Para pruebas por API
   se usa `@motomoto-qa.co`.
5. Supabase solo valida la direccion de correo **cuando va a enviar de verdad**. Una cuenta
   que existe con dominio no entregable da 400 y una que no existe da 200, y eso parece
   enumeracion de cuentas sin serlo. Para comprobar D74 hace falta un dominio entregable.
6. El compilador de React prohibe `setState` sincrono en el cuerpo de un efecto. La solucion
   no es silenciar la regla: es derivar el estado en el render. Salio mejor que el original,
   porque elimino la ventana en la que se veia el perfil del usuario anterior.
7. Al llamar funciones de la base de datos hay que respetar los tipos exactos.
   `p_passenger_count` es `smallint`: pasarle un entero da `42883`, funcion no encontrada, y
   una prueba puede salir en verde por el motivo equivocado.
8. Supabase desaconseja llamar a `supabase.auth` desde dentro de su propio manejador de
   cambio de estado: la llamada espera un candado que el manejador no ha soltado y la
   aplicacion se cuelga sin ningun error. La carga del perfil va en un efecto separado.

### Pruebas de la fase

11 verificaciones de alta de perfil y proteccion de rol y estado. 6 del ciclo de
autenticacion contra la API real. 9 de recuperacion de contrasena, incluido enlace caducado.
5 estados de cuenta verificados en el emulador con capturas. 12 ataques por la API,
saltandose la interfaz, todos rechazados. Verificado en emulador a 411 dp y en la tablet a
800 dp.

---

## 15.6 PERFIL Y FOTO (Fase 7)

### Archivos

```
src/app/passenger/profile.tsx        Datos reales. Foto editable
src/app/passenger/edit-profile.tsx   Nombre y telefono, con las validaciones del registro
src/app/change-password.tsx          En la raiz: tambien la usa el conductor
src/features/profile/avatar-service.ts   Elegir, comprimir, subir, firmar y borrar
src/features/profile/profile-avatar.tsx  Muestra la foto y permite cambiarla
```

### Almacenamiento

Bucket `avatars`, privado, limite de 1 MB por archivo, solo `image/jpeg`, `image/png` y
`image/webp`. Cuatro politicas sobre `storage.objects`:

- **ver:** el dueno, un administrador, o la contraparte de un viaje, mediante
  `shares_ride_with`. Los mismos que pueden ver el nombre de esa persona
- **subir, reemplazar y borrar:** solo en la propia carpeta

La ruta es `<uuid del usuario>/<marca de tiempo>.jpg`. La primera carpeta es lo que comparan
las politicas, y la marca de tiempo es lo que hace que la ruta sea la version.

`storage.objects` **no admite borrado directo por SQL**: hay que usar la API de Storage. Es
una proteccion de Supabase contra archivos huerfanos.

### Reglas aprendidas, no repetir estos errores

1. `fetch(uri).arrayBuffer()` **no sabe leer una direccion `file://`** en React Native. No
   falla: devuelve un cuerpo vacio, el servidor lo acepta, y queda un archivo de catorce
   bytes. Se lee con `expo-file-system`. Hay una comprobacion que rechaza cualquier imagen de
   menos de 1 KB para que no vuelva a pasar en silencio.
2. Reemplazar el archivo con un nombre fijo no basta. Si la ruta no cambia, la pantalla no
   pide una direccion firmada nueva y sigue mostrando la foto anterior desde la cache. El
   servidor tenia la foto nueva y la aplicacion la vieja.
3. Para recortar una imagen en un circulo hace falta `overflow: 'hidden'` en el contenedor,
   no solo `borderRadius`.
4. Un dato de una captura no se juzga a ojo. Una imagen de fondo blanco dentro de un circulo,
   sobre pantalla blanca, parece sin recortar y no lo esta. Se perdio un paso persiguiendo un
   fallo inexistente. Para comprobar recortes hace falta una imagen de contenido oscuro.
5. `pgcrypto` esta en el esquema `extensions`, igual que PostGIS.

### Pruebas de la fase

Nombre, telefono y correo reales en pantalla en los dos perfiles. Edicion con las
validaciones del registro y normalizacion del telefono verificada contra la base de datos.
Cambio de contrasena con la actual equivocada, comprobando que **la contrasena no cambia**, y
con la actual correcta, comprobando que la antigua deja de servir. Foto por galeria y por
camara real en la tablet, con recorte, compresion, reemplazo y borrado del archivo anterior.
Diez ataques por la API, todos rechazados. Verificado en emulador a 411 dp y tablet a 800 dp.

---

## 15.7 MAPA Y UBICACION (Fase 8)

### La evaluacion de proveedores

Se probaron Google Places Autocomplete (New) y Mapbox Search Box contra **39 sitios reales
de Amalfi**, escritos como los dice la gente ("la bomba", "el parque"), con la busqueda
restringida al municipio y **pidiendo la coordenada de cada primer resultado** para medir a
que distancia del parque cae.

Resultado: **Mapbox 22 utiles, Google 13**, contando solo lo que cae dentro del casco.

Lo que decidio la arquitectura, mas que el ganador:

- **"El parque" no lo encuentra ninguno de los dos.** Tampoco la alcaldia, el cementerio,
  el coliseo, la estacion de bomberos ni dos de los tres colegios
- **16 de 39 sitios no tienen respuesta util en ningun proveedor**
- Los dos devuelven nombres convincentes que caen en **otro municipio**: Google ofrecio un
  "Coliseo Municipal" a 30 km y un "Cementerio Municipal" a 30 km. Sin pedir la coordenada,
  todo eso parecia acierto
- Fallan justo en los nombres coloquiales, que son los que usa la gente a diario

Conclusion: **la tabla `places` no es un atajo, es la columna vertebral.** D10 queda
confirmado con datos. El punto en el mapa pasa de extra a imprescindible, porque es lo que
salva las busquedas que fallan. El buscador es un complemento que fallara cuatro de cada
diez veces.

Aviso de tarifas para la Fase 9: Mapbox Search Box trae **solo 500 busquedas gratis al mes**.
Mapbox tiene otra API de geocodificacion con 100.000 gratis, sin comparar todavia.

### El cambio de fondo: se acabo Expo Go

Un mapa es codigo nativo, y Expo Go es una app ya compilada que no puede incorporarlo. Desde
esta fase se trabaja con un **cliente de desarrollo propio**, compilado en local.

La recarga en caliente funciona igual. Lo unico que cambia es que la app que se abre en el
emulador y en la tablet es la nuestra.

```powershell
npx.cmd expo prebuild --platform android    # regenera android/ desde app.config.ts
cd android; .\gradlew.bat assembleDebug     # compila el APK
adb install -r android\app\build\outputs\apk\debug\app-debug.apk
npx.cmd expo start --dev-client             # servidor de desarrollo

# Conectar la app al servidor. Sin esto el cliente se queda en su pantalla de inicio.
adb reverse tcp:8081 tcp:8081
adb shell am start -a android.intent.action.VIEW -d "motomoto://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081" com.motomoto.app
```

Solo hay que recompilar si se toca codigo nativo o se anade una libreria. Un cambio de
TypeScript sigue siendo instantaneo.

### Claves de Google Cloud

Dos claves distintas, y conviene no confundirlas:

| Clave | Para que | Restriccion |
|---|---|---|
| `GOOGLE_MAPS_ANDROID_KEY` | El mapa dentro de la app | Apps de Android: `com.motomoto.app` + huella SHA-1. API: Maps SDK for Android |
| `GOOGLE_TEST_API_KEY` | Solo la evaluacion de proveedores, desde el PC | Sin restriccion de aplicacion. APIs: Places (New) y Geocoding |

**Huella SHA-1 de depuracion:** `5E:8F:16:06:2E:A3:CD:2C:4A:0D:54:78:76:BA:A6:F3:8C:AB:F6:25`

Sale de `android/app/debug.keystore`, que trae la plantilla de Expo. Se consulta asi:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore android\app\debug.keystore -storepass android -alias androiddebugkey
```

Al publicar (Fase 26) habra otra huella distinta y habra que anadirla a la misma clave.

### Archivos

```
app.config.ts                        Sustituye a app.json. Lee la clave del .env
src/features/map/region.ts           Coordenadas de Amalfi y niveles de zoom
src/features/map/use-location.ts     Permisos, GPS y los siete estados
src/features/map/map-style.ts        Estilo del mapa, claro y oscuro
src/features/map/map.tsx             Envoltorio de react-native-maps (D117)
src/features/map/location-gate.tsx   Pantallas de permiso, GPS apagado y sin senal
src/app/passenger/index.tsx          El mapa real sustituye al marcador de posicion
src/components/ui/bottom-sheet.tsx   Gestion del teclado (D123)
src/components/ui/screen.tsx         Comentario corregido sobre adjustResize
```

### Los siete estados de la ubicacion

`checking`, `permission-required` con `canAsk` verdadero o falso, `services-disabled`,
`locating`, `unavailable`, `ready`. Los siete verificados con captura.

### Reglas aprendidas, no repetir estos errores

1. **Expo trae su propio `debug.keystore` dentro de `android/app/`**, y `build.gradle`
   apunta ahi, no a `~/.android/debug.keystore`. Crear el keystore estandar del sistema y
   suponer que Gradle lo usara produce una huella que no vale para nada, y el sintoma es un
   mapa en blanco color crema **sin ningun error en el log**.
2. `animateToRegion` **llamado antes de que el mapa nativo este listo se descarta en
   silencio**: no falla, no devuelve nada que comprobar. Hay que esperar a `onMapReady`. Y
   no se debe marcar el centrado como hecho antes de saber que la orden se ejecuto, porque
   entonces no se reintenta nunca.
3. Un `featureType` invalido en el estilo del mapa **anula el estilo entero**. Google lanza
   `InvalidStyleException` en logcat y dibuja un mapa sin estilo, que es facil confundir con
   "el estilo se aplico y no se nota". No existe `park`: es `poi.park`.
4. **`adjustResize` ya no encoge la ventana** cuando la app dibuja de borde a borde, que es
   lo que hace Expo por defecto desde SDK 54. El teclado se pinta encima. Las pantallas con
   el contenido arriba no lo notan; lo que va anclado abajo, como un bottom sheet, queda
   detras del teclado. El comentario de `Screen` que decia lo contrario venia de la Fase 3 y
   estuvo mal desde entonces.
5. El compilador de React rechaza un `setState` alcanzable desde el cuerpo de un efecto,
   aunque ocurra despues de un `await`: no sabe seguir la frontera asincrona. La solucion no
   es silenciar la regla, es sacar la llamada del cuerpo del efecto.
6. En Git Bash, `adb shell screencap -p /sdcard/x.png` falla: convierte la ruta de Android en
   una ruta de Windows. Los comandos de adb con rutas del dispositivo van por PowerShell.
7. `pm set-permission-flags` no existe antes de API 31. Para probar el permiso denegado para
   siempre en un dispositivo Android 11 hay que denegarlo dos veces a mano.

### Pruebas de la fase

Quince puntos de validacion, superados en emulador a 411 dp y en la tablet a 800 dp, en modo
claro y oscuro. Los siete estados de ubicacion con captura. Cuatro errores del asistente
diagnosticados y corregidos (E15 a E18). El mapa se verifico con la ubicacion simulada en el
parque de Amalfi y con GPS real en la tablet.

---

## 15.8 ORIGEN Y DESTINO (Fase 9)

### La tabla de lugares dejo de estar vacia

36 lugares de Amalfi cargados por migracion. Los nombres los escribio el dueno tal y como los
dice la gente. Las coordenadas vienen de dos sitios:

- **20 del buscador de Mapbox**, verificando de cada una a que distancia del parque cae. Sin
  esa comprobacion, un "Coliseo Municipal" a 30 km y una "Alcaldia" que era la de Anori
  habrian entrado como buenas
- **16 marcadas a mano sobre un mapa**, porque ningun proveedor las conoce. Entre ellas
  **el parque**, que es el destino mas pedido del pueblo

Ese segundo grupo es la razon de ser de la tabla. Para marcarlas se genero un mapa de un solo
uso, un HTML con Mapbox GL donde el dueno hizo clic en cada sitio. Se probo antes de
entregarlo, simulando los clics en el navegador.

La validacion previa a escribir encontro dos duplicados reales: "estacion de policia" con
"el comando" (11 m) y "alto de la virgen" con "alto de la linea" (39 m). Se fusionaron.

### Que API de Mapbox, y por que

| API | Aciertos sobre 39 sitios | Gratis al mes |
|---|---|---|
| Search Box | **22** | 500 |
| Geocoding v6 | 3 | 100.000 |
| Geocoding v5 | 3 | 100.000 |

Para el camino inverso, en cambio, las dos devolvieron **lo mismo** en los 12 puntos
probados, asi que ahi se usa la barata (D128).

### El hallazgo del camino inverso

**Amalfi si tiene direcciones en los datos de Mapbox.** Al soltar un punto en el parque
devuelve "Carrera 21 19 068", y acierta en todo el casco urbano.

Es lo contrario de lo que pasa al buscar: nadie teclea "Carrera 21 #19-068" en un buscador,
pero al pinchar en el mapa esa direccion existe y es correcta. El camino inverso funciona
mucho mejor que el directo, y por eso el punto en el mapa acabo siendo mas util que el
buscador.

### Archivos

```
supabase/migrations/20260801012726_seed_amalfi_places.sql   Los 36 lugares
supabase/migrations/20260801015032_list_places_function.sql Lectura con lat y lng

src/features/destination/types.ts             Tipos y patron de resultado
src/features/destination/geo.ts               Distancias y lugar mas cercano
src/features/destination/places-service.ts    Lee los lugares
src/features/destination/use-places.ts        Cache de modulo
src/features/destination/mapbox-service.ts    Buscar, ubicar y camino inverso
src/features/destination/describe-point.ts    La logica de D127
src/features/ride/ride-draft.tsx              El formulario a medio hacer

src/app/passenger/destination.tsx             Buscador. Sirve a origen y destino
src/app/passenger/pick-on-map.tsx             Chincheta fija y mapa que se arrastra
src/app/passenger/index.tsx                   Resumen del viaje en la hoja
src/app/passenger/_layout.tsx                 Envuelve la zona con el borrador
```

### Reglas aprendidas, no repetir estos errores

1. **Un buscador que falla no debe vaciar la lista y callarse.** El pasajero leia "no
   encontramos ese sitio" cuando lo que pasaba era que Mapbox no respondio: buscaria otro
   nombre, fallaria igual, y concluiria que la aplicacion no sirve. Un error tecnico no
   puede disfrazarse de conclusion sobre lo que el usuario busca.
2. **Un recuadro de busqueda de 25 km alcanza municipios enteros.** Sin filtrar, "hospital"
   ofrecia el de Anori y el de Campamento con el mismo aspecto que el de aqui. El filtro se
   midio contra los 39 sitios antes de darlo por bueno: conserva los 22 de Amalfi y bloquea
   los 5 de fuera.
3. **`keyboardShouldPersistTaps` en 'handled' se come el primer toque.** Con el teclado
   abierto, tocar un resultado solo cerraba el teclado; habia que tocar dos veces, y la
   segunda vez la lista ya se habia movido. Con 'always' funciona al primer toque.
4. `initialRegion` **solo se lee en el primer render**, y para entonces la ubicacion casi
   nunca esta lista. Dejarlo asi hace que la pantalla abra en un sitio u otro segun quien
   gane la carrera. Mismo error que E16 y misma correccion: esperar a `onMapReady`.
5. Las variables `EXPO_PUBLIC_` **se leen cuando arranca Metro**. Anadir una al `.env` con el
   servidor ya en marcha no la hace aparecer: hay que reiniciarlo.
6. El generador de tipos de Supabase declara como `string` una columna de retorno que admite
   nulos. Se normaliza en la capa de servicio para que la mentira no se propague.
7. En Windows PowerShell 5.1 **no existe `-Encoding utf8NoBOM`**, y su `utf8` escribe BOM.
   Para regenerar los tipos hay que usar `[System.IO.File]::WriteAllText` con
   `UTF8Encoding($false)`.

### Pruebas de la fase

26 puntos de validacion, superados en tablet a 800 dp y emulador a 411 dp, en modo claro y
oscuro. Los tres caminos al destino y las cuatro ramas de la etiqueta, cada una con captura.
Probado sin conexion: la lista sigue funcionando desde la cache y el buscador dice la verdad.
Cuatro ataques por la base de datos suplantando a un pasajero, todos rechazados.

### Corregido despues, durante la Fase 13

Dos fallos que llevaban aqui desde esta fase y que **nadie vio en 26 puntos de validacion**.
Los encontro el usuario usando la aplicacion, no las pruebas, y los dos salen del mismo sitio:
el origen podia dejar de ser "mi ubicacion" pero no podia volver a serlo.

1. **No habia forma de volver a "Tu ubicacion actual".** El origen empieza en null, que
   significa "donde estoy" (D137), pero la pantalla de seleccion solo ofrecia los lugares de
   la empresa y "Elegir en el mapa". En cuanto el pasajero elegia un sitio concreto se
   quedaba encerrado: ni volviendo atras, ni pidiendo otro viaje. Ahora es la primera fila
   de la lista, **solo cuando se elige el origen** y solo mientras no se este buscando otra
   cosa. Para el destino no aparece, porque "voy a donde estoy" no es un viaje.
2. **El origen se quedaba pegado al viaje siguiente.** El aspa de "Tu viaje" solo borraba el
   destino. `clear()` existia en el borrador desde el primer dia y **no lo llamaba nadie**.
   El pasajero pedia un viaje "desde cero" y salia recogiendolo donde estuvo una vez.

Lo segundo no se nota si la aplicacion se cierra entre viaje y viaje, porque el borrador vive
en memoria. Sale justo cuando se piden dos viajes seguidos sin salir, que es lo normal.

---

## 15.9 CANTIDAD DE PASAJEROS (Fase 10)

### Sin migraciones

`max_passengers_per_request` ya existia en `app_settings` desde la Fase 5, con valor 3 y
lectura abierta a cualquier usuario autenticado. No hubo que tocar la base de datos.

Se comprobo que se lee de verdad y no esta escrito en el codigo: se cambio a 4 en el
servidor, la aplicacion dejo elegir 4 y el mensaje del limite se adapto solo. Devuelto a 3
y reiniciada, vuelve a detenerse en 3.

### El fallo que destapo esta fase

El resumen del viaje **cortaba el boton "Continuar"** en el telefono. La causa no era el
selector nuevo: los puntos de anclaje de la hoja eran una fraccion de la pantalla, y una
fraccion no sabe nada de lo que hay dentro. El mismo 0,3 da 240 dp en la tablet y 274 dp en
el telefono, mientras que el contenido pide los que pide. Al revisar capturas anteriores se
vio que **ya rozaba el limite antes de esta fase**; el selector fue lo que lo empujo fuera.

La correccion no fue subir la fraccion hasta que cupiera, que es ir probando numeros en cada
pantalla nueva, sino enseñarle a la hoja a medirse (D145). Ahora un panel puede decir "tan
alto como lo que llevo dentro" y acierta en cualquier pantalla.

Resultado: el resumen paso de ocupar la mitad de la pantalla a un cuarto en la tablet y un
tercio en el telefono.

### Archivos

```
src/features/ride/settings.ts          Lee el maximo de app_settings
src/features/ride/passenger-count.tsx  El selector
src/features/ride/ride-draft.tsx       Guarda la cantidad
src/components/ui/bottom-sheet.tsx     Anclaje 'content' y medida del contenido
src/app/passenger/index.tsx            Tarjeta unica, anclaje minimo y aspa de descarte
```

### Reglas aprendidas, no repetir estos errores

1. **Un punto de anclaje en fracciones no garantiza que el contenido quepa.** Da alturas
   distintas en cada aparato mientras el contenido pide siempre la misma, asi que o sobra
   sitio o se corta un boton. La solucion es medir el contenido, no ajustar la fraccion a
   ojo hasta que se vea bien en el aparato que se tenga delante.
2. Para medir el alto natural de un bloque, ese bloque **no puede llevar `flex: 1`**. Con el
   puesto reporta el alto del contenedor, que es justo el dato que no sirve.
3. Las medidas de `onLayout` llegan con decimales. Sin redondear, una diferencia de medio
   pixel dispara otro render, que vuelve a medir, sin fin.
4. Tercera vez con la regla del `setState` dentro de un efecto. Aqui la solucion correcta no
   era diferirlo con un temporizador como en las dos anteriores, sino **ajustar el estado en
   el render**, porque era estado derivado de otro y no una tarea asincrona.
5. **Quitar un control por parecer redundante exige comprobar que su funcion sigue estando.**
   Se retiro "Cambiar de destino" alegando que la fila del destino ya tenia "Cambiar", y era
   falso: aquel boton descartaba el viaje entero y el otro solo abre el buscador. El pasajero
   se quedo sin forma de echarse atras. **Lo detecto el usuario preguntando, no las pruebas.**

### Pruebas de la fase

12 puntos de validacion en tablet a 800 dp y emulador a 411 dp, en modo claro y oscuro,
incluida la comprobacion del maximo cambiandolo en el servidor. Panel medido en los dos
aparatos antes y despues de la correccion, y anclaje minimo verificado en ambos.

---

## 15.10 CREACION DE SOLICITUD (Fase 11)

### El area de servicio dejo de ser una idea

Hasta esta fase, "todo el municipio" (D11) era una frase. Ahora es un poligono en la base de
datos. El dato salio de OpenStreetMap y se comprobo antes de usarlo: **1206 km2, que coincide
con la superficie real de Amalfi**, y los 36 lugares de la Fase 9 caen dentro.

El circulo se descarto midiendo, no opinando. Desde el parque, el municipio llega a 43 km al
norte pero solo a 12 al oeste. Un circulo que lo cubriera entero se tragaria cuatro municipios
vecinos.

La simplificacion tambien se midio en lugar de elegirse a ojo:

```
sin simplificar    2485 puntos   desviacion   0 m   area 1206,0 km2
tolerancia 0,0005   490 puntos   desviacion  56 m   area 1206,0 km2   <- elegida
tolerancia 0,001    270 puntos   desviacion 111 m   area 1205,8 km2
```

**H11 queda cerrado.** El punto en el mapa ya no puede mandar a un conductor a otro municipio.

### El dato que cambio una decision

Al probar Directions con puntos reales de Amalfi:

| Viaje | Linea recta | Por carretera | Rodeo |
|---|---|---|---|
| Dentro del casco | 693 m | 873 m | x1,26 |
| Al norte del municipio | 16,8 km | **37,0 km** | **x2,21** |

Ese viaje al norte le sale a Mapbox en **2 h 25 min en coche**, y en motorraton seria mas. Es
informacion nueva para la conversacion sobre cobertura real con la empresa: el municipio
acordado como zona de servicio tiene su extremo a mas de dos horas.

### Lo que existia en el servidor y nadie habia ejecutado

`cancel_request` estaba escrita desde la Fase 5 y **nunca habia funcionado** (E25). Y
`expire_stale_requests` existia con un comentario que decia "la invocara una tarea
programada", tarea que no se habia creado: hasta esta fase ninguna solicitud caducaba.

Las dos aparecieron el mismo dia, al hacer la primera prueba de extremo a extremo. Las 57
verificaciones de la Fase 5 se centraron en lo que la base de datos debe RECHAZAR, y el camino
feliz de cada funcion no se recorrio, entre otras cosas porque sin conductores sembrados no
habia forma de llegar a tener una solicitud viva que cancelar.

### Archivos

```
supabase/migrations/20260804234258_service_area.sql            poligono, margen y validacion
supabase/migrations/20260804235949_expire_requests_schedule.sql pg_cron y limpieza dirigida
supabase/migrations/20260805000923_get_active_request.sql       lectura de la solicitud viva
supabase/migrations/20260805004304_fix_cancel_request_actor_cast.sql  correccion de E25

supabase/dev-tools/seed_test_driver.sql     conductor de prueba, repetible
supabase/dev-tools/remove_test_driver.sql   lo deshace

src/features/ride/errors.ts          traduccion de los codigos del hint
src/features/ride/ride-service.ts    unico punto que llama a las tres funciones
src/features/ride/route-service.ts   Mapbox Directions y formateadores
src/features/ride/use-countdown.ts   cuenta atras con clave de reinicio

src/components/ui/form-error.tsx     movida desde features/auth/
src/theme/colors.ts                  token onDangerSubtle y escalones danger300 y danger900
src/app/passenger/index.tsx          las cuatro caras de la hoja
```

### Reglas aprendidas, no repetir estos errores

1. **Un CASE que asigna a una columna de tipo enumerado necesita conversion explicita.** Un
   literal suelto se resuelve solo, pero dentro de un CASE PostgreSQL fija el tipo del CASE
   primero, y con dos literales sin tipo sale `text`. De `text` a un enumerado no hay
   conversion implicita. No dependia de que hubiera filas: PL/pgSQL prepara la sentencia al
   ejecutarla y ahi ya falla.
2. **Un bloque con `exception` es un punto de guardado.** Si la funcion lanza despues de haber
   escrito algo, ese algo se deshace. La limpieza dirigida de `request_ride` no sobrevive a un
   `NO_DRIVERS_AVAILABLE`, y esta bien: lo que importaba era el mensaje que ve el pasajero, y
   la durabilidad la pone pg_cron.
3. **Un valor no sirve como identidad.** La cuenta atras se reiniciaba cuando cambiaba el
   numero de partida, y dos solicitudes seguidas empiezan siempre igual. En produccion habrian
   sido 300 y 300, con lo que "Volver a pedirlo" habria estado roto SIEMPRE: creaba la
   solicitud y la pantalla seguia diciendo que nadie la tomo.
4. **Si se cambia la firma de un hook, la prueba no vale sin reinicio completo.** El recambio
   en caliente mantuvo el comportamiento antiguo sin avisar, la correccion parecio no
   funcionar y estuve a punto de buscar la causa donde no estaba. Solo al matar la aplicacion
   se vio que era correcta desde el principio.
5. **Un mensaje de error que ya no es cierto es una pantalla que miente.** Tras rechazar el
   origen por estar fuera de zona, cambiar el punto de recogida dejaba el aviso puesto bajo un
   viaje que ya era valido. Ahora el error caduca en cuanto cambia cualquier dato de la
   solicitud, incluida la cantidad de pasajeros.
6. **Un token de color no puede hacer dos trabajos.** `danger` servia de fondo de boton y de
   texto sobre fondo teñido. En el tema oscuro eso daba 1,44:1 y el aviso no se leia.
7. El generador de tipos de Supabase volvio a declarar como no nulo un retorno que admite
   nulos, esta vez `seconds_remaining`. Segunda vez, misma solucion: normalizar en el servicio.
8. **La ubicacion del conductor de prueba caduca a los dos minutos.** Ese valor es un
   parametro por defecto de `find_available_drivers` y no se lee de la configuracion (H12).

### Pruebas de la fase

78 comprobaciones automaticas y 21 en dispositivo, todas en OK. Las automaticas incluyen 15
del area de servicio contra PostGIS y suplantando roles, 5 de la caducidad incluido el barrido
real de pg_cron esperando al minuto, 8 de aislamiento entre pasajeros, 7 del ciclo completo de
solicitud, 15 de la traduccion de errores contra el archivo compilado, 14 del contrato HTTP con
un token real y 14 de Directions contra la API.

En dispositivo: tablet a 800 dp y emulador a 411 dp, en claro y oscuro, con el emulador
simulando ubicacion dentro de Amalfi para poder probar "Tu ubicacion actual" como origen. Se
verifico el ciclo entero, la expiracion bajando el parametro del servidor a 30 segundos, la
restauracion tras matar la aplicacion y la resincronizacion al volver de segundo plano.

### Corregido despues, durante la Fase 13

**"Tu ubicacion actual" viajaba al conductor como nombre del punto de recogida.** Ese texto
esta escrito desde el punto de vista del pasajero, y era lo que se guardaba en
`ride_requests.origin_label` cuando el origen era su posicion. El conductor abria su pantalla
y leia "RECOGER EN: Tu ubicacion actual": ni una direccion, ni una referencia, ni un barrio.
Lo vio el usuario en la tablet, no las 21 comprobaciones en dispositivo de esta fase.

Ahora se resuelve con `describePoint`, el mismo criterio que ya usaba elegir un punto en el
mapa (D127): el nombre del lugar si esta encima de uno, "Cerca de X" a media distancia, y la
direccion de Mapbox en los demas casos. Verificado pidiendo un servicio real: donde antes se
guardaba "Tu ubicacion actual" ahora se guarda "Cancha sintética".

Cuesta una llamada de red antes de crear la solicitud, y se paga a proposito: el conductor va
a conducir hasta ese punto. Si la red falla se guarda "Punto compartido por el pasajero", que
es honesto y lo manda al mapa, que si trae la coordenada exacta.

**Queda un problema mayor sin resolver, y es de la Fase 14.** Cuando el pasajero elige un
lugar de la lista, se guarda **la coordenada que el dueno marco para ese sitio, no donde esta
el pasajero**. En sitios como "Alto de la Virgen", que abarca casi tres cuadras, el conductor
puede acabar a doscientos metros. La navegacion no lo arregla: guiar con precision hacia un
punto equivocado no sirve de nada.

---

## 15.11 MODULO DEL CONDUCTOR (Fase 12)

### El dato que decidio la arquitectura

La regla R2 da al conductor **veinte segundos** para responder. Sondeando cada diez, la oferta
le aparece cuando ya le quedan diez: la mitad de su tiempo se va antes de que vea nada. Para
que no se notara habria que preguntar cada dos o tres segundos, y eso son mas de mil
peticiones por hora y por conductor con datos moviles.

Por eso se adelanto el tiempo real, que estaba previsto para la Fase 13. **Medido: el aviso
llega en poco mas de un segundo desde que el pasajero confirma.**

### Lo que estaba escrito y no se cumplia

`offer_request_to_drivers` ofrecia a los **cinco** conductores mas cercanos. La regla R4,
aprobada en la Fase 0, dice "se ofrece la solicitud a todos los conductores disponibles del
municipio". Ese cinco no se decidio nunca: era el valor por defecto de un parametro.

Al corregirlo aparecio una tension entre dos cosas ya aprobadas: **D7 dice cercania y R4 dice
todos**. Si se ofrece a todos a la vez, gana quien toca antes, no el mas cercano. El lote de
cinco era, sin decirlo, un intento de conciliarlas. Se resolvio a favor de R4 (D160).

### La linea de la privacidad

Es la primera fase donde el conductor ve datos de otra persona, y donde se dibuja la linea:

- **Antes de aceptar** ve el viaje: de donde a donde, cuanta gente, a que distancia esta la
  recogida. No ve el nombre. Comprobado con dos usuarios que nunca habian coincidido
- **El telefono si es visible antes de aceptar** por la API, porque vive en `ride_requests` y
  la politica deja leer la solicitud a quien recibio la oferta. La aplicacion no lo enseña,
  pero no hay muro
- **Al aceptar** aparecen nombre y telefono, y el telefono es un boton de llamada

### Archivos

```
supabase/migrations/20260805150842_driver_offers_and_realtime.sql
supabase/migrations/20260805153818_offer_to_all_available_drivers.sql
supabase/migrations/20260805180658_driver_active_rides.sql

src/features/driver/driver-service.ts          estado, vehiculo, ofertas, aceptar, rechazar
src/features/driver/use-driver-offers.ts       tiempo real y lista de ofertas
src/features/driver/use-location-reporting.ts  posicion cada 30 s mientras disponible
src/features/driver/offer-card.tsx             la oferta con su temporizador
src/features/driver/active-ride-card.tsx       el servicio aceptado y su pasajero
src/features/ride/settings.ts                  generalizado a cualquier parametro numerico
src/app/driver/index.tsx                       datos reales en lugar de la maqueta
```

### Reglas aprendidas, no repetir estos errores

1. **Un usuario insertado a mano en `auth.users` no puede iniciar sesion si deja columnas de
   token en nulo.** GoTrue las lee como texto y responde 500 con "Database error querying
   schema", que no dice nada de la causa. Son `confirmation_token`, `recovery_token`,
   `email_change_token_new` y `email_change`, y van a cadena vacia.
2. **Una ubicacion no se puede envejecer con un UPDATE.** `driver_locations` tiene un
   disparador BEFORE UPDATE que reescribe `updated_at` con `now()`. La prueba que lo intentaba
   salia verde por el motivo equivocado, confirmando que una fila "de treinta segundos" seguia
   siendo elegible cuando en realidad era de cero. Se envejece borrando e insertando.
3. **Un tamano fijo para un dato configurable acaba desbordandose.** La burbuja del
   temporizador media 52 por 52, suficiente para los dos digitos de R2. Al subir
   `offer_response_seconds` para poder probar sin prisa, el numero se salio y partio en dos
   lineas. Misma familia que la leccion de la Fase 10 sobre las fracciones de pantalla.
4. **Cuarta vez con el `setState` dentro de un efecto.** Y otra vez la solucion correcta era
   ajustar el estado en el render, no diferirlo con un temporizador, porque era estado
   derivado y no una tarea asincrona.
5. **Lanzar un `.cmd` desde Node en Windows exige `shell: true`.** Sin el, `execFileSync` falla
   con EINVAL y no explica por que.
6. **El SQL con JSON dentro va por archivo, no por linea de comandos.** El shell de Windows
   destroza las comillas y el error que se ve no tiene nada que ver con la causa.

### Pruebas de la fase

64 comprobaciones automaticas y 15 en dispositivo, todas en OK. Entre las automaticas: 9 de la
lectura de ofertas con aislamiento entre dos conductores, 7 del tiempo real con dos sesiones
reales, 9 del reparto a todos los disponibles, 19 del contrato del servicio por HTTP, 9 del
envio de posicion y 7 de los viajes activos.

En dispositivo: tablet a 800 dp con GPS real y emulador a 411 dp, en claro y oscuro. Se
verifico el ciclo entero con solicitudes reales enviadas desde fuera, incluida la cadencia de
treinta segundos del envio de posicion, medida entre dos envios consecutivos.

---

## 15.12 RECOGER PASAJEROS EN RUTA (D161)

**Terminado el 2026-08-05.** No es una fase del plan original: el usuario lo pidio al acabar el
paso 7 de la Fase 12 y se abordo justo despues de cerrarla, en siete pasos autorizados uno a
uno.

### Que pidio, con sus palabras

Que un conductor que ya lleva un servicio pueda **recoger a otro pasajero si le queda de
camino y le sobran asientos**. Lo explico asi:

> En Amalfi se acostumbra a que si el motorraton tiene el espacio para llevar a otro pasajero
> y queda cerquita del destino o coincide con la ruta, lo recoge. Asi tambien lo quiero en la
> aplicacion, que el conductor lo vea en la app para que si le sirve, lo acepte y asi optimice
> el viaje y sus ganancias haciendo una sola ruta pero con dos viajes.

Y comparo con Uber y DiDi, que no funcionan asi.

### Que lo impedia

La regla **R7**, aprobada en la Fase 0, decia "viajes activos simultaneos por conductor: 1". No
era solo una frase del documento: habia **dos indices unicos** en `rides` que lo hacian
imposible.

```
rides_one_active_per_driver    unique (driver_id)   where status in (activos)
rides_one_active_per_vehicle   unique (vehicle_id)  where status in (activos)
```

**El modelo de datos si lo aguanta.** `rides.passenger_count` guarda cuantas personas van en
ese vehiculo concreto, y su comentario de la Fase 5 dice:

> Con un solo motorraton coincide con el total de la solicitud; el dia que se reparta un grupo,
> cada viaje llevara su parte.

Se diseño pensando en repartir **un grupo entre varios vehiculos**. Lo que se pide es la imagen
espejo: **varias solicitudes en un vehiculo**. La estructura sirve igual. El obstaculo son los
dos indices, no el diseño.

### Los siete pasos, y que hizo cada uno

1. **La regla de capacidad.** Fuera los dos indices unicos, dentro un disparador que suma los
   pasajeros de los viajes activos del vehiculo y los compara con su capacidad (D162). Un
   indice no sabe sumar. Se repusieron los dos indices como no unicos, porque la suma los
   necesita para buscar
2. **Asientos libres.** `find_available_drivers` deja de comparar `max_passengers` con el grupo
   y resta primero lo que el motorraton ya lleva encima
3. **Disponibilidad recalculada.** `accept_ride_offer` deja de apagarla y la recalcula (D164).
   **Este es el paso que enciende la funcion**: los dos anteriores prepararon el terreno sin
   cambiar nada visible
4. **La pantalla del conductor.** Viajes en curso y ofertas a la vez, con los asientos libres a
   la vista y el aviso de por que el interruptor se apago solo
5. **La ruta en el mapa**, adelantada de la Fase 14 (D165, D166)
6. **Pruebas de conjunto** y checklist de regresion
7. **Documentacion**, que es esto

### Lo que ya se dejo preparado en la Fase 12

Sabiendo que esto venia, dos piezas se escribieron en plural desde el principio y **no hubo que
reescribirlas**. Funcionaron tal cual:

- `list_driver_active_rides()` devuelve una lista de viajes, no una fila
- La pantalla del conductor ya recorria esa lista con `viajes.map(...)`

### La ruta dejo de ser un adorno

Dibujar el recorrido estaba previsto para la **Fase 14**, como un extra. Pero **sin ver la ruta
el conductor no puede juzgar si el segundo viaje le sirve**, asi que pasa a ser lo que hace
posible la funcion. Se adelanto solo eso (D165); el seguimiento y el marcador en movimiento se
quedan en la Fase 14. La navegacion giro a giro sigue fuera de alcance (D157).

### LAS TRES PREGUNTAS DEL LADO DEL PASAJERO, YA RESPONDIDAS

Son del lado del pasajero, que es donde esto tiene consecuencias que nadie ve venir. El usuario
las respondio el 2026-08-05, antes de autorizar el trabajo.

1. **Su viaje va a tardar mas por el desvio. ¿Se le avisa? ¿Puede negarse?**
   No se le avisa y no puede negarse. En Amalfi compartir es la costumbre.
2. **¿Se le dice que va a compartir, o se entera al subirse?**
   Se entera al subirse. Con sus palabras: "el conductor toma la decision solo, alla es asi
   como se maneja normalmente". La aplicacion no muestra nada al pasajero sobre esto.
3. **El tiempo estimado que le mostramos (D149) deja de ser fiable. ¿Que se hace con el?**
   Se deja como esta. Se sigue mostrando el mismo calculo aunque el desvio lo deje corto.

**Consecuencia de las tres juntas: D161 no toca ni una pantalla del pasajero.** Todo el trabajo
esta en el servidor y en la pantalla del conductor. Si alguna vez aparece la necesidad de
avisar, sera una decision nueva, no un olvido de esta.

### Archivos

```
supabase/migrations/20260805215913_replace_r7_with_vehicle_capacity.sql
supabase/migrations/20260805221747_count_free_seats_for_offers.sql
supabase/migrations/20260805222621_recalculate_availability_on_accept.sql

src/features/driver/route-preview.tsx   NUEVO. El mapa de la oferta con las rutas en curso
src/features/map/map.tsx                admite trazados, marcadores y modo no interactivo
src/features/map/region.ts              regionContaining, para encuadrar varios puntos
src/features/ride/route-service.ts      fetchRouteGeometry, y la peticion comun extraida
src/features/ride/errors.ts             VEHICLE_CAPACITY_EXCEEDED y DRIVER_VEHICLE_CONFLICT
src/features/driver/offer-card.tsx      el mapa, entre las direcciones y los botones
src/features/driver/driver-service.ts   comentarios que ya no decian la verdad sobre R7
src/app/driver/index.tsx                asientos libres, encabezados y el aviso de completo
```

### Reglas aprendidas, no repetir estos errores

1. **Una prueba puede pasar por el motivo equivocado y no notarse hasta semanas despues.**
   `prueba_ciclo` comprueba casos que esperan NO_DRIVERS_AVAILABLE, y eso exige que su
   conductor sea el unico disponible. Paso en el paso 3 porque la ubicacion del conductor de
   prueba llevaba mas de dos minutos sin refrescarse. Al reejecutarla con el seed recien
   corrido se cayo entera. Ahora aisla a los demas conductores y los restaura al terminar.
   Misma familia que la leccion 2 de la Fase 12.
2. **Un mapa incompleto que no se declara incompleto es peor que no tener mapa.** Con la red
   estrangulada, la ruta ofrecida cargo y la del servicio en curso no. El codigo descartaba en
   silencio las que fallan, asi que el conductor veia un mapa aparentemente completo con una
   sola linea y habria concluido que la solicitud nueva no se cruza con nada. Ahora se cuentan
   las que faltan y se dicen.
3. **El tono mas apagado del tema no sirve sobre un mapa.** `textTertiary` esta pensado para
   texto sobre fondo blanco; el mapa ya es gris claro y la ruta desaparecia. La primera captura
   parecia demostrar que las rutas en curso no llegaban del servidor, cuando llegaban
   perfectamente. Se usa `textPrimary`, que ademas se invierte con el tema.
4. **Una comprobacion puede funcionar por accidente.** Para distinguir "no llega" de "no se ve"
   se puso `colors.text`, que **no existe** en el tema. El color llego indefinido y Android
   pinto negro por defecto: la ruta aparecio y el diagnostico resulto correcto, pero por el
   motivo equivocado. Lo cazo el `typecheck`. En modo oscuro ese negro accidental era casi
   invisible.
5. **`RETURNING ... INTO` no admite un elemento de array** en PL/pgSQL. Hace falta una variable
   suelta y asignar despues.
6. **`ride_offers` no tiene `created_at`, tiene `offered_at`.** Ordenar por la columna
   equivocada revienta con 42703 en mitad de una prueba de concurrencia.
7. **`supabase db query -f` solo devuelve el ultimo SELECT del archivo.** Poner la comprobacion
   y la limpieza en el mismo fichero borra los datos antes de poder leer el resultado.
8. **Un script de limpieza que borra por patron de correo es un cuchillo sin mango.** Se uso
   `like '%@motomoto-qa.co'` excluyendo a mano el conductor de prueba. No causo daño porque no
   habia otras cuentas con ese dominio, pero lo correcto es borrar por los identificadores
   fijos que uno mismo creo.

### Pruebas

**41 comprobaciones automaticas** repartidas en cuatro scripts, mas **dos carreras con procesos
simultaneos reales**, mas **15 comprobaciones en dispositivo**.

Las dos carreras merecen mencion aparte, porque al quitar los indices unicos se perdio la
garantia que daba el motor de la base de datos y hubo que reponerla con bloqueos:

- **Dos conductores aceptando la misma solicitud en el mismo instante.** Entra uno. Se ejecuto
  dos veces y gano un proceso distinto cada vez, asi que la carrera es real
- **Un mismo conductor con dos ofertas de 2 pasajeros y 3 asientos.** Entra una, la otra muere
  con VEHICLE_CAPACITY_EXCEEDED. **Esta carrera no podia existir antes de D161**: con R7,
  aceptar la primera oferta te dejaba sin disponibilidad y no habia segunda

En dispositivo: tablet a 800 dp y emulador a 411 dp, en claro y oscuro, aceptando desde la
pantalla y comprobando cada estado contra el dato del servidor.

### Lo que quedo sin verificar

**El aviso de mapa incompleto no se ha visto en pantalla.** Se provoco una vez estrangulando la
red del emulador, se escribio la correccion, y en dos intentos posteriores de reproducirlo las
dos rutas cargaron igualmente. Compila y pasa lint, pero segun el criterio de terminado de este
proyecto eso no basta. La via para verlo es poner un token de Mapbox invalido un momento.

**El flujo del pasajero no se probo en dispositivo** tras refactorizar `route-service.ts`. La
tablet tiene la sesion del conductor y el emulador no entrega GPS. Se cubrio por el contrato de
la API, comprobando que la variante del pasajero sigue pidiendo `overview=false` y no descarga
geometria, y por `request_ride` en las pruebas automaticas.

### Checklist de regresion

Volver a pasarlo cada vez que se toque la capacidad, las ofertas o la disponibilidad. **Antes de
nada, refrescar el conductor de prueba**, porque su ubicacion caduca a los dos minutos.

| Script | Comprobaciones | Que protege |
|---|---|---|
| `prueba_capacidad.sql` | 15 | La regla que sustituyo a R7 |
| `prueba_asientos.sql` | 13 | Que el buscador reste los asientos ocupados |
| `prueba_ciclo.sql` | 12 | El ciclo entero por las funciones reales |
| `prueba_interruptor.sql` | 1 | Que aceptar no encienda la disponibilidad de quien la apago |

En dispositivo, con `demo_01_montar.sql` y `demo_02_segunda_solicitud.sql`, y `demo_03_limpiar.sql`
al terminar, que ademas devuelve `offer_response_seconds` a los veinte segundos de R2:

1. Con un servicio de 2 encima, el conductor sigue en **Disponible**
2. La tarjeta del motorraton dice **"Un asiento libre · 2 a bordo"**
3. Aparece **"Esperando otra solicitud, te queda un asiento"**
4. La segunda oferta entra **en tiempo real**, con su temporizador
5. Aparecen los encabezados **TU SERVICIO** y **NUEVA SOLICITUD**
6. El mapa de la oferta dibuja **dos rutas**, la ofrecida y la que ya lleva
7. Al aceptar: **"Completo · 3 a bordo"** y el aviso de que el motorraton esta lleno, no de que
   el conductor apago algo
8. Las dos tarjetas de servicio, con su boton de llamada
9. Todo lo anterior en claro y oscuro, y en los dos anchos

---

## 15.13 ASIGNACION EN TIEMPO REAL (Fase 13)

### La mitad que faltaba

La Fase 12 adelanto el tiempo real, pero solo para el conductor. Del lado del
pasajero no habia ni tiempo real ni sondeo: `get_active_request` se llamaba al
abrir la aplicacion y al volver de segundo plano (D152), y nada mas.

En la practica, el pasajero pedia un servicio, un conductor lo aceptaba a los
diez segundos, y **el seguia viendo "buscando motorraton" hasta que cerraba la
aplicacion y la volvia a abrir**. El motorraton podia estar llegando y el sin
saberlo. Y aunque se hubiera enterado, no habria visto a quien: la funcion no
devolvia nada del conductor.

Buena parte de la fase ya estaba hecha antes de empezarla, y conviene decirlo:
la busqueda de conductores, el reparto a todos los disponibles y la prevencion de
carreras venian de la Fase 12 y de D161.

### Los cinco pasos

1. **`get_active_request` devuelve al conductor asignado** (D167)
2. **Se publica `ride_requests`** para tiempo real (D168)
3. **El pasajero escucha** con `useRequestRealtime`
4. **Su panel muestra al conductor**, con boton de llamada
5. **Prueba con dos sesiones** en dos aparatos, y de paso se cerraron dos huecos
   del lado del conductor (D169)

### Los dos huecos del conductor

Salieron mientras se probaba el paso 4, y los dos terminaban con el conductor
actuando sobre informacion falsa:

- **El pasajero cancela un servicio ya aceptado.** La tarjeta seguia en pantalla
  con su nombre y su telefono. Podia ir a recoger a alguien que cancelo hace diez
  minutos
- **Otro conductor acepta primero.** La oferta se quedaba hasta caducar. La Fase
  12 lo dejo escrito como limite conocido, a la espera de que se publicara
  `ride_requests`

Los dos se cerraron con el mismo hook del pasajero, porque quien ve que lo
deciden las politicas y no el codigo (D169).

### Archivos

```
supabase/migrations/20260810192332_active_request_includes_driver.sql
supabase/migrations/20260810195813_publish_ride_requests_realtime.sql

supabase/dev-tools/seed_second_driver.sql   NUEVO. Segundo conductor de prueba

src/features/ride/use-request-realtime.ts   NUEVO. El hook, para los dos lados
src/features/ride/ride-service.ts           AssignedDriver y su traduccion
src/features/ride/route-service.ts          overview=full (D171)
src/app/passenger/index.tsx                 el panel del conductor asignado
src/app/driver/index.tsx                    se entera de lo que pase a su solicitud
src/app/driver/profile.tsx                  el motorraton, que era maqueta
src/features/driver/offer-card.tsx          cifras de ancho fijo
src/components/ui/bottom-sheet.tsx          tolerancia al medir la altura
src/features/driver/use-driver-offers.ts    el limite conocido ya no existe
```

### Reglas aprendidas, no repetir estos errores

1. **Una pantalla que nacio con datos escritos a mano se queda asi para siempre
   si nadie la mira.** El perfil del conductor enseñaba "Motorraton 12, placa
   ABC12" desde la Fase 4. La Fase 12 conecto la pantalla de inicio y esta se
   quedo atras, asi que inicio y perfil daban placas distintas del mismo
   vehiculo, y la de perfil no existia en ninguna parte. La placa es lo que
   identifica la unidad y lo que un pasajero comprobaria antes de subirse.
2. **Redondear no estabiliza una medida que oscila.** El bottom sheet redondeaba
   el alto de su contenido para evitar renders por medio pixel. Pero si la medida
   cae cerca de un valor y medio, el redondeo alterna entre dos enteros: la hoja
   cambia un pixel, el contenido se vuelve a medir, y la pantalla tiembla. Hace
   falta una tolerancia, no un redondeo.
3. **Un numero que cambia empuja al texto de al lado.** En la tipografia normal
   cada digito mide distinto, asi que un contador dentro de una fila con `flex: 1`
   reajusta a su vecino una vez por segundo. Se arregla con
   `fontVariant: ['tabular-nums']`.
4. **Optimizar sin medir sale caro.** Se pidio la geometria simplificada de las
   rutas razonando que en un recuadro pequeño no se notaria y que se ahorrarian
   datos. Las dos mitades eran falsas: se notaba mucho y el ahorro eran 131 bytes.
5. **Medir con la aplicacion pausada no mide nada.** Las primeras mediciones del
   temblor salieron planas porque Android habia pausado la app y no renderizaba:
   dos capturas seguidas eran identicas byte a byte. Antes de concluir que algo
   no se mueve, hay que comprobar que esta vivo.
6. **Comprobar que el codigo llego al dispositivo antes de dudar del codigo.** Al
   aplicar la primera correccion, la medicion salio igual que antes. No era que
   la correccion fallara: el bundle no se habia recargado. Sin comprobarlo, el
   paso siguiente habria sido cambiar otra cosa y no saber cual arreglo que.
7. **Cerrar sesion cierra todas las sesiones.** `signOut` de Supabase invalida la
   sesion de ese usuario en todos los aparatos. Al cerrar la del conductor en el
   emulador, la tablet tambien se salio.
8. **Un script de limpieza que borra sin avisar puede pisar lo que otro esta
   probando.** La limpieza de las pruebas borro una solicitud que el usuario
   estaba usando en ese momento.

### Pruebas

**19 comprobaciones automaticas** del paso 1, **seis de ellas de privacidad
ejecutadas con el rol `authenticated`**, que es lo unico que hace que las
politicas se apliquen: una prueba de RLS hecha desde postgres pasa siempre y no
comprueba nada.

**La RLS en tiempo real se probo con un cliente de verdad**, no con SQL: un
proceso de Node que inicia sesion y abre un websocket. Dos decisiones de esa
prueba importan tanto como el resultado. Se suscribio **sin filtro**, para que lo
unico capaz de separar las solicitudes fuera la politica y no el filtro. Y **la
solicitud ajena se cambio primero**, ocho segundos antes que la propia, para que
"no llego" no pudiera confundirse con "llego tarde".

**En dos aparatos a la vez**, tablet como conductor y emulador como pasajero:

- El pasajero se entera de que le asignaron conductor **entre 4,2 y 6,2 segundos**
  (el guion muestrea cada dos, ese es el margen)
- El pasajero cancela y **la tarjeta desaparece de la tablet sola**
- Otro conductor acepta primero y **la oferta desaparece sola**, en 13 segundos

Los temblores se diagnosticaron **comparando pixeles entre instantes**, no a ojo:
que columnas y que filas se redibujaban. Es lo que distinguio "gira el girador",
que debe cambiar, de "se mueve el texto", que no.

### Lo que queda comprometido para la Fase 14

Tres cosas, y las tres responden a la misma pregunta: **como llega el conductor
hasta el pasajero.** Estan escritas aqui porque el usuario las pidio expresamente
y se le dijo que se harian; no son ideas sueltas ni pendientes menores.

1. **La ruta dibujada en la pantalla del pasajero.** La echo en falta al ver que
   el conductor si la tiene. Las piezas ya existen: `fetchRouteGeometry` y el
   mapa con trazados de `Map`.
2. **Navegacion abriendo Google Maps o Waze** con el punto puesto (D157). El
   usuario pregunto por construir una navegacion propia con el SDK de Mapbox y
   **se decidio que no**: cuesta 0,08 dolares por viaje pasando los mil al mes,
   en una plataforma que no cobra nada (D8), y sobre todo no resuelve el problema
   de abajo. Un enlace a Waze cuesta cero y el conductor ya sabe usarlo. Idea
   suya que conviene recoger: ofrecerlo al tocar "voy en camino".
3. **Una referencia escrita del punto de recogida**, corta y opcional, tipo
   "frente a la tienda" o "la casa azul". Es lo que la gente dice por telefono
   hoy, y **es lo unico que salva los casos como "Alto de la Virgen"**, donde el
   nombre abarca tres cuadras y la coordenada guardada es la del lugar y no la de
   la persona. Necesita una columna nueva en `ride_requests`, un campo en el
   resumen del viaje y mostrarlo en la tarjeta del conductor.

**El orden importa: la 3 es la que arregla el problema de verdad.** La 2 sin la 3
lleva al conductor con mucha precision al sitio equivocado.

---

## 15.14 SEGUIMIENTO DEL CONDUCTOR (Fase 14)

### Los cinco pasos, y en que orden

Se hizo en el orden que dejo escrito la Fase 13, y ese orden importaba: **la referencia
primero**. Guiar al conductor con precision hasta una coordenada equivocada es peor que no
guiarlo.

1. **La referencia escrita del punto de recogida.** Columna nueva, y el campo en las dos
   pantallas
2. **La ruta dibujada en la pantalla del pasajero**, que era el encargo de la Fase 13
3. **El envio de posicion durante el servicio**, con los dos ritmos de R9
4. **El pasajero ve moverse su motorraton**, con tiempo de llegada y estado de la conexion
5. **La navegacion**, abriendo la aplicacion de mapas del conductor

### Lo que arreglo la referencia

En Amalfi hay sitios como "Alto de la Virgen" cuyo nombre abarca tres cuadras, y lo que se
guardaba era la coordenada del LUGAR, no la de la persona que espera en una de esas esquinas.
Eso se resolvia por telefono. Ahora la frase viaja en la solicitud y el conductor la lee sin
llamar.

Es corta y opcional a proposito: obligarla anadiria un paso a cada servicio para cubrir el caso
raro. El limite de 80 caracteres es lo que cabe en dos lineas de la tarjeta sin cortarse.

### Dos fallos que no estaban en el plan

**El envio de posicion se apagaba con el interruptor** (D175). Desde D164, aceptar una oferta
puede apagar la disponibilidad porque el motorraton se lleno; con el codigo anterior, eso
apagaba tambien el envio de posicion. El conductor dejaba de existir en el mapa del pasajero
**justo mientras iba a recogerlo**. Salio al leer el codigo para cambiar la cadencia, no de una
prueba.

**E30, y fue del asistente.** Al reescribir `request_ride` para anadirle el parametro nuevo se
partio de la definicion de la Fase 5, cuando esa funcion se habia redefinido dos veces despues.
La version aplicada **borro las dos comprobaciones de zona de servicio (D150) y la caducidad
dirigida (D151)**, y estuvo asi en el servidor unos minutos: cualquiera habria podido pedir un
servicio con destino fuera del municipio. Se corrigio el archivo, se deshizo lo aplicado y se
volvio a aplicar, porque la migracion no estaba en git y dejar una equivocada en la historia
era peor.

**La leccion esta escrita en la cabecera de esa migracion:** el cuerpo de estas funciones se
reescribe entero cada vez, asi que hay que partir de la ULTIMA version aplicada.

```bash
grep -l "function public.request_ride(" supabase/migrations/*.sql
```

Las pruebas 13 a 15 del script de la referencia existen para que ese error no pueda repetirse
en silencio: comprueban zona de servicio y caducidad dirigida a proposito.

### Lo que ya estaba esperando en el servidor

Por segunda vez, y conviene decirlo: **no hizo falta ninguna politica nueva**.
`driver_locations_select_active_passenger` esta escrita desde la Fase 5 y dice exactamente que
un pasajero puede leer la posicion del conductor con el que comparte un viaje activo. En la
Fase 13 paso lo mismo con `drivers_select_ride_counterpart`. El modelo de seguridad se diseno
entero antes que las pantallas, y las pantallas van llegando a politicas que ya existian.

### Archivos

```
supabase/migrations/20260811184748_pickup_reference.sql            NUEVO
supabase/migrations/20260811204827_driver_location_for_passenger.sql  NUEVO
supabase/migrations/20260811210019_active_request_includes_driver_id.sql NUEVO

src/features/ride/use-driver-location.ts    NUEVO. Tiempo real de la posicion
src/features/driver/navigation.ts           NUEVO. El enlace geo:

src/features/ride/ride-service.ts           referencia, posicion y driver_id
src/features/ride/ride-draft.tsx            la referencia en el borrador
src/features/ride/route-service.ts          una sola funcion, fetchRoute (D173)
src/features/ride/errors.ts                 PICKUP_REFERENCE_TOO_LONG
src/features/driver/driver-service.ts       la referencia llega al viaje aceptado
src/features/driver/active-ride-card.tsx    la referencia y el boton de navegacion
src/features/driver/route-preview.tsx       usa fetchRoute
src/features/driver/use-location-reporting.ts  los dos ritmos de R9 (D175)
src/features/map/map.tsx                    el marcador del motorraton
src/app/passenger/index.tsx                 campo, ruta, marcador, llegada y senal
src/app/driver/index.tsx                    pasa `riding` al envio de posicion
src/types/database.ts                       regenerado
```

### Reglas aprendidas, no repetir estos errores

1. **Antes de reescribir una funcion, buscar cual es la ultima version.** Es E30 y es la mas
   cara de las de hoy: se perdieron dos validaciones de seguridad sin darse cuenta.
2. **Una prueba puede fallar por estar mal escrita.** Dos veces hoy: una esperaba un texto de
   relleno que se quedo puesto, y otra intentaba envejecer una fila con un UPDATE que el
   disparador `set_updated_at` pisaba. Un rojo falso cuesta tiempo; un verde falso cuesta mucho
   mas, asi que conviene mirar la prueba antes que el codigo.
3. **Un dato de prueba escrito a mano puede parecer un fallo del producto.** El usuario vio que
   el punto del mapa no era el parque. No lo era, pero el punto lo habia escrito el asistente
   en un script, no la aplicacion. La tabla de lugares tenia el correcto.
4. **Medir es distinto de mirar.** Los dos ritmos de R9 se dieron por buenos leyendo
   `updated_at` del servidor cada pocos segundos, no viendo la pantalla: 30 s y 10 s exactos.
5. **Cuando algo no se puede probar, averiguar por que antes de culpar al codigo.** El salto de
   posicion no disparaba nada; la causa era que la aplicacion nunca recibia el cambio, y se
   demostro reiniciandola y viendo la posicion saltar de golpe.
6. **Tocar el manifiesto tiene un precio.** La navegacion directa a Waze exigia declarar
   paquetes y recompilar el cliente de desarrollo. `geo:` evita las dos cosas (D178).

### Pruebas

**24 comprobaciones automaticas**, todas en verde y todas dentro de transacciones que se
deshacen: el servidor no quedo con un solo usuario ni una solicitud de prueba.

| Script | Comprobaciones | Que protege |
|---|---|---|
| `prueba_referencia.sql` | 16 | La restriccion atacada de frente, la normalizacion, la linea de privacidad de D172 y **la regresion de E30** |
| `prueba_posicion.sql` | 8 | Quien puede y quien no puede ver donde esta un conductor |

De las 8 de la posicion, **cinco son de privacidad**: un pasajero no ve a un conductor ajeno,
un pasajero sin viaje no ve a nadie, un conductor no ve a otro, `anon` no puede llamar a la
funcion, y **al terminar el viaje el pasajero deja de verlo**. Todas ejecutadas con el rol
`authenticated`.

**En dispositivo, 17 comprobaciones.** Las que mas valen:

- El resumen con el campo nuevo **entra completo en 411 dp**: E23 no volvio
- La ruta se dibuja, y **se reconstruye sola tras cerrar la aplicacion del todo**, con la
  cuenta atras donde iba
- **30 s, 10 s y 120 s exactos** de cadencia, medidos contra `updated_at`
- El marcador del motorraton **se movio solo en menos de cinco segundos** ante un cambio hecho
  en el servidor. El criterio de aceptacion 4 pide menos de quince
- "Perdimos su señal" al envejecer la posicion cuatro minutos
- La navegacion abrio Google Maps en **"El parque", 6,904700 / -75,076700, Amalfi**

### Lo que quedo sin verificar, y por que no se puede

Las dos cosas dependen de un aparato que se mueva, y **el equipo actual no puede producir
movimiento**:

1. **La mitad de los cincuenta metros de R9.** Los dos ritmos por tiempo estan medidos; el
   adelanto por desplazamiento no. Se intento quitando el temporizador de en medio y moviendo
   el punto en Fake GPS: no se envio nada, y la causa es que **la aplicacion solo recoge la
   posicion simulada al arrancar el vigilante**
2. **El marcador atenuado** cuando la posicion caduca. El texto si se vio; el marcador se quedo
   fuera de cuadro

**Esto ya no es un pendiente menor.** Sin tablet y con Fake GPS comportandose asi, no hay forma
de comprobar nada que dependa de un aparato en movimiento: ni la regla de los 50 m, ni el
marcador moviendose de verdad, ni el recorrido historico que viene en la Fase 15. Hace falta un
telefono Android real, que ya estaba apuntado en los pendientes para la Fase 23 y ahora es el
unico camino.

### La pregunta de las paradas, respondida

El usuario pregunto al cerrar la fase como se mostrarian los puntos de recogida y destino
cuando el conductor lleva dos o tres servicios (D161). La respuesta esta en D180, y tiene dos
mitades:

- **Waze no admite paradas intermedias desde un enlace.** Google Maps si, hasta nueve
  `waypoints`. Asi que una ruta multiparada obliga a Google Maps y deja sin efecto el selector
  de aplicaciones
- **Y el bloqueo de fondo es otro:** para ordenar las paradas hay que saber **quien va ya a
  bordo**, y ese dato nace con los estados de la Fase 15. Hoy la aplicacion no distingue "voy a
  recoger a Ana" de "ya llevo a Ana dentro", asi que cualquier orden seria una suposicion

Mientras tanto se queda un boton por servicio y el conductor elige, que es D161 aplicado.

### Checklist de regresion

Volver a pasarlo cada vez que se toque la referencia, la posicion del conductor o
`request_ride`. **Antes de nada, refrescar el conductor de prueba.**

| Script | Comprobaciones |
|---|---|
| `prueba_referencia.sql` | 16 |
| `prueba_posicion.sql` | 8 |

Y en dispositivo, con un servicio aceptado:

1. El resumen del viaje **cabe entero**, con el boton "Confirmar servicio" a la vista
2. La referencia escrita aparece en la tarjeta del conductor, con su filo naranja
3. La ruta se dibuja en la pantalla del pasajero y **sobrevive a cerrar la aplicacion**
4. El motorraton aparece en el mapa del pasajero y se mueve
5. "Llega en X min" aparece y no parpadea
6. Al envejecer la posicion, "Perdimos su señal"
7. "Cómo llegar" abre el selector de mapas y el punto es el correcto
8. Todo lo anterior en claro y en oscuro

---

## 15.15 CICLO COMPLETO DEL SERVICIO (Fase 15)

### Lo que ya estaba hecho, y lo que faltaba

**Las cuatro funciones de transicion existian desde la Fase 5**, escritas y probadas
antes de que hubiera una sola pantalla que las llamara, con la regla R5 dentro y el
calculo de la distancia incluido. Esta fase no invento la maquina de estados: la
conecto, y al conectarla encontro tres cosas rotas que solo se ven cuando algo las usa.

### Los cinco pasos

1. **Las cuatro transiciones en la pantalla del conductor**, un boton por vez (D182)
2. **El pasajero ve en que va su servicio**, y se despide al terminar (D185)
3. **El recorrido historico**, que hasta ahora nadie escribia
4. **Los dos encargos heredados de la Fase 14**: navegacion al destino y lista de paradas
5. **Restaurar al reabrir** y validar el ciclo entero

### Los tres fallos que encontro

**El primero, y el mas grave: el pasajero no se enteraba de que el conductor habia
llegado.** Se movio el viaje a "en camino" desde el servidor y la pantalla siguio
diciendo "tomo tu servicio" indefinidamente. La causa es exacta: las cuatro transiciones
escriben en `rides`, y el pasajero solo escuchaba `ride_requests`. **De las cuatro, solo
dos tocan la solicitud.** Salir hacia el punto y anunciar la llegada se quedaban sin que
nadie las oyera, y la llegada es justo el aviso que hace que el pasajero salga a la calle.
Se corrigio publicando `rides` (D184).

**El segundo: terminar un servicio encendia la disponibilidad** (D181). Una linea de la
Fase 5 que D161 y D164 dejaron obsoleta sin que nadie volviera a mirarla. Un conductor que
apagaba el interruptor porque paraba de trabajar volvia a recibir solicitudes al cerrar su
ultimo viaje.

**El tercero, sutil: la distancia del viaje podia incluir la aproximacion** (D188). La
politica de la Fase 5 deja al conductor grabar puntos tambien mientras va a recoger, y
`complete_ride` los sumaba todos. En uso normal no pasaba, porque el cliente solo graba
durante el recorrido; por la API si.

### La pregunta de las paradas, respondida en codigo

El usuario pregunto al cerrar la Fase 14 como se mostrarian los puntos de recogida y
destino con dos o tres servicios. La respuesta esta implementada y sale del dato, no de
una suposicion: un viaje que aun no arranco aporta su recogida, uno en curso aporta su
destino. **Solo se podia hacer ahora**, porque hace falta saber quien va ya a bordo.

### Archivos

```
supabase/migrations/20260812083511_finishing_does_not_turn_availability_on.sql  NUEVO
supabase/migrations/20260812084420_revoke_anon_on_ride_transitions.sql          NUEVO
supabase/migrations/20260812091646_finished_request_summary.sql                 NUEVO
supabase/migrations/20260812093837_shorter_finished_summary_window.sql          NUEVO
supabase/migrations/20260812094629_publish_rides_realtime.sql                   NUEVO
supabase/migrations/20260812132825_trip_distance_from_started_at.sql            NUEVO

src/features/ride/use-ride-realtime.ts        NUEVO. El pasajero escucha su viaje
src/features/driver/use-track-recording.ts    NUEVO. El rastro, cada 50 m
src/features/driver/pending-stops.tsx         NUEVO. La lista de paradas

src/features/driver/driver-service.ts    las cuatro transiciones y el rastro
src/features/driver/active-ride-card.tsx un boton por estado, navegacion segun estado
src/features/ride/ride-service.ts        rideStatus y el resumen final
src/features/ride/errors.ts              los codigos de las transiciones
src/app/driver/index.tsx                 avanzarViaje, rastro y paradas
src/app/passenger/index.tsx              los cinco estados y la despedida
src/types/database.ts                    regenerado
```

### Reglas aprendidas, no repetir estos errores

1. **Una prueba que no comprueba las dos vistas no comprueba nada.** El fallo de la
   llegada habria pasado cualquier prueba que mirara la tabla `rides`. Por eso la prueba
   del ciclo comprueba, en cada paso, lo que ve el pasajero Y lo que ve el conductor.
2. **Una linea correcta puede volverse falsa sin que nadie la toque.** El
   `set is_available = true` era razonable cuando se escribio. Lo rompieron dos decisiones
   posteriores, y siguio ahi. Al cambiar una regla hay que buscar quien mas dependia de la
   anterior.
3. **Un dato de prueba escrito a mano parece un fallo del producto.** Volvio a pasar: el
   usuario vio que el destino no era el hospital. No lo era, y estaba a 426 m, porque el
   asistente lo habia escrito a mano en un script. Es la segunda vez en dos dias.
4. **Antes de culpar al proveedor, comprobar el propio estilo.** Con las rutas "por calles
   que no existen" se reviso primero `map-style.ts`, que solo apaga puntos de interes.
5. **La recarga en caliente no resuelve archivos nuevos.** Un `ReferenceError` sobre un
   hook recien creado no era del codigo: Metro no lo habia resuelto. Se arregla arrancando
   en frio, y hay que comprobarlo antes de tocar nada.
6. **En Git Bash, `adb ... /sdcard/...` falla.** La ruta se convierte en ruta de Windows.
   Va por PowerShell. Ya estaba escrito y se volvio a tropezar.

### Pruebas

**35 comprobaciones automaticas**, todas en verde y dentro de transacciones que se
deshacen.

| Script | Comprobaciones | Que protege |
|---|---|---|
| `prueba_transiciones.sql` | 12 | Que no se pueda saltar ni repetir un paso, R5, y que el viaje sea de su conductor |
| `prueba_recorrido.sql` | 7 | Quien puede escribir el rastro y que la distancia mida solo el viaje |
| `prueba_paradas.sql` | 4 | Dos servicios en estados distintos, que es de donde sale la lista |
| `prueba_ciclo_completo.sql` | 12 | El ciclo entero, **comprobando las dos vistas en cada paso** |

**En dispositivo:** el ciclo completo tocado uno por uno desde la pantalla del conductor,
el cambio de estado llegando al pasajero en tiempo real, la despedida al terminar, la
lista de paradas con dos servicios, los botones "Ir a la recogida" y "Ir al destino", y
**el criterio de aceptacion 5**: matar la aplicacion con dos servicios encima y verla
volver entera.

### Lo que quedo sin verificar

1. **Que la aplicacion grabe el rastro en movimiento.** El emulador no le entrega
   posiciones que cambien: comprobado con Fake GPS, que solo la entrega al arrancar el
   vigilante, y con `emu geo fix` en bucle, que no llega. Es la misma limitacion que
   bloqueo la regla de los 50 m en la Fase 14, ahora confirmada por dos caminos.
2. **La restauracion del lado del pasajero en pantalla.** El camino de datos si esta
   probado (comprobacion 8 del ciclo) y en la Fase 14 se vio la ruta reconstruirse tras
   cerrar del todo, pero no se vio la pantalla del pasajero restaurandose en pleno viaje.

### Lo que queda comprometido para despues

1. **Cambiar el mapa a Mapbox**, ya aprobado por el usuario para justo despues de esta
   fase. El motivo esta en H18: la ruta se calcula con Mapbox y se dibuja sobre un mapa de
   Google, y en Amalfi no coinciden.
2. **Las cancelaciones son de la Fase 18.** Hoy la pantalla del pasajero sigue ofreciendo
   "Cancelar servicio" con el pasajero dentro del motorraton. Cuando se puede cancelar y
   que pasa entonces se decide alli.

---

## 15.16 EL MAPA PASO A MAPBOX (fuera del plan de fases)

### Por que se hizo

**Lo encontro el usuario mirando la pantalla.** Vio que la ruta dibujada cruzaba manzanas
vacias y que los puntos no caian donde debian, y lo dijo antes de dejarnos seguir con la
fase.

El diagnostico separo dos cosas:

1. **El destino equivocado era un dato de prueba del asistente**, escrito a mano en un
   script, a 426 m del hospital real. Segunda vez en dos dias.
2. **La ruta cruzando solares era real, y no era culpa de la ruta.** Se calculaba con Mapbox
   y se dibujaba sobre un mapa de Google. Se rendero **la misma ruta, con las mismas
   coordenadas, sobre el mapa de Mapbox**: cada tramo caia sobre una calle. Mapbox decia
   pasar por Calle 17, Carrera 23 y 168 m de una via sin nombre; Google dibujaba esa zona
   casi vacia. Se comprobo ademas que no era nuestro estilo, que solo apaga puntos de
   interes.

Encaja con lo que ya sabiamos desde la Fase 8: de 39 sitios reales de Amalfi, **Mapbox
acerto 22 y Google 13**. El municipio esta mal cubierto por Google, y eso alcanza tambien a
sus calles.

### Que costo, y que no

**D117 se gano su sueldo.** Se escribio en la Fase 8 con una sola idea: que ninguna pantalla
importara la libreria de mapas, para que el proveedor viviera en un archivo. Funciono:
`map.tsx` paso de Google a Mapbox y **ninguna pantalla cambio**. Solo tres archivos tocaban
la libreria vieja, y era unicamente para nombrar tipos.

Dos decisiones sostuvieron eso:

- **La referencia del mapa conserva `animateToRegion` y `fitToCoordinates` con la misma
  firma.** Por dentro se traducen a la camara de Mapbox, que piensa en limites y no en
  deltas. Sin esto habria habido que reescribir las tres pantallas que mueven la camara
- **El tipo `Region` es ahora nuestro**, en `region.ts`. Era la ultima atadura fuera del
  componente

### El problema de cumplimiento que salio por el camino

**El logo y la atribucion de Mapbox son obligatorios por sus terminos, y por defecto quedan
tapados.** Van abajo a la izquierda, que es justo donde esta el bottom sheet en el mapa del
pasajero. Al subirlos arriba, los tapaba la cabecera de "Marca el punto". No es un detalle
estetico: tapado es incumplir.

Se resolvio con una propiedad `logoOffset`: **cada pantalla decide donde caben**, porque cada
una tapa un sitio distinto. Comprobado en pantalla en las dos.

### El token de descarga, y un error del asistente

El SDK nativo se baja de un repositorio privado que pedia un token secreto (`sk.`) con
alcance `DOWNLOADS:READ`. Dos cosas que conviene dejar escritas:

- **El asistente volco la configuracion entera con `expo config --type introspect` y el token
  quedo impreso en la conversacion.** Se pidio rotarlo. La exposicion no llego al
  repositorio porque `/android` esta ignorado desde la Fase 2
- **Se dejo de pasar el token como opcion del plugin.** Esa via, ademas de estar
  desaconsejada, **lo escribe en `android/gradle.properties`** y hace que aparezca en
  cualquier volcado. Ahora el plugin lo lee del entorno como
  `RNMAPBOX_MAPS_DOWNLOAD_TOKEN`, y **no aparece en ningun archivo del proyecto**:
  comprobado, cero ocurrencias en `gradle.properties`
- **Y probablemente no hacia falta.** El propio codigo que genera la libreria dice que Mapbox
  ya no exige el token y lo mantiene por compatibilidad. Se dejo puesto porque no estorba

### Archivos

```
app.config.ts                        el plugin, sin pasarle el token
package.json                         @rnmapbox/maps 10.3.5, sin react-native-maps
src/features/map/map.tsx             reescrito entero sobre Mapbox
src/features/map/region.ts           el tipo Region pasa a ser nuestro
src/app/passenger/index.tsx          usa MapHandle en vez del tipo de la libreria
src/app/passenger/pick-on-map.tsx    idem, y coloca el logo abajo
src/features/driver/route-preview.tsx  coloca el logo dentro del recuadro
```

### Reglas aprendidas, no repetir estos errores

1. **La recarga en caliente no aplica los cambios del mapa.** Paso TRES veces en la misma
   sesion: las tres parecia que el codigo estaba mal y solo hacia falta reiniciar en frio.
   Ante cualquier cambio en `map.tsx`, `am force-stop` y volver a abrir ANTES de dudar.
2. **No volcar la configuracion entera cuando hay secretos.** `expo config --type introspect`
   imprime todo, tokens incluidos. Para comprobar que una variable existe basta con
   `awk -F= '/^NOMBRE/ {print length($2)}' .env`, que no ensena el valor.
3. **Un dato de prueba escrito a mano parece un fallo del producto.** Tercera vez. Los
   scripts de prueba deberian tomar las coordenadas de la tabla `places`, no escribirlas.
4. **Mapbox trabaja en [longitud, latitud].** Invertirlas no da error: pone Amalfi en Somalia.

### Pruebas

Todo en el emulador, en claro y en oscuro:

- **La compilacion nativa**: `BUILD SUCCESSFUL` en 6 min 42 s
- **El mapa del pasajero carga**, y aparecen sitios que Google no tenia: el Politecnico Jaime
  Isaza Cadavid, Mercados J.J., la E.S.E Hospital El Carmen, el Hotel Riachon
- **LA RUTA VA POR LAS CALLES.** Era el motivo del cambio y quedo resuelto
- **Elegir punto en el mapa**: la direccion se actualiza al soltar el dedo, y al caer en un
  punto sin nombre pide referencia y bloquea el boton (D127)
- **Modo oscuro**: estilo oscuro de Mapbox, chincheta legible
- **Logo y atribucion visibles** en las dos pantallas

### Lo que quedo sin verificar

**La vista previa de rutas del conductor**, el recuadro de 160 dp dentro de la tarjeta de
oferta. Necesita montar una oferta viva con sus veinte segundos de ventana. El riesgo es bajo
—es el mismo componente con `interactive={false}`— pero no se vio.

### Lo que queda pendiente de este cambio

- **Decidir si se retira la clave de Google Maps** de `app.config.ts`. Ya no la usa nadie
- **Mirar si los puntos de interes estorban.** D125 los apagaba en Google con dos motivos: que
  competian con nuestros marcadores y que en Amalfi eran incorrectos. El segundo desaparecio.
  Si el primero molesta, se hace un estilo propio en Mapbox Studio
- **El costo cambio de modelo.** El mapa de Google era gratis e ilimitado dentro de la app; el
  SDK de Mapbox se cobra por usuarios activos al mes, con una franja gratuita que un piloto
  municipal no roza. A esta escala no se nota, pero ya no es "gratis para siempre"

---

## 15.17 HISTORIAL (Fase 16)

### Que se hizo

Las dos pantallas existian desde la Fase 4, vacias y con un comentario que decia "se
construye de verdad en la Fase 16". Esta fase las lleno, y de paso encontro tres cosas rotas
que solo se ven cuando algo las usa.

**Las dos listas no son la misma lista, y esa es la decision de fondo (D196).** El pasajero
tiene solicitudes; el conductor tiene ofertas. Por eso la del conductor sale de
`ride_offers` y salen tambien las que rechazo: la pregunta que la empresa se va a hacer en
la Fase 20 —cuantas se estan rechazando— solo se puede responder si estan.

### Los cinco pasos

1. **Las consultas en servidor**, una por rol, con su script que intenta leer lo ajeno
2. **"Mis viajes" del pasajero**, con sus estados de carga, vacio y error
3. **"Servicios realizados" del conductor**, con los cinco desenlaces
4. **El detalle de un servicio**, con la linea de tiempo, para las dos partes
5. **La decision sobre H15** y el checklist de validacion

### Los tres fallos que encontro

**El primero, de privacidad, y lo encontro la prueba y no la revision.** La funcion del
conductor daba el nombre del pasajero en cualquier oferta, tambien en las rechazadas. La
causa es exacta: se confio en la politica `profiles_select_ride_counterpart`, que **mira a
la persona y no al viaje**. Un conductor que llevo a alguien una vez pasa su comprobacion
para siempre, asi que en una oferta rechazada de esa misma pasajera el nombre salia igual. Y
quien es el pasajero es justo lo que no ve hasta aceptar, desde la Fase 12. Se corrigio
dentro de la funcion (D198).

**El segundo, en pantalla: la fila se cortaba por donde no debia.** La linea de abajo iba
toda seguida y con un nombre de conductor normal lo primero que desaparecia era el dato del
viaje: "Conductor de prueba · Unidad 99 · 11 m...". Se partio en dos lineas, el recorrido
arriba.

**El tercero, y afecta a toda la aplicacion: sin conexion, ninguna pantalla decia "sin
conexion".** Se apago la red del emulador y el historial dijo "ocurrio un error inesperado".
El mensaje real era `fetch failed: java.net.UnknownHostException: Unable to resolve host`, y
la lista de textos de red buscaba `failed to fetch`, que es **lo mismo escrito al reves**.
Sin DNS el aparato ni siquiera intenta conectarse, que es lo que pasa cuando alguien se
queda sin datos en la carretera. Corregido en `features/ride/errors.ts` y en
`features/auth/errors.ts`, y ahora la pantalla usa la variante `offline` del sistema de
diseno: "Sin conexion", con su icono, en vez de "Algo salio mal". Es el hallazgo H19.

### H15, decidido

**Se cierra en la Fase 22, con el plan escrito dentro de la migracion.** Hoy la base de
datos deja de mentir sobre si misma: los comentarios de `shares_ride_with`,
`driver_linked_to_request` y de la propia politica dicen que el acceso al perfil de la
contraparte **no caduca**. El detalle esta en D203 y el plan completo, en cuatro pasos, en
`20260819223000_h15_comment_tells_the_truth.sql`.

### Archivos

```
supabase/migrations/20260819144500_ride_history.sql                    NUEVO
supabase/migrations/20260819210500_ride_history_detail.sql             NUEVO
supabase/migrations/20260819223000_h15_comment_tells_the_truth.sql     NUEVO
supabase/dev-tools/prueba_historial.sql                                NUEVO
supabase/dev-tools/prueba_detalle_historial.sql                        NUEVO

src/features/history/history-service.ts   NUEVO. Las cuatro consultas
src/features/history/use-history.ts       NUEVO. La lista paginada, sin saber de que es
src/features/history/use-detail.ts        NUEVO. El detalle, con su "no encontrado"
src/features/history/format-when.ts       NUEVO. Fecha y hora en espanol, sin Intl
src/features/history/timeline.tsx         NUEVO. La linea de tiempo

src/app/passenger/history.tsx     la lista del pasajero, antes vacia
src/app/driver/history.tsx        la lista del conductor, antes vacia
src/app/passenger/trip/[id].tsx   NUEVO. El detalle del pasajero
src/app/driver/job/[id].tsx       NUEVO. El detalle del conductor
src/app/driver/_layout.tsx        el detalle no es una pestana (href: null)
src/features/ride/errors.ts       los textos de red que faltaban (H19)
src/features/auth/errors.ts       los mismos, por el mismo motivo
src/types/database.ts             regenerado
```

### Reglas aprendidas, no repetir estos errores

1. **Una politica que mira a la persona no sirve para proteger un momento.**
   `shares_ride_with` responde "comparten viaje" y se leyo como "estan de viaje". Cuando lo
   que hay que proteger es un instante, el filtro va donde se sabe el instante.
2. **La lista de textos de red estaba incompleta desde la Fase 6 y nadie lo vio**, porque
   hasta hoy nadie habia apagado la red y mirado la pantalla. Un caso degradado que no se
   provoca a proposito no esta probado, esta supuesto.
3. **Una comprobacion que no puede ver lo que busca siempre sale bien.** Las pruebas de fuga
   se hacen desde fuera de la sesion suplantada: dentro, RLS esconde justo la fila que
   delataria el fallo.
4. **Una prueba que espera un numero fijo de filas se rompe sola.** Las cuentas de prueba ya
   tienen historial de verdad. Las comprobaciones miran las filas que la propia prueba creo,
   y de quien es cada fila devuelta, no cuantas hay.
5. **Fast Refresh estaba apagado en el emulador.** La pantalla del conductor siguio
   ensenando el texto viejo de la Fase 4 despues de escribirla entera. Es la misma leccion
   del mapa, ahora sin tocar el mapa: ante una pantalla que no refleja el codigo,
   `am force-stop` y volver a abrir ANTES de dudar.

### Pruebas

**50 comprobaciones automaticas**, todas en verde y dentro de transacciones que se deshacen.

| Script | Comprobaciones | Que protege |
|---|---|---|
| `prueba_historial.sql` | 32 | Las dos listas: que salga lo que es de cada quien, el orden, el limite, y **cuatro intentos de leer lo ajeno** |
| `prueba_detalle_historial.sql` | 18 | El detalle: la linea de tiempo, la privacidad del nombre y de la referencia, y que un identificador ajeno devuelva cero filas |

**En dispositivo**, con las dos cuentas:

- Los tres finales del pasajero en pantalla, contrastados fila por fila contra la tabla
- Los cinco desenlaces del conductor, incluidos `rejected` y `taken_by_other`
- **El mismo servicio visto por los dos**, con las mismas cinco horas
- El detalle abierto **por enlace directo con un identificador ajeno**: "no encontramos ese
  servicio", ni error ni datos de otro
- La paginacion, bajando la tanda a 3 temporalmente: cuatro paginas, sin repetir filas
- **Sin conexion**: "Sin conexion" con su icono, y "Reintentar" recupera la lista
- Modo claro y oscuro en las cuatro pantallas

### Lo que quedo sin verificar

1. **El estado vacio de las dos listas.** Las cuentas de prueba ya tienen historial, y
   vaciarlo no se deshace. Se vera con la primera cuenta nueva.
2. **La paginacion con datos reales de mas de veinte filas.** Se probo bajando la tanda a 3;
   con veinte hara falta un historial que hoy no existe.

### Lo que queda comprometido para despues

- **H15 en la Fase 22**, con su plan escrito (D203)
- **H16 se ve ahora en pantalla.** El historial del conductor ensena "A 86,8 km de la
  recogida" en una oferta real de la Fase 13. No lo causa esta fase, pero ya no es un
  hallazgo teorico: un conductor lo lee
- **El mapa del recorrido en el detalle.** Se dejo fuera a proposito: el rastro de
  `ride_locations` esta vacio porque el emulador no produce movimiento, y un mapa vacio es
  peor que ninguno

---

## 15.18 CALIFICACIONES (Fase 17)

### Lo que ya estaba hecho, y lo que faltaba

**La tabla, la funcion y el disparador se escribieron en la Fase 5 y hasta esta fase no los
habia usado ninguna pantalla.** `ratings` con la regla R8 —una calificacion por parte y por
viaje, no editable, sostenida por un indice unico y no por una comprobacion que alguien pueda
olvidar—, `rate_ride` con sus tres validaciones, y el disparador que recalcula
`drivers.rating_average`. Esta fase no invento la maquina: la conecto, y antes de conectarla
la puso a prueba.

### Los cinco pasos

1. **Probar lo que ya existia**, intentando romperlo
2. **La pantalla del pasajero**, colgada de la despedida que ya salia al terminar
3. **La del conductor**, colgada de una despedida nueva
4. **Calificar desde el historial**, y ver ahi la calificacion dada
5. **El checklist de validacion**

### Los fallos que encontro

**El primero, y estaba anunciado: `anon` podia ejecutar `rate_ride`.** La migracion de la Fase
15 que cerro las transiciones dejo escrito, con nombre y apellido, que quedaban pendientes
`accept_ride_offer`, `reject_ride_offer`, `cancel_request` y `rate_ride`. La prueba lo
confirmo. Sin sesion no se puede colar una calificacion —`rater_id` no admite nulos— pero si
distinguir las respuestas y averiguar si cierto viaje existe y en que estado esta, con una
funcion que corre como el dueno de la base de datos. Se cerro solo esta (D211); las otras tres
siguen en la lista de la Fase 22.

**El segundo, dos veces, uno en cada lado: la tarjeta seguia ofreciendo calificar despues de
haber calificado.** Pasa porque la calificacion ocurre en otra pantalla. Se corrigio
preguntando al volver, y ahi esta lo que importa: **la pregunta filtra por quien califica, no
por el viaje**. La politica `ratings_select_involved` deja ver las dos filas de un mismo
servicio, la que uno dio y la que recibio, asi que preguntar solo por el viaje diria "ya esta
calificado" en cuanto lo hiciera la otra parte, y la aplicacion dejaria de ofrecer algo que
todavia se podia hacer. La prueba 20 existe para eso (D209).

**El tercero, de navegacion, y solo se ve en el aparato: volver atras llevaba a otra pestana.**
El detalle de un servicio y la pantalla de calificar del conductor colgaban de las pestanas,
escondidos con `href: null`. Se calificaba desde el historial y se aterrizaba en Inicio. La
zona del conductor pasa a ser una **pila por encima de las pestanas**, con las tres pantallas
en un grupo `(tabs)` que no cambia ninguna direccion (D210).

**El cuarto y el quinto los encontro LA TABLET, con datos reales, y ninguno de
los dos habia salido en el emulador.**

- **Un servicio cancelado que si tuvo conductor salia como "Sin calificar"** y
  ofrecia el boton. Tocarlo habria dado error del servidor, porque `rate_ride`
  solo acepta terminados. La condicion era "hay viaje"; la correcta es "hay viaje
  y termino" (migracion `20260821021500`).
- **La pantalla no se releia al volver de calificar.** Se calificaba desde el
  detalle, se volvia, y seguia diciendo "todavia no calificaste" con la
  calificacion ya guardada. Ahora las dos listas y los dos detalles releen al
  recuperar el foco, saltandose la primera vez para no pedir dos veces al abrir.

**El sexto no es del producto sino de la prueba, y merece quedar escrito.** La comprobacion
del promedio decia "que cambie despues de calificar", y fallo: el conductor ya tenia una
calificacion real de 4, se le puso otra de 4 y el promedio se quedo igual. Lo correcto no es
exigir que se mueva, sino que **coincida con lo que dicen las calificaciones**. Igual que en la
Fase 16 con las cuentas de filas: una prueba que espera un numero fijo se rompe sola en cuanto
las cuentas de prueba se usan de verdad.

### Archivos

```
supabase/migrations/20260819234500_revoke_anon_on_rate_ride.sql            NUEVO
supabase/migrations/20260820001500_finished_request_has_ride_and_rating.sql NUEVO
supabase/migrations/20260820020000_history_knows_about_ratings.sql         NUEVO
supabase/dev-tools/prueba_calificaciones.sql                              NUEVO

src/features/rating/rating-service.ts   NUEVO. Unico punto que llama a rate_ride
src/features/rating/star-picker.tsx     NUEVO. Las estrellas, para tocar y para leer

src/app/passenger/rate/[id].tsx   NUEVO. Calificar al conductor
src/app/driver/rate/[id].tsx      NUEVO. Calificar al pasajero
src/app/driver/(tabs)/_layout.tsx NUEVO. Las tres pestanas, ahora dentro de un grupo
src/app/driver/_layout.tsx        el guardia, y ahora una pila por encima de las pestanas
src/app/driver/(tabs)/index.tsx   la despedida del conductor y su atajo para calificar
src/app/passenger/index.tsx       la despedida del pasajero, con su atajo
src/app/passenger/history.tsx     la marca de "Sin calificar"
src/app/driver/(tabs)/history.tsx idem
src/app/passenger/trip/[id].tsx   el bloque TU CALIFICACION
src/app/driver/job/[id].tsx       idem
src/components/ui/input.tsx       primer campo de texto largo de la aplicacion
src/features/history/history-service.ts  already_rated, my_stars y my_comment
src/features/history/use-detail.ts       relee al volver a la pantalla
src/features/history/use-history.ts      idem
src/features/auth/session.tsx            tope de 15 s en el arranque (H20)
supabase/migrations/20260821021500_only_completed_can_be_rated.sql  NUEVO
src/features/ride/ride-service.ts        la despedida trae el viaje y si esta calificado
src/features/ride/errors.ts              los codigos de calificar
src/types/database.ts                    regenerado
```

### Reglas aprendidas, no repetir estos errores

1. **Preguntar "esta calificado" no es lo mismo que "lo calificaste tu".** Son dos filas
   distintas y la politica deja ver las dos. Cuando un dato tiene dos duenos posibles, el
   filtro por dueno no es opcional.
2. **Una prueba que exige que un numero cambie es fragil.** Lo que hay que exigir es el
   invariante: que el precalculado coincida con lo calculado.
3. **Un pendiente anunciado sigue siendo un pendiente.** Que `rate_ride` estuviera abierta a
   `anon` estaba escrito desde la Fase 15 y aun asi hubo que tropezar con ello en una prueba
   para cerrarlo.
4. **Fast Refresh esta apagado en el emulador, y muerde una vez por fase.** En esta se termino
   un servicio entero para ver que la tarjeta no salia, y no salia porque el bundle era
   anterior. `am force-stop` y abrir de nuevo ANTES de dudar del codigo.
5. **La aplicacion pisa la ubicacion sembrada.** `seed_test_driver.sql` deja al conductor a
   109 m del parque, pero con la aplicacion abierta el aparato manda la suya cada pocos
   segundos. En las pruebas acabo a 1,3 km, y por eso "He llegado" exigio subir
   `driver_arrival_radius_m`.

### Pruebas

**74 comprobaciones automaticas**, todas en verde y dentro de transacciones que se deshacen.

| Script | Comprobaciones | Que protege |
|---|---|---|
| `prueba_calificaciones.sql` | 24 | R8 por las dos partes, calificar lo ajeno, lo no terminado y lo inexistente, seis y cero estrellas, escribir a mano en la tabla, el promedio como invariante, y **que lo calificado por el otro no cuente como propio** |
| `prueba_historial.sql` | 32 | Las dos listas de la Fase 16, ahora tambien con `already_rated` |
| `prueba_detalle_historial.sql` | 18 | Los dos detalles de la Fase 16 |

**En dispositivo**, con el ciclo completo del servicio recorrido **tres veces de punta a
punta** —crear la solicitud desde SQL, aceptar, salir, llegar, iniciar y finalizar desde la
aplicacion—:

- La despedida del conductor al terminar, con su atajo para calificar
- La pantalla de calificar, con sus cinco palabras y su comentario opcional
- Entrar a calificar y volver **sin** calificar: el atajo sigue ahi
- Calificar: el atajo se retira
- El historial marcando "Sin calificar" solo donde toca
- Calificar **desde el historial**, y el detalle mostrando despues las estrellas y el comentario
- **El perfil del conductor con "4,0 · una calificacion"**, que es el disparador de la Fase 5
  visto por primera vez en pantalla
- Volver atras devolviendo a donde se estaba, despues de arreglar la navegacion

### Lo que quedo sin verificar

1. **Calificar al TERMINAR, del lado del pasajero.** Lo que si se vio en la tablet es
   calificar desde el historial, de punta a punta: la marca "Sin calificar", el detalle, las
   cinco estrellas, el boton bloqueado hasta elegir, el envio y las estrellas al volver. La
   despedida con su atajo se probo del lado del conductor, y en el del pasajero se quedo sin
   provocar.
2. **Un comentario de mas de 1000 caracteres por la API.** El campo corta antes; la
   restriccion de la tabla esta probada por el lado de las estrellas pero no por el del texto.

### Lo que queda comprometido para despues

- **Los reportes son de la Fase 20** (D204), con la bandeja que los lee
- **Las otras tres funciones abiertas a `anon`** siguen en la Fase 22
- **La calificacion que uno recibe** no se ensena viaje por viaje (D208). Si la empresa la
  necesita al detalle, es del panel

---

## 15.19 FASE 18: CANCELACIONES Y ERRORES OPERATIVOS

**PROBADA EN LOS DOS APARATOS A LA VEZ, EN TIEMPO REAL, EL 2026-08-21.** Con el emulador de
conductor y la tablet de pasajero (cuenta personal del usuario, Jhan Roldan, la tablet ya la
tenia abierta) conectados los dos por USB y `adb reverse` en los dos. **Quien toco los
controles y tomo las capturas fue el asistente, no el usuario**: se dirigieron las dos
pantallas por `adb shell input` y las transiciones de servidor (crear, aceptar y avanzar el
viaje) se hicieron con `supabase db query` impersonando a cada usuario, siguiendo el mismo
patron de los scripts de `dev-tools`. Se avisa esto explicitamente porque la regla del
proyecto es "Jhan prueba en dispositivo", y aqui la excepcion queda anotada en vez de
disimulada. **Falta que el usuario la mire con sus propios ojos antes de darla por
aprobada**, que sigue siendo su decision, no la del asistente.

El alcance quedo cerrado por decision del usuario (D216, 2026-08-21): de "errores operativos"
solo se construyo lo que no depende del panel de administrador. R10 y el bloqueo de un
conductor a mitad de operacion se revisan enteros en la Fase 20.

### Que habia y que faltaba

`cancel_request` (pasajero) y `cancel_ride` (conductor) existian desde la Fase 5 y estaban
bien escritas. Lo que faltaba era todo lo demas:

- La pantalla del pasajero ofrecia "Cancelar servicio" en los cinco estados, **incluido
  `in_progress`**, donde el servidor ya la rechazaba con `INVALID_STATE_TRANSITION`. Lo dejo
  escrito la seccion 15.15 al cerrar la Fase 15
- `cancel_ride` no la llamaba ninguna pantalla. El conductor no tenia como cancelar
- D187 (Fase 15) quedo pendiente a proposito: que ve el pasajero en cada tipo de cancelacion
  del conductor

### Que se hizo

- **Migracion** `20260821201620_driver_cancelled_notice.sql`: funcion
  `get_driver_cancelled_notice()`, mismo patron que `get_finished_request` (D213). Aplicada con
  `db push` y verificada con `prueba_cancelaciones.sql` (nuevo, en `supabase/dev-tools/`): 5
  comprobaciones en verde, incluido el ataque de que una pasajera no vea el aviso de otra
- Tipos regenerados en `src/types/database.ts`
- `src/features/ride/ride-service.ts`: `fetchDriverCancelledNotice`
- `src/features/driver/driver-service.ts`: `cancelRide`
- `src/features/driver/active-ride-card.tsx`: boton "Cancelar servicio" con confirmacion
  (`Modal` con `tone="danger"`), texto distinto si el pasajero ya va a bordo
- `src/app/driver/(tabs)/index.tsx`: `cancelarViaje`, releyendo estado y viajes al terminar.
  No enciende la disponibilidad (D181 sigue mandando)
- `src/app/passenger/index.tsx`, el cambio mas grande:
  - El boton de cancelar desaparece en `in_progress` (D214) y pide confirmacion antes de
    cancelar en los demas casos
  - Aviso breve cuando el conductor anterior cancelo antes de recogerlo, detectado en el
    cliente sin llamada nueva (D212)
  - Pantalla nueva `ServicioCanceladoPorConductor` para cuando cancela con el pasajero a
    bordo (D213), enganchada en `sincronizarSolicitud` justo despues de comprobar si el
    servicio termino

`npm run typecheck`, `lint` y `format:check` en cero.

### Lo que queda fuera, a proposito (D216)

- **R10**, conductor sin senal durante un viaje: pospuesto a la Fase 20 por falta de panel
  (D215)
- Bloqueo del administrador a mitad de operacion: mismo motivo, es del panel
- El GPS que deja de responder ya tiene cobertura parcial de fases anteriores (H20, tope de
  15 s) y no se toco aqui
- El resto de la lista de la seccion 8 —nadie acepta, dos conductores aceptan a la vez, el
  conductor termina por accidente, cerrar la aplicacion— ya estaba cubierto por fases
  anteriores. Con esto, la Fase 18 no tiene mas trabajo de codigo pendiente: lo que sigue es
  el checklist en dispositivo

### Una cosa que se penso al escribir y resulto no ser cierta

Se penso que `find_available_drivers`, al no excluir a quien acaba de cancelar, podia
reofrecerle al mismo conductor la solicitud que el mismo acaba de soltar. **Probado y
descartado**: en el checklist, el conductor de prueba cancelo (comprobacion 4) y no volvio a
recibir esa solicitud, aunque siguio disponible y con ubicacion fresca. `offer_request_to_drivers`
ya lo evita —no se investigo el mecanismo exacto, pero el comportamiento observado es el
correcto— y no hace falta tocar nada.

### Checklist, resultado real

Las cinco comprobaciones centrales, **verificadas en pantalla con captura, no solo en la base
de datos**:

1. **Pasajero cancela mientras busca.** El modal dice "¿Cancelar la búsqueda?" / "Dejaremos de
   buscarte un motorratón.". Confirma, la solicitud se cancela, vuelve a "¿A dónde vas?". OK
2. **Pasajero cancela con conductor ya asignado, antes de que salga.** El modal dice "¿Cancelar
   este servicio?" / "Le avisamos al conductor y queda libre para tomar otro servicio.". Al
   confirmar, **la tarjeta del conductor desaparece de su pantalla en tiempo real**, sin tocar
   nada del lado del conductor. OK
3. **El boton de cancelar del pasajero no aparece en `in_progress`.** Con el viaje "Vas en
   camino", la tarjeta termina en "Llamar al conductor": no hay boton de cancelar debajo. OK
4. **Conductor cancela ANTES de llegar a recoger.** El pasajero, con la app ya suscrita (con
   una solicitud viva), ve aparecer solo el aviso "Tu conductor anterior canceló. Seguimos
   buscando otro." por encima de "Avisando a los motorratones cercanos", en tiempo real, sin
   recargar nada. OK
5. **Conductor cancela CON el pasajero a bordo.** El pasajero ve, en tiempo real, la pantalla
   nueva: "Servicio cancelado" / "Conductor de prueba canceló el servicio" / "Puedes volver a
   pedirlo cuando quieras.", con el origen y el destino debajo y el boton "Entendido". Al
   cerrarla, cae limpio en el mapa. OK

**Sin probar en pantalla, verificado solo por lectura de codigo:**

6. Conductor con dos servicios a la vez (D161): cancelar uno no toca el otro. No se armo el
   escenario de dos solicitudes simultaneas sobre el mismo conductor; el codigo opera siempre
   por `rideId` (`cancelarViaje`, `ActiveRideCard`), asi que no hay por donde se puedan
   mezclar, pero eso es lectura, no una captura. Queda pendiente si el usuario quiere verlo con
   sus propios ojos
7. Que el conductor no reciba de vuelta su propia solicitud cancelada: **si se probo**, ver el
   apartado de arriba

**Efectos secundarios de la sesion de pruebas, ya limpios:**

- `offer_response_seconds` se subio a 300 para poder aceptar sin pelear con los 20 segundos de
  R2, y se devolvio a 20 al terminar (comprobado con `select`)
- Quedaron seis solicitudes de prueba en el servidor, todas `cancelled`, con el mismo criterio
  de fases anteriores: no se borran porque no se puede deshacer y no molestan a nada
- Se encontro (no se produjo) un caso de **H17 real**: `seed_test_driver.sql` dice dejar al
  conductor "a unos 130 metros del parque", pero contra la fila real de `places` ("El parque",
  6.907392 / -75.074987) esta a 963 m. La comprobacion 5 tuvo que crear su solicitud con la
  ubicacion que el conductor reportaba de verdad, no contra "El parque", para poder pasar de
  `assigned` a `in_progress` sin chocar con R5. No se toco la semilla: es el mismo hallazgo que
  ya esta pendiente de tu decision

---

## 15.20 FASE 19: NOTIFICACIONES PUSH

**PROBADA DE PUNTA A PUNTA EL 2026-08-25, CON LOS DOS AVISOS VISTOS EN LA BANDEJA DEL SISTEMA
DE DOS APARATOS DISTINTOS.** Pendiente unicamente de tu aprobacion y del commit.

### Que cubre

Los dos avisos que el flujo de la seccion 7 deja escritos: al pasajero cuando el conductor
llega (`driver_arrived`), al conductor cuando le ofrecen una solicitud nueva. Nada mas: no se
inventaron eventos que el flujo no pide.

### Decision de arranque: hizo falta cuenta de Expo

D113 (Fase 8) habia decidido trabajar sin cuenta de Expo. Un token de Expo Push exige un
proyecto EAS si o si, asi que **se creo uno**: `npx eas-cli@latest login` mas
`npx eas-cli@latest init`, cuenta `jhan160711`, proyecto `@jhan160711/motomoto`,
`projectId` `93c1536c-ce38-4977-8588-7362b53d761a` ya escrito en `app.config.ts` en
`extra.eas.projectId`. **El login lo hizo el usuario en su propia terminal**, no el asistente:
entrar credenciales esta fuera de lo que el asistente puede ejecutar. Esto NO cambia como se
compila hoy (D113 sigue vigente para eso), solo identifica el proyecto ante el servicio de
notificaciones.

### Backend, TERMINADO Y VERIFICADO

- Migracion `20260821223728_push_notifications.sql`: activa `pg_net` (ya disponible en el
  proyecto, no hizo falta pedir nada), anade `profiles.push_token`, y dos disparadores
  (`rides` -> `driver_arrived`, `ride_offers` -> insercion) que llaman a
  `send_push_notification`, una funcion que guarda el aviso en `notifications` y lo manda por
  la API de Expo Push si hay token. **No se toco `confirm_driver_arrival` ni
  `offer_request_to_drivers`**: son disparadores sobre las tablas, no cambios dentro de esas
  funciones, para no arriesgarse a la leccion de E30 (recrear una funcion desde una version
  vieja)
- Migraciones `20260825163833_push_channel_high_importance.sql` y
  `20260825164922_push_channel_v2.sql`: anaden `channelId` y `priority: high` al cuerpo que se
  le manda a Expo. Ver "El canal de Android, tres intentos hasta que sono". **El
  `channelId` del servidor y `CANAL_SERVICIO` del cliente tienen que coincidir**: si se
  separan, el aviso entra por el canal generico de Expo y vuelve a llegar callado, con todo lo
  demas funcionando
- `prueba_notificaciones.sql` (nuevo, en `dev-tools`): **7 comprobaciones en verde**, incluida
  la de que un usuario normal no puede llamar a `send_push_notification` directamente
- Tipos regenerados

### Firebase, EL COSTO QUE NO SE ADVIRTIO A TIEMPO

**Expo Push entrega por FCM en Android, asi que ademas de la cuenta de Expo hace falta un
proyecto de Firebase.** El asistente no lo dijo al presentar la opcion "empuje completo", solo
menciono EAS; el usuario acepto sin saber que venia esto detras. Se reconocio al descubrirlo,
pero la leccion es del asistente: **al ofrecer un camino hay que enumerar todos sus costos, no
el primero que se ve.**

Lo que hubo que hacer, en este orden:

1. **`google-services.json`**, creado por el usuario en Firebase Console (proyecto
   `motomoto2026-444cb`, paquete `com.motomoto.app`) y guardado en la raiz. Se referencia
   desde `app.config.ts` con `android.googleServicesFile`. **NO esta en el repositorio**: la
   plantilla de Expo ya lo ignoraba de fabrica (`.gitignore` linea 41) y se respeto esa
   decision. No es que sea secreto —Firebase lo documenta como publico y acaba dentro del APK,
   igual que la clave de mapas—, pero con un solo desarrollador no aporta versionarlo.
   **RIESGO A NO OLVIDAR: si ese archivo se pierde, la compilacion nativa falla** y hay que
   volver a bajarlo de Firebase Console. El asistente escribio primero que si iba al
   repositorio, sin comprobar que la plantilla ya decia lo contrario; se corrigio al verlo en
   `git status`
2. **Clave de cuenta de servicio de FCM**, subida por el usuario al panel de Expo
   (expo.dev -> Credentials -> Android -> FCM V1 service account key). **Esta SI es secreta**:
   permite escribirle a todos los usuarios de la aplicacion. Esta en `.gitignore` como
   `fcm-service-account.json` y `*-firebase-adminsdk-*.json`
3. El formulario web de Expo **exige un keystore para crear el identificador**, aunque no se
   use la compilacion en la nube. Se subio el keystore de DEPURACION que genera `prebuild`
   (`android/app/debug.keystore`, contrasenas publicas y estandar: `android` /
   `androiddebugkey` / `android`), copiado como `upload-debug.jks` porque el formulario valida
   la extension y rechaza `.keystore`. **PENDIENTE PARA LA FASE 26**: ese keystore es de
   desarrollo y no sirve para publicar; hay que generar uno real y reemplazarlo antes de subir
   a Google Play

### Cliente

- `npx expo install expo-notifications`, mas el plugin en `app.config.ts`
- `src/features/notifications/notifications-service.ts`: `savePushToken`, escritura directa a
  `profiles.push_token` (excepcion acotada mas de las que ya describe D83)
- `src/features/notifications/use-push-registration.ts`: pide permiso, saca el token de Expo
  y lo guarda. Se llama una vez desde `src/app/_layout.tsx`, dentro de `SessionProvider`, no
  desde cada pantalla
- `typecheck`, `lint` y `format:check` en cero

**Los cuatro caminos de fallo dejan rastro, y esto se corrigio a media fase.** La primera
version devolvia `null` en silencio si no habia permiso, si faltaba el `projectId`, si fallaba
la llamada o si algo lanzaba. Cuando el token no llegaba al servidor no habia forma de saber
por cual de los cuatro: el permiso estaba concedido, la fila seguia vacia y el registro no
decia nada. Se anadio un `console.warn` en cada uno, y **el mensaje aparecio de inmediato con
la causa exacta**: `Unable to get Firebase Messaging instance. Did you configure
googleServicesFile...`. Un fallo que no se anuncia cuesta el doble de encontrar.

### Recompilacion nativa, HECHA

`expo-notifications` es modulo nativo: hizo falta `npx expo prebuild --platform android` mas
`gradlew.bat assembleDebug`. **Aqui aparecio un problema nuevo, sin relacion con el codigo**:
el `.apk` con las dos arquitecturas junto pesa 210 MB, y el emulador solo tenia 513 MB libres
(92% del disco lleno). Se resolvio compilando cada arquitectura por separado
(`-PreactNativeArchitectures=x86_64` para el emulador, `=arm64-v8a` para la tablet), que da
un `.apk` de ~125 MB cada uno. **Anotar esto para la proxima vez que haga falta recompilar**:
un build con las dos arquitecturas juntas puede no caber.

### Checklist, resultado real

Con el conductor de prueba en el emulador y el pasajero (cuenta personal del usuario, que
**autorizo explicitamente** al asistente a manejarla para estas pruebas) en la tablet:

1. **El dialogo de permiso sale solo al abrir**, en los dos aparatos. OK
2. **El token queda guardado en `profiles.push_token`** para las dos cuentas, empezando por
   `ExponentPushToken[`. OK
3. **Aviso al conductor.** Se creo una solicitud desde SQL y el push aparecio en la bandeja
   del emulador: "Nueva solicitud de servicio / Tienes un servicio disponible cerca de ti".
   **Visto en captura**, no deducido de la tabla. OK
4. **Aviso al pasajero.** Se llevo un viaje hasta `driver_arrived` y el push aparecio en la
   bandeja de la tablet: "Tu motorratón llegó / Te está esperando en el punto de recogida".
   **Visto en captura.** OK
5. **Expo acepto los tres envios** con `{"status":"ok"}` en `net._http_response`. OK

6. **El aviso suena y sale flotando** (paso 3, ver abajo). Confirmado por el usuario en la
   tablet: "si sonó y salió flotando". OK

### El canal de Android, tres intentos hasta que sono

**El aviso llegaba pero no se notaba.** En la primera version el canal quedo en importancia
`DEFAULT`, que no suena ni se asoma: "Tu motorratón llegó" estaba en la bandeja, pero el
usuario solo lo encontro al desplegarla, cuatro minutos tarde. Para los dos avisos de esta
fase eso no sirve —uno saca al pasajero a la calle y el otro le da al conductor los veinte
segundos de R2—, asi que el usuario pidio subir la importancia.

Costo tres intentos, y los dos primeros fallaron por el mismo motivo de fondo: **Android
congela la configuracion de un canal en cuanto se crea.** Despues solo el usuario puede
tocarla desde los ajustes del sistema. Cambiar el codigo no cambia un canal que ya existe.

1. `default`, importancia `DEFAULT`. Llegaba callado
2. `service-alerts`, ya en `MAX`, pero creado con `sound: 'default'`. **Esa propiedad no
   significa "el sonido del sistema"**: es el nombre de un archivo de sonido propio que
   tendria que venir empaquetado. Los dos aparatos mostraron en pantalla "Custom sound
   'default' not found in native app" y el aviso siguio sin sonar. Se vio en `dumpsys
   notification`: el canal quedaba con `mAudioAttributes=null`
3. `service-alerts-v2`, en `MAX` y **sin** `sound`, que es como se pide el sonido del sistema.
   `dumpsys` ya muestra `mAudioAttributes: usage=USAGE_NOTIFICATION`, y el aviso suena

`CANALES_VIEJOS` en `use-push-registration.ts` borra los dos anteriores al arrancar, para no
dejarle al usuario tres entradas en sus ajustes de notificaciones con dos muertas.

**La misma palabra significa dos cosas distintas en dos sitios**, y por ahi se colo el error:
en el canal de Android `sound: 'default'` es un archivo que no existe, y en el cuerpo que se
le manda a Expo Push `'sound': 'default'` si es el sonido por defecto. El del servidor se
quedo como estaba, a proposito.

### Tropiezos de esta sesion, que no eran del codigo

- **Pantalla en blanco en los DOS aparatos a la vez.** Parecia un fallo del cambio recien
  hecho y no lo era: **Metro estaba colgado**, sin responder a una peticion del bundle ni en
  tres minutos. Probablemente quedo asi tras el `prebuild`, que regenera `android/`. Se
  arreglo con `npx expo start --dev-client --clear`. **Si dos aparatos fallan igual y a la
  vez, sospechar de Metro antes que del codigo**
- **`gradlew assembleDebug` fallo una vez sin decir por que**, y al repetirlo exactamente
  igual compilo bien. Se perdio el mensaje por filtrar la salida con `Select-Object -Last 5`:
  al capturar todo, el error ya no estaba. **No filtrar la salida de un build que falla**
- **Tres ANR al arrancar en el emulador**, de la sesion anterior: era la maquina sobrecargada
  (Android Studio, Epic Games Launcher, Gradle). El usuario cerro programas y arranco a la
  primera
- El `.apk` con las dos arquitecturas pesa 210 MB y no cabia en el emulador (92% de disco).
  **Compilar cada arquitectura por separado**: `-PreactNativeArchitectures=x86_64` para el
  emulador, `=arm64-v8a` para la tablet, ~125 MB cada uno
- El paquete `host.exp.exponent` (Expo Go) se desinstalo del emulador para liberar 264 MB. No
  hacia falta desde D91
- El servidor de `adb` se colgo una vez a mitad de una instalacion larga; se mato con
  `Stop-Process` y se reinicio solo, sin perder nada

### Efectos secundarios ya limpios

- `offer_response_seconds` volvio a 20 y `driver_arrival_radius_m` a 150. Los dos se subieron
  para poder aceptar y llegar sin pelear con R2 y R5, **y el motivo de R5 es el de siempre**:
  la aplicacion pisa la ubicacion sembrada (ver el bloque LEE ESTO PRIMERO)
- Quedaron notificaciones y solicitudes de prueba en el servidor, con el mismo criterio de
  fases anteriores: no se borran

### Lo que falta

Las dos hechas: el usuario aprobo y comiteo la fase el 2026-08-25.
`google-services.json` y `upload-debug.jks` **no aparecieron en la lista del commit**: el
primero lo ignora la plantilla de Expo y el segundo es una copia temporal del keystore de
depuracion, que se puede borrar cuando se quiera.

---

## 15.21 BLOQUE ESPECIAL: TARIFAS, ENCOMIENDAS Y CARGA (TERMINADO, IBA ANTES DE LA FASE 20)

**EMPEZADO EL 2026-08-25, TERMINADO EL 2026-08-26.** Los ocho pasos hechos y verificados:
servidor, pantalla del pasajero, historial y recaudo del conductor, y la regresion de las fases
11 a 19. La auditoria formal contra el codigo esta hecha, las decisiones previas estan cerradas,
y todo -servidor y pantallas- esta aplicado y verificado, con once archivos de pruebas
automaticas en verde y verificacion en vivo en la tablet real y el emulador. El detalle esta al
final de esta seccion, en los ocho bloques "Lo que se hizo" y las dos correcciones D233/D234.

### De donde sale

Peticion de los duenos de la empresa, entregada por el usuario el 2026-08-25. **Se coloca
entre la Fase 19 y la Fase 20 a proposito**: varias de estas cosas —tarifas, destinos rurales,
tipos de carga, recaudo— son datos que el panel administrativo tendra que gestionar, asi que
construir el panel antes obligaria a rehacerlo.

### Lo que cambia de fondo

**D217: la aplicacion pasa a calcular y mostrar el valor del servicio.** Modifica a D8 y al
parrafo de la seccion 1. La aplicacion **sigue sin procesar pagos**: cobra el conductor, en
efectivo. Lo que se anade es que el pasajero vea cuanto va a costar **antes** de confirmar.

### Los requisitos, tal como llegaron

1. **Encomienda como servicio independiente**, con descripcion libre ("caja con documentos",
   "bulto de café", "repuestos")
2. **Pasajero con carga**, distinto de los otros dos casos. Los tres no se confunden entre si:
   pasajero solo / pasajero + carga / encomienda sola
3. **Tarifas administrables, NO escritas en el codigo.** Crear, consultar, modificar,
   activar y desactivar
4. **Tarifas iniciales**, que son un punto de partida y no valores permanentes:
   - Urbano: 1 persona $4.000, 2 personas $6.200, 3 personas $8.500
   - Recargo nocturno (10:00 p. m. a 5:00 a. m.): $7.000 / $12.000 / $17.000
   - **36 destinos rurales** con precio fijo cada uno, de $10.800 (La Vibora, Alto del Rio) a
     $100.000 (Cajamarca)
   - Carga: caja pequena $1.700, caja grande $2.800, domicilios y encomiendas $3.800, bulto de
     cemento $2.800, bulto de café $4.900, bicicleta $2.300
5. **Historial del conductor** con fecha, hora, origen, destino, tipo de servicio, pasajeros,
   carga, encomienda, tarifa, valor y estado
6. **Recaudo del conductor**: servicios realizados, valor de cada uno, total acumulado, por
   periodo
7. **Calificaciones y comentarios** en los dos sentidos

### Matriz de auditoria, PRIMERA LECTURA SIN VERIFICAR CONTRA EL CODIGO

**ESTA MATRIZ SE QUEDA COMO ESTABA, y debajo va la corregida.** Era una lectura de memoria, y
se conserva a proposito: comparar las dos es lo que ensena cuanto vale la regla 2 del proyecto
("verificar, no suponer"). De trece filas, **una estaba equivocada** y otras cuatro escondian
un problema que solo aparecio al mirar el codigo.

| Requisito | Primera lectura | Por comprobar |
|---|---|---|
| Encomienda independiente | No existe | Que `ride_requests` no tenga ya un tipo de servicio |
| Descripcion de encomienda | No existe | — |
| Pasajero con carga | No existe | — |
| Tipos de carga | No existe | — |
| Tarifas configurables | **No existe, y contradecia a D8** | Si `app_settings` sirve de base o hace falta tabla propia |
| Mostrar tarifa al usuario | No existe | Donde encaja en la pantalla de resumen (D147) |
| Tarifas urbanas por pasajeros | No existe | Se apoya en `passenger_count`, que si existe |
| Recargo nocturno | No existe | Con que reloj se decide: el del servidor, no el del telefono (D154) |
| Tarifas rurales por destino | No existe | **Los 36 destinos contra las 36 filas de `places`**: hay que ver cuantos coinciden |
| Historial del conductor | **YA EXISTE** (Fase 16) | Si hay que anadirle las columnas de valor y tipo de servicio |
| Recaudo del conductor | No existe como pantalla | Si se puede calcular sobre el historial que ya hay |
| Calificaciones | **YA EXISTE** (Fase 17) | Nada. Cubierto en los dos sentidos |
| Comentarios | **YA EXISTE** (Fase 17) | Nada. Opcional, junto a las estrellas |

**Dos de trece ya estan hechas** (historial y calificaciones con comentario), y una tercera
—recaudo— probablemente se apoye en la que ya hay en vez de necesitar tabla nueva.

### La matriz de verdad, contra el codigo (2026-08-25)

Hecha leyendo las 45 migraciones aplicadas y `src` entero, no de memoria.

| Requisito | Codigo real | Estado | Accion |
|---|---|---|---|
| Encomienda independiente | No hay tipo de servicio en ninguna parte: ni enum, ni columna, ni pantalla | No existe | Nueva |
| Descripcion de encomienda | Lo unico parecido es `pickup_reference`, 80 caracteres, y es otra cosa | No existe | Nueva |
| Pasajero con carga | Confirmado, nada | No existe | Nueva |
| Tipos de carga | Confirmado, nada | No existe | Nueva |
| Tarifas configurables | `app_settings` **no sirve**: clave/valor jsonb, sin activo/inactivo, sin trazabilidad | No existe | Tablas propias (D223) |
| Mostrar tarifa al usuario | Confirmado. El sitio exacto es `ResumenDelViaje`, junto a la fila de distancia y tiempo | No existe | Nueva |
| Tarifas urbanas por pasajeros | `passenger_count` existe y R11 ya lo valida en servidor | No existe, base si | Nueva |
| Recargo nocturno | **Ninguna migracion menciona zonas horarias** y el servidor va en UTC | No existe | Nueva |
| Tarifas rurales por destino | **La primera lectura estaba equivocada.** Los 36 destinos NO son los 36 lugares: solo coincide de nombre "La vibora", y esa coincidencia esta en duda | No existe, y faltan datos | Nueva + coordenadas |
| Historial del conductor | `list_driver_history` da fecha, origen, destino, pasajeros y desenlace. **Le faltan tipo de servicio, carga y valor** | Existe, incompleto | Ampliar, no rehacer |
| Recaudo del conductor | No hay pantalla ni funcion, pero `ride_offers` mas `rides` ya tienen todo menos el valor | No existe | Nueva, encima de lo que hay |
| Calificaciones | Tabla `ratings`, `rate_ride`, los dos sentidos, una por parte y por viaje | **Cumple** | Ninguna |
| Comentarios | Columna `comment`, hasta 1000 caracteres, opcional | **Cumple** | Ninguna |

**Dos de trece cumplen, una esta a medias, diez son nuevas.** Coincide con la primera lectura
salvo en las tarifas rurales.

### Los cinco hallazgos que solo aparecieron al mirar el codigo

1. **Los 36 destinos rurales no son los 36 lugares de `places`.** Son dos listas distintas.
   Faltan las coordenadas de 34 sitios, y ese dato no esta en ningun sitio del proyecto: lo
   tiene que dar quien conoce Amalfi. **Bloquea las tarifas rurales, nada mas**
2. **No habia forma de saber si un viaje es urbano o rural.** `service_area` es el municipio
   entero, 1206 km2, y `places` no marca zona. Resuelto con D218
3. **El destino no siempre es un lugar de la lista.** Puede venir del buscador de Mapbox o de
   una chincheta, y entonces `destination_place_id` es nulo. Resuelto con D219
4. **La encomienda chocaba con dos restricciones vivas.** `rr_passenger_count_range` exige
   minimo 1 pasajero y `enforce_ride_capacity` suma asientos. Resuelto con D220. Comprobado
   ademas que `enforce_ride_capacity` usa `sum(...)`, asi que el cero no le molesta
5. **`app_settings` no valia para las tarifas.** Resuelto con D223

### El dato que decidio D218

Se midio la distancia al parque de los 36 lugares de `places`. **34 estan a menos de 2 km.**
Los dos que se salen son Vereda Guayabito, a 6,3 km, y Vereda Manzanares, a 3,5 km. Con la
lista actual siendo practicamente toda urbana, un perimetro urbano no habria separado nada.

Ese mismo calculo dejo una pregunta para la empresa: **la empresa cobra $10.800 por "La
Vibora", y "La vibora" de `places` esta a 1,34 km del parque.** A esa distancia $10.800 no
cuadra frente a los $4.000 urbanos. Probablemente son dos sitios distintos con el mismo
nombre. **Sin confirmar.** El otro parecido, "Manzanares" a $12.000 contra "Vereda Manzanares"
a 3,5 km, si cuadra.

### Impacto previsible, tambien por comprobar

- **Base de datos:** tabla o tablas de tarifas; tipo de servicio en `ride_requests`; carga y su
  descripcion; el valor calculado guardado con el servicio. **Cuidado con `rides` y
  `ride_requests`**, que las tocan casi todas las funciones de las fases 11 a 18
- **`request_ride`:** es la funcion mas reescrita del proyecto y la que mas ha sufrido (ver el
  aviso de E30 en `20260811184748_pickup_reference.sql`). Si hay que tocarla, **partir de su
  ULTIMA version aplicada**, no de la primera que aparezca al buscar
- **Aplicacion movil:** el resumen del viaje (D147) tiene que mostrar el valor; hace falta
  elegir tipo de servicio antes o durante el flujo actual
- **Tiempo real:** no deberia cambiar
- **Fase 20:** el panel tendra que gestionar tarifas, destinos, tipos de carga y recaudo

### Orden aprobado por el usuario el 2026-08-25

1. ~~**Auditoria real contra el codigo** y matriz corregida~~ **HECHO**
2. ~~Decidir la forma de las tarifas y de los tipos de servicio, **antes** de escribir la
   primera migracion~~ **HECHO**, D218 a D225
3. **Migracion de tarifas, con sus pruebas de romper — HECHO Y VERIFICADO**
4. **Migracion de tipo de servicio y carga, con sus pruebas de romper — HECHO Y VERIFICADO**
5. **Calculo del valor en el servidor — HECHO Y VERIFICADO**, incluida la tarifa del punto
   mas cercano (D226), que no estaba prevista, y **`request_ride` ya lo usa**
6. **Pantallas del pasajero: elegir tipo de servicio, anadir carga y ver el valor —
   HECHO Y VERIFICADO EN EL EMULADOR**
7. ~~Historial y recaudo del conductor, encima de lo que ya existe~~ **HECHO Y VERIFICADO EN EL
   EMULADOR**
8. ~~Regresion de las fases 11 a 19~~ **HECHO** (con una pieza sin cerrar en vivo, ver mas abajo)


Las tarifas rurales entran como filas cuando lleguen las coordenadas, **sin tocar el esquema**:
por eso no bloquean nada mas que a si mismas.

### Lo que se hizo: paso 1, las tarifas (2026-08-25)

**Nueva implementacion.** `supabase/migrations/20260825223000_fare_tables.sql`.

Tres tablas, todas con RLS, lectura para cualquier autenticado y escritura solo para el
administrador, igual que `places`:

- **`urban_fares`** — la rejilla de cantidad de pasajeros por franja horaria. Clave compuesta,
  6 filas cargadas. **Sin `is_active` a proposito**: apagar "dos pasajeros de noche" no
  significa nada y dejaria un servicio sin precio a las once
- **`rural_fares`** — el precio fijo por destino, apuntando a `places` con `on delete
  restrict`. **Vacia**, esperando coordenadas. Se cobra plana, sin importar cuantos van
- **`cargo_types`** — el catalogo, 6 filas. Nombre unico normalizado como en `places`

En `app_settings`, tres parametros nuevos: `fare_timezone`, `night_fare_start_hour` y
`night_fare_end_hour`.

**31 comprobaciones automaticas, todas en verde**, en
`supabase/dev-tools/prueba_tarifas.sql`: 16 intentos de romper restricciones, 6 sobre los
datos que dio la empresa, 6 de politicas suplantando a un pasajero real y 3 sin sesion.

Dos merecen mencion. **La 21 y la 22 miden la hora**: las 03:00 UTC tienen que ser las 22:00
en Amalfi, inicio de la franja, y las 22:00 UTC tienen que ser las 17:00, todavia de dia. La
segunda es la que importa: si alguien quitara la conversion, la primera seguiria en verde por
casualidad. **La 16 se espera en verde ENTRANDO y no rechazando**: es el hallazgo H10 visto en
la tabla nueva, "Caja  grande" con dos espacios en medio convive con "Caja grande". Queda
medido para que no se descubra en la Fase 20.

**Un error, y fue del script y no de la migracion:** al suplantar a `anon` la prueba se caia
con un 42501 sobre la tabla temporal de resultados, porque el permiso solo se le habia
concedido a `authenticated`. Una sola correccion.

**Un tropiezo que no era del codigo.** `supabase db push` fallaba con
`failed to parse environment file: .env`. La causa no tenia nada que ver con el proyecto: el
`.env` tenia al final **siete lineas de PowerShell** (`$env:ANTHROPIC_...`), ajustes de Claude
Code pegados en el archivo equivocado. Un `.env` espera `CLAVE=valor`, asi que el parser se
rendia con el archivo entero y **ninguna** variable se leia. Se movieron a
`.env.claude-code.ps1` (ignorado por git, como todo `.env.*`) con respaldo previo en
`.env.backup-20260825`. Comprobado que el token nunca subio al repositorio: `.gitignore`
lineas 36 y 37.

**Resuelto por el usuario el 2026-08-25:** la encomienda urbana **si paga el recargo
nocturno**, o sea $7.000 a partir de las diez. Con eso D221 queda cerrada del todo.

### Lo que se hizo: paso 2, tipo de servicio y carga (2026-08-25)

**Nueva implementacion.** `supabase/migrations/20260825234500_service_type_and_cargo.sql`.

**Los tres casos se distinguen con dos datos y no con tres valores de un enum**, que es lo que
pidio la empresa al decir "no confundir estos tres casos":

```
pasajero solo      service_type = 'passenger', sin filas de carga
pasajero + carga   service_type = 'passenger', con filas de carga
encomienda sola    service_type = 'parcel',    passenger_count = 0
```

Un tercer valor, `passenger_with_cargo`, habria sido un dato capaz de contradecir a otro: nada
impediria guardarlo sin carga, ni guardar `passenger` con tres bultos. Asi la contradiccion no
cabe.

Lo que entro:

- **`service_type`** en `ride_requests`, enum de dos valores, con `default 'passenger'`. **Las
  45 solicitudes que ya existian quedaron clasificadas solas** y `request_ride` sigue
  funcionando sin tocarla
- **`parcel_description`**, obligatoria entre 3 y 120 caracteres si el servicio es encomienda y
  **prohibida** si es viaje de pasajeros. El encargo decia "debe permitir una descripcion", que
  es mas suave: **se apreto a proposito**, porque el conductor tiene que decidir si acepta
  llevar algo sin nadie que se lo explique por el camino. Se afloja quitando media restriccion
- **El cero pasajeros, atado al tipo de servicio.** `rr_passenger_count_range` se sustituyo por
  `rr_passenger_count_matches_service`: cero exactamente en la encomienda, de 1 a 10 en el
  viaje de pasajeros. **No se abrio el cero en general**, que era la forma facil y la
  equivocada: un viaje de pasajeros vacio no ocuparia asiento y dejaria acumular viajes
  fantasma
- **`rides.passenger_count`** pasa a 0..10 sin atarlo al tipo, y **queda dicho por que**: esa
  tabla no tiene `service_type` y un CHECK no puede mirar otra tabla. La regla vive donde nace
  el dato
- **`ride_request_cargo`**, la lista de carga (D224). Una linea por tipo, con cantidad y
  `unit_amount` congelado (D225). `unique (request_id, cargo_type_id)`: dos lineas del mismo
  tipo son una linea con cantidad dos

**La carga la ve el conductor ANTES de aceptar**, y es una diferencia deliberada con el nombre
y el telefono del pasajero, que desde la Fase 12 no viajan hasta que acepta (D172). El motivo
es que no es lo mismo: quien es el pasajero no cambia la decision de aceptar; que lleve una
bicicleta si la cambia. Un conductor que acepta a ciegas y descubre el bulto al llegar es un
servicio cancelado en el sitio.

**Sin politica de insercion, actualizacion ni borrado para nadie**, ni siquiera el
administrador. Esas filas nacen dentro de `request_ride` en la misma transaccion que la
solicitud. Dejar que el telefono escriba ahi permitiria carga anadida despues de que el
conductor viera el precio que acepto.

**29 comprobaciones automaticas, todas en verde**, en
`supabase/dev-tools/prueba_encomiendas.sql`.

**La 12 es la que justifica D220** y la que mas facil se habria dado por buena sin medirla: un
conductor con una encomienda encima **todavia puede aceptar sus tres pasajeros**. Va con la 13
vigilandola, que mete un pasajero mas y comprueba que el limite si rechaza: sin esa pareja, la
12 podria estar en verde porque el control de capacidad no funciona en absoluto.

**Dos errores, los dos del script y ninguno de la migracion.** El primero: la limpieza previa
caducaba solo las solicitudes `searching`, y el primer pasajero de la base tenia una
`in_progress`, asi que R6 tumbaba todas las inserciones. El segundo, mas interesante:
`enforce_ride_capacity` **hace dos cosas y la primera no tiene que ver con los asientos** —si
el conductor lleva un viaje con OTRO motorraton, rechaza con `DRIVER_VEHICLE_CONFLICT`—. El
conductor 1 tenia un viaje vivo con la unidad 99 y el script elegia la 98, la de numero mas
bajo, asi que saltaba ese conflicto y **la capacidad nunca llegaba a medirse**. Las dos
comprobaciones que importaban estaban en rojo por algo que no era lo que probaban. Una
correccion cada vez.

De paso quedo escrito en el archivo que **los once pasajeros los atrapa el disparador y no la
restriccion**: `enforce_ride_capacity` es BEFORE y corre antes, asi que rechaza por capacidad
comparando 11 contra 3. La restriccion de 10 no llega a evaluarse mientras ningun vehiculo
tenga mas de diez plazas.

### Lo que se hizo: paso 3, el calculo del valor (2026-08-25)

**Nueva implementacion.** `supabase/migrations/20260826010000_fare_calculation.sql`.

**Se partio en dos a proposito.** Aqui va la formula, aislada y probada; enganchar
`request_ride` va aparte. Esa funcion es la que produjo E30, y mezclar una formula sin
verificar con su reescritura seria pedir el mismo error otra vez.

**`quote_fare`**, una funcion que devuelve una fila con el desglose: `is_rural`, `is_night`,
`trip_amount`, `cargo_amount` y `total_amount`. **La misma que usara `request_ride`**, y eso
es lo unico que garantiza que el pasajero pague lo que vio: dos calculos separados se
desincronizan el dia que alguien toque uno.

El calculo vive en el servidor por D83 y por algo mas concreto: **el recargo nocturno depende
de la hora, y la hora del telefono la cambia cualquiera desde los ajustes**. Un pasajero
podria pagar tarifa de dia a medianoche adelantando el reloj.

Tres parametros nuevos en `app_settings` para D219: `fare_center_lng`, `fare_center_lat` y
`unpriced_destination_max_km`, este ultimo en 5 km como punto de partida. **El centro usa las
coordenadas de `places` y no las de D122**, que es el hallazgo H17: si se resuelve al reves,
se cambian dos numeros desde el panel.

**Cinco columnas de valor en `ride_requests`**: `fare_amount`, `fare_trip_amount`,
`fare_cargo_amount`, `fare_is_night` y `fare_is_rural`. Admiten nulo porque **las 45
solicitudes anteriores a D217 no tienen valor y no se les puede inventar uno**: un cero ahi
seria peor que un vacio, porque un cero parece un dato. Se guarda el desglose y no solo el
total porque con los precios cambiando desde el panel, un total suelto no se puede volver a
explicar dentro de seis meses.

**LA FORMULA QUEDO GARANTIZADA POR LA BASE DE DATOS, no por el codigo.** Misma idea que el
indice unico de las ofertas aceptadas de la Fase 5: la regla deja de ser algo que hay que
acordarse de cumplir. Tres restricciones nuevas:

- `rr_fare_matches_parts`: en la encomienda el total es la mayor de las dos partes, y en el
  viaje de pasajeros es la suma. Un total que no cuadre no entra, venga de donde venga
- `rr_fare_all_or_nothing`: o estan las cinco columnas o no esta ninguna
- `rr_fare_rural_is_never_night`: D222 tambien escrito en la estructura

**43 comprobaciones automaticas, todas en verde a la primera**, en
`supabase/dev-tools/prueba_calculo_tarifa.sql`. Cubren los seis casos de la tarifa urbana, los
rurales planos, las tres formas de combinar carga, las once que tienen que fallar con su
codigo de error, las cuatro restricciones de columna y los permisos.

**Los ejemplos de la empresa, comprobados uno a uno:**

| Servicio | Cuenta | Valor |
|---|---|---|
| 3 personas a un rural de 15.000 | plana | 15.000 |
| 1 persona urbana + bicicleta | 4.000 + 2.300 | 6.300 |
| 3 personas rural + bulto de cafe | 15.000 + 4.900 | 19.900 |
| Encomienda urbana, caja pequena | mayor(4.000, 1.700) | 4.000 |
| Encomienda urbana, bulto de cafe | mayor(4.000, 4.900) | 4.900 |
| Encomienda urbana de noche, bulto de cafe | mayor(7.000, 4.900) | 7.000 |
| Encomienda rural 12.000, bicicleta | mayor(12.000, 2.300) | 12.000 |

**Dos detalles del archivo de pruebas que valen para el que venga.** Uno: **todas las
comprobaciones pasan la hora a mano**, ninguna deja `now()`. Una prueba que no fije la hora
pasaria por la tarde y fallaria a medianoche, y eso no es una prueba. Dos: **los cuatro bordes
de la franja estan medidos** -21:59, 22:00, 04:59 y 05:00- porque un `>` donde va un `>=`
desplaza el recargo una hora entera sin que nada mas se note. Y hay una quinta, la 21, que
escribe la misma hora en UTC: si alguien quitara la conversion de zona, las cuatro primeras
podrian seguir en verde y esa se pondria roja.

**Sin errores en esta migracion.** Es la primera del bloque que salio a la primera.

---

### Lo que se hizo: paso 3b, la tarifa del punto mas cercano (2026-08-25)

**Nueva implementacion.** `supabase/migrations/20260826024500_rural_fare_nearest_point.sql`.

**No estaba en el plan.** Salio de una pregunta del usuario al revisar el paso 3, y era un
hueco de verdad: `quote_fare` solo sabia cobrar rural si el destino era exactamente uno de la
lista. Un punto entre dos destinos caia en urbano o rebotaba. Ver D226, D227 y D228.

Lo que entro: `quote_fare` **se borro y se volvio a crear** —cambia el tipo de retorno y eso
`create or replace` no lo admite, asi que hubo que volver a conceder permisos— con dos
columnas nuevas de salida, `reference` y `reference_m`. Y en `ride_requests`, la columna
`fare_reference` con dos restricciones: una tarifa rural sin referencia esconde de donde salio
el numero, y una referencia en un viaje urbano no significa nada. Van juntas o no van.

El orden dentro de la funcion importa y queda dicho: **primero el destino exacto, y solo si no
tiene precio propio se busca el mas cercano.** Un destino de la lista nunca se redondea a otro.

**54 comprobaciones en el archivo del calculo, todas en verde.** Las once nuevas cubren el
punto medio ganado por cada lado, que el destino exacto no se redondea, que fuera del radio no
se pega, que una tarifa apagada deja de servir de referencia y las dos restricciones de la
columna.

**UN ERROR, Y ES EL MAS INSTRUCTIVO DEL BLOQUE.** Al aplicar D226, **diecinueve
comprobaciones que estaban en verde se pusieron rojas de golpe**. La causa no era la funcion:
era el montaje del archivo de pruebas. Para probar lo rural inventaba dos tarifas sobre El
hospital y El coliseo, que estan a 431 y 467 metros del parque, y **casi todas las
comprobaciones urbanas usan el parque como destino**. Con la regla nueva, el parque se pegaba
a una tarifa rural y devolvia 15.000 donde tenia que devolver 4.000.

En la realidad ningun destino rural va a estar a cuatrocientos metros del parque, asi que el
que fallaba era el montaje. Se corrigio creando **dos lugares de prueba con coordenadas
elegidas**, a 10 y 11,5 km al norte y separados 1,5 km: la geometria la decide el archivo y no
el azar de donde caen los lugares de Amalfi. **Y el radio de D226 se fija dentro del archivo**
en vez de leer el de produccion, porque ese valor es provisional y va a cambiar: una prueba
que dependiera de el se pondria roja el dia que se afine, sin que nada estuviera mal.

**La leccion, que vale para todo el proyecto:** una regla nueva puede volver ambiguo el
montaje de pruebas que ya existian, sin que ninguna este mal escrita. Diecinueve rojas de
golpe no significaron diecinueve fallos: significaron uno.

---

### Lo que se hizo: paso 4, request_ride con valor, carga y encomienda (2026-08-25)

**Existente — modificada para cumplir el nuevo requisito.**
`supabase/migrations/20260826040000_request_ride_with_fare.sql`. Cierra D217: a partir de aqui
una solicitud nace con su valor escrito, el mismo que el pasajero vio antes de confirmar.

**Se partio de `20260811184748_pickup_reference.sql`**, que era la ultima version aplicada, y
**se conservaron sus once comprobaciones en el mismo orden**: perfil, cuenta bloqueada, rol,
telefono, R11, las dos de zona de servicio (D150), la referencia, la caducidad dirigida
(D151), R6 y la de conductores disponibles. Eso es justo lo que E30 borro sin querer.

**Los cuatro parametros nuevos van al final y con valor por defecto**, asi que la llamada que
hoy hace `ride-service.ts` sigue valiendo sin tocar una linea de TypeScript. La pantalla se
ocupa en su propio paso.

**`find_available_drivers` NO se toco, y se comprobo leyendola antes de decidirlo.** Filtra por
`asientos libres >= p_passenger_count`, y una encomienda pide cero, asi que cualquier conductor
disponible es candidato aunque lleve el motorraton lleno. Es exactamente D220.

**32 comprobaciones automaticas, todas en verde**, en
`supabase/dev-tools/prueba_solicitud_con_valor.sql`. La mitad son regresion de E30.

**DISCREPANCIA ENCONTRADA ENTRE ESTE DOCUMENTO Y EL CODIGO, y se reporta tal cual.** La
seccion 15.14 dice que la Fase 14 dejo 24 comprobaciones en `prueba_referencia.sql` y
`prueba_posicion.sql`, **y ninguno de los dos archivos esta en el repositorio**. Entre ellas
estaban las tres pruebas de regresion que se anadieron al corregir E30 "para que no pueda
repetirse en silencio". O sea que **la red que debia proteger esta reescritura no existia**, y
esta reescritura es exactamente la operacion que produjo E30. Las de `request_ride` se
escribieron aqui; **las de `get_driver_location` siguen sin existir** y quedan pendientes.

**Un error, y fue del montaje de la prueba.** Para comprobar D151 hacia falta una solicitud
viva pero vencida, y se puso `expires_at` en el pasado dejando `requested_at` en ahora:
`rr_expiry_after_request` exige que la caducidad sea posterior a la peticion, asi que la fila
no entraba y el archivo se caia entero. Hay que mover las dos fechas. Una sola correccion.

**Y un hallazgo nuevo, H21, que salio al escribir la comprobacion 29.** Esta abajo, con los
demas hallazgos abiertos. No se toco nada: es una decision de la empresa, no del codigo.

**Una alarma que resulto ser falsa, y queda escrita porque el metodo funciono.** Al comprobar
que la prueba no hubiera dejado nada, el servicio en curso que habia antes aparecio terminado.
Se investigo en vez de darlo por bueno: **cero filas con `cancelled_by = 'admin'`**, que es la
huella que dejarian estos scripts, y el viaje quedo `completed`, que ningun script de aqui
sabe hacer porque todos cancelan. Lo termino la aplicacion cincuenta minutos antes de la
prueba. El rollback funciono.

---

### Lo que se hizo: correccion D230/D231 y carga de 24 destinos rurales (2026-08-26)

**Correccion de un error del asistente, no de un fallo del sistema.** El usuario entrego
`docs/destinos-rurales.csv` con coordenadas de 34 destinos, en grados/minutos/segundos.
Convertidas y verificadas contra `is_within_service_area` antes de escribir nada: **24 caen
dentro del municipio**, 2 tienen la longitud mal transcrita (falta el 7 inicial: llegan como
"5°..." en vez de "75°...") y 10 siguen sin coordenada.

**Medir antes de cargar destapo que D226 estaba mal planteada.** Alto del Rio queda a 1.432 m
del parque; El Taparo a 1.459 m. Con el radio de 2 km de D227, **32 de los 36 lugares urbanos
caian dentro del radio de un destino rural, el parque incluido**: un viaje al parque habria
cobrado 10.800 en vez de 4.000. Nunca llego a produccion porque no se habia cargado ninguna
tarifa rural todavia con esa regla puesta.

**La causa era una interpretacion estrecha, no el codigo.** El usuario dijo "si esta mas cerca
de un lugar que de el otro, se cobre el del lugar mas cerca", sin limitarlo a los rurales, y
asi quedo escrito D230. `supabase/migrations/20260826053000_nearest_place_wins.sql` reescribe
`quote_fare` para comparar contra TODOS los lugares activos de `places`, no solo los que
tienen fila en `rural_fares`. Un lugar urbano nunca pierde contra si mismo, a cero metros, asi
que deja de necesitar que nada lo proteja.

**El radio subio a 3 km (D231), y esta vez con separacion real medida**: 314 m minima, 979
mediana, 4.273 maxima entre los 24 destinos. Con la regla nueva, pasarse de radio ya no
encarece el pueblo: solo alcanza a puntos sin ningun nombre cerca.

**Los 24 destinos verificados se cargaron**, en
`supabase/migrations/20260826060000_seed_rural_fares_batch1.sql`. Cada uno es un lugar nuevo
en `places` (`sort_order` 20, para separarlo visualmente de los urbanos de la Fase 9) con su
fila en `rural_fares`. Tiene que ser un lugar y no solo una tarifa porque D230 compara
distancias contra `places` entero.

**Verificacion contra los datos reales, 60 de 60 en verde**, no solo contra la sintetica: los
24 destinos exactos cobran su tarifa exacta, y **los 36 lugares urbanos de la Fase 9, el
parque incluido, siguen cobrando 4.000**. Es la comprobacion que motivo la correccion, hecha
con las coordenadas de verdad y no con los lugares inventados de las pruebas automaticas.

**146 comprobaciones automaticas existentes vueltas a correr despues del cambio de regla,
todas en verde.** Una tuvo que reescribirse: la 51 de `prueba_calculo_tarifa.sql` esperaba que
al apagar un destino rural el punto cayera al siguiente rural; con D230 el resultado es
mejor — el punto se queda sin poder cobrarse y rebota por D219, que es lo honesto cuando la
empresa retira un destino en vez de cobrar la tarifa de un sitio a kilometro y medio.

**Lo que sigue sin cargar, y por que:**

- **Cañada Onda y Finca Posada.** El usuario corrigio el nombre de la primera (no "Cañonada").
  Las coordenadas de las dos siguen con la longitud rota; pendientes de confirmacion
- **10 destinos sin coordenada**: Sorrento, Entrada a la Mina, Los Tanques, La Mina, La
  Aguacatera, Cajamarca, Palmitas, La Blanquita, y los dos nombres en duda: **La Vibora**
  (¿es "La víbora" de `places`, a 1,34 km del parque?) y **Manzanares** (¿es "Vereda
  Manzanares", a 3,49 km, que si cuadra con sus 12.000?)

---

### Lo que se hizo: cuatro nombres resueltos y cargados (2026-08-26)

**Existente — modificada para cumplir el nuevo requisito**, en dos de los cuatro casos; **nueva
implementacion** en los otros dos. `supabase/migrations/20260826070000_seed_rural_fares_batch2.sql`.

El usuario entrego las coordenadas de Cañada Honda (corrigio el nombre, no "Cañonada"), Finca
Posada, y los dos nombres en duda. **Los dos en duda se midieron antes de decidir, y salieron
distintos** (D232): Manzanares resulto ser el mismo sitio que "Vereda Manzanares" (288 m de
diferencia, ruido de GPS); La Vibora resulto ser un sitio distinto de "La víbora" urbana (3.817
m de diferencia).

**Cañada Honda y Finca Posada entraron sin ambiguedad**, aunque quedaron cerca de destinos ya
cargados (219 m de Alto del Rio, 359 m de Finca Doña Lucia): no es senal de duplicado, son
nombres y precios distintos en la lista de la empresa, y la separacion entre los 24 rurales de
la primera tanda ya bajaba hasta 314 m.

**Verificacion contra el servidor, no contra la memoria**, antes de cada decision: se comprobo
que el "La víbora" viejo no tuviera ninguna solicitud que lo referenciara antes de renombrarlo,
y despues de la migracion se confirmo que sigue existiendo un solo "la víbora" activo y que
cada uno de los cuatro nombres cobra exactamente su tarifa.

**146 comprobaciones existentes vueltas a correr, todas en verde. Sin regresion.**

**28 de 36 tarifas rurales cargadas.** Quedan 8 sin coordenada: Sorrento, Entrada a la Mina,
Los Tanques, La Mina, La Aguacatera, Cajamarca, Palmitas y La Blanquita.

---

### Lo que se hizo: paso 6, la pantalla del pasajero (2026-08-26)

**Nueva implementacion.** Modulo `src/features/fare/` (diez archivos: tipos, dos servicios, dos
hooks, cuatro componentes y el formateador de pesos) mas cambios en
`src/app/passenger/index.tsx`, `src/features/ride/ride-draft.tsx`,
`src/features/ride/ride-service.ts` y `src/features/ride/errors.ts`. Ademas,
`supabase/migrations/20260826080000_active_request_includes_fare.sql`: `get_active_request`
extendida con el tipo de servicio, la descripcion y el valor, para que D152 (restaurar un
servicio en curso al reabrir la aplicacion) siga funcionando con encomiendas y no solo con
viajes de pasajeros.

**`ResumenDelViaje` gano cuatro piezas nuevas, todas condicionadas al tipo de servicio:**

- `ServiceTypeToggle` -Pasajero/Encomienda- arriba de la tarjeta. Los tres casos del encargo
  siguen sin confundirse: es el mismo boton "Pasajero" con o sin carga, y solo "Encomienda"
  cambia la forma del formulario de abajo
- El campo de pasajeros se sustituye por la descripcion de la encomienda cuando corresponde
- `ChosenCargoList` -lo ya elegido, con su precio y un boton para quitar- y `CargoPicker`, un
  dialogo con los seis tipos y un contador de mas y menos cada uno, mismo patron que
  `PassengerCount`. "Agregar carga" pasa a decir "Agregar otra carga" en cuanto hay una linea,
  que es como se resuelve el pedido de la empresa sin boton aparte
- `FareRow`, el valor en vivo, con la referencia del destino rural cuando aplica (D228)

**El boton de confirmar espera a tener un precio valido**, no solo a que termine de enviar.
Antes de este paso el unico candado era la ruta de Mapbox, decorativa; el valor es el punto
central de D217, asi que aqui si bloquea: mientras se calcula, mientras una encomienda no
tiene carga todavia, o si el servidor rechazo el destino, el boton espera.

**`useFareQuote` llama a la MISMA funcion `quote_fare` que usara `request_ride`** para congelar
el valor, con el mismo patron de debounce que ya usaba la estimacion de ruta (D149). Sin fecha
propia: se deja que el servidor use su reloj, que es el que de verdad decide el recargo
nocturno.

**Verificado en el emulador, no solo compilado.** Se abrio la aplicacion de verdad, se entro
como el pasajero de prueba y se probaron en vivo los dos casos:

- **Pasajero + bicicleta**: $4.000 + $2.300 = **$6.300**, la suma
- **Encomienda + bulto de cafe**: mayor($4.000, $4.900) = **$4.900**, la comparacion

Los dos salieron exactos. Tambien se comprobo en pantalla: el boton "Agregar carga" cambiando
a "Agregar otra carga", el precio recalculandose al quitar la carga, el boton de confirmar
deshabilitado mientras una encomienda no tiene carga, y que el caso ya existente de "no
sabemos donde recogerte" -sin tocar en este paso- seguia funcionando igual que antes: **sin
regresion**.

**Un ajuste que salio de mirar la pantalla y no del codigo.** La primera version de `FareRow`
decia "Calculando el valor" con un giro cuando una encomienda no tenia carga todavia, y era
enganoso: no hay nada calculandose, hace falta que el pasajero agregue algo. Se vio en el
emulador de camino a la primera comprobacion, no en un caso de prueba. Se cambio a "Agrega una
carga para ver el valor" con el icono de la caja, sin el giro.

**146 comprobaciones existentes en 0 fallando** tras extender `get_active_request`, mas 5
nuevas para la extension en `supabase/dev-tools/prueba_active_request_fare.sql`: una solicitud
vieja sigue leyendose con el valor en nulo, una encomienda trae su desglose completo, la carga
detallada sigue siendo consultable aparte, otro pasajero no ve nada ajeno, y sin sesion no se
puede leer nada.

**Lo que se vio en pantalla y no estaba en el plan: la barra de pestanas del emulador no
respondia donde se esperaba.** Costo varias capturas en la sesion darse cuenta de que las
coordenadas visuales del emulador no correspondian una a una con los pixeles reales de la
captura. Se resolvio leyendo la jerarquia de la interfaz con `uiautomator dump` en lugar de
adivinar por coordenadas, que es lo mas fiable y lo que deberia usarse desde ahora para
cualquier prueba en el emulador que necesite tocar un punto exacto.

---

### Correccion D233: la tarifa rural en los dos sentidos (2026-08-26)

**Correccion de un error del asistente**, no un fallo del sistema, encontrado por el usuario
probando la aplicacion de verdad -no en el emulador de esta sesion, en su telefono-.
`supabase/migrations/20260826090000_rural_fare_both_directions.sql`.

**El reporte, con sus palabras:** "si tengo un viaje del parque a la vereda manzanares, el
costo es de 12000, pero si el viaje se invierte de manzanares al parque, cuesta 4000". Se
revizo el codigo y se confirmo: `quote_fare` nunca miraba el origen, solo el destino.

**La correccion.** Nueva funcion auxiliar `rural_fare_for_point`, que extrae la logica de D230
-el lugar exacto si tiene `place_id`, si no el mas cercano dentro del radio- para poder
aplicarla dos veces sin repetir el codigo: una al origen, otra al destino. Despues:

- ninguno de los dos es rural -> tarifa urbana, como siempre
- uno de los dos es rural -> esa es la tarifa, sea origen o destino
- los dos son rurales y distintos -> **gana el mas caro** (decision del usuario, 2026-08-26:
  no hay tarifa de la empresa para un trayecto entre dos veredas, y cobrar de menos seria peor)

**`quote_fare` cambio de firma**: ahora recibe los cuatro datos del origen, no solo los del
destino. `request_ride` ya los tenia en sus propios parametros; solo hubo que pasarselos.

**D219 se volvio simetrico.** Antes solo el destino sin lugar y lejos rebotaba. Ahora el origen
puede ser una vereda de verdad -es justo el caso que este arreglo hace posible, recoger a
alguien fuera del pueblo-, asi que la misma comprobacion se aplica a los dos, con codigos
distintos: `ORIGIN_NOT_PRICED` y `DESTINATION_NOT_PRICED`, para que el mensaje no le diga "el
destino" a quien penso en el punto de recogida.

**Consecuencia en el cliente que hay que saber**: `quote_fare` ahora necesita el origen. La
pantalla del resumen ya podia mostrarse sin ubicacion conocida (D137, "Continuar sin
ubicacion"), y hasta ahora igual calculaba un precio porque el origen no le importaba a la
formula. Sin origen, ya no hay valor que mostrar: mostrar un precio sin saber de donde sale
seria volver a suponer que es urbano, que es justo el error que se corrigio. `useFareQuote`
gano un tercer estado -`pending: 'origin'`, junto al ya existente `'cargo'`- y `FareRow` dice
"Necesitamos saber de dónde sales para ver el valor" en vez de girar para siempre.

**158 comprobaciones automaticas, todas en verde**, repartidas en los cinco archivos del
bloque. `prueba_calculo_tarifa.sql` crecio de 54 a 61: nueve nuevas prueban el viaje al reves
cobrando lo mismo, el caso de dos rurales distintos ganando el mas caro, y `ORIGIN_NOT_PRICED`
con una chincheta lejos como origen.

**Un tropiezo real al escribir las pruebas, y vale la pena dejarlo escrito.** Al correr
`prueba_calculo_tarifa.sql` salieron **23 comprobaciones en rojo de golpe**, todas devolviendo
10.800 -Alto del Rio- donde debian devolver 4.000. La causa: el archivo se escribio cuando
`rural_fares` estaba vacia, y usaba "el parque" como coordenada suelta, sin `place_id`. Desde
que se cargaron los 28 destinos rurales reales de esta misma sesion, Alto del Rio quedo a 1.432
m del parque, dentro del radio de D230, y esa coordenada suelta empezo a pegarsele a un rural
de verdad. **La aplicacion real nunca comete este error** -cuando el pasajero elige un lugar de
la lista, el `place_id` siempre viaja-, asi que el fallo era del archivo de pruebas, no del
codigo. Se corrigio apagando todas las tarifas rurales reales al principio de la transaccion de
prueba, que de todos modos se revierte al final: la produccion nunca se entera, y la prueba deja
de depender de que ningun destino rural futuro caiga cerca del parque.

**Y un segundo hallazgo, mas pequeno, de la misma corrida:** una comprobacion (D230, "apagar el
mas cercano deja el punto sin precio") tenia la expectativa equivocada desde que se escribio, y
no fue esta correccion quien lo rompio: los dos lugares sinteticos de prueba estan a 1,5 km
entre si y el radio de prueba es 2 km, asi que apagar uno **siempre** deja al otro alcanzable.
Se corrigio la comprobacion para probar lo que de verdad pasa -cae al siguiente que siga
activo- y se anadio una nueva que apaga los dos y esa si prueba "sin precio".

**Verificado en el emulador, con los datos reales, no solo con datos sinteticos:**
Parque -> Vereda Manzanares y Vereda Manzanares -> Parque, los dos $12.000, el ejemplo exacto
del reporte del usuario. Con la ruta real de Mapbox dibujada, 4,3 km y 11 minutos.

---

### Correccion D234: la busqueda del punto mas cercano vuelve a comparar contra TODOS los lugares (2026-08-26)

**Segunda correccion de un error del asistente en el mismo dia**, tambien encontrada por el
usuario probando de verdad -esta vez en la tablet y en el emulador, no solo en el telefono-.
`supabase/migrations/20260826100000_rural_snap_compares_all_places.sql`.

**El reporte, con capturas de las dos.** En la tablet, un origen de "Tu ubicacion actual" a
133,6 km del parque -el GPS real, lejos de Amalfi- daba "Ocurrio un error inesperado". En el
emulador, el mismo origen a 800 m y a 1,4 km del parque -dentro del pueblo- cobraba **$10.800
Tarifa de Alto del Rio** y **$10.800 Tarifa de La vibora** en dos pruebas distintas, en vez de
los $4.000 urbanos. El mismo origen elegido de la lista -Estacion de bomberos, El callejon- daba
bien, $4.000.

**La causa, encontrada leyendo el codigo, no adivinada.** D230 (`20260826053000`) ya habia
resuelto exactamente este problema, pero para el destino solamente: "gana el punto nombrado mas
cercano, urbano o rural", comparando `quote_fare` contra TODOS los lugares activos con un
`left join` a `rural_fares`. D233, al reescribir esa logica en una funcion compartida
(`rural_fare_for_point`) para poder aplicarla al origen y al destino, la escribio con un
`join` -no `left join`- contra `rural_fares`: buscaba el rural mas cercano dentro del radio
**sin comparar nunca contra los urbanos**. Deshizo D230 sin que nadie se diera cuenta, porque
todas las pruebas de D233 usaban lugares elegidos de la lista (`place_id`), que no pasan por esa
busqueda. Solo "Tu ubicacion actual" -la unica forma real de mandar una coordenada suelta- lo
delataba.

**La correccion.** Se devuelve el `left join` de D230 dentro de `rural_fare_for_point`: se busca
el lugar activo mas cercano entre TODOS dentro del radio, y solo si ESE lugar tiene tarifa
rural se cobra. Que el mas cercano sea urbano -o un rural sin tarifa activa- es la respuesta
correcta, "esto no es rural", no un fallo.

**Un segundo hallazgo salio al correr las pruebas, y no es un error nuevo, es uno que ya estaba
mal desde que se escribio.** La comprobacion 57 de `prueba_calculo_tarifa.sql` esperaba que
apagar la tarifa del lugar sintetico mas cercano hiciera que el punto "cayera" al siguiente
rural que le siguiera activo. Esa nunca fue la regla que D230 escribio: D230 dice "gana el punto
nombrado mas cercano, urbano o rural", sin condicion de que tenga tarifa activa. Si el mas
cercano se queda sin tarifa, eso ES urbano desde su perspectiva, y entonces decide D219 -la
distancia al centro del pueblo-, no una cascada a un segundo lugar rural. El comportamiento que
la prueba 57 esperaba era, sin que nadie lo hubiera decidido asi, un efecto secundario de la
misma regresion de D233: buscar solo entre rurales activos hacia parecer que habia una cascada.
Se corrigio la expectativa de la prueba -ahora espera `DESTINATION_NOT_PRICED`, coherente con
D219-, no el codigo del servidor.

**Tambien se agrego una comprobacion nueva, la 62**, que reproduce el reporte del usuario
directamente: una coordenada en el parque mismo, sin `place_id`, con un lugar rural sintetico a
1,5 km -dentro del radio-, y confirma que gana el parque, urbano, $4.000.

**Y se cerro el hueco del mensaje generico.** `ORIGIN_NOT_PRICED`, el codigo nuevo de D233, no
tenia traduccion en `src/features/ride/errors.ts`: por eso la tablet, con un origen a 133,6 km,
mostraba "Ocurrio un error inesperado" en vez de "Ese punto de recogida no tiene tarifa. Elige
uno de la lista de lugares". Se agrego junto a `DESTINATION_NOT_PRICED`, que ya lo tenia.

**Las 159 comprobaciones automaticas, todas en verde**: los 62 de `prueba_calculo_tarifa.sql`
-61 mas la nueva 62, con la 57 corregida- y las 97 de los otros cuatro archivos, sin cambios.

**Verificado en vivo en el emulador, con el escenario exacto que reporto el usuario**: "Tu
ubicacion actual" -> "El parque", 1,4 km. Antes: $10.800, Tarifa de La vibora. Ahora: $4.000,
sin referencia.

---

### Lo que se hizo: paso 7, historial y recaudo del conductor (2026-08-26)

**Dos de los trece requisitos originales que faltaban por cerrar.** El historial del conductor
(Fase 16) ya existia y solo le faltaba el valor; el recaudo no existia ni como pantalla ni como
funcion. `supabase/migrations/20260826110000_driver_history_and_earnings.sql`,
`supabase/dev-tools/prueba_recaudo.sql` (12 comprobaciones).

**El historial.** `list_driver_history` y `get_driver_job` ganaron `service_type`,
`parcel_description` y las columnas de tarifa -`fare_amount`, `fare_is_rural`,
`fare_reference`, y en el detalle ademas `fare_trip_amount`/`fare_cargo_amount`/`fare_is_night`-.
Postgres no deja usar `create or replace` para anadir columnas a un `returns table` -"cannot
change return type of existing function", 42P13-, asi que las dos se borraron y se crearon de
nuevo, mismo patron que D233 con `quote_fare`.

**El recaudo, D235.** Decidido con el usuario: **pestana propia**, no una tarjeta encima de
"Servicios" -esa pestana mezcla rechazos y expiraciones sin valor, y el recaudo es dinero, no
registro operativo-. `list_driver_earnings(p_period, p_from_date, p_to_date)`, nueva, consulta
`rides.status = 'completed'` directo -no reutiliza `list_driver_history`-, y **el periodo lo
decide el servidor con su propio reloj (D154)**: `'today'`/`'week'` se calculan con
`fare_timezone` y medianoche local, sin que el telefono mande ningun instante. La pantalla de
esta version ofrece "Hoy" y "Esta semana"; el servidor ya acepta `'custom'` con fechas -no
timestamptz, por el mismo motivo de D154- para cuando haga falta un rango, que no se construyo
por no hacer falta todavia.

**Cliente:** `src/features/history/history-service.ts` extendido (`DriverJob`/`DriverJobDetail`
con los campos nuevos); `src/app/driver/(tabs)/history.tsx` con el valor y el tipo de servicio
en cada tarjeta; `src/app/driver/job/[id].tsx` con una tarjeta "EL VALOR" nueva, que reusa
`fetchRequestCargo` -la misma funcion que ya usaba el resumen del pasajero- para listar la carga
de una encomienda. Modulo nuevo `src/features/earnings/` (`types.ts`, `earnings-service.ts`,
`use-earnings.ts`, `period-toggle.tsx`) y pantalla nueva `src/app/driver/(tabs)/earnings.tsx`,
registrada como cuarta pestana en `src/app/driver/(tabs)/_layout.tsx`.

**Un detalle de React que costo una vuelta.** El primer `useEarnings` ponia
`setLoading(true)` con un `setTimeout` al principio del efecto que reacciona al cambio de
periodo, y el lint lo rechazo -`react-hooks/set-state-in-effect`-. Se corrigio con el mismo
patron que ya usa `use-fare-quote`: guardar el periodo anterior y limpiar en el render mismo en
cuanto cambia, no dentro del efecto.

**12 comprobaciones nuevas, todas en verde**, y un hallazgo real durante la escritura de las
pruebas: la comprobacion que verificaba "cada conductor ve solo lo suyo" fallaba con
`auth.uid()` nulo. La causa: buscaba al otro conductor en una subconsulta ejecutada DESPUES de
`set local role authenticated`, y `drivers` tiene RLS -sin `auth.uid()` puesto todavia, la
subconsulta veia cero filas y `sub` quedaba nulo en el reclamo JWT-. Se corrigio buscandolo
ANTES del cambio de rol, con el privilegio con el que corre el montaje. Las otras
comprobaciones tambien se protegieron contra los servicios reales que esta cuenta de prueba
acumula de sesiones anteriores, filtrando por los identificadores propios de la prueba -misma
leccion que D233/D234 con `rural_fares`-.

**Verificado en vivo en el emulador**, con dos servicios completados reales insertados para la
prueba -uno de pasajero urbano, uno de encomienda con carga-, ademas de los servicios antiguos
de antes de D217 que ya existian en la cuenta de prueba:

- El historial muestra "$4.000" en la tarjeta del pasajero y "$4.000" en la de la encomienda
  -con "Encomienda" en vez de "1 pasajero"-, y los servicios de antes de D217 no muestran ningun
  valor, como corresponde
- El detalle del pasajero trae la tarjeta "EL VALOR" con el monto; el de la encomienda ademas
  trae "Caja pequeña" debajo, la carga real de esa solicitud
- La pestana "Recaudo", en "Hoy", suma **$8.000** -los dos servicios de hoy- y lista cada uno
  con su ruta y su valor; en "Esta semana" suma lo mismo y ademas lista los dos servicios
  viejos con **"Sin valor"**, sin inventarles un numero

**Un problema de entorno, no de la aplicacion, aparecio a mitad de la verificacion.** El
emulador llevaba mucho rato pausado -coincidiendo con la interrupcion de la sesion por limite de
uso- y su canal grafico quedo trabado: `screencap` y `uiautomator dump` se colgaban
indefinidamente, y logcat confirmo la causa real, `SurfaceFlinger: Faking VSYNC due to driver
stall`, un atasco del driver de GPU del host que sobrevivio incluso a reiniciar el emulador.
Se resolvio relanzandolo con renderizado por software (`-gpu swiftshader_indirect`), que evita
el paso por el GPU del host. Queda como leccion para esta maquina: si `screencap` se cuelga
despues de una pausa larga, no es la app, es el emulador, y la salida es relanzarlo con
`-gpu swiftshader_indirect`.

**171 comprobaciones automaticas en verde en total** (159 de antes, mas las 12 de
`prueba_recaudo.sql`). `npm run typecheck`, `npm run lint` y `npm run format:check`, los tres
en 0.

---

### Lo que se hizo: paso 8, regresion de las fases 11 a 19 (2026-08-26)

**Dos partes: los once archivos de pruebas automaticas, y una prueba en vivo con la tablet
como pasajero y el emulador como conductor, con datos reales de principio a fin, no
sinteticos.**

**Automatica, primero.** Los once `.sql` de `supabase/dev-tools/` corridos de nuevo:
`prueba_tarifas`, `prueba_encomiendas`, `prueba_calculo_tarifa`, `prueba_solicitud_con_valor`,
`prueba_active_request_fare`, `prueba_recaudo` -las seis del bloque especial- y
`prueba_calificaciones`, `prueba_cancelaciones`, `prueba_detalle_historial`, `prueba_historial`,
`prueba_notificaciones` -las cinco de las fases 16 a 19-. **Las once en 0 fallando.** Cubren de
sobra las fases 16 a 19; de las fases 11 a 15 cubren lo que toca el bloque especial de verdad
-`request_ride` entero, D220 y el choque con `enforce_ride_capacity`-, pero no el ciclo
aceptar-llegar-empezar-terminar en si, que no cambio de codigo esta vez.

**Un hallazgo de `prueba_recaudo.sql` que se corrigio de paso.** El `sum(fare_amount)` de dos
comprobaciones llevaba el filtro de aislamiento -`request_id like 'ea000000%'`- solo en el
`count`, no en el `sum`: al insertar datos de verificacion reales para el paso 7 (mas abajo en
esta seccion), el total salio inflado. Se corrigio aplicando el mismo filtro a las dos
agregaciones. Mismo tipo de leccion que D233/D234 con `rural_fares`, aplicada aqui al recaudo.

**En vivo, con la tablet de verdad como pasajero -Jhan Roldan- y el emulador como conductor
-conductor.prueba-, sin datos sinteticos.** Un hallazgo aparte primero: al abrir la app en la
tablet aparecio un aviso de React, *"Can't perform a React state update on a component that
hasn't mounted yet"*. Se investigo -no se ignoro- y no volvio a aparecer tras recargar; no se
pudo achacar a un cambio de esta sesion ni reproducir de nuevo, asi que queda anotado y sin
cerrar, no como regresion confirmada.

Con un viaje real -Alto de la Virgen a El parque, elegidos de la lista para no depender del GPS
real de la tablet, que esta lejos de Amalfi-, se verifico en vivo, en este orden:

1. **La solicitud y la tarifa**: `$4.000`, calculado bien, con los datos reales de la tablet
2. **La oferta**: le llego al conductor con la distancia, el mapa y el valor correctos, y con
   los 20 segundos de la regla R2 cumpliendose de verdad -varias ofertas expiraron exactamente a
   los 20 segundos, cronometradas contra el reloj del servidor, no supuestas-
3. **`accept_ride_offer`**: acepto bien, devolvio un `ride_id` real
4. **`start_driving_to_pickup`**: paso a "en camino" sin error
5. **La regla R5** -no dejar confirmar la llegada si el conductor no esta cerca de verdad-
   **rechazo correctamente** una confirmacion de llegada estando a 749 m del punto de recogida,
   con el mensaje de siempre

**Lo que NO se pudo cerrar en vivo, y por que.** Los ultimos tres pasos -llegar, empezar,
terminar- necesitaban que la ubicacion en vivo del conductor de prueba llegara de verdad a
`driver_locations` desde cerca del punto de recogida. En este emulador, tras el reinicio con
renderizado por software del paso 7, ni `emu geo fix` ni la app "Fake GPS" -que si sirvio para
la ubicacion inicial- lograron que la app empujara una ubicacion nueva a tiempo: la distancia
medida se quedo clavada en 749 m durante varios intentos, incluso tras mover el marcador.
**Es un problema de este entorno de prueba, no del codigo**: el ciclo completo
aceptar-llegar-empezar-terminar es exactamente el mismo que las fases 12 a 15 ya tenian antes
del bloque especial, nadie lo toco esta vez, y **si esta cubierto, con distancias sinteticas
controladas, por `prueba_solicitud_con_valor.sql`** y por las pruebas de las fases 12 a 15 que
quedaron comiteadas en su momento.

**Tambien goteo, sin buscarlo, una confirmacion util:** el error generico de la tablet de la
correccion D234 -"Ocurrio un error inesperado" para un origen sin tarifa- se volvio a ver, esta
vez ya corregido: el mensaje fue "Ese punto de recogida no tiene tarifa. Elige uno de la lista
de lugares", en la tablet real, con el GPS real de la tablet -a 133 km de Amalfi- como origen.

**Veredicto: sin regresion.** Las once pruebas automaticas en verde, y en vivo se confirmo la
solicitud, la tarifa, la oferta con sus tiempos, la aceptacion y el rechazo correcto por
distancia. Lo unico que falto cerrar en vivo -el tramo final del ciclo- es una limitacion de
este dispositivo de prueba en este momento, no un cambio de comportamiento, y esta cubierto por
otras pruebas.

---

## 15.22 FASE 20: PANEL ADMINISTRATIVO (EN CURSO)

**EMPEZADA EL 2026-08-26.** Es la primera fase que no construye nada dentro de la aplicacion
movil: el panel es un proyecto Next.js aparte, y el trabajo aqui es tanto de la aplicacion web
nueva como de no romper la que ya existe.

### Los once pasos acordados con el usuario

El orden sale de la seccion 5 -lo que el panel tiene que hacer- mas lo que las fases 18 y 19
dejaron esperando a que existiera panel (D204, D215, D216) y lo que el bloque especial dejo por
gestionar (tarifas, destinos, tipos de carga, recaudo).

| # | Paso | Estado |
|---|---|---|
| 1 | Proyecto Next.js y acceso administrativo | **HECHO Y VERIFICADO** |
| 2 | Servidor: auditoria y bloqueo de cuentas | **HECHO Y VERIFICADO** |
| 3 | Tablero con los servicios en curso | **HECHO Y VERIFICADO** |
| 4a | Gestion de los conductores que ya existen | **HECHO Y VERIFICADO**, pantallas incluidas |
| 4b | Alta de un conductor nuevo | **HECHO Y VERIFICADO**, con inicio de sesion real |
| 4c | Documentos de conductores y vehiculos | **HECHO Y VERIFICADO**, subida real incluida |
| 5 | Gestion de vehiculos y asignacion conductor-vehiculo | **HECHO Y VERIFICADO**, pantallas incluidas |
| — | **DOBLE TURNO** (fuera del plan, pedido el 2026-08-27) | **HECHO Y VERIFICADO EN SERVIDOR** |
| 6a | Lugares y tarifas rurales (con D229) | **HECHO Y VERIFICADO**, pantallas incluidas |
| 6b | Tarifas urbanas, tipos de carga y parametros | **HECHO Y VERIFICADO**, pantallas incluidas |
| 7 | Listado de pasajeros con bloqueo | **HECHO Y VERIFICADO**, pantallas incluidas |
| 8 | Listado e inspeccion de servicios, con linea de tiempo | **HECHO Y VERIFICADO**, pantallas incluidas |
| 9 | Asignacion manual de conductor a una solicitud (D7) | Pendiente |
| 10 | Reportes y calificaciones (D204) | Pendiente |
| 11 | R10 y bloqueo del conductor a mitad de operacion (D215, D216) | Pendiente |

### Lo que se hizo: paso 1, el proyecto y el acceso (2026-08-26)

**Nueva implementacion.** Carpeta `admin/`, dentro del mismo repositorio que la aplicacion movil
(D236). Next.js 16.3.3, React 19.2.8, Tailwind 4, TypeScript.

**Antes de escribir una linea se comprobo el estado real contra el servidor y contra git**, y
las dos comprobaciones corrigieron lo que decia este documento:

- **La cabecera decia "SIN COMITEAR" doce archivos del bloque especial.** Es falso desde que el
  usuario comiteo: `git status` sale limpio y el ultimo commit es `611e0e8`, "Fase de mejoras
  terminada". La nota estaba fechada el 25 y el trabajo siguio el 26
- **NO EXISTIA NINGUN ADMINISTRADOR.** El rol `admin`, `is_admin()` y todas sus politicas RLS
  existen desde la Fase 5, pero la tabla tenia cuatro pasajeros, dos conductores y **cero
  administradores**. O sea que ninguna de esas politicas se habia ejecutado nunca de verdad

**El primer administrador, y por que costo mas que un UPDATE.**
`supabase/dev-tools/seed_admin.sql`, con la maniobra que ya avisaba la regla 1 de las aprendidas
en la Fase 6: `profiles_protect_columns` revierte cualquier cambio de rol incluso ejecutando
como `postgres`, porque `is_admin()` depende de `auth.uid()` y en un script no hay sesion. El
disparador es BEFORE UPDATE y no cubre INSERT, asi que **hay que sustituir la fila**, no
actualizarla. Es el mismo patron de `seed_test_driver.sql`, con la leccion de E28 incluida: las
cuatro columnas de token a cadena vacia y no a nulo, o la cuenta no puede iniciar sesion.
Cuenta: `admin.prueba@motomoto-qa.co` / `Admin.2026`, "Administrador de prueba".

**La guardia de acceso (D238).** Vive en un solo archivo, `admin/src/proxy.ts`, y no en cada
pantalla: mismo criterio que D70 en la aplicacion movil, para que una pantalla nueva quede
protegida sin que haya que acordarse. Y mismo criterio que D72: **decide que se dibuja, no que
se permite.** La autorizacion de verdad siguen siendo las politicas RLS de la Fase 5, que ya
exigen `is_admin()`; si alguien se saltara esta guardia, la base de datos seguiria sin
devolverle una sola fila.

Dos detalles que no son adorno:

- **`getUser()` y no `getSession()`.** El segundo se cree lo que diga la cookie, que el
  navegador puede haber tocado; el primero pregunta al servidor de Supabase. Se comprobo
  mandando una cookie falsificada a mano: responde 307 igual que sin sesion
- **A quien tiene sesion pero no es administrador se le cierra la sesion antes de devolverlo al
  acceso.** Sin eso quedaria dando vueltas: con sesion abierta, sin permiso y sin forma de
  entrar con otra cuenta

**El mensaje de error del acceso es el mismo para una contrasena equivocada y para una cuenta
que existe pero no es administradora** (D239). Decir "esa cuenta no tiene permiso" confirmaria
que el correo existe, que es el mismo criterio de D74 en la recuperacion de contrasena.

**Lo que se hizo para no romper la aplicacion movil.** El panel vive dentro de la misma carpeta,
asi que la configuracion del raiz lo veia. Se aislo igual que `example/` en D42: `admin` excluido
en `tsconfig.json`, en `eslint.config.js` y en `.prettierignore`, y las salidas de Next anadidas
al `.gitignore`. **Se comprobo que hacia falta**: antes del cambio, `npm run format:check` del
raiz fallaba con doce archivos del panel.

**Y se comprobo que Metro sigue construyendo la aplicacion movil**, que era el riesgo de verdad
de meter un `node_modules` de 364 paquetes dentro del proyecto. No se dio por bueno que
arrancara: **se pidio el bundle entero de Android y se midio**. HTTP 200, 6.590.930 bytes, cero
colisiones de modulos. **Por eso NO se anadio `metro.config.js`**: no hace falta, y la regla 4
dice que no se deja puesto un cambio hecho sobre una hipotesis que no se confirmo.

**Estilos: Tailwind (D237).** Se decidio con el usuario. El panel es casi todo tablas,
formularios y filtros, y con CSS a mano las diez pantallas acaban descuadradas entre si. **La
paleta no se reinventa**: `admin/src/app/globals.css` declara los mismos nombres semanticos y los
mismos valores crudos de `src/theme/colors.ts` (D47), incluida la nota del hallazgo H14 sobre el
rojo. **El panel no implementa tema oscuro**, a diferencia de la aplicacion: se usa a plena luz
en una oficina, y dos temas duplicarian el trabajo de cada pantalla.

**Tres tropiezos, los tres diagnosticados en vez de parcheados:**

1. **El lint rechazo el formulario de acceso** con `react-hooks/set-state-in-effect`, el mismo
   error que salio en `useEarnings` en el paso 7 del bloque especial. **No se silencio la regla**
   (regla 6 de las aprendidas): el mensaje de "sin permiso" que manda el proxy por la URL se
   **deriva en el render**, y en cuanto el usuario intenta entrar manda el resultado de su
   intento
2. **Next elegia mal la raiz del proyecto.** Lo avisaba al arrancar: con dos `package-lock.json`
   -el del movil y el del panel- escogia la carpeta de arriba, y habria pasado a vigilar el
   proyecto movil entero. Corregido fijando `turbopack.root`
3. **Next 16 deprecio `middleware.ts` en favor de `proxy.ts`.** Salio en el log al arrancar. Se
   migro el archivo y la funcion exportada. **Despues del cambio el servidor seguia dando un
   error de "falta el export" aunque el archivo lo tenia**, y la causa no era el codigo sino la
   cache de Turbopack: borrando `.next` el arranque salio limpio. Se comprobo leyendo el log
   completo, no suponiendo

**Verificado, y separado por quien lo verifico:**

| Que | Como | Resultado |
|---|---|---|
| El raiz no se rompe | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| La aplicacion movil sigue compilando | Bundle Android real pedido a Metro | 200, 6,59 MB, sin colisiones |
| Calidad del panel | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| El administrador existe | Consulta al servidor tras la semilla | rol `admin`, activo, tokens no nulos |
| Sin sesion no se entra | `GET /` | 307 a `/acceso` |
| Una cookie falsificada tampoco | `GET /` con cookie inventada | 307 a `/acceso` |
| **Entrar de verdad como administrador** | **El usuario, en su navegador** | **Funciono**, y el log del servidor lo confirma con `GET / 200` |
| **Que el acceso RECHACE a un pasajero** | **El usuario, en su navegador** | **Rechazado**, con el mensaje comun de D239 |

**La prueba de romper del paso 1 esta hecha, y se comprobo que valia.** El usuario entro con la
cuenta del pasajero de prueba y el panel la rechazo. Antes de darlo por bueno **se pregunto al
servidor por el estado de esa cuenta**, porque un rechazo puede salir en verde por el motivo
equivocado: si la cuenta estuviera bloqueada, sin confirmar o sin contrasena, el panel la habria
rechazado igual y no se habria probado nada. Esta **activa, con el correo confirmado y con
contrasena**, a nombre de Ana Gomez y con rol `passenger`. Es decir que **lo unico que la separa
del administrador es el rol**, que es exactamente lo que la guardia tenia que mirar.

Es la misma leccion que la pareja de comprobaciones 12 y 13 de `prueba_encomiendas.sql`, donde
una prueba estuvo en verde porque el control que debia medirse ni siquiera llegaba a ejecutarse.

**El paso 1 queda cerrado.** El asistente no introduce contrasenas en formularios, asi que las
dos pruebas de sesion real —entrar y ser rechazado— las hizo el usuario.

---

### Lo que se hizo: paso 2, la auditoria y el bloqueo de cuentas (2026-08-26)

**Nueva implementacion.** `supabase/migrations/20260826170000_admin_audit_and_account_status.sql`
y su correccion `20260826180000_fix_admin_action_flag_requires_admin.sql`, mas
`supabase/dev-tools/prueba_auditoria.sql` (23 comprobaciones).

**La auditoria del paso 2 destapo lo mismo que el paso 1 con los administradores:** una pieza
declarada que nunca habia existido de verdad. `admin_audit_logs` esta desde la Fase 5, con sus
dos indices y su politica de lectura, y al medirla contra el servidor tenia **cero filas**;
ninguna migracion del proyecto escribia en ella. Lo mismo `reports`, cero filas. `notifications`
si tenia 20, o sea que la Fase 19 esta viva.

**Y detras habia un hueco peor.** `profiles_update_admin` permitia a un administrador cambiar el
estado de cualquier cuenta con un UPDATE directo, asi que el panel **podria bloquear a alguien
sin dejar rastro**, y la auditoria seguiria en cero. No hacia falta ni el panel: basta una
sesion de administrador y una llamada a la API a mano.

**D240, decidido con el usuario:** las acciones administrativas van por **funciones que auditan
en la misma transaccion**. No es una convencion que haya que recordar: si la auditoria falla, el
cambio tampoco pasa. Misma idea con la que el bloque especial garantizo la formula de la tarifa
con restricciones en vez de con codigo.

Lo que entro:

- **`log_admin_action`**, el unico camino de escritura de la auditoria. Es `security definer`
  porque la tabla **no tiene politica de INSERT para nadie, ni para el administrador**: si el
  panel pudiera insertar filas de auditoria, tambien podria inventarlas
- **`admin_set_account_status`**, bloquear y desbloquear. Es la accion transversal de los pasos
  4 y 7. **Un administrador no puede bloquearse a si mismo**, porque `is_admin()` exige cuenta
  activa y seria perder el panel sin vuelta atras desde el propio panel
- **El disparador `protect_profile_columns` deja de eximir al administrador.** Ahora un UPDATE
  directo del rol o del estado se revierte tambien para el, y el unico camino es la funcion

**UN ERROR DEL ASISTENTE, Y LO ENCONTRO LA PRUEBA DE ROMPER, NO LA REVISION DEL CODIGO.** Al
quitarle al disparador la exencion de `is_admin()` se puso en su lugar una marca de transaccion
(`motomoto.admin_action`), **y la marca quedo como UNICA condicion**. Resultado: cualquiera que
la pusiera se saltaba la proteccion entera, y no solo el estado —tambien el rol—. **Un pasajero
podia hacerse administrador.** La version de la Fase 5 era menos estricta con los
administradores pero mas segura con todo el mundo: **el cambio empeoro la seguridad en vez de
mejorarla**.

Lo cazo la **comprobacion 17**, escrita a proposito como "el intento mas fino": ponerse la marca
a mano siendo pasajero. Esperaba `active` y obtuvo `blocked`. La correccion es una sola —el
disparador exige **las dos cosas**, la marca Y `is_admin()`— y se le anadio la **comprobacion 23**,
que prueba la mitad peor del mismo agujero: con el estado se queda fuera alguien, con el rol se
queda dentro del panel cualquiera.

**La leccion, y vale mas que la correccion:** al apretar una tuerca se puede aflojar otra. La
proteccion vieja y la nueva cubrian cosas distintas, y sustituir una por otra dejo un hueco que
ninguna de las dos tenia por separado. **La marca no es una llave: es la senal de que la accion
viene por el camino auditado. La autorizacion la sigue dando `is_admin()`.**

**23 comprobaciones, todas en verde.** Once prueban que funciona; doce prueban que **no se puede
rodear**: un pasajero llamando a las funciones, un administrador bloqueado, un UPDATE directo,
un INSERT inventado en la auditoria, un DELETE de lo ya registrado y los dos intentos de la
marca. La 21 y la 22 van en pareja a proposito: sin la 21 en verde —un segundo administrador
activo SI puede— la 22 podria estar en verde porque la funcion no funciona en absoluto.

**Regresion de los doce archivos: 280 comprobaciones, 0 fallando.** Se corrio entera porque el
disparador que se toco es de la Fase 5 y lo dispara cualquier actualizacion de perfil de la
aplicacion movil.

**`prueba_notificaciones.sql` salio en rojo, y NO era regresion de este paso.** Se diagnostico
en vez de suponerlo: mi cambio solo toca `protect_profile_columns`, por donde las notificaciones
no pasan. Eran **dos premisas que el mundo real habia invalidado**, las dos por las pruebas en
vivo de la Fase 19 y del bloque especial:

- La comprobacion 4 contaba **todas** las notificaciones `new_offer` del conductor, sin filtrar
  por la oferta de la prueba. Habia 17 reales acumuladas del 25 y el 26, asi que salia 2 donde
  debia salir 1. Se filtro por `data->>'offerId'`, que es la clave que la funcion guarda de
  verdad —comprobado leyendo una fila real, no suponiendo el nombre—
- La comprobacion 5 daba por hecho que **el segundo conductor no tenia `push_token`**. Dejo de
  ser cierto: los dos conductores de prueba ya lo tienen, porque se usaron en aparatos reales.
  Ahora la prueba **se lo quita a si misma** dentro de la transaccion que se deshace. Una premisa
  heredada del mundo real no es una premisa

Es la misma leccion que el `sum` de `prueba_recaudo.sql` en el paso 8 del bloque especial, y ya
van tres veces: **una prueba que no controla sus datos se pone roja sin que nada este roto.**

**Tipos regenerados** con `admin_set_account_status` y `log_admin_action` dentro.
`npm run typecheck`, `npm run lint` y `npm run format:check` de la aplicacion movil, los tres
en 0.

**Lo que NO entro en este paso, y por que.** La bandeja de reportes (D204) necesita pantalla y va
en el paso 10; la tabla ya existe y no le falta nada del servidor. Las demas acciones
administrativas —aprobar un conductor, cambiar una tarifa, asignar un vehiculo— se construyen en
su paso y **ya tienen la base**: una llamada a `log_admin_action` dentro de su propia funcion.

---

### Lo que se hizo: paso 3, el tablero de servicios en curso (2026-08-26)

**Nueva implementacion.** `supabase/migrations/20260826200000_admin_active_services.sql`,
`supabase/dev-tools/prueba_tablero.sql` (11 comprobaciones), las dos herramientas
`seed_active_service.sql` / `remove_active_service.sql`, y en el panel el modulo
`admin/src/features/dashboard/` (cinco archivos) mas la pagina de inicio, que deja de ser un
marcador de posicion.

**`admin_list_active_services`**, una funcion de lectura. En curso son los tres estados vivos de
`ride_request_status`: `searching`, `assigned` e `in_progress`. Lo terminado, cancelado y
caducado es del listado de servicios del paso 8.

**Se hace con funcion y no con consultas desde el navegador** aunque la RLS ya lo permitiria: por
lo mismo que el historial de la Fase 16, la forma del dato se decide en un sitio, el panel no
tiene que saber que un servicio vive repartido entre `ride_requests` y `rides`, y se evitan cinco
consultas anidadas por fila.

**Pero es `security invoker`, al reves que las funciones que escriben**, y esa es la decision
que mas importa de este paso (D242). Con `security definer` un pasajero que llamara a la funcion
—esta concedida a `authenticated`— **habria visto el tablero entero de la empresa**. Siendo
invoker, las politicas se aplican con su identidad y ve lo suyo. **Las comprobaciones 9 y 10 lo
miden en pareja**: la 9 confirma que no ve el servicio de otro y la 10 que SI ve el suyo, porque
sin la segunda la primera podria estar en verde por devolver cero a todo el mundo.

Tres datos que la funcion calcula y que no estaban en ninguna tabla:

- **`waiting_seconds`**, cuanto lleva vivo el servicio. Se calcula en el servidor por D154: el
  reloj del ordenador que abre el panel lo cambia cualquiera. **`searching` es el estado que mas
  importa del tablero** aunque parezca el menos interesante, porque un servicio que lleva rato
  sin encontrar motorraton es el problema que la empresa quiere ver antes de que el pasajero se
  canse
- **`pending_offers`**, cuantos conductores tienen la oferta delante ahora mismo. Distingue "no
  hay nadie cerca" de "la han visto cinco y ninguno la coge", que son dos problemas distintos
- **`driver_location_age_seconds`**, hace cuanto se supo donde estaba el conductor. Un tablero
  que muestra un servicio en marcha con una posicion de hace veinte minutos esta mintiendo, y es
  justo la alerta de R10 que espera el paso 11

**El `left join` a `rides` excluye los cancelados**, y no es un detalle: un servicio puede tener
un viaje cancelado —el conductor se echo atras— y haber vuelto a `searching` esperando otro. Sin
ese filtro el tablero mostraria el conductor que ya no viene.

**En el panel**, `useActiveServices` **consulta cada diez segundos en vez de suscribirse a
tiempo real** (D243), aunque la Fase 13 ya publico `ride_requests` y `rides` en realtime. El
motivo esta escrito en el codigo: **tres de los datos que muestra —la espera, la antiguedad de la
posicion y las ofertas vivas— cambian con el paso del tiempo aunque no cambie ninguna fila**, asi
que una suscripcion no evitaria refrescar igual. Si hace falta inmediatez, se anade encima sin
tirar esto.

**Si falla la consulta, el listado anterior se conserva** y se avisa aparte. Un corte de red no
tiene por que vaciar la pantalla que el despachador esta mirando.

**El color del estado de espera nunca es la unica senal**: va con el numero de minutos y con su
icono. Es D202 de la aplicacion movil aplicado al panel, por el mismo motivo del hallazgo H14.

**Tres tropiezos, los tres diagnosticados contra el servidor y no adivinados:**

1. **La migracion no aplicaba y el error no decia por que.** Se ejecuto el cuerpo como consulta
   suelta para que Postgres diera el mensaje real: **`ride_offers` no tiene columna `status`**,
   tiene `response`, y su enum es `ride_offer_response`. Una oferta no tiene estado propio, tiene
   la respuesta que dio el conductor
2. **Dos errores de montaje de la prueba, los dos por restricciones vivas del proyecto.** La
   regla R6 (`rr_one_active_per_passenger`) no admite dos servicios activos del mismo pasajero,
   asi que hacen falta tres personas para tres servicios; y `ro_response_coherence` exige
   `responded_at` en toda respuesta distinta de `pending`, asi que una oferta caducada sin fecha
   de respuesta no entra
3. **El lint volvio a marcar `react-hooks/set-state-in-effect`**, ahora por la consulta inicial.
   Tercera vez en el proyecto, y tampoco se silencio: **la primera consulta se programa con un
   temporizador igual que las demas**, y el cuerpo del efecto solo programa

**Verificado, y separado por quien lo verifico:**

| Que | Como | Resultado |
|---|---|---|
| La funcion, contra el servidor | `prueba_tablero.sql` | **11 de 11**, tres de ellas de privacidad |
| Regresion completa | Los trece archivos de `dev-tools/` | **291 comprobaciones, 0 fallando** |
| El panel compila para produccion | `npm run build` | Compila, y el proxy queda registrado |
| Calidad del panel | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| La aplicacion movil no se rompe | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| **El tablero en pantalla** | **El usuario, en su navegador** | **Los dos servicios se ven bien** |

**Para poder mirarlo hizo falta sembrar datos**, porque al empezar el paso las 57 solicitudes de
la base estaban **todas** terminadas, canceladas o caducadas: no habia ni una viva. De ahi salen
las dos herramientas nuevas. **`seed_active_service.sql` es el unico archivo de `dev-tools/` que
deja filas**, a diferencia de los `prueba_*.sql`, y por eso viene con su archivo de limpieza;
conviene ejecutarlo al terminar, porque un servicio en `searching` deja al pasajero de prueba sin
poder pedir otro por la regla R6. Se limpio al terminar y se comprobo: cero.

---

### Lo que se hizo: paso 4a, gestion de los conductores que ya existen (2026-08-26)

**EL PASO 4 ERA TRES BLOQUES Y SE PARTIO CON EL USUARIO.** La auditoria previa lo destapo antes
de escribir nada:

| Parte del paso 4 | Estado real al auditarlo |
|---|---|
| Listar, ver y editar conductores | Todo en servidor. Faltaba pantalla |
| Bloquear y desbloquear la cuenta | **Ya hecho en el paso 2**, con auditoria |
| Aprobar y retirar la aprobacion | Faltaba la funcion auditada |
| **Dar de alta un conductor nuevo** | **Bloqueado.** Crear una cuenta de Auth no lo permite la clave publicable |
| Documentos | **No existe el bucket.** Solo hay `avatars`, y `documents` lleva cero filas desde la Fase 5 |

Se hizo **4a** y quedaron **4b** —el alta— y **4c** —los documentos— para sus propios pasos. El
motivo de partirlo esta escrito en la migracion: el alta obliga a meter la clave `service_role`
en el panel, **una clave que salta toda la RLS**, y mezclar esa decision con pantallas normales
es la forma de que pase sin discutirse.

`supabase/migrations/20260826220000_admin_driver_management.sql`,
`supabase/dev-tools/prueba_conductores.sql` (24 comprobaciones), el modulo
`admin/src/features/drivers/` (cinco archivos) y la reestructuracion de las rutas del panel.

**EL MISMO HUECO DEL PASO 2, EN OTRA TABLA.** `protect_driver_columns` empezaba por "si es
administrador, puede cambiar cualquier cosa", asi que **se podia aprobar o bloquear a un
conductor con un UPDATE directo y sin dejar rastro**, igual que pasaba con el estado de las
cuentas. Se aplico la misma correccion de D241: la marca de transaccion **mas** `is_admin()`,
nunca una sola de las dos. **Las comprobaciones 13 y 14 lo miden**, y la 14 cubre la otra mitad
de lo que ese disparador protege: que nadie se suba la calificacion a mano.

Que ese hueco apareciera dos veces en dos tablas distintas es el dato que importa: **la exencion
"si es administrador, pasa" estaba repetida en el proyecto**, y arreglarla en un sitio no la
arreglaba en el otro. Quedan por revisar las demas politicas `_all_admin` cuando lleguen sus
pasos.

**Tres funciones nuevas:**

- **`admin_list_drivers`**, lectura, `security invoker` por D242. Trae el vehiculo asignado -solo
  el vivo, `unassigned_at is null`- y **si el conductor va conduciendo ahora mismo**, que es el
  dato que decide si se le puede retirar la aprobacion. Ordena poniendo primero a los pendientes
  de aprobar, que son los que esperan una decision de la empresa
- **`admin_set_driver_approval`**, auditada. **Es distinta de bloquear la cuenta a proposito**, y
  por eso son dos funciones y no una con un parametro: bloquear la cuenta deja a la persona sin
  poder entrar en la aplicacion; retirar la aprobacion la deja entrar pero no trabajar. La
  empresa usa las dos cosas en momentos distintos
- **`admin_update_driver_contact`**, auditada. Va por funcion aunque la RLS ya permitiria el
  UPDATE directo, por D240: **el telefono que se edita aqui es el que la aplicacion le ensena al
  pasajero para llamar a su conductor**

**D244: no se retira la aprobacion a quien va conduciendo.** Es la respuesta a lo que la Fase 18
dejo pendiente en D216 —"que el administrador bloquee a un conductor a mitad de operacion"— y la
respuesta es que **no se hace a ciegas**: dejar a un pasajero dentro de un motorraton cuyo
conductor acaba de perder el permiso no arregla nada. El servidor responde
`DRIVER_HAS_ACTIVE_RIDE` y el panel apaga el boton. **Las dos cosas**: el boton apagado explica
por que no se puede, y la comprobacion del servidor es la que de verdad lo impide, porque el
estado de la pantalla puede tener diez segundos de antiguedad. Cancelar el servicio primero desde
el panel es del paso 11.

**Dos detalles de la funcion de aprobacion que no son adorno.** Retirar la aprobacion **apaga la
disponibilidad**, porque `drivers_available_only_when_approved` haria fallar la operacion entera
si no; y **la fecha de aprobacion no se borra al retirar**, porque
`drivers_approved_has_date` la exige en un solo sentido, a proposito, para conservar cuando se
aprobo por primera vez.

**En el panel**, las rutas se reorganizaron en un grupo `(panel)` —entre parentesis, asi que no
sale en la URL— con la cabecera y la navegacion en un layout comun, para que la pantalla de
acceso quede fuera. **La guardia no hubo que tocarla**: `/conductores` quedo protegida sola,
que es exactamente lo que D238 buscaba al ponerla en un solo sitio. Comprobado: responde 307.

**La lista de conductores NO se refresca sola**, al reves que el tablero. No cambia por su
cuenta: cambia cuando alguien de la empresa la cambia, y quien la cambia es quien esta mirando la
pantalla. Un temporizador solo serviria para mover el listado bajo el raton de quien esta a punto
de pulsar un boton.

**Los errores del servidor se traducen por su codigo `hint`, nunca por el texto del mensaje**
(D88). Comparar cadenas de texto para decidir que ensenar es la forma de que un dia deje de
funcionar en silencio.

**Dos errores mios en las pruebas, y el segundo es el interesante:**

1. Uso `v_row.column1` sobre un `select ... into` de un solo valor, que no existe. Error de
   escritura, corregido con una variable de texto
2. **La comprobacion 21 esperaba que un pasajero NO viera ningun conductor, y ve UNO.** Se
   investigo en vez de forzar el resultado: es `drivers_select_ride_counterpart`, politica de la
   Fase 5 que deja al pasajero ver la calificacion del conductor que lo lleva. **La equivocada
   era la expectativa, no el codigo**, igual que le paso a la 57 de `prueba_calculo_tarifa` con
   D234. Reescrita, mide algo mejor que "no ve nada": **ve solo al suyo** (21), **es justo el
   suyo** (23) y **no ve a los otros dos** (24)

Ademas, una comprobacion mal disenada por mi: la 10 intentaba aprobar al conductor ocupado para
vigilar a la 9, pero `pending` tambien es retirar la aprobacion, asi que la regla la rechazaba
con razon. Se cambio por corregirle el contacto, que si esta permitido: **entre la 8, la 9 y la
10 queda claro que el rechazo es por el viaje en marcha y no porque la funcion rechace todo lo
que toque a ese conductor.**

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las tres funciones | `prueba_conductores.sql` | **24 de 24**, doce de ellas intentando rodear |
| Regresion completa | Los catorce archivos de `dev-tools/` | **315 comprobaciones, 0 fallando** |
| La guardia cubre la ruta nueva | `GET /conductores` sin sesion | 307 a `/acceso`, sin tocar el proxy |
| El panel compila para produccion | `npm run build` | Compila, con las dos rutas |
| Calidad del panel | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| La aplicacion movil no se rompe | `typecheck`, `lint`, `format:check` | Los tres en 0 |
| **Las pantallas en el navegador** | **El usuario, en su navegador** | **Las tres funcionan**: aprobar y retirar aprobacion, el telefono invalido rechazado con su mensaje, y bloquear y desbloquear la cuenta |

**Y LA AUDITORIA SE COMPROBO CON LAS ACCIONES REALES DEL USUARIO, no solo con las sinteticas.**
Despues de que las probara en pantalla se consulto `admin_audit_logs`: **las cuatro acciones
estaban ahi**, con quien las hizo, la hora en horario de Colombia y el estado anterior y
posterior. Es la primera vez que esa tabla tiene filas de verdad desde que se creo en la Fase 5.

Una de las cuatro entradas confirma D244 sin haberla buscado: al retirar la aprobacion, el
`before_data` guardo `is_available: true` y el conductor quedo no disponible. **La regla se ve en
el registro**, no solo en la prueba.

**Se comprobo ademas como quedaron los conductores despues de las pruebas**, que es lo que evita
dejar el entorno roto para la sesion siguiente: los dos **aprobados y con la cuenta activa**. El
primero quedo `is_available = false`, y **eso es correcto**: retirar la aprobacion apaga la
disponibilidad y volver a aprobar NO la reenciende, porque ese interruptor lo maneja el conductor
desde su aplicacion. Hay que reejecutar su semilla antes de usarlo para probar.

---

### Lo que se hizo: paso 5, vehiculos y asignacion (2026-08-27)

**Nueva implementacion.** `supabase/migrations/20260827010000_admin_vehicle_management.sql`, su
correccion `20260827020000`, `supabase/dev-tools/prueba_vehiculos.sql` (26 comprobaciones), el
modulo `admin/src/features/vehicles/` y la pantalla `/motorratones`.

**TERCERA VEZ QUE APARECE EL MISMO HUECO.** El paso 2 lo encontro en `profiles`, el 4a en
`drivers`, y aqui estaba otra vez en `vehicles` y en `driver_vehicle_assignments`: las politicas
`_all_admin` son `for all`, asi que se podia crear, editar, asignar y desasignar **con escritura
directa y sin dejar rastro**. Se cerraron las dos —conservando la lectura, que `vehicles` la
tiene abierta a proposito por D86— y **quedan avisadas las que faltan**: `document_types`,
`documents` y `places`, para sus pasos.

Que aparezca tres veces ya no es casualidad: **la exencion "si es administrador, pasa" estaba
repetida por todo el esquema de la Fase 5**, y no habia panel entonces que la usara a diario.

Cinco funciones: `admin_list_vehicles` -lectura, invoker por D242-, `admin_create_vehicle`,
`admin_update_vehicle`, `admin_assign_vehicle` y `admin_unassign_vehicle`, las cuatro ultimas
auditadas.

**Dos reglas de proteccion nuevas, las dos con el criterio de D244:**

- **No se retira ni se manda a taller una unidad que va por la calle con un pasajero dentro**
  (`VEHICLE_HAS_ACTIVE_RIDE`)
- **No se le baja la capacidad por debajo de lo que ya lleva encima**
  (`CAPACITY_BELOW_CURRENT_LOAD`). Esta no la atrapaba nada: `enforce_ride_capacity` mira al
  aceptar el viaje, no al editar el vehiculo, asi que se podia dejar un viaje de tres pasajeros
  en una unidad declarada de dos, **un dato que se contradice a si mismo**

**La comprobacion 4 mide el hallazgo H10 en esta tabla**: una placa repetida se atrapa aunque
venga en minusculas. Sin comparar normalizado, `zzv802` pasaria la comprobacion y chocaria
despues contra el indice unico con un 23505 sin explicacion, porque el disparador
`normalize_vehicle_plate` la habria puesto en mayusculas.

**UN FALLO REAL EN LA MIGRACION, y es de los que se aprenden.** `admin_assign_vehicle` cerraba la
asignacion anterior con `unassigned_at = now()`, y **`now()` en PostgreSQL no es el reloj: es el
instante en que empezo la transaccion**. Al cerrar una asignacion creada en esa misma
transaccion, las dos fechas salian identicas y saltaba `dva_period_valid`.

Lo cazo la comprobacion 11, y **solo porque las pruebas corren dentro de una transaccion**. El
panel nunca lo habria sufrido —cada accion es su propia transaccion—, y por eso el fallo es
peor, no mejor: **un fallo que solo aparece segun quien llame a la funcion se descubre tarde y en
el sitio equivocado.** Corregido con `clock_timestamp()` en las dos funciones, tambien en la que
ninguna prueba habia pisado.

**Verificado por el usuario en pantalla:** el alta con numero repetido rechazada, la asignacion,
el cambio de estado y el boton de asignar apagado en una unidad en taller.

---

### Lo que se hizo: DOBLE TURNO, fuera del plan (2026-08-27)

**Peticion del usuario mientras probaba el paso 5**, con sus palabras: *"en el plan esta previsto
que un motorraton lo pueden manejar dos o mas personas? es que algunos tienen doble turno"*.

**No estaba previsto, y el sistema lo impedia a proposito.** `dva_one_active_per_vehicle`, indice
unico parcial de la Fase 5, solo admitia una asignacion vigente por unidad, con este motivo
escrito: *"sin la segunda, dos conductores podrian aparecer al volante del mismo motorraton, y un
pasajero recibiria datos de un vehiculo que no es el que viene por el"*.

**Ese motivo seguia siendo bueno, pero resolvia "dos a la vez", no "dos por turnos".** La regla
estaba en el sitio equivocado: en QUIEN TIENE ASIGNADA la unidad, cuando lo que importa es QUIEN
ESTA TRABAJANDO CON ELLA AHORA.

`supabase/migrations/20260827040000_shared_vehicle_shifts.sql`, su ajuste `20260827050000` y
`supabase/dev-tools/prueba_doble_turno.sql` (16 comprobaciones).

**D246, decidido con el usuario entre tres opciones.** Varias asignaciones vigentes por unidad,
**pero un solo conductor disponible a la vez entre los que la comparten**. La regla vive en
`is_available` y no en la asignacion porque **es ahi donde se decide quien recibe servicios**:
`find_available_drivers` filtra por esa columna, asi que dos companeros disponibles a la vez
recibirian ofertas distintas y **los dos podrian aceptar con un solo motorraton fisico**.

**Media solucion ya estaba puesta desde la Fase 5 sin saberlo:** `enforce_ride_capacity` suma los
asientos ocupados **por vehiculo y no por conductor**, asi que dos companeros nunca podrian
sobrecargar la unidad entre los dos. Esa mitad no hubo que tocarla.

**El mensaje de error nombra al companero y la unidad** —*"Juan Perez ya esta conectado con el
motorraton 99"*—, y `setAvailability` lo prefiere al texto fijo del catalogo. **Es la unica vez en
el proyecto que se usa el mensaje del servidor en vez del `hint`**, y el motivo esta escrito: con
el nombre delante el conductor resuelve llamando a su companero; sin el, tiene que llamar a la
oficina para averiguar quien esta conectado. Sigue siendo el `hint` el que decide (D88); el texto
solo se muestra. **Y se anadio igualmente al catalogo de `errors.ts` como respaldo**, porque sin
traduccion el conductor habria leido "Ocurrio un error inesperado", que es exactamente D234.

**UN ERROR QUE SE CORRIGIO ANTES DE QUE LLEGARA A LA PANTALLA.** La primera version de
`admin_list_vehicles` devolvia los conductores como **dos listas paralelas** —un texto
`"Ana, Juan"` y un array de identificadores, las dos ordenadas por nombre—, y el panel tenia que
emparejarlas partiendo el texto por comas. **Eso se rompe con un conductor llamado "Gomez, Ana":
el panel quitaria del turno a una persona distinta de la que se pulso, en silencio.** Se cambio a
un `jsonb` con los pares antes de escribir la pantalla.

**16 comprobaciones, todas en verde.** La 9 es la central -el companero no se conecta a la vez- y
va con la 11 vigilandola -tras el relevo si entra-, porque sin esa pareja la 9 podria estar en
verde porque nadie puede conectarse nunca, que romperia la aplicacion entera. La 15 mide la
consecuencia que de verdad importa: de los que comparten unidad, **solo uno queda visible para
`find_available_drivers`**.

**LA CUARTA PREMISA HEREDADA DEL MUNDO REAL, y esta la provoco el propio panel.** Al probar la
pantalla de motorratones, el usuario quito y reasigno unidades, y **el "Conductor de prueba" se
quedo sin ninguna vigente**: dos cerradas, la 99 y una 96. Eso tumbo `prueba_recaudo` y
`prueba_solicitud_con_valor` con un 23502, **sin que nada estuviera roto**, y ademas **habria
dejado su aplicacion movil sin funcionar**, que es lo que de verdad importaba de ese hallazgo. Se
restauro con `seed_test_driver.sql` y las dos pruebas pasan a **crear su propia asignacion si no
la encuentran**. Van cuatro veces con la misma leccion —el `sum` de `prueba_recaudo`, las dos de
`prueba_notificaciones` y esta—: **una prueba monta lo que necesita, no lo encuentra.**

**Tambien hubo que corregir `prueba_vehiculos`**, que usaba `driver_name`: esa columna dejo de
existir al cambiar la forma del listado. No es una prueba que estuviera mal, es un contrato que
cambio por una decision aprobada.

---

### Lo que se hizo: los botones dejan de ser planos (2026-08-27)

**Reportado por el usuario probando el panel**, no por las pruebas: *"si posas el puntero sobre
ellos son completamente planos"*.

Era cierto y era mio: cada boton repetia su pinta en clases sueltas y **ninguno tenia estados**.
Se centralizo en `admin/src/app/globals.css` con tres clases -`.btn`, `.btn-primario`,
`.btn-secundario`- y se migraron los 17 botones del panel. **Se centralizo porque el problema no
era un boton**: era que la pinta estaba repetida en cada sitio, asi que arreglarlos uno a uno
habria dejado el siguiente igual de plano.

Las tres senales, y por que las tres:

- **hover**, dice "esto se puede pulsar", antes de pulsarlo
- **active**, dice "te he oido" en el momento del clic. **Es la que faltaba y la que mas se
  nota**: sin ella, en una conexion lenta no se sabe si el clic entro. Encoge el boton en vez de
  solo oscurecerlo, porque el movimiento se percibe aunque el cambio de color sea sutil
- **focus-visible**, dice donde esta el teclado. No es decoracion: sin ella el panel no se puede
  usar sin raton

Un boton apagado no responde a nada: ni encoge, ni cambia el cursor. Los enlaces de la navegacion
llevaban el mismo problema y se arreglaron igual.

---

### Lo que se hizo: paso 6a, lugares y tarifas rurales (2026-08-27)

**El paso 6 son cinco areas y se partio en dos.** Lugares y tarifas rurales van juntas **porque
D229 las ata**; las tarifas urbanas, los tipos de carga y los parametros son catalogos pequenos y
fijos, y van en 6b.

`supabase/migrations/20260827080000_admin_places_and_rural_fares.sql`, sus dos correcciones
`20260827090000` y `20260827100000`, `supabase/dev-tools/prueba_lugares.sql` (25 comprobaciones),
el modulo `admin/src/features/places/` y la pantalla `/lugares`.

**CUARTA APARICION DEL MISMO HUECO**, y en las tablas donde mas importa: `places_all_admin` y
`rural_fares_all_admin` permitian **cambiar un precio con un UPDATE directo y sin dejar rastro**.
Se cerraron las dos. **Faltan `urban_fares`, `cargo_types` y `app_settings`**, que se cierran en
6b.

**D229 SE APLICO CON EL DATO, NO CON EL CRITERIO.** La decision decia que el panel no dejara
crear un lugar sin decidir su tarifa. Aqui no se pregunta "¿es rural?" y se confia en la
respuesta: **se mide la distancia al centro y se compara con `unpriced_destination_max_km`, el
mismo parametro que usa D219 para rebotar destinos sin precio**. Si el lugar cae fuera de ese
radio y no trae tarifa, no se crea. Asi la regla del panel y la del servidor son **el mismo
numero**, y afinar una afina la otra. El mensaje de rechazo **da los kilometros**, porque quien
lo lee tiene que poder decidir si pone precio o si movio mal la chincheta.

**UN HALLAZGO CON DATOS DE PRODUCCION, Y ES EL QUE JUSTIFICA TODO EL PASO.** Al medir los 63
lugares reales aparecio **"Vereda Guayabito": activa en la lista del pasajero, a 6,3 km del
centro y sin tarifa**. Al elegirla, el servidor la rebotaba con `DESTINATION_NOT_PRICED`. Llevaba
asi **desde la Fase 9**, desde antes de que existieran las tarifas, y no habia molestado a nadie
solo porque nunca la uso ningun viaje.

**El usuario pidio borrarla y se propuso desactivarla en su lugar**, con el precedente de D232 -a
"La vibora" se la renombro y apago, no se borro- y un motivo concreto: **borrarla pierde sus
coordenadas**, y recrearla obligaria a volver a conseguirlas. Se desactivo **llamando a la
funcion del panel**, no con un UPDATE, para que quedara en la auditoria igual que si se hubiera
pulsado el boton. Quedan sus coordenadas intactas: `-75.09602, 6.85448`.

**Y AL DESACTIVARLA APARECIO UN FALLO DEL ASISTENTE.** El contador de lugares sin tarifa **se
quedo en 1**: `needs_fare` no miraba si el lugar estaba activo. Un lugar apagado no sale en la
lista del pasajero, asi que **no puede rebotar**: no hay nada que arreglar, y un aviso que
siempre esta encendido es un aviso que nadie mira. Corregido en `20260827100000`, con dos
comprobaciones nuevas -la 24 y la 25- que ademas miden que **al reactivarlo el aviso vuelve
solo**, que es lo que prueba que la condicion esta en el sitio correcto.

**DOS ERRORES DEL ASISTENTE, Y LOS DOS SON EL MISMO.** Se llamo a `is_within_service_area` y a
`quote_fare` **suponiendo sus firmas en vez de mirarlas**: la primera recibe longitud y latitud
sueltas, no un punto; la segunda pone el tipo de servicio antes que los pasajeros. Las dos
existen desde hace fases. **La regla 2 del proyecto -verificar, no suponer- vale tambien para las
firmas de las funciones propias, no solo para los datos.** Lo unico bueno: un error de tipos en
PL/pgSQL no salta al crear la funcion, solo al llamarla, asi que lo cazo la primera comprobacion
que intento crear un lugar. Sin la prueba, habria aparecido en el panel.

**Y UNA EXPECTATIVA MIA EQUIVOCADA, no un fallo del codigo.** La comprobacion 18 media un viaje
entre dos lugares con tarifa propia y esperaba el precio del destino. **D233 dice que con dos
rurales distintos gana el mas caro**, asi que el codigo tenia razon. Se reescribio con un origen
urbano, que es lo que se queria medir.

**Tres decisiones de la pantalla que no son adorno:**

- **La ubicacion no se puede editar** (D248). Mover un lugar cambia su distancia al centro, y con
  ella si necesita tarifa (D229) y a que destino se pega un punto suelto (D230). Es una operacion
  con consecuencias sobre los precios, no un campo mas de un formulario
- **Quitar una tarifa la apaga, no la borra.** El precio se conserva por si el destino vuelve a
  atenderse, y la pantalla lo dice, porque desde fuera "quitar" suena a perder el dato
- **El aviso rojo solo aparece cuando hay algo roto**, con un enlace que filtra la lista

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las funciones | `prueba_lugares.sql` | **25 de 25** |
| Regresion completa | Los diecisiete archivos | **380 comprobaciones, 0 fallando** |
| El estado real de los lugares | Consulta al servidor | 63 lugares, 61 activos, 28 con tarifa, **0 rotos** |
| `/lugares` sin sesion | `GET` | 307 a `/acceso` |
| Panel y aplicacion movil | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **La pantalla** | **El usuario, en su navegador** | **Funciona** |

---

### Lo que se hizo: paso 6b, tarifas urbanas, tipos de carga y parametros (2026-08-27)

`supabase/migrations/20260827120000_admin_fares_cargo_and_settings.sql`, su correccion
`20260827140000`, `supabase/dev-tools/prueba_configuracion.sql` (25 comprobaciones), dos
comprobaciones nuevas en `prueba_conductores.sql`, el modulo `admin/src/features/config/` y la
pantalla `/tarifas`.

**LA REJILLA URBANA NO SE CREA NI SE BORRA, SOLO SE EDITA.** Son seis casillas fijas -uno, dos o
tres pasajeros, de dia o de noche- y esa forma la decidio la empresa. `urban_fares` **no tiene
`is_active` a proposito** desde el bloque especial: apagar "dos pasajeros de noche" no significa
nada y dejaria un servicio sin precio a las once.

**Los parametros se agrupan en dos, porque `app_settings` mezcla dos cosas muy distintas**:
precios y horarios por un lado, y reglas de operacion por otro -los veinte segundos de R2, el
maximo de R11, el radio de llegada de R5-. Viven en la misma tabla, pero cambiar una tarifa y
cambiar el reparto de servicios no son la misma decision. **Cada clave lleva su rango comprobado
en el servidor, y cada rango tiene su motivo**: no son numeros redondos, son los limites donde el
sistema deja de funcionar. Un cero en `offer_response_seconds` caducaria cada oferta antes de que
el conductor la viera, y la aplicacion dejaria de repartir servicios **sin que nada pareciera
roto**.

**La zona horaria se valida contra el catalogo de PostgreSQL**, no contra una lista escrita a
mano: `pg_timezone_names`. Una lista propia se queda vieja y nadie se entera.

**Los valores se editan de uno en uno, no con un formulario y un boton al final** (D249). Un
formulario con veinte campos invita a tocar cuatro cosas y guardarlas juntas; si una falla la
validacion, quien lo usa no sabe cual. De uno en uno, **cada cambio lleva su propia respuesta y su
propia linea en la auditoria**.

**EL HALLAZGO DEL PASO, Y NO LO ENCONTRO NINGUNA PRUEBA.** Al terminar se listaron las politicas
`for all` que quedaban vivas —para comprobar una frase que el asistente acababa de escribir en la
migracion, "ninguna tabla del panel admite ya escritura directa sin auditoria"— y **la frase era
falsa**: `drivers_all_admin` seguia abierta desde el paso 4a.

Alli se aprieto el disparador `protect_driver_columns` y **se dio por hecho que bastaba**. No
bastaba: el disparador solo protege cinco columnas, asi que quedaba abierto **cambiar
`is_available` de cualquier conductor —o borrarle la ficha— con un UPDATE directo y sin rastro**.
Con el doble turno (D246) es peor todavia, porque esa columna decide **quien de los que comparten
motorraton recibe los viajes**.

**La leccion: el disparador y la politica protegen cosas distintas, y apretar uno no cierra la
otra.** Es la misma forma del error de D241 —sustituir una proteccion por otra dejando un hueco
que ninguna de las dos tenia por separado— y la segunda vez que el asistente la comete en esta
fase. Corregido en `20260827140000`, con dos comprobaciones nuevas en `prueba_conductores.sql`
que miden el UPDATE y el DELETE.

**Y quedo comprobado que comprobar sirve**: la frase estaba escrita, era plausible, y **solo
mirarla contra el servidor la desmintio**.

**Con esto, de todas las tablas que el panel gestiona solo quedan abiertas `documents` y
`document_types`**, que son del paso 4c. Las demas —`profiles`, `drivers`, `vehicles`,
`driver_vehicle_assignments`, `places`, `rural_fares`, `urban_fares`, `cargo_types` y
`app_settings`— pasan todas por funciones auditadas.

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las funciones | `prueba_configuracion.sql` | **25 de 25 a la primera** |
| El hueco de `drivers` | `prueba_conductores.sql`, dos nuevas | **26 de 26** |
| Regresion completa | Los dieciocho archivos | **409 comprobaciones, 0 fallando** |
| **Que el rollback no dejo nada tocado** | Consulta al servidor tras las pruebas | Intacto: $4.000, R2 en 20 s, `America/Bogota` |
| Politicas de escritura que quedan | `pg_policies` | Solo `documents` y `document_types` (paso 4c) |
| Panel y aplicacion movil | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **La pantalla** | **El usuario, en su navegador** | **Funciona** |

**Una advertencia sobre `prueba_configuracion.sql`, que lo dice en su cabecera:** es **el unico
archivo de pruebas que toca los precios y los parametros reales**. No hay alternativa —la rejilla
son seis filas fijas y `app_settings` tiene una fila por clave, no se pueden inventar copias—, asi
que **el `rollback` del final es lo unico que lo hace seguro**. No debe partirse en trozos ni
ejecutarse por partes.

---

### Lo que se hizo: paso 4b, dar de alta conductores (2026-08-27)

**Lo ultimo que le faltaba al panel para poder incorporar personal sin tocar la base de datos a
mano.** `supabase/migrations/20260827160000_admin_create_driver.sql`, su correccion
`20260827170000`, `supabase/dev-tools/prueba_alta_conductor.sql` (21 comprobaciones) y tres
componentes nuevos en `admin/src/features/drivers/`.

**POR QUE NO SE PODIA HACER DESDE EL NAVEGADOR**, y por que este paso se aparto del 4a. Un
conductor no puede auto-registrarse, asi que la cuenta la crea el panel, y con la clave
publicable no sale: `auth.signUp` **inicia sesion como el usuario recien creado** —echando al
administrador de su propia sesion— y el perfil nace con rol `passenger`, que un UPDATE no puede
cambiar (regla 1 de las aprendidas).

**D250: se hace con una funcion `security definer`, no con la clave `service_role`.** Decidido
con el usuario entre las dos opciones. El motivo es **el alcance del poder**: la `service_role`
salta toda la RLS para cualquier operacion, y quien la tenga puede leer y escribir cualquier cosa
de cualquier usuario. Esta funcion corre con privilegios tambien, pero **acotada a una operacion
y con `is_admin()` comprobado dentro**. Un agujero aqui da de alta conductores; un agujero con la
`service_role` da todo. Ademas el proyecto ya crea cuentas asi desde la Fase 12:
`seed_test_driver.sql` y `seed_admin.sql` llevan meses haciendolo.

**D251: la contrasena la genera el sistema y se muestra una sola vez.** El panel no deja
elegirla: cuando las elige una persona para veinte conductores acaban siendo todas parecidas. El
formato es **dictable por telefono** —`Moto-XXXX-9999`, sin O ni I ni L ni S, que se confunden
con 0, 1 y 5 al hablar—, porque asi es como va a llegarle al conductor.

**La contrasena NUNCA se escribe en la auditoria**, y la comprobacion 8 lo mide buscandola
dentro de `before_data` y `after_data`. Un registro que la guardara seria un almacen de
contrasenas en claro que cualquier administrador podria leer. La 9 la vigila: comprueba que el
alta **si** queda registrada, para que la 8 no este en verde por no haberse registrado nada.

**Nace pendiente de aprobar, no aprobado**, que es D245 aplicado al alta: dar de alta y autorizar
a trabajar son dos decisiones distintas, y la segunda suele depender de unos papeles que aun no
estan.

**`admin_reset_driver_password` entro con el alta**, porque es su complemento inevitable: un
conductor olvida su contrasena y la empresa tiene que poder darle otra. **Solo funciona sobre
cuentas de conductor**, y la comprobacion 17 mide por que: sin esa restriccion, un administrador
podria darle contrasena nueva a **otro administrador** y entrar con su cuenta.

**UN FALLO DEL ASISTENTE, Y ES UNA TRAMPA DE SUPABASE QUE CONVIENE CONOCER.** La funcion
generadora se cerro con `revoke all ... from public`, **y eso no basta**: Supabase tiene un
`ALTER DEFAULT PRIVILEGES` que concede `execute` a `anon`, `authenticated` y `service_role` sobre
**toda funcion nueva del esquema `public`**. Ese permiso es un grant explicito a cada rol, asi que
revocarle a `PUBLIC` no lo toca. Medido: `has_function_privilege('anon', ...)` decia **true**, y
la comprobacion 21 lo cazo esperando un rechazo y recibiendo una contrasena. Corregido con
`revoke ... from anon, authenticated`.

**Las demas funciones del panel no lo sufren** porque a todas se les concede `execute` a
`authenticated` a proposito y todas comprueban `is_admin()` dentro. Esta era la unica que debia
quedar cerrada, precisamente porque no comprueba nada.

**H22, un hallazgo que salio de tirar del hilo y que NO se toco.** Se listaron todas las funciones
del esquema que `anon` puede ejecutar y aparecen varias operativas: `cancel_request`,
`accept_ride_offer`, `cancel_ride`, `reject_ride_offer`. **Se probaron llamandolas sin sesion en
vez de suponer**, y las cuatro **se defienden solas**: comprueban la propiedad con `auth.uid()`,
que sin sesion es nulo, y responden "Esa solicitud no es tuya". Las demas de la lista son
funciones de disparador, que no se pueden llamar sueltas. **No hay ningun agujero abierto: hay
permisos que sobran.** Queda para la Fase 22, que es donde toca, y no se toco ahora porque son
funciones vivas de las fases 11 a 18 y cambiarles los permisos sin volver a probar el ciclo
completo arriesga mas de lo que gana.

**En el panel**, el dialogo de la contrasena **no se cierra tocando fuera ni con Escape**, al
reves que los demas: solo con el boton, y hay que marcar una casilla que dice "ya la anote". Es
friccion a proposito —un cierre accidental ahi cuesta una llamada al conductor—. Y el dialogo se
abre **antes** de recargar la lista, porque la recarga puede tardar y esa contrasena no se puede
perder por el camino.

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las dos funciones | `prueba_alta_conductor.sql` | **21 de 21** |
| Regresion completa | Los diecinueve archivos | **430 comprobaciones, 0 fallando** |
| El generador ya no esta expuesto | `has_function_privilege` | `anon` y `authenticated` en `false` |
| Panel y aplicacion movil | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **QUE EL CONDUCTOR CREADO ENTRE DE VERDAD EN LA APLICACION** | **El usuario, en el aparato** | **Entro bien** |

**Esa ultima fila es la que cierra el paso, y es la unica que el asistente no podia hacer.** Desde
SQL solo se puede comprobar que la fila tenga la forma que GoTrue espera —las cuatro columnas de
token vacias y no nulas, que es E28—; que GoTrue la acepte de verdad solo se sabe iniciando
sesion. El archivo de pruebas lo dice en su cabecera para que nadie lo de por cubierto.

**Quedo una cuenta real creada en la prueba:** "juan" (`juan@motomoto-qa.co`), pendiente de
aprobar y sin motorraton, tal como nace.

**UNA PRUEBA FALLO SIN CULPA DE NADIE, Y LA LECCION YA ESTABA ESCRITA.** Al correr la regresion,
tres comprobaciones de `prueba_solicitud_con_valor.sql` esperaban 4.000 —la urbana de dia— y
obtenian 7.000. **Eran las 22:20 en Amalfi**: acababa de empezar la franja nocturna y **el
servidor tenia razon**. Ese archivo deja correr `now()`, que es exactamente lo que el bloque
especial dejo advertido al escribir `prueba_calculo_tarifa.sql` —"todas las comprobaciones pasan
la hora a mano; una prueba que no fije la hora pasaria por la tarde y fallaria a medianoche"— y a
este archivo no se le habia aplicado.

`request_ride` calcula con `now()` y no admite que se le pase una hora, asi que la solucion no
podia ser fijarla: **el archivo aparta la franja nocturna** a una ventana que no incluye el
momento de la ejecucion, dentro de su propia transaccion. Comprobado despues que la franja real
sigue en 22–5.

---

### Lo que se hizo: paso 4c, documentos de conductores y vehiculos (2026-08-27)

**Cierra el bloque de la flota y, con el, el hueco de las politicas `_all_admin`.**
`supabase/migrations/20260827190000_admin_documents.sql`,
`supabase/dev-tools/prueba_documentos.sql` (24 comprobaciones) y el modulo
`admin/src/features/documents/`, colgado de las fichas de conductor y de motorraton.

**ESTADO AL EMPEZAR**, medido: `document_types` con 2 filas, `documents` con **cero**, y un solo
bucket, `avatars`. La tabla existe desde la Fase 5 y **nunca se habia usado**.

**El bucket `documents` es privado, y con mas motivo que el de las fotos.** Una foto de perfil
sale en la calle; una cedula no se recupera si se filtra. 5 MB, imagenes y PDF -las matriculas y
los seguros suelen llegar asi-.

**QUIEN VE QUE.** Solo el administrador y **el propio conductor sus propios papeles**. No los de
otro conductor, y **tampoco los del vehiculo aunque lo comparta por doble turno**: los papeles
del motorraton son de la empresa. **Y puede verlos pero no borrarlos** (comprobacion 21): si
pudiera, se libraria de una licencia vencida antes de que la empresa la mirara.

**EL ORDEN DE LA SUBIDA ESTA ELEGIDO, no es casual** (D252). El archivo no pasa por SQL: el panel
lo sube a Storage y **despues** registra la fila. Se eligio asi porque **un archivo sin fila es
basura recuperable y una fila sin archivo es un documento que la empresa cree tener y no tiene**.
Si el registro falla, el panel borra el archivo que acaba de subir.

**`requires_expiry` deja de ser decorativo.** Existe desde la Fase 5 y nada lo hacia cumplir: la
comprobacion 6 mide que un tipo que pide vencimiento lo pide de verdad, porque un seguro sin
fecha no se puede vigilar. La pantalla ademas avisa **al elegir el tipo**, no al fallar el envio:
para entonces el archivo ya se subio y hubo que borrarlo.

**Tres estados de vencimiento y no dos** -vencido, vence en menos de 30 dias, al dia-, porque
piden acciones distintas: uno hay que resolverlo ya, el otro se puede planificar.

**Este si borra de verdad, al reves que casi todo el proyecto.** Un documento no es historial de
una operacion: es un papel que puede estar mal escaneado o ser el equivocado. La funcion
**devuelve la ruta** para que el panel borre tambien el archivo —si no, el bucket acumularia
cedulas de gente que ya no trabaja alli— y la auditoria conserva lo que habia, que es lo unico
que quedara de ese documento.

**CON ESTO SE ACABO EL HUECO QUE APARECIO CINCO VECES.** Comprobado contra `pg_policies`:
**cero politicas `for all`** en todo el esquema. Las nueve tablas que el panel gestiona pasan
todas por funciones auditadas.

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las cinco funciones | `prueba_documentos.sql` | **24 de 24** |
| Regresion completa | Los veinte archivos | **454 comprobaciones, 0 fallando** |
| Politicas `for all` que quedan | `pg_policies` | **0** |
| Panel | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **La subida de un archivo real** | **El usuario, desde el panel** | **Funciono** |

**Y SE COMPROBO CONTRA STORAGE, no solo contra la fila.** Despues de que el usuario subiera un
documento se consultaron las dos mitades: la fila en `documents` y el objeto en
`storage.objects`. **Coinciden**: un PDF de 728 KB en
`driver/<id-del-conductor>/<uuid>.pdf`, con su tipo MIME y subido por el administrador. Era la
comprobacion que el archivo de pruebas no podia hacer —Storage tiene su propia API y sus
politicas se evaluan alli—, y es justo la que decide si D252 funciona: **archivo y ficha
existiendo a la vez**.

**LOS DOS CONDUCTORES CREADOS PROBANDO ROMPIERON CINCO PRUEBAS, y no por un fallo.** Siete sitios
elegian "el primer conductor que haya" sin mirar su estado; al nacer "juan" pendiente de aprobar
—que es lo correcto—, todo lo que dependia de su disponibilidad se caia con
`drivers_available_only_when_approved`. Corregidos los siete: ahora piden un conductor aprobado.
**Quinta vez que una prueba se rompe por heredar una premisa del mundo real**, y la regla ya
esta escrita: **una prueba no toma lo que encuentra, toma lo que necesita.**

La primera correccion fue **parcial y lo destapo otra rotura**: `prueba_encomiendas.sql` usa
`v_cond1` y `v_cond2` en un bloque aparte, que el arreglo no toco, y al quedar desalineados el
conductor "sin oferta" resulto ser el mismo que si la tenia. Corregido tambien.

---

### Lo que se hizo: paso 7, listado de pasajeros con bloqueo (2026-08-27)

**EL PASO MAS CORTO DE LA FASE, y conviene decir por que: el bloqueo ya existia.**
`admin_set_account_status` se construyo en el paso 2 y sirve igual para un pasajero que para un
conductor —por eso se llamo "cuenta" y no "conductor"—, con su auditoria y su regla de no
bloquearse a uno mismo. Aqui solo faltaba **la lista desde la que decidir**.

`supabase/migrations/20260827220000_admin_passengers.sql`,
`supabase/dev-tools/prueba_pasajeros.sql` (20 comprobaciones), el modulo
`admin/src/features/passengers/` y la pantalla `/pasajeros`.

**QUE VE LA EMPRESA DE UN PASAJERO, y por que cada dato:**

- **Los desenlaces por separado, no un total.** "Veinte servicios" no dice si fueron bien. Con
  los datos reales se vio de inmediato lo que la pantalla sirve para ver: **Carlos Diaz tiene 2
  cancelados y 0 terminados**, mientras Ana Gomez tiene 7 y 7
- **Su calificacion, la que le ponen los conductores.** Existe en los dos sentidos desde la Fase
  17 pero **nunca se habia mirado**: solo `drivers.rating_average` esta precalculada. **Aqui se
  calcula al vuelo y no se guarda**, porque la del conductor se lee en cada oferta —el pasajero la
  ve antes de aceptar— y esta se mira desde una pantalla y de vez en cuando: un disparador que la
  mantuviera seria mas cosas que pueden desincronizarse a cambio de nada
- **Si tiene un servicio en curso**, para no bloquear a ciegas a quien va montado ahora mismo

**D253: bloquear a alguien con un servicio en curso EXIGE MOTIVO ESCRITO, pero no se prohibe.**
Es la diferencia deliberada con D244, donde a un conductor conduciendo **si** se le impide
retirarle la aprobacion: alli el perjudicado es un tercero —el pasajero que va dentro—; aqui el
afectado es el propio bloqueado, y **puede haber una urgencia real que justifique dejarlo fuera
ahora mismo**, como que agreda al conductor. Se piden diez caracteres y **la auditoria guarda el
motivo y el hecho de que habia un viaje vivo**, que es el dato que explicara la decision dentro
de seis meses.

**Dos detalles de la pantalla que salieron del dato real, no del diseno:**

- **El porcentaje de cancelaciones solo se muestra con cinco servicios o mas.** Con dos, un 50%
  no significa nada y ensenarlo invita a decidir sobre ruido
- **El detalle dice quien cancelo cada servicio y por que.** Es lo que responde "¿por que cancela
  tanto?" antes de decidir, y sin eso el numero de cancelaciones acusa al pasajero de algo que
  pudo hacer el conductor

**El porcentaje se calcula en la pantalla y no en el servidor**, a proposito: la empresa decide si
un 40% es mucho, y ese criterio va a cambiar. Guardarlo lo convertiria en una regla.

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las dos funciones | `prueba_pasajeros.sql` | **20 de 20** |
| Regresion completa | Los veintiun archivos | **474 comprobaciones, 0 fallando** |
| `/pasajeros` sin sesion | `GET` | 307 a `/acceso` |
| Panel y aplicacion movil | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **La pantalla** | **El usuario, en su navegador** | **Funciona** |
| Como quedaron los datos | Consulta tras las pruebas | Los cuatro pasajeros activos, ninguno bloqueado por descuido |

**TRES ERRORES DEL ASISTENTE, TODOS DE MONTAJE DE PRUEBAS, y el tercero se repite.** Dos con
`rides_timeline_order`: primero se pusieron las tres fechas iguales, y despues separadas pero sin
`driver_arrived_at`. **La restriccion exige que exista la llegada si hay inicio** —un viaje no
puede empezar antes de que el conductor llegue— y se leyo su definicion con
`pg_get_constraintdef` en vez de seguir adivinando. Y el tercero fue **otra vez `v_row.column1`
sobre un `select ... into` de un solo valor**, que ya habia pasado en `prueba_conductores.sql` y
en `prueba_documentos.sql`: **tercera vez, y por eso queda escrito aqui**.

---

### Lo que se hizo: paso 8, listado e inspeccion de servicios (2026-08-28)

`supabase/migrations/20260828010000_admin_rides.sql`,
`supabase/dev-tools/prueba_servicios.sql` (23 comprobaciones), el modulo
`admin/src/features/rides/` y la pantalla `/servicios`.

**LO QUE YA EXISTIA Y NO SE REHIZO.** `list_driver_history` y `list_passenger_history` son de la
Fase 16 y **siguen siendo de sus duenos**: cada uno ve lo suyo, con las reglas de privacidad de
D198 -el nombre del pasajero solo viaja si el conductor acepto-. Las funciones de este paso son
otra cosa: **la empresa mirando su propia operacion**, y por eso **si ensenan las dos partes
juntas con sus telefonos**. Para resolver una queja hace falta ver a los dos.

**Cuatro funciones**: el listado con filtros y total para paginar, el detalle con la linea de
tiempo completa, las ofertas y las calificaciones.

**LO MAS UTIL DEL PASO NO ES EL LISTADO: SON LAS OFERTAS.** `admin_get_ride_offers` dice a que
conductores les llego un servicio, cual rechazo, cual dejo pasar el tiempo y **cuanto tardo cada
uno en responder**. Eso convierte "nadie lo tomo" -9 de los 57 servicios reales- en algo
accionable: **no es lo mismo que no le llegara a nadie que que le llegara a cinco y ninguno lo
quisiera**. La pantalla lo dice explicitamente cuando no hubo ninguna oferta.

**La linea de tiempo ensena tambien los pasos que NO ocurrieron, apagados.** Ver que un servicio
nunca llego a "el conductor llego" dice tanto como ver que si. Y la cancelacion **sustituye al
final en vez de sumarse**: un servicio cancelado no termino.

**D255: EL RECORRIDO SE DEVUELVE COMO DATOS, NO COMO MAPA.** `ride_locations` tiene hoy **12
puntos repartidos en 10 viajes** -uno por viaje-, y no es un fallo de la tabla: **el emulador no
puede producir movimiento**, medido desde la Fase 14, y nadie ha conducido de verdad con la
aplicacion. Un mapa con un punto no ensena nada, asi que el panel muestra cuantos puntos hay y
entre que horas. **El mapa se pondra cuando haya rastros de verdad**, y entonces se vera si sirve.

**El total de la paginacion lo calcula el servidor sobre lo filtrado** -`count(*) over ()`- y
viaja en cada fila. Sin eso, la pantalla tendria que pedir el listado entero solo para saber
cuantas paginas hay.

**Verificado:**

| Que | Como | Resultado |
|---|---|---|
| Las cuatro funciones | `prueba_servicios.sql` | **23 de 23** |
| Regresion completa | Los veintidos archivos | **497 comprobaciones, 0 fallando** |
| Contra los datos reales | Consulta al servidor | 57 servicios: 36 cancelados, 12 terminados, 9 sin tomar |
| `/servicios` sin sesion | `GET` | 307 a `/acceso` |
| Panel y aplicacion movil | `build`, `typecheck`, `lint`, `format:check` | Todo en 0 |
| **La pantalla** | **El usuario, en su navegador** | **Funciona** |

**Un error del asistente, y es LA CUARTA VEZ:** `v_row.column1` sobre un `select ... into` de un
solo valor, que ya habia pasado en `prueba_conductores`, `prueba_documentos` y `prueba_pasajeros`.
Queda escrito en el archivo por eso.

---

### LOS 36 DESTINOS RURALES, COMPLETOS (2026-08-28)

**Se cierra lo que quedaba abierto desde el bloque especial del 2026-08-25.** El usuario trajo las
coordenadas de los ocho que faltaban -Sorrento, Entrada a la Mina, Los Tanques, La Mina, La
Aguacatera, Cajamarca, Palmitas y La Blanquita- en `docs/destinos-rurales.csv`.
`supabase/migrations/20260828040000_seed_rural_fares_batch3.sql`.

**El esquema no tuvo que cambiar ni una linea.** Entraron como filas, que es exactamente lo que se
buscaba al disenarlo asi en el paso 1 del bloque especial: las tarifas rurales entran como filas
cuando lleguen las coordenadas, sin tocar el esquema.

**LO QUE SE MIDIO ANTES DE ESCRIBIR NADA**, que es lo que en la carga anterior destapo el problema
de D230: los ocho **caen dentro del area de servicio**, **ninguno repite nombre**, y todos estan
lo bastante lejos del centro como para necesitar tarifa propia (D229).

**LO QUE ENCONTRO ESA MEDICION, Y SE DECIDIO CON EL USUARIO (D254).** Cuatro destinos de la zona
de la mina quedan muy juntos y con precios muy distintos:

| Entre | Distancia | Diferencia |
|---|---|---|
| El Taparo ($12.000) y Los Tanques ($17.000) | **98 m** | $5.000 |
| Entrada a la Mina ($15.000) y La Mina ($25.000) | **232 m** | $10.000 |
| El Taparo ($12.000) y La Mina ($25.000) | 528 m | **$13.000** |

Para comparar: **la separacion minima entre los 28 ya cargados era de 219 m**. Esta es menos de la
mitad, con el doble de diferencia de precio.

**Cuando importa y cuando no**, que es lo que permitio decidir: si el pasajero **elige el destino
de la lista** -como se pide casi siempre- viaja el `place_id` y **la tarifa es exacta**. Solo una
**coordenada suelta** -"Tu ubicacion actual" o una chincheta- se resuelve por D230 al lugar
nombrado mas cercano, y ahi 98 metros separan cobrar 12.000 de cobrar 17.000.

**No es un fallo del codigo ni de los datos.** La empresa tiene cuatro puntos de referencia juntos
en esa zona, y sus precios reflejan lo lejos que queda cada uno **por carretera**, no en linea
recta. El usuario decidio cargarlos tal cual, que es lo que respeta lo que la empresa cobra de
verdad.

**Verificado despues de cargar:**

| Que | Resultado |
|---|---|
| Cada destino cobra su tarifa, preguntando a `quote_fare` | **8 de 8 exactos** |
| **Los lugares urbanos no se contaminaron** | **33 de 33 siguen cobrando $4.000** |
| Tarifas rurales activas | **36**, la lista completa |
| Regresion | 497 comprobaciones, 0 fallando |

**Esa segunda fila es la que importaba.** En la carga de agosto, medir antes destapo que 32
lugares urbanos -el parque incluido- habrian empezado a cobrar tarifa rural. Esta vez la misma
comprobacion salio limpia.

---

## 15.3 ESTADO ACTUAL

- **Fase actual:** Fases 0 a 19 completadas, aprobadas y comiteadas, **mas D161, el cambio del
  mapa a Mapbox y el bloque especial de tarifas, encomiendas y carga (seccion 15.21), que esta
  TERMINADO Y COMITEADO**. **La Fase 20 esta en curso**
- **Paso actual:** Fase 20. Los pasos 1, 2, 3, 4a, 4b, 5, 6a y 6b estan **hechos y verificados**
  con sus pantallas probadas, **y el 4c tambien, con la subida de un archivo real comprobada
  contra Storage**. Ademas, el doble turno (D246), que no estaba en el plan y modifica una regla
  de la Fase 5. **Quedan los pasos 9 a 11**: asignacion manual, reportes y R10
- **Los dos aparatos tienen el cliente de desarrollo al dia**, compilado con Firebase dentro.
  Solo hay que recompilar si se toca codigo nativo otra vez, y entonces **una arquitectura por
  vez**: el `.apk` con las dos juntas no cabe en el emulador (seccion 15.20)
- **Ultimo paso completado:** La Fase 19 entera, probada en los dos aparatos. Antes, la
  Fase 18
- **Funcionalidades terminadas:** Sistema de diseno (12 componentes), navegacion por roles
  con guardias, base de datos completa con sus politicas y funciones, autenticacion completa
  con registro, login, logout, sesion persistente, recuperacion de contrasena y estados de
  cuenta, perfil del pasajero con edicion, contrasena y foto, mapa principal con permisos,
  ubicacion, marcador, camara y estados degradados, y seleccion de origen y destino por
  lista de lugares, buscador de direcciones y punto en el mapa, y seleccion de la cantidad
  de pasajeros con el maximo configurado por la empresa, y creacion real de la solicitud con
  zona de servicio validada en servidor, distancia y tiempo por carretera, caducidad
  automatica y restauracion del estado al reabrir, y el modulo del conductor completo con
  disponibilidad, envio de posicion, ofertas en tiempo real, aceptacion y rechazo, y **recoger
  pasajeros en ruta**, con la capacidad controlada por asientos y la ruta dibujada en el mapa,
  y **la asignacion en tiempo real de las dos partes**: el pasajero ve a su conductor en cuanto
  alguien acepta, y el conductor deja de ver lo que ya no existe, y **el seguimiento del
  conductor**: la referencia escrita del punto de recogida, la ruta dibujada en la pantalla del
  pasajero, los dos ritmos de envio de posicion de R9, el motorraton moviendose en el mapa con
  su tiempo de llegada y su estado de conexion, y la navegacion hacia el punto de recogida, y
  **el ciclo completo del servicio**: las cuatro transiciones desde la pantalla del conductor,
  los cinco estados reflejados en la del pasajero, el resumen al terminar, el recorrido
  historico con su distancia, y la lista de paradas cuando lleva varios servicios, y **el
  historial de las dos partes**: el pasajero ve sus servicios terminados, cancelados y
  caducados; el conductor ve sus ofertas con su desenlace, incluidas las que rechazo y las que
  se llevo otro, y las dos partes pueden abrir el detalle con la linea de tiempo completa, y
  **las calificaciones**: las dos partes se califican al terminar o mas tarde desde el
  historial, una sola vez por servicio, y el promedio del conductor se recalcula solo y se ve
  en su perfil
- **Pruebas realizadas:** Entorno 13 puntos. Proyecto 15 puntos. Diseno 15 puntos.
  Navegacion validada en emulador y tablet. Base de datos 57 verificaciones contra el
  servidor. Autenticacion 43 verificaciones, detalladas en 15.5. Perfil y foto, detalladas
  en 15.6, incluidos 10 ataques por la API. Mapa y ubicacion 15 puntos, detallados en 15.7,
  con los siete estados verificados por captura. Origen y destino 26 puntos, detallados en
  15.8, incluidas las pruebas sin conexion. Cantidad de pasajeros 12 puntos, detallados en
  15.9, con el maximo verificado cambiandolo en el servidor. Creacion de solicitud 78
  comprobaciones automaticas y 21 en dispositivo, detalladas en 15.10. Modulo del conductor 64
  automaticas y 15 en dispositivo, detalladas en 15.11. D161 41 automaticas, dos carreras con
  procesos simultaneos y 15 en dispositivo, detalladas en 15.12. Fase 13, 19 automaticas con
  seis de privacidad ejecutadas como `authenticated`, la RLS de tiempo real probada con un
  cliente real, y las pruebas de dos aparatos a la vez, detalladas en 15.13. Fase 14, 24
  automaticas y 17 en dispositivo, detalladas en 15.14, con cinco de privacidad de la posicion
  del conductor y tres de regresion de E30. Fase 15, 35 automaticas repartidas en cuatro
  scripts y el ciclo completo en dispositivo, detalladas en 15.15, con la prueba del ciclo
  comprobando **las dos vistas en cada paso**. Fase 16, 50 automaticas en dos scripts y las
  cuatro pantallas en dispositivo con las dos cuentas, detalladas en 15.17, incluidos cinco
  intentos de leer lo ajeno y **el mismo servicio contrastado desde los dos lados**. Fase 17,
  73 automaticas en tres scripts, detalladas en 15.18, y **el ciclo completo del servicio
  recorrido tres veces de punta a punta** en el emulador
- **Errores pendientes:** Ninguno. **Sin verificar, todo por la misma causa —el equipo actual
  no puede producir movimiento—:** la regla de los 50 metros de R9, que la aplicacion grabe el
  rastro moviendose, y el aviso de mapa incompleto de D161. Ademas, **la restauracion del lado
  del pasajero no se vio en pantalla** (15.15). El marcador atenuado si quedo verificado en la
  Fase 15
- **Errores resueltos hasta ahora:** E1 a E33. Los veintitres ultimos, todos del asistente.
  **Fase 15, los tres encontrados al conectar la maquina de estados:** E31, **el pasajero no se
  enteraba de que el conductor habia llegado**, porque las cuatro transiciones escriben en
  `rides` y el pasajero solo escuchaba `ride_requests`; de las cuatro, solo dos tocan la
  solicitud. E32, **terminar un servicio encendia la disponibilidad** aunque el conductor la
  hubiera apagado a mano: una linea de la Fase 5 que D161 y D164 dejaron obsoleta sin que nadie
  volviera a mirarla. E33, **la distancia del viaje podia incluir el trayecto de aproximacion**,
  porque `complete_ride` sumaba todos los puntos del rastro y la politica permite grabar
  tambien yendo a recoger. **Los tres salieron de conectar y probar, no de leer el codigo.**
  **Fase 14, uno del asistente:** E30, al reescribir `request_ride` para anadirle la
  referencia se partio de la definicion de la Fase 5, cuando esa funcion se habia redefinido
  dos veces despues; la version aplicada **borro las dos comprobaciones de zona de servicio y
  la caducidad dirigida**, y estuvo asi en el servidor unos minutos. Se corrigio con una sola
  correccion, se verifico contra el servidor y **se anadieron tres pruebas de regresion** para
  que no pueda repetirse en silencio.
  **Fase 12, los dos del asistente:** E28 el conductor de prueba **no podia iniciar sesion**,
  porque el archivo de semilla dejaba cuatro columnas de token en nulo y GoTrue no lo admite;
  no se detecto en la Fase 11 porque nunca hizo falta que entrara, y en la 12 es lo primero que
  se necesita. E29 la burbuja del temporizador se desbordaba cuando el numero pasaba de dos
  digitos, y salio al subir un parametro **que la empresa puede cambiar**: con los veinte
  segundos de R2 nunca habria aparecido.
  **Fase 11, los tres del asistente:** E25 `cancel_request` llevaba rota desde la Fase 5 por
  una conversion de tipo ausente en un CASE, es decir, **cancelar una solicitud nunca habia
  funcionado**, y no se detecto porque las pruebas de la Fase 5 cubrieron lo que la base de
  datos debe rechazar y no el camino feliz de cada funcion; E26 el error del servidor no
  caducaba al corregir el viaje, asi que quien arreglaba el punto de recogida seguia leyendo
  que estaba fuera de zona; E27 la cuenta atras se reiniciaba segun el valor y no segun la
  solicitud, con lo que "Volver a pedirlo" habria estado roto siempre en produccion, creando
  solicitudes reales que el pasajero no veia. **Los tres salieron de usar la aplicacion, no de
  leer el codigo.**
  Los catorce anteriores, tambien del asistente.
  **Fase 10, los dos del asistente:** E23 el resumen del viaje cortaba el boton "Continuar"
  en el telefono, porque las alturas de la hoja eran una fraccion de la pantalla y no del
  contenido; ya rozaba el limite antes de esta fase y el selector lo empujo fuera. E24 se
  retiro el boton "Cambiar de destino" alegando que era redundante con el "Cambiar" de la
  fila del destino, y era falso: aquel descartaba el viaje entero y este solo abre el
  buscador, asi que el pasajero se quedo sin forma de echarse atras. **Lo detecto el usuario
  preguntando donde habia quedado, no las pruebas.**
  Los doce anteriores, tambien del asistente.
  **Fase 9, los cuatro del asistente, todos encontrados probando en el dispositivo y ninguno
  leyendo el codigo:** E19 el buscador vaciaba la lista y se callaba cuando Mapbox fallaba,
  con lo que el pasajero leia "no encontramos ese sitio" ante un problema de red; E20 salian
  destinos de Anori y Campamento con el mismo aspecto que los de Amalfi, y un pasajero podia
  mandar al conductor veinte kilometros fuera sin enterarse; E21 el mapa del selector abria
  en un sitio u otro segun quien ganara la carrera entre el GPS y el mapa, que es E16 otra
  vez; E22 con el teclado abierto habia que tocar **dos veces** para elegir un resultado,
  porque el primer toque se gastaba en cerrar el teclado.
  Los ocho anteriores, tambien del asistente.
  **Fase 8, los cuatro del asistente:** E15 dar una huella SHA-1 equivocada por suponer que
  Gradle usa el keystore del sistema, cuando Expo trae el suyo dentro del proyecto, con el
  sintoma de un mapa en blanco sin ningun error en el log; E16 mover la camara antes de que
  el mapa nativo estuviera listo, orden que se descarta en silencio, agravado por marcar el
  centrado como hecho sin comprobar que se ejecuto; E17 el teclado tapando el bottom sheet,
  con la causa en una suposicion de la Fase 3 sobre `adjustResize` que dejo de ser cierta,
  **encontrado por el usuario y no por las pruebas**; E18 un `featureType` inexistente que
  anulaba el estilo completo del mapa. Ademas, en E18 se habia aplicado antes un cambio sobre
  una hipotesis equivocada, que se retiro al encontrar la causa real en lugar de dejarlo
  puesto por si acaso.
  Los cuatro anteriores, tambien del asistente.
  En la Fase 6, ambos en pruebas y no en codigo: E11 preparar un bloqueo con el rol
  privilegiado, que el disparador revierte, produciendo un fallo falso; E12 llamar a
  `request_ride` con un entero donde va un `smallint`, que hizo que una prueba saliera **en
  verde por el motivo equivocado**. En la Fase 7, ambos en codigo: E13 leer la imagen con
  `fetch`, que en React Native no lee direcciones `file://` y subio un archivo de catorce
  bytes sin que nada protestara; E14 reemplazar la foto con un nombre de archivo fijo, con lo
  que la aplicacion seguia mostrando la anterior desde la cache mientras el servidor ya tenia
  la nueva. Un verde falso es peor que un rojo, y una pantalla que miente es peor que un error
  visible
- **Hallazgos cerrados en la Fase 12:** H12, la antiguedad maxima de la ubicacion ya se lee de
  `app_settings`. H13, con D160 se ofrece a todos, y un barrido periodico alcanza ademas a
  quien se conecta despues de crearse la solicitud
- **Hallazgos resueltos:** H1 .gitignore no protegia .env. H2 licencia MIT de Expo.
  H3 cabecera de expo-router sin tema. H4 Expo Go desactualizado en la tablet.
  H5 `profiles_protect_columns` no exime al rol privilegiado. H6 la API de Auth rechaza los
  correos `@motomoto.test`. H9 `adjustResize` dejo de encoger la ventana con el modo de
  borde a borde, corregido en `BottomSheet` y documentado en `Screen`
- **Hallazgos abiertos:** **H21 NUEVO, del 2026-08-25, y es una pregunta para la empresa mas
  que un fallo.** `accept_ride_offer` hace `is_available = (is_available and v_free > 0)`, o
  sea que **un conductor que llena el motorraton queda marcado como no disponible**, y
  `find_available_drivers` filtra por esa columna antes de contar asientos. Resultado: **a un
  motorraton lleno de pasajeros nunca se le ofreceria una encomienda**, aunque D220 diga que la
  carga va en la parrilla y no quita puesto. La aritmetica de asientos si funciona — esta
  medido en la comprobacion 29 de `prueba_solicitud_con_valor.sql` —; lo que corta es la
  columna. **No se toco a proposito**: cambiar la disponibilidad afecta a los caminos vivos de
  las fases 13 y 14, y ademas hay que preguntarle a la empresa si un motorraton con tres
  personas debe poder llevar ademas un bulto. La comprobacion 30 deja medido el comportamiento
  de hoy. H10 el indice unico de `places` normaliza mayusculas y espacios de
  los extremos pero no los del medio, asi que "El  parque" con dos espacios entraria como un
  lugar distinto; importara cuando el administrador pueda crearlos desde el panel (Fase 20).
  **H15 DECIDIDO, se cierra en la Fase 22.** `shares_ride_with` no filtra por estado, asi que
  **una vez que un conductor lleva a alguien puede leer su nombre y su telefono para siempre**,
  y `driver_linked_to_request` deja igual de expuesto `contact_phone` de cualquier solicitud
  que se le llegara a ofrecer. En la Fase 16 se decidio no tocarlo todavia (D203): arreglarlo
  bien obliga a que el telefono deje de ser una columna legible y pase a viajar solo por
  funciones que comprueban el estado, y eso toca los caminos vivos de las fases 12 a 14, que
  no se pueden volver a verificar con un solo emulador y sin movimiento. **Lo que si esta
  hecho:** los comentarios de las dos funciones y de la politica ya dicen la verdad, y ninguna
  pantalla del historial ensena el telefono ni el nombre de quien no llevo. El plan de cierre,
  en cuatro pasos, esta escrito en `20260819223000_h15_comment_tells_the_truth.sql`.
  **H20 RESUELTO** en la Fase 17, y lo encontro la tablet: **la aplicacion se quedaba en
  "Cargando" para siempre al arrancar** si la peticion del perfil no respondia ni fallaba, que
  es lo que hace una red que va y viene. Sin error, sin reintentar y sin salida. La pantalla de
  entrada ya sabia enseñar el error y ofrecer las dos cosas desde la Fase 6; lo que faltaba era
  que el error llegara a existir. Ahora esas dos peticiones del arranque tienen tope de 15 s
  (`conLimite` en `features/auth/session.tsx`). Medido en la tablet: con la red bien el perfil
  llega en 1,4 s, asi que el tope no estorba. **En el emulador no salio nunca**: hizo falta un
  aparato real con una red de verdad.
    **H19 RESUELTO** en la Fase 16: **sin conexion, ninguna pantalla decia "sin conexion"**. La
  lista de textos de red buscaba `failed to fetch` y el mensaje real de Android es
  `fetch failed: java.net.UnknownHostException`, que es lo mismo escrito al reves. Afectaba a
  toda la aplicacion desde la Fase 6, y no se vio antes porque nadie habia apagado la red y
  mirado la pantalla. Corregido en `features/ride/errors.ts` y `features/auth/errors.ts`.
  **H16** `find_available_drivers` **no tiene radio de corte**: la distancia solo se usa para
  ordenar. Un conductor en Medellin es candidato para un viaje en Amalfi, a 130 km, y se vio en
  pantalla durante las pruebas. En la Fase 5 se decidio asi razonando que "Amalfi cabe
  holgadamente en el radio que habriamos puesto", dando por hecho que todos los conductores
  estan dentro del municipio. Conviene decidir si eso debe seguir siendo cierto.
  **H18 RESUELTO** con el cambio a Mapbox (seccion 15.16). Decia: **la ruta se calcula con
  Mapbox y se dibuja sobre un mapa de Google, y en Amalfi los dos no coinciden.** Lo vio el usuario: la linea cruzaba manzanas vacias y los puntos no caian
  donde debian. Se comprobo renderizando la MISMA ruta con las MISMAS coordenadas sobre el mapa
  de Mapbox: cada tramo cae sobre una calle. Mapbox dice que pasa por Calle 17, Carrera 23 y
  168 m de una via sin nombre; Google dibuja esa zona casi vacia. No es el estilo propio, que
  solo apaga puntos de interes. Encaja con lo que ya sabiamos desde la Fase 8: de 39 sitios
  reales de Amalfi, Mapbox acerto 22 y Google 13. **Se resuelve pasando el mapa a Mapbox**, ya
  aprobado por el usuario para justo despues de la Fase 15.
  **H17** `AMALFI_CENTER`, la vista inicial del mapa, esta a **353 metros del parque**. D122 la
  documenta como "Parque de Amalfi (6,9047 / -75,0767)", pero la tabla de lugares tiene el
  parque en 6,907392 / -75,074987. **Lo encontro el usuario mirando la pantalla**, al ver que
  el punto de una prueba no caia donde esta el parque. Solo afecta a donde abre el mapa cuando
  todavia no hay ubicacion, asi que no rompe nada, pero la justificacion escrita de D122 —"el
  parque dice donde opera el servicio"— hoy no se sostiene. Decidir cual de las dos
  coordenadas es la buena, que es cosa de quien conoce Amalfi.
  **H14** los pares de color de estado del sistema de diseno no llegan al contraste minimo de
  4,5:1. El de error quedo corregido en la Fase 11 con el token `onDangerSubtle`, pero siguen
  bajo minimos exito, aviso e informacion, y el error **dentro de un campo**, que usa `danger`
  sobre la superficie y en oscuro da 3,08:1: por debajo del estandar aunque legible.
  H7 el navegador de Android no entrega el enlace de recuperacion a
  la app, aceptado por D95 y a resolver en la Fase 25. H8 los 21 mensajes de las funciones de
  la base de datos estan escritos sin tildes, contra D56
- **Commits:** 21a12b7 inicial, 8ad6705 configuracion, 442e7ce licencia,
  d52d7a7 sistema de diseno, 06588b8 navegacion, 1c415ba ancho en pantallas grandes,
  3c4f30e base de datos, e4a8648 estado de la Fase 6, b6f92e6 autenticacion y perfil,
  1850acf mapa principal con permisos y estados de ubicacion,
  bf58d19 seleccion de origen y destino con los lugares de Amalfi,
  3490d35 selector de pasajeros y hoja ajustada al contenido,
  fe6c852 estado de la Fase 12 y la decision de recoger en ruta,
  154711f recoger pasajeros en ruta (D161),
  1f16df6 asignacion en tiempo real de las dos partes (Fase 13),
  d2ec67d seguimiento del conductor en el mapa del pasajero (Fase 14),
  1c2e465 aprobacion de la Fase 14 en el documento
- **Datos de prueba que quedaron en el servidor:** nueve solicitudes de la cuenta del usuario,
  una cancelada y ocho caducadas, todas de "Alto de la Virgen" a "El parque". Se dejaron a
  proposito, porque borrarlas no se deshace y sirven para probar el historial de la Fase 16.
  Ademas dos cuentas de prueba: `conductor.prueba@motomoto-qa.co`, que es la semilla, y
  `fase11.auth@motomoto-qa.co`, creada para poder cerrar sesion en el emulador sin pedirle la
  contrasena al usuario. **Al cerrar la Fase 14 no quedo nada mas**: los servicios de prueba se
  cancelaron por la funcion real y los parametros volvieron a 30, 10 y 20
- **Proximo paso autorizado:** Ninguno. La Fase 18 esta pendiente de autorizacion

### Estado del equipo ahora mismo

Para no rehacer trabajo ya hecho al retomar en otra conversacion:

- **El cliente de desarrollo esta instalado** en la tablet `HVA59QB5` y en el emulador
  `motomoto_phone`. No hay que compilar nada salvo que se toque codigo nativo o se anada una
  libreria
- **Las claves estan en `C:\dev\motomoto\.env`**: la de Google Maps para Android, la de
  pruebas de Google para el PC, el token de Mapbox y sus dos variantes. Ese archivo no sube
  al repositorio y no hay que pedirselas al usuario otra vez
- La base de datos tiene los 36 lugares cargados y `max_passengers_per_request` en 3
- Existe `C:\dev\ubicar-amalfi.html`, el mapa de un solo uso con el que se marcaron los 16
  sitios que ningun proveedor conoce. Sirve para anadir mas lugares mientras no exista el
  panel. Se puede borrar sin consecuencias
- El servidor de desarrollo se arranca con `npx.cmd expo start --dev-client`. Si la aplicacion
  se queda en la pantalla de inicio del cliente, hay que hacer `adb reverse` y abrirla con el
  enlace `motomoto://expo-development-client/?url=...` de la seccion 17

### Lo que desaparecio en la Fase 11

- El `onPress={() => {}}` del boton del resumen. Ahora crea la solicitud de verdad, y el boton
  se llama "Confirmar servicio" en lugar de "Continuar", porque ya no continua a ningun sitio:
  compromete algo
- `src/features/auth/form-error.tsx`, movida a `src/components/ui/`. No tenia nada de
  especifico de autenticacion y la carpeta de viajes tambien la necesitaba
- El pendiente sobre si mostrar los mensajes de la base de datos o traducirlos, abierto desde
  la Fase 6. Se traducen desde el codigo del `hint` (D155)

### Lo que desaparecio en la Fase 10

- El boton "Cambiar de destino" a pie de hoja. Su funcion no desaparecio: vive ahora en el
  aspa de la cabecera (D148), que no gasta alto y se ve con el panel bajado
- Las alturas fijas en fracciones para el resumen del viaje, sustituidas por la medida real
  del contenido (D145)

### Lo que desaparecio en la Fase 9

- El "Parque principal" de mentira que mostraba la hoja del pasajero. Ahora la lista sale de
  la base de datos
- El campo de texto real dentro de la hoja, sustituido por un boton con su aspecto (D139)

### Lo que desaparecio en la Fase 8

- **Expo Go.** Ya no se usa. El mapa es codigo nativo y Expo Go no puede incorporarlo. En su
  lugar hay un cliente de desarrollo propio, compilado en local
- `app.json`, sustituido por `app.config.ts`
- El marcador de posicion del mapa en `src/app/passenger/index.tsx`, aquel texto que decia
  "El mapa de Amalfi se integra en la Fase 8"

### Lo que sigue siendo temporal

- El vehiculo del panel del conductor, "Motorraton 12 / Placa ABC12". Sale de la base de
  datos en la Fase 12
- El borrador del viaje se pierde si la aplicacion se cierra del todo (D137). Eso sigue
  siendo asi y es correcto: lo que si se restaura desde la Fase 11 es la solicitud ya enviada,
  que vive en el servidor
- Que un conductor acepte todavia no se entera nadie. El panel dice "buscando" hasta que
  caduca, porque el tiempo real es de la Fase 13

### Lo que desaparecio en la Fase 6

- La sesion simulada en memoria de `src/features/auth/session.tsx`. Su interior es ahora
  Supabase Auth y **la forma exportada no cambio**: ninguna guardia ni pantalla hubo que
  tocar, que era el objetivo de D69. Lo unico que se retiro fue `signInAs`
- El bloque MODO DESARROLLO de `src/app/(auth)/welcome.tsx`, con los dos botones de acceso
  directo por rol. Se adelanto desde el paso 6.8 porque no podia convivir con la sesion real

### Lo que desaparecio en la Fase 7

- Las rutas `/catalog` y `/catalog/sheet`, el catalogo del sistema de diseno, retiradas
  segun D73. Con ellas se fue el panel de estado de conexion que vivia dentro
- Nada mas apuntaba a esas rutas, asi que no quedaron enlaces roted. El unico componente que
  se quedo sin usar es `Skeleton`, que es parte del sistema de diseno y hara falta en cuanto
  haya listas que carguen

### Lo que sigue siendo temporal

- El vehiculo del panel del conductor, "Motorraton 12 / Placa ABC12", que es dato de ejemplo.
  Sale de la base de datos en la Fase 12

---

## 16. PENDIENTES CONOCIDOS

- **Telefono Android con GPS y datos moviles. Ya no es un pendiente de la Fase 23: es el unico
  camino para cerrar cosas de la 14.** La tablet ya no esta, y Fake GPS solo entrega la
  posicion al arrancar la aplicacion, asi que **no hay forma de probar nada que dependa de un
  aparato en movimiento**: la regla de los 50 metros de R9, el marcador del pasajero moviendose
  de verdad, y el recorrido historico que viene en la Fase 15
- **Recuperar el ancho de 800 dp para las pruebas.** Se simula con `adb shell wm size` y
  `wm density`, o con un AVD de tablet. Desde la Fase 4 se probaba en los dos anchos por D76, y
  la Fase 14 se cerro solo con 411 dp
- **Los scripts de prueba no estan en el repositorio.** `prueba_capacidad.sql`,
  `prueba_asientos.sql`, `prueba_ciclo.sql`, `prueba_interruptor.sql`, `prueba_referencia.sql`
  `prueba_posicion.sql`, `prueba_transiciones.sql`, `prueba_recorrido.sql`,
  `prueba_paradas.sql` y `prueba_ciclo_completo.sql` viven en carpetas temporales, pero los checklists de regresion de las
  secciones 15.12 y 15.14 los nombran como si estuvieran a mano. **Hoy esa lista apunta a
  archivos que nadie tiene.** Recogerlos en `supabase/dev-tools/` antes de la Fase 23
- **Revocar `anon` en las funciones que faltan** (Fase 22). En la Fase 15 se cerro para las
  cuatro transiciones; quedan `accept_ride_offer`, `reject_ride_offer`, `cancel_request` y
  `rate_ride`, ademas de varias funciones de disparador que no deberia poder llamar nadie
- **Decidir la coordenada del parque (H17).** `AMALFI_CENTER` esta a 353 m del parque que dice
  la tabla de lugares, y D122 la documenta como el parque
- Conectividad de datos durante las pruebas de campo en Amalfi. Sin ella el dispositivo
  obtiene su posicion por GPS pero no puede enviarla al servidor
- Titular de los derechos del software. El archivo LICENSE dice "Todos los derechos
  reservados" pero no nombra a nadie. Falta decidir si el codigo pertenece al desarrollador
  o a la empresa de motorratones, y anadir ese nombre (antes de la Fase 25)
- Nombre comercial definitivo e identidad de marca (antes de la Fase 25)
- **Nombre visible de la aplicacion.** Android muestra "motomoto" en minusculas en el dialogo
  de permisos y bajo el icono, porque es el nombre tecnico del proyecto. Se corrige junto al
  nombre comercial (D1, Fase 25)
- **Permisos heredados de las herramientas:** `RECORD_AUDIO` y `SYSTEM_ALERT_WINDOW` entran
  en el manifest por el cliente de desarrollo y el selector de fotos. Hay que revisarlos
  antes de publicar, porque Google Play pregunta por ellos (Fase 25)
- **Vigilar el consumo del buscador.** Search Box trae 500 sesiones gratis al mes y no hay
  alternativa: la API barata no conoce Amalfi (D126). Con las tres medidas puestas (testigo
  por busqueda, pausa de 400 ms y la lista de lugares primero) deberia sobrar para el piloto,
  pero conviene mirar el consumo real en Mapbox tras el primer mes de uso (Fase 24)
- **Condiciones de uso de Mapbox sobre un mapa de Google.** Sus terminos restringen mostrar
  datos de Mapbox sobre un mapa base de otro proveedor, y aqui el mapa lo dibuja Google (D110)
  mientras la ruta la calcula Mapbox (D149). Venia ocurriendo desde la Fase 11 con el tiempo
  estimado; con D161 la ruta se dibuja y es mas visible. No bloquea nada hoy y esto no es una
  lectura legal, pero conviene mirarlo antes de publicar (Fase 26)
- **Peticiones de ruta por oferta.** Cada oferta pide su trazado mas el de cada viaje en curso.
  Con el cupo de 100.000 al mes sobra para el piloto, pero es la primera vez que una pantalla
  hace varias llamadas a Directions a la vez y conviene medirlo con uso real (Fase 24)
- **Ampliar la lista de lugares.** Los 36 actuales son el arranque. Hay 16 sitios del
  municipio que ningun proveedor conoce y que se marcaron a mano; con el uso apareceran mas.
  Se dan de alta desde el panel (Fase 20)
- Anadir la huella SHA-1 de la clave de publicacion a la clave de Google Maps (Fase 26)
- Configuracion de un servidor de correo propio para la recuperacion de contrasena en
  produccion. El correo integrado de Supabase tiene limites bajos y no sirve para usuarios
  reales (antes de la Fase 25)
- **Enlaces de aplicacion de Android** para el correo de recuperacion, con dominio propio y
  archivo de verificacion publicado en el. Es la unica forma fiable de que el enlace abra la
  app sin pasar por el navegador (H7). Va junto al dominio, al nombre comercial y al servidor
  de correo: son la misma conversacion (Fase 25)
- Verificar la recuperacion de contrasena con esquema `motomoto://` en la primera compilacion
  real. Hoy solo se pudo probar `exp://` dentro de Expo Go, donde el navegador no entrega el
  enlace (Fase 26)
- **RESUELTO en la Fase 11.** Se decidio traducir desde el codigo del `hint` (D155). H8 deja
  de afectar al pasajero: los 21 mensajes sin tildes ya no llegan a ninguna pantalla. Los
  codigos del conductor, que son otros doce, se anaden a `src/features/ride/errors.ts` en las
  fases 12 y 13, cuando existan las pantallas que los provocan
- Terminar H14: los pares de exito, aviso e informacion siguen sin contraste suficiente, y el
  error dentro de un campo se queda en 3,08:1 en el tema oscuro. Solo se corrigio el aviso de
  error, que era el unico ilegible
- Quitar al rol `anon` el permiso de ejecutar `request_ride`. Hoy puede llamarla y la funcion
  la rechaza desde dentro; revocarlo seria una capa mas (Fase 22)
- Revisar el almacenamiento de la sesion, AsyncStorage frente a expo-secure-store (D93,
  Fase 22)
- Cerrar la sesion en los demas dispositivos al cambiar la contrasena. Supabase no lo hace por
  defecto, asi que hoy un cambio de contrasena no expulsa a quien ya estuviera dentro en otro
  telefono (Fase 22)
- Habilitar el cambio de correo cuando exista verificacion (D101, Fase 25)
- Reactivar la confirmacion de correo cuando exista servidor propio (D91, Fase 25)
- Textos legales: terminos de uso y politica de privacidad (antes de la Fase 25)
- Cuenta de Google Play Console (antes de la Fase 26)
- Definicion final de los documentos exigidos a conductores y vehiculos. En el MVP se
  arranca con documento de identidad del conductor y matricula del vehiculo
- Mecanismo de seleccion del municipio dentro de la app cuando existan varias instalaciones
  (Fase 25)

---

## 17. PROTOCOLO DE TRABAJO

1. Se avanza estrictamente por fases. No se inicia una fase sin aprobacion explicita
2. Cada fase termina en un checklist de validacion, no en la siguiente fase
3. Ante un error se congela el desarrollo: diagnostico, un solo cambio controlado,
   verificacion, y solo despues se continua
4. Toda creacion o modificacion de archivo se indica con su ruta exacta
5. Este archivo se actualiza al cerrar cada fase

### Como se ha trabajado hasta ahora, y como debe seguirse

Esto no es teoria: es lo que se ha hecho en las seis fases anteriores y lo que el usuario
espera que continue igual.

**Verificar, no suponer.** Cada paso se comprueba contra la realidad: consultando el
servidor, ejecutando la app en el emulador o en la tablet y tomando capturas de pantalla.
Una migracion no esta bien porque el SQL parezca correcto, sino porque se probo contra la
base de datos. Un componente no esta bien porque compile, sino porque se vio funcionando.

**Probar intentando romper.** Despues de cada migracion se escribe un script que intenta
violar cada restriccion a proposito y comprueba que la base de datos las rechaza. Ese
metodo encontro tres errores que ninguna revision de codigo habria detectado.

**Ante un error, parar.** Se diagnostica, se explica la causa real, se aplica una sola
correccion controlada y se verifica. No se cambian varias cosas a la vez.

**Reconocer los propios errores sin adornos.** La mayoria de los treinta errores registrados
fueron del asistente. Se dijeron claramente, con su causa y su leccion.

**Antes de cada commit:** `npm.cmd run typecheck`, `npm.cmd run lint` y
`npm.cmd run format:check`, los tres en 0.

**Comandos de trabajo mas usados:**

```powershell
npm.cmd run typecheck
npm.cmd run lint
npm.cmd run format
npx.cmd expo start --dev-client
npx.cmd supabase db push
npx.cmd supabase db query --linked "<sql>"

# Android. adb esta en %ANDROID_HOME%\platform-tools
adb devices
adb reverse tcp:8081 tcp:8081

# Abrir la app y conectarla al servidor. Con dos dispositivos, anadir -s <serie>
adb shell am start -a android.intent.action.VIEW -d "motomoto://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081" com.motomoto.app

adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png <destino>
adb shell "cmd uimode night yes"   # probar modo oscuro

# Emulador
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd motomoto_phone -gpu host
adb -s emulator-5554 emu geo fix -75.0767 6.9047   # simular el parque de Amalfi
```

**Dispositivos de prueba:** emulador `motomoto_phone` a 411 dp y tablet Lenovo
`HVA59QB5` a 800 dp. Probar en ambos anchos.

**Los comandos de adb con rutas del dispositivo van por PowerShell.** En Git Bash,
`/sdcard/...` se convierte en una ruta de Windows y `screencap` falla con su mensaje de uso.

**Aviso recurrente:** al abrir la app, el cliente de desarrollo puede quedarse en su propia
pantalla de inicio en vez de cargar el proyecto. Se resuelve con `adb reverse` y abriendo la
app con el enlace `motomoto://expo-development-client/?url=...` de arriba.

### Continuidad en una conversacion nueva

Al entregar este archivo en una conversacion nueva: leerlo completo, identificar la ultima
fase terminada y el paso actual, no repetir trabajo completado, preguntar por informacion
critica faltante y continuar desde el ultimo punto estable.

**No avanzar de fase sin autorizacion expresa del usuario, ni siquiera si parece obvio.**
