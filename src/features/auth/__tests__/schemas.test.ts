import {
  registerSchema,
  loginSchema,
  editProfileSchema,
  changePasswordSchema,
  resetPasswordSchema,
} from '../schemas';

describe('registerSchema', () => {
  const base = {
    fullName: 'Ana Restrepo',
    phone: '3001234567',
    email: 'Ana@Ejemplo.com',
    password: 'clave-larga',
    acceptedTerms: true,
  };

  it('acepta un registro bien formado y normaliza el correo a minusculas', () => {
    const r = registerSchema.parse(base);
    expect(r.email).toBe('ana@ejemplo.com');
  });

  it('recorta el nombre y exige al menos 2 caracteres', () => {
    expect(registerSchema.safeParse({ ...base, fullName: ' A ' }).success).toBe(false);
    expect(registerSchema.parse({ ...base, fullName: '  Ana  ' }).fullName).toBe('Ana');
  });

  it('acepta el telefono con espacios y guiones, y guarda solo los digitos', () => {
    expect(registerSchema.parse({ ...base, phone: '300 123 45 67' }).phone).toBe('3001234567');
    expect(registerSchema.parse({ ...base, phone: '(300) 123-4567' }).phone).toBe('3001234567');
  });

  it('rechaza un celular que no empieza por 3 o que no tiene 10 digitos', () => {
    expect(registerSchema.safeParse({ ...base, phone: '4001234567' }).success).toBe(false);
    expect(registerSchema.safeParse({ ...base, phone: '300123456' }).success).toBe(false);
  });

  it('exige contrasena de al menos 8 caracteres', () => {
    expect(registerSchema.safeParse({ ...base, password: 'corta' }).success).toBe(false);
  });

  it('exige aceptar los terminos (Fase 26 paso 3)', () => {
    expect(registerSchema.safeParse({ ...base, acceptedTerms: false }).success).toBe(false);
    const r = registerSchema.safeParse({ ...base, acceptedTerms: false });
    if (!r.success) expect(r.error.issues[0]?.path).toEqual(['acceptedTerms']);
  });
});

describe('loginSchema', () => {
  it('solo pide que la contrasena no este vacia', () => {
    expect(loginSchema.safeParse({ email: 'a@b.co', password: 'x' }).success).toBe(true);
    expect(loginSchema.safeParse({ email: 'a@b.co', password: '' }).success).toBe(false);
  });
});

describe('editProfileSchema', () => {
  it('comparte los validadores del registro', () => {
    expect(editProfileSchema.safeParse({ fullName: 'Ana', phone: '3001234567' }).success).toBe(
      true,
    );
    expect(editProfileSchema.safeParse({ fullName: 'Ana', phone: '123' }).success).toBe(false);
  });
});

describe('changePasswordSchema', () => {
  const ok = {
    currentPassword: 'la-actual',
    password: 'la-nueva-8',
    confirmPassword: 'la-nueva-8',
  };

  it('acepta cuando las dos nuevas coinciden y son distintas de la actual', () => {
    expect(changePasswordSchema.safeParse(ok).success).toBe(true);
  });

  it('rechaza si las dos nuevas no coinciden, sobre confirmPassword', () => {
    const r = changePasswordSchema.safeParse({ ...ok, confirmPassword: 'otra-cosa' });
    expect(r.success).toBe(false);
    if (!r.success) expect(r.error.issues[0]?.path).toEqual(['confirmPassword']);
  });

  it('rechaza si la nueva es igual a la actual, sobre password', () => {
    const r = changePasswordSchema.safeParse({
      currentPassword: 'misma-clave',
      password: 'misma-clave',
      confirmPassword: 'misma-clave',
    });
    expect(r.success).toBe(false);
    if (!r.success) expect(r.error.issues[0]?.path).toEqual(['password']);
  });
});

describe('resetPasswordSchema', () => {
  it('pide la contrasena dos veces y que coincidan', () => {
    expect(
      resetPasswordSchema.safeParse({ password: 'clave-nueva', confirmPassword: 'clave-nueva' })
        .success,
    ).toBe(true);
    expect(
      resetPasswordSchema.safeParse({ password: 'clave-nueva', confirmPassword: 'distinta' })
        .success,
    ).toBe(false);
  });
});
