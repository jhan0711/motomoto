import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

/**
 * Guardia de acceso del panel.
 *
 * Se llama `proxy` y no `middleware` porque Next 16 deprecio ese nombre: al
 * arrancar el servidor lo avisa. Es el mismo mecanismo, corre igual antes de
 * cada peticion.
 *
 * Hace dos cosas en cada peticion: refrescar la sesion, porque el token de
 * Supabase caduca y solo esta capa puede reescribir las cookies, y decidir si
 * quien pide la pagina puede verla.
 *
 * Igual que en la aplicacion movil (D70), la guardia vive en un solo sitio y no
 * en cada pantalla: una pantalla nueva queda protegida sin que haya que
 * acordarse. Y igual que D72, esta guardia decide QUE SE DIBUJA, no que se
 * permite: la autorizacion de verdad son las politicas RLS del servidor, que ya
 * exigen `is_admin()` desde la Fase 5. Si alguien se saltara esta comprobacion,
 * la base de datos seguiria sin devolverle una sola fila.
 */
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // `getUser` y no `getSession`: el segundo se cree lo que diga la cookie, que
  // el navegador puede haber tocado. Este pregunta al servidor de Supabase.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isLoginPage = path === '/acceso';

  if (!user) {
    if (isLoginPage) return response;
    const url = request.nextUrl.clone();
    url.pathname = '/acceso';
    return NextResponse.redirect(url);
  }

  // Hay sesion, pero una sesion de pasajero o de conductor no abre el panel.
  // El rol se lee del servidor, nunca de la cookie.
  const { data: profile } = await supabase
    .from('profiles')
    .select('role, status')
    .eq('id', user.id)
    .single();

  const isAdmin =
    (profile?.role === 'admin' || profile?.role === 'super_admin') && profile?.status === 'active';

  if (!isAdmin) {
    // Se cierra la sesion antes de devolverlo al acceso. Si no, quedaria dando
    // vueltas: con sesion abierta pero sin permiso, y sin forma de entrar con
    // otra cuenta.
    await supabase.auth.signOut();
    const url = request.nextUrl.clone();
    url.pathname = '/acceso';
    url.searchParams.set('error', 'sin_permiso');
    return NextResponse.redirect(url);
  }

  // La pantalla de administradores es solo del super admin. Un administrador
  // normal que la pida a mano vuelve al tablero. Las funciones del servidor lo
  // rechazan igual -todas comprueban `is_super_admin()`-; esto evita el
  // parpadeo de cargar una pantalla que no va a poder usar.
  if (path.startsWith('/administradores') && profile?.role !== 'super_admin') {
    const url = request.nextUrl.clone();
    url.pathname = '/';
    return NextResponse.redirect(url);
  }

  if (isLoginPage) {
    const url = request.nextUrl.clone();
    url.pathname = '/';
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  /*
   * Se excluyen los archivos estaticos y el icono: no son pantallas y
   * comprobarles la sesion solo anade una consulta por imagen.
   */
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};
