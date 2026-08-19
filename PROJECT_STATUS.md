# PROJECT_STATUS.md

Documento de continuidad del proyecto. Si se pierde el contexto de una conversacion,
este archivo contiene todo lo necesario para retomar el trabajo desde el ultimo punto estable.

- **Proyecto:** MotoMoto (nombre provisional)
- **Ultima actualizacion:** 2026-08-12
- **Fases completadas y aprobadas:** 0 definicion funcional, 1 preparacion del equipo,
  2 creacion del proyecto, 3 sistema de diseno, 4 navegacion, 5 base de datos,
  6 autenticacion, 7 perfil del pasajero, 8 mapa principal,
  9 seleccion de origen y destino, 10 seleccion de pasajeros,
  11 creacion de solicitud, 12 modulo del conductor, 13 asignacion en tiempo real,
  14 seguimiento del conductor
- **Ademas, terminado:** **D161, recoger pasajeros en ruta**, que no es una fase del plan
  original y sustituye a la regla R7. Con el se adelanto de la Fase 14 el dibujo de la ruta
- **Fase 15 terminada:** el servicio se mueve por sus cinco estados desde la pantalla del
  conductor, el pasajero ve en cual va y se despide al terminar, y el recorrido queda
  registrado. Detalle en la seccion 15.15
- **Trabajo siguiente:** **cambiar el mapa a Mapbox**, ya aprobado por el usuario para justo
  despues de la Fase 15. NO es la Fase 16. El motivo esta en el hallazgo H18: la ruta se
  calcula con Mapbox y se dibuja sobre un mapa de Google, y en Amalfi los dos no coinciden.
  Toca codigo nativo y obliga a recompilar el cliente de desarrollo
- **Ultimo commit:** 1c2e465 feat: track the driver on the passenger's map.
  **La Fase 15 esta hecha y probada pero SIN CONFIRMAR:** seis migraciones nuevas, tres
  archivos nuevos y siete modificados esperan commit, mas este documento
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

**Por donde se sigue: CAMBIAR EL MAPA A MAPBOX, y no es la Fase 16.** El usuario lo aprobo
expresamente al cerrar la Fase 15, con estas palabras: "termina la fase 15 y despues cambiamos
el mapa a Mapbox".

El motivo es el hallazgo **H18**, y esta demostrado con evidencia: **la ruta se calcula con
Mapbox y se dibuja sobre un mapa de Google**, y en Amalfi los dos no coinciden. El usuario vio
la linea cruzando manzanas vacias; se rendero la MISMA ruta, con las MISMAS coordenadas, sobre
el mapa de Mapbox y cada tramo caia sobre una calle. La ruta esta bien; el mapa de debajo es el
que le falta informacion.

Lo que implica el cambio: una libreria nativa (`@rnmapbox/maps`), **recompilar el cliente de
desarrollo** y reescribir `src/features/map/map.tsx`, que es un solo archivo justamente porque
D117 se escribio pensando en este dia. De paso cierra el pendiente de los terminos de Mapbox
sobre mapa ajeno.

**La Fase 15 esta terminada**, con su registro en la seccion 15.15. Alli estan las dos cosas
que quedaron sin verificar y por que.

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

**YA NO HAY TABLET.** Desde la Fase 14 el unico aparato es el emulador `motomoto_phone`. Eso
cambia tres cosas y conviene tenerlas presentes antes de planear una prueba:

- **No hay dos aparatos.** Para probar los dos lados hay que alternar sesiones en el mismo
  emulador, y `signOut` cierra la sesion de ese usuario en todas partes. Alternar cuesta unos
  minutos por vuelta. La alternativa que funciono bien en la Fase 14 es **manejar un lado
  desde SQL**: crear la solicitud, aceptarla o mover la posicion del conductor con
  `supabase db query`, y mirar la otra mitad en pantalla.
- **No hay ancho de 800 dp.** Se simula con `adb shell wm size` y `wm density`, o creando un
  AVD de tablet. No es una tablet, pero cubre el reparto del espacio, que es lo que se probaba.
- **No hay hardware real.** Ni SIM, ni GPS de verdad, ni conectividad de campo. Todo lo que
  dependa de eso queda pendiente de conseguir un telefono Android.

**El emulador no puede producir movimiento, y esto se comprobo a fondo en la Fase 14.** Hay un
**Fake GPS instalado** que si le da una posicion de Amalfi a la aplicacion, pero **solo la
entrega cuando el vigilante arranca**: con la aplicacion corriendo, mover el punto en Fake GPS
no le llega. Verificado midiendo la posicion enviada al servidor antes y despues de moverla, y
reiniciando la aplicacion para ver el salto. Consecuencia: **nada que dependa de un aparato que
se mueve se puede probar aqui**, y eso incluye la regla de los 50 metros de R9 y el marcador
del pasajero moviendose de verdad.

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

La plataforma NO procesa pagos y NO calcula tarifas. El pago se acuerda y se realiza fuera
de la aplicacion. La arquitectura debe permitir incorporar pagos en el futuro sin reconstruir
el sistema.

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
| D8 | Dinero | Ningun dato monetario en el MVP |
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

### Decisiones de la Fase 15

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
| D192 | Una parada por vez, sin ruta multiparada | Cada parada se navega por separado. Una ruta con paradas intermedias obliga a Google Maps, porque **Waze no las admite desde un enlace**, y eso dejaria sin efecto el selector de aplicaciones de D178 |

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
| 15 | Ciclo completo del servicio | COMPLETADA |
| 16 | Historial | Pendiente |
| 17 | Calificaciones | Pendiente |
| 18 | Cancelaciones y errores operativos | Pendiente |
| 19 | Notificaciones | Pendiente |
| 20 | Panel administrativo | Pendiente |
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
```

Totales, contados contra el servidor: **18 tablas, 47 politicas, 35 funciones**. Las 18 con
seguridad de fila activa.

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

## 15.3 ESTADO ACTUAL

- **Fase actual:** Fases 0 a 14 completadas y aprobadas, **mas D161**. **Fase 15 terminada y
  pendiente de aprobacion.** Siguiente: **cambiar el mapa a Mapbox**, ya aprobado, y despues la
  Fase 16
- **Paso actual:** Ninguno en curso. **La Fase 15 esta sin confirmar en git**: seis migraciones
  nuevas, tres archivos nuevos y siete modificados, mas este documento
- **Ultimo paso completado:** Cierre de la Fase 15. El conductor mueve el servicio por sus
  cinco estados, el pasajero ve en cual va y recibe un resumen al terminar, el recorrido queda
  registrado, y con dos o tres servicios encima ve la lista de sus paradas
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
  historico con su distancia, y la lista de paradas cuando lleva varios servicios
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
  comprobando **las dos vistas en cada paso**
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
- **Hallazgos abiertos:** H10 el indice unico de `places` normaliza mayusculas y espacios de
  los extremos pero no los del medio, asi que "El  parque" con dos espacios entraria como un
  lugar distinto; importara cuando el administrador pueda crearlos desde el panel (Fase 20).
  **H15** la politica `profiles_select_ride_counterpart` dice en su comentario "solo durante el
  servicio", y la segunda mitad se cumple pero la primera no: `shares_ride_with` no filtra por
  estado, asi que **una vez que un conductor lleva a alguien puede leer su nombre y su telefono
  para siempre**. No esta claro que la intencion escrita sea la correcta, porque en la Fase 16
  el conductor tendra un historial y ahi querra ver a quien llevo. Puede que sobre el
  comentario y no el comportamiento, o que la respuesta sea "el nombre si, el telefono no".
  Decidir en la Fase 16.
  **H16** `find_available_drivers` **no tiene radio de corte**: la distancia solo se usa para
  ordenar. Un conductor en Medellin es candidato para un viaje en Amalfi, a 130 km, y se vio en
  pantalla durante las pruebas. En la Fase 5 se decidio asi razonando que "Amalfi cabe
  holgadamente en el radio que habriamos puesto", dando por hecho que todos los conductores
  estan dentro del municipio. Conviene decidir si eso debe seguir siendo cierto.
  **H18** **la ruta se calcula con Mapbox y se dibuja sobre un mapa de Google, y en Amalfi los
  dos no coinciden.** Lo vio el usuario: la linea cruzaba manzanas vacias y los puntos no caian
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
- **Proximo paso autorizado:** **Cambiar el mapa a Mapbox**, aprobado por el usuario al cerrar
  la Fase 15. La Fase 16 va despues

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
