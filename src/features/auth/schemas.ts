import { z } from 'zod';

/**
 * Validaciones de los formularios de autenticacion.
 *
 * Estas reglas replican a proposito las restricciones de la base de datos. Si
 * fueran mas permisivas, el registro fallaria en el servidor con un error que el
 * usuario no puede entender ni corregir; si fueran mas estrictas sin motivo,
 * rechazariamos datos que el sistema acepta.
 *
 * Nada de lo que hay aqui es una medida de seguridad: es ayuda al usuario. La
 * seguridad real vive en las restricciones de la tabla y en las politicas RLS.
 */

// Restriccion equivalente en la base de datos: profiles_full_name_length,
// entre 2 y 120 caracteres una vez recortados los espacios.
const fullName = z
  .string()
  .trim()
  .min(2, { error: 'El nombre debe tener al menos 2 caracteres.' })
  .max(120, { error: 'El nombre no puede superar los 120 caracteres.' });

// El correo se guarda en minusculas. Supabase ya trata el correo sin distinguir
// mayusculas, pero normalizarlo aqui evita que el mismo usuario vea su correo
// escrito de dos formas distintas segun como lo tecleo ese dia.
const email = z
  .string()
  .trim()
  .toLowerCase()
  .pipe(z.email({ error: 'Escribe un correo electrónico válido.' }));

/**
 * Telefono movil colombiano: diez digitos que empiezan por 3.
 *
 * Se aceptan espacios, guiones y parentesis al teclear y se descartan antes de
 * validar, porque la gente escribe su numero como quiere y rechazarlo por un
 * espacio seria absurdo. Lo que se guarda son siempre diez digitos limpios.
 *
 * Es obligatorio desde el registro (D92): el backend exige telefono para poder
 * solicitar un servicio, y pedirlo mas tarde dejaria cuentas que existen pero no
 * pueden usar la aplicacion.
 */
const phone = z
  .string()
  .trim()
  .transform((value) => value.replace(/\D/g, ''))
  .refine((value) => /^3\d{9}$/.test(value), {
    error: 'Escribe un número de celular colombiano de 10 dígitos.',
  });

// Ocho caracteres. El proyecto de Supabase acepta seis; aqui somos algo mas
// estrictos, que es seguro en esta direccion. Nunca al reves.
const newPassword = z
  .string()
  .min(8, { error: 'La contraseña debe tener al menos 8 caracteres.' })
  .max(72, { error: 'La contraseña no puede superar los 72 caracteres.' });

export const registerSchema = z.object({
  fullName,
  phone,
  email,
  password: newPassword,
});

/**
 * En el inicio de sesion la contrasena solo se comprueba que no este vacia.
 *
 * Validar aqui su longitud le diria a quien lo intenta que esa contrasena no
 * puede ser la correcta, y ademas dejaria fuera a cuentas creadas cuando la
 * regla era otra.
 */
export const loginSchema = z.object({
  email,
  password: z.string().min(1, { error: 'Escribe tu contraseña.' }),
});

/**
 * Edicion del perfil.
 *
 * Comparte a proposito los mismos validadores que el registro. Si aqui fueran
 * mas laxos, se podria dejar por edicion un perfil que el registro habria
 * rechazado, y el resultado seria una cuenta que existe pero no puede pedir un
 * servicio porque el backend exige telefono valido.
 *
 * El correo no esta: no se edita en el MVP (D91).
 */
export const editProfileSchema = z.object({ fullName, phone });

/**
 * Cambio de contrasena desde dentro de la aplicacion.
 *
 * Pide la contrasena actual, y Supabase no la exige. Sin ella, un telefono
 * desbloqueado durante un minuto es una cuenta perdida: cualquiera podria
 * cambiar la contrasena y quedarse con ella. Cuesta una llamada de mas.
 *
 * Tambien se comprueba aqui que la nueva no sea igual a la actual, para no
 * gastar un viaje al servidor en decir algo que se sabe desde el formulario.
 */
export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, { error: 'Escribe tu contraseña actual.' }),
    password: newPassword,
    confirmPassword: z.string(),
  })
  .refine((values) => values.password === values.confirmPassword, {
    error: 'Las dos contraseñas no coinciden.',
    path: ['confirmPassword'],
  })
  .refine((values) => values.password !== values.currentPassword, {
    error: 'La contraseña nueva es igual a la actual.',
    path: ['password'],
  });

export const forgotPasswordSchema = z.object({ email });

/**
 * Contrasena nueva, al final del enlace de recuperacion.
 *
 * Se pide dos veces porque aqui no existe la red de seguridad habitual: quien
 * llega a esta pantalla no recuerda su contrasena, asi que una errata al teclear
 * la nueva lo dejaria fuera otra vez y sin forma de darse cuenta.
 */
export const resetPasswordSchema = z
  .object({
    password: newPassword,
    confirmPassword: z.string(),
  })
  .refine((values) => values.password === values.confirmPassword, {
    error: 'Las dos contraseñas no coinciden.',
    path: ['confirmPassword'],
  });

export type ChangePasswordValues = z.output<typeof changePasswordSchema>;
export type EditProfileValues = z.output<typeof editProfileSchema>;
export type RegisterInput = z.input<typeof registerSchema>;
export type RegisterValues = z.output<typeof registerSchema>;
export type LoginValues = z.output<typeof loginSchema>;
export type ForgotPasswordValues = z.output<typeof forgotPasswordSchema>;
export type ResetPasswordValues = z.output<typeof resetPasswordSchema>;
