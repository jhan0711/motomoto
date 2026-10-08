# Textos legales — BORRADOR

**Estos dos documentos son un borrador de partida. NO están revisados por un
abogado y NO deben publicarse tal cual.** Fase 25, paso 4 (2026-09-02).

- `politica-de-privacidad.md` — tratamiento de datos, Ley 1581 de 2012 y Decreto
  1377 de 2013 (Colombia).
- `terminos-de-uso.md` — condiciones de uso de la aplicación.

## Lo que un abogado tiene que decidir antes de publicar

Marcado en el texto como **[REVISAR]**. Lo principal:

1. **Naturaleza del servicio.** ¿AmalfiGoApp es una plataforma de intermediación
   entre pasajeros y conductores, o presta el servicio de transporte? El
   mototaxismo tiene un tratamiento legal particular en Colombia; esta decisión
   cambia la responsabilidad, los seguros exigibles y hasta si la app se puede
   publicar sin más.
2. **Quién es el responsable del tratamiento de datos.** El borrador pone a Jhan
   Carlo Roldán Sepúlveda (titular del software y quien publica la app). Si hay
   una empresa de mototaxis que opera el servicio, puede que el responsable sea
   la empresa y Jhan el encargado/proveedor tecnológico, o que haya dos
   responsables. Hay que aclarar esa relación.
3. **Limitación de responsabilidad** por accidentes, conducta del conductor,
   pérdida de encomiendas, exactitud de las tarifas y del mapa.
4. **Seguros.** Qué cobertura exige la ley al conductor / al vehículo, y qué se
   le dice al pasajero sobre eso.
5. **Transferencia internacional de datos.** Supabase, Mapbox, Google y Resend
   almacenan o procesan datos fuera de Colombia. Hay que declarar la
   transferencia y su base legal.
6. **Canal de atención y dirección física.** La Ley 1581 exige un medio para que
   el titular ejerza sus derechos. Falta el correo definitivo (va con el dominio)
   y, si la ley lo pide, una dirección.
7. **Datos de menores de edad** y de los conductores (documento de identidad).
8. **Registro Nacional de Bases de Datos (RNBD)** ante la SIC: si aplica por el
   tamaño de la operación.

## Cambios del 2026-10-08 — aprobados por el abogado

Los textos de septiembre ya los revisó el abogado, y esta actualización
(`politica-de-privacidad.md`) también la aprobó (2026-10-08) y se publicó. Qué
cambió y por qué:

1. **Pagos (sección 2.3).** Decía "la aplicación no procesa pagos". Ya no es
   cierto: los conductores recargan saldo por Wompi (D279). Ahora dice que el
   viaje se paga en efectivo, que la app nunca recibe datos de tarjeta y qué se
   guarda de una recarga (valor, fecha, estado, referencia).
2. **Ubicación en segundo plano del conductor (2.2).** La política hablaba solo
   de "mientras la aplicación está abierta". Los conductores la envían también
   minimizada, solo estando "disponibles" o en un servicio (D116, D271).
3. **Saldo y movimientos (2.2, finalidad 7, sección 8).** Dato y finalidad
   nuevos. Se dice que los registros de recargas, comisiones y ajustes **no se
   borran** (el libro `driver_ledger` solo admite añadir filas): **[REVISAR]**
   si eso es defendible frente a una solicitud de supresión de un conductor.
4. **Wompi y Apple como terceros (sección 5).** Wompi procesa las recargas y
   trata los datos de pago bajo su propia política. Apple entrega las
   notificaciones en iPhone.
5. **Eliminar la cuenta (sección 6).** Decía "escribir al correo". Los
   pasajeros pueden hacerlo en la app y en `amalfigo.app/eliminar-cuenta`; los
   conductores, por el correo, porque su cuenta la gestiona la empresa.
6. **Datos que el usuario escribe (2.1)** y **valor ofrecido/acordado** en el
   historial (D277): referencia de recogida, descripción de una encomienda.

**Falta, y no se tocó:** `terminos-de-uso.md` tampoco habla de la comisión ni
del saldo del conductor. Hay que decidir con el abogado si va ahí.
