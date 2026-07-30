# PROJECT_STATUS.md

Documento de continuidad del proyecto. Si se pierde el contexto de una conversacion,
este archivo contiene todo lo necesario para retomar el trabajo desde el ultimo punto estable.

- **Proyecto:** MotoMoto (nombre provisional)
- **Ultima actualizacion:** 2026-07-29
- **Fases completadas y aprobadas:** 0 definicion funcional, 1 preparacion del equipo,
  2 creacion del proyecto, 3 sistema de diseno, 4 navegacion, 5 base de datos,
  6 autenticacion
- **Fase completada pendiente de aprobacion:** 7 perfil del pasajero
- **Fase siguiente:** FASE 8 — Mapa principal (NO INICIADA)
- **Ultimo commit:** pendiente. El commit de la Fase 6 se hace desde GitHub Desktop;
  sustituir esta linea por su hash. El anterior fue 3c4f30e feat: add database schema,
  RLS policies and Supabase client
- **Carpeta del proyecto:** C:\dev\motomoto
- **Repositorio:** https://github.com/jhan0711/motomoto (privado)

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
| R7 | Viajes activos simultaneos por conductor | 1 |
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
| 7 | Perfil del pasajero | COMPLETADA, pendiente de aprobacion |
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
| Tablet fisica | Lenovo TB-X306X | Android 11, API 30, arm64-v8a. 800x1280 a 160 dpi, es decir 800 dp de ancho logico frente a los 411 dp del emulador. GPS por hardware presente. Sin tarjeta SIM. 3,85 GB de RAM. Serie HVA59QB5 |
| Expo Go en la tablet | 57.0.2 | Play Store solo ofrecia la 54.0.8. Instalado el APK oficial desde github.com/expo/expo-go-releases. minSdk=24, asi que Android 11 siempre estuvo soportado |
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

### Nota operativa: emulador con sesion en cache

Al reabrir el emulador, Expo Go restaura la ultima sesion en cache. Si vienes de otro
proyecto veras la aplicacion anterior con el aviso `Cannot connect to Expo CLI`. Solucion:

```
adb reverse tcp:8081 tcp:8081
adb shell am force-stop host.exp.exponent
adb shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:8081"
```

La redireccion de puerto por adb es mas fiable que depender de la IP de la red local, que
desde dentro del emulador no siempre es alcanzable.

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
```

Totales: **17 tablas, 46 politicas, 29 funciones**. Las 17 con seguridad de fila activa.

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
```

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

## 15.3 ESTADO ACTUAL

- **Fase actual:** Fase 6 completada y aprobada. **Fase 7 completada, pendiente de
  aprobacion**
- **Paso actual:** Ninguno en curso
- **Ultimo paso completado:** Cierre de la Fase 7. Perfil con datos reales, edicion, cambio de
  contrasena, foto por camara y galeria, y retirada del catalogo
- **Funcionalidades terminadas:** Sistema de diseno (12 componentes), navegacion por roles
  con guardias, base de datos completa con sus politicas y funciones, autenticacion completa
  con registro, login, logout, sesion persistente, recuperacion de contrasena y estados de
  cuenta, y perfil del pasajero con edicion, contrasena y foto
- **Pruebas realizadas:** Entorno 13 puntos. Proyecto 15 puntos. Diseno 15 puntos.
  Navegacion validada en emulador y tablet. Base de datos 57 verificaciones contra el
  servidor. Autenticacion 43 verificaciones, detalladas en 15.5. Perfil y foto, detalladas
  en 15.6, incluidos 10 ataques por la API
- **Errores pendientes:** Ninguno
- **Errores resueltos hasta ahora:** E1 a E14. Los cuatro ultimos, todos del asistente.
  En la Fase 6, ambos en pruebas y no en codigo: E11 preparar un bloqueo con el rol
  privilegiado, que el disparador revierte, produciendo un fallo falso; E12 llamar a
  `request_ride` con un entero donde va un `smallint`, que hizo que una prueba saliera **en
  verde por el motivo equivocado**. En la Fase 7, ambos en codigo: E13 leer la imagen con
  `fetch`, que en React Native no lee direcciones `file://` y subio un archivo de catorce
  bytes sin que nada protestara; E14 reemplazar la foto con un nombre de archivo fijo, con lo
  que la aplicacion seguia mostrando la anterior desde la cache mientras el servidor ya tenia
  la nueva. Un verde falso es peor que un rojo, y una pantalla que miente es peor que un error
  visible
- **Hallazgos resueltos:** H1 .gitignore no protegia .env. H2 licencia MIT de Expo.
  H3 cabecera de expo-router sin tema. H4 Expo Go desactualizado en la tablet.
  H5 `profiles_protect_columns` no exime al rol privilegiado. H6 la API de Auth rechaza los
  correos `@motomoto.test`
- **Hallazgos abiertos:** H7 el navegador de Android no entrega el enlace de recuperacion a
  la app, aceptado por D95 y a resolver en la Fase 25. H8 los 21 mensajes de las funciones de
  la base de datos estan escritos sin tildes, contra D56
- **Commits:** 21a12b7 inicial, 8ad6705 configuracion, 442e7ce licencia,
  d52d7a7 sistema de diseno, 06588b8 navegacion, 1c415ba ancho en pantallas grandes,
  3c4f30e base de datos. **Los de las fases 6 y 7 estan pendientes de hacerse desde
  GitHub Desktop**
- **Proximo paso autorizado:** Ninguno hasta autorizacion de la Fase 8

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

- Telefono Android con GPS y datos moviles, para las pruebas de campo del criterio de
  aceptacion 4. La tablet cubre hardware real y pantalla grande, pero no tiene SIM y no
  representa a los usuarios finales, que usaran telefonos
- Conectividad de datos durante las pruebas de campo en Amalfi. Sin ella el dispositivo
  obtiene su posicion por GPS pero no puede enviarla al servidor
- Titular de los derechos del software. El archivo LICENSE dice "Todos los derechos
  reservados" pero no nombra a nadie. Falta decidir si el codigo pertenece al desarrollador
  o a la empresa de motorratones, y anadir ese nombre (antes de la Fase 25)
- Nombre comercial definitivo e identidad de marca (antes de la Fase 25)
- Eleccion del proveedor de mapas, tras probar el autocompletado real en Amalfi (Fase 8)
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
- Decidir si la aplicacion muestra los mensajes que devuelven las funciones de la base de
  datos o los traduce desde el codigo del `hint`. Los 21 mensajes actuales estan sin tildes
  (H8), contra D56. La recomendacion es traducir desde el codigo, como ya hace `errors.ts`
  para autenticacion, para desacoplar los textos del esquema (Fase 11)
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

**Reconocer los propios errores sin adornos.** Tres de los diez errores registrados fueron
del asistente. Se dijeron claramente, con su causa y su leccion.

**Antes de cada commit:** `npm.cmd run typecheck`, `npm.cmd run lint` y
`npm.cmd run format:check`, los tres en 0.

**Comandos de trabajo mas usados:**

```powershell
npm.cmd run typecheck
npm.cmd run lint
npm.cmd run format
npx.cmd expo start
npx.cmd supabase db push
npx.cmd supabase db query --linked "<sql>"

# Android. adb esta en %ANDROID_HOME%\platform-tools
adb devices
adb reverse tcp:8081 tcp:8081
adb shell am force-stop host.exp.exponent
adb shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:8081" host.exp.exponent
adb shell screencap -p /sdcard/s.png
adb pull /sdcard/s.png <destino>
adb shell "cmd uimode night yes"   # probar modo oscuro
```

**Dispositivos de prueba:** emulador `motomoto_phone` a 411 dp y tablet Lenovo
`HVA59QB5` a 800 dp. Probar en ambos anchos.

**Aviso recurrente:** al reabrir el emulador o la tablet, Expo Go restaura la ultima
sesion en cache y muestra `Cannot connect to Expo CLI`. Se resuelve con `adb reverse`,
cerrar Expo Go y abrirlo con el enlace `exp://127.0.0.1:8081`.

### Continuidad en una conversacion nueva

Al entregar este archivo en una conversacion nueva: leerlo completo, identificar la ultima
fase terminada y el paso actual, no repetir trabajo completado, preguntar por informacion
critica faltante y continuar desde el ultimo punto estable.

**No avanzar de fase sin autorizacion expresa del usuario, ni siquiera si parece obvio.**
