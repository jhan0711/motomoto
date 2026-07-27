# PROJECT_STATUS.md

Documento de continuidad del proyecto. Si se pierde el contexto de una conversacion,
este archivo contiene todo lo necesario para retomar el trabajo desde el ultimo punto estable.

- **Proyecto:** MotoMoto (nombre provisional)
- **Ultima actualizacion:** 2026-07-26
- **Fases completadas:** FASE 0 — Definicion funcional (APROBADA), FASE 1 — Preparacion del equipo (APROBADA)
- **Fase siguiente:** FASE 2 — Creacion y organizacion del proyecto (NO INICIADA)
- **Carpeta del proyecto:** C:\dev\motomoto

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
- **Mapas:** por decidir entre Google Maps y Mapbox. Se decide en la Fase 8 tras probar
  empiricamente la calidad del autocompletado de direcciones en Amalfi
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
10. Un conductor acepta. Estado ASSIGNED. Tarjeta con foto, nombre, calificacion, placa,
    modelo y telefono del conductor
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
4. Vehiculos: alta con placa, tipo, modelo y capacidad maxima. Asignacion a un conductor
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
| R7 | Viajes activos simultaneos por conductor | 1 |
| R8 | Calificaciones por servicio y por parte | 1, no editable |
| R9 | Frecuencia de envio de ubicacion del conductor | Disponible: 30 s. En viaje: 10 s o 50 m |
| R10 | Conductor sin senal durante un viaje activo | 3 min, alerta al admin, sin cancelacion automatica |
| R11 | Maximo de pasajeros por solicitud | 3, configurable por el admin |
| R12 | Un conductor no vuelve a recibir una solicitud que ya rechazo | Controlado por ride_offers |

Los grupos de mas de 3 personas quedan fuera del MVP. La app mostrara un mensaje indicando
que deben solicitar dos servicios por separado.

---

## 10. TABLAS A DISENAR EN LA FASE 5

Ninguna tabla se crea hasta haber dibujado y aprobado el modelo entidad-relacion.

```
profiles                    Datos comunes de todo usuario y su rol
drivers                     Datos especificos del conductor y su estado de aprobacion
vehicles                    Placa, tipo, modelo y capacidad maxima de pasajeros
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
7. Un conductor bloqueado por el admin no puede iniciar sesion ni operar
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
| 2 | Creacion y organizacion del proyecto | NO INICIADA |
| 3 | Sistema de diseno | Pendiente |
| 4 | Navegacion | Pendiente |
| 5 | Supabase y base de datos | Pendiente |
| 6 | Autenticacion | Pendiente |
| 7 | Perfil del pasajero | Pendiente |
| 8 | Mapa principal | Pendiente |
| 9 | Seleccion de origen y destino | Pendiente |
| 10 | Seleccion de pasajeros | Pendiente |
| 11 | Creacion de solicitud | Pendiente |
| 12 | Modulo del conductor | Pendiente |
| 13 | Asignacion en tiempo real | Pendiente |
| 14 | Seguimiento del conductor | Pendiente |
| 15 | Ciclo completo del servicio | Pendiente |
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

## 15.1 ESTADO ACTUAL

- **Fase actual:** Fase 1 completada y aprobada. Fase 2 pendiente de autorizacion
- **Paso actual:** Ninguno en curso
- **Ultimo paso completado:** Aprobacion del checklist de validacion de la Fase 1
- **Funcionalidades terminadas:** Ninguna. No se ha escrito codigo de producto
- **Pruebas realizadas:** Validacion completa del entorno, 13 puntos
- **Errores pendientes:** Ninguno
- **Errores resueltos en la Fase 1:** E1 core.autocrlf no aplicado. E2 cmdline-tools ausente.
  E3 plataforma android-36 ausente. E4 imagen Wear OS instalada por error. E5 21 versiones
  redundantes de cmdline-tools, 2,77 GB liberados. E6 politica de ejecucion de PowerShell
- **Archivos creados:** PROJECT_STATUS.md
- **Repositorio Git:** no inicializado. Se crea en la Fase 2
- **Proximo paso autorizado:** Ninguno hasta aprobacion de la Fase 2

---

## 16. PENDIENTES CONOCIDOS

- Nombre comercial definitivo e identidad de marca (antes de la Fase 25)
- Color de marca (antes de la Fase 3)
- Eleccion del proveedor de mapas, tras probar el autocompletado real en Amalfi (Fase 8)
- Configuracion de un servidor de correo propio para la recuperacion de contrasena en
  produccion. El correo integrado de Supabase tiene limites bajos y no sirve para usuarios
  reales (antes de la Fase 25)
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

### Continuidad en una conversacion nueva

Al entregar este archivo en una conversacion nueva: leerlo completo, identificar la ultima
fase terminada y el paso actual, no repetir trabajo completado, preguntar por informacion
critica faltante y continuar desde el ultimo punto estable.
