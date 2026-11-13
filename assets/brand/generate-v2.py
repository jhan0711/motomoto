"""
Genera los iconos y la pantalla de arranque con el LOGO NUEVO (2026-11-13).

    python assets/brand/generate-v2.py

Fuente: `assets/brand/logo-v2/AmalfiGoApp_Icono_1024.png`, el icono que entrego el
diseno (App_Store_Icon_1024x1024). Trae un marco oscuro (#14171A) alrededor de un
cuadrado blanco redondeado con el dibujo. iOS y Android redondean las esquinas
por su cuenta, asi que dejar el marco se veria como "una ficha dentro de otra
ficha". Aqui se descarta el marco y se usa el cuadrado blanco A SANGRE.

Sustituye a `generate.mjs`, que partia del logo anterior (el escudo, en SVG).

Salidas, todas en `assets/images/`:
  icon.png                       1024, RGB. Icono de la app y logo de la bienvenida.
  ios-icon.png                   1024, RGB sin alfa (App Store).
  android-icon-foreground.png    1024, el dibujo dentro de la zona segura (66 %), sobre blanco.
  android-icon-monochrome.png    1024, silueta para los iconos con tema (Android 13+).
  splash-icon.png                1024, la ficha blanca redondeada, fondo transparente.
  favicon.png                    48.
El fondo del icono adaptativo (`#FFFFFF`) y el de la pantalla de arranque
(`#14171A`) estan en `app.config.ts`.

Solo usa Pillow (no hace falta numpy).
"""
import os
from PIL import Image, ImageChops, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = os.path.join(AQUI, 'logo-v2', 'AmalfiGoApp_Icono_1024.png')
IMAGES = os.path.normpath(os.path.join(AQUI, '..', 'images'))

BLANCO = (255, 255, 255)
CARBON = (20, 23, 26)

src = Image.open(FUENTE).convert('RGB')
assert src.size == (1024, 1024), src.size

# 1) El cuadrado blanco redondeado que hay dentro del marco oscuro.
mascara_blanca = src.convert('L').point(lambda v: 255 if v > 235 else 0)
caja = mascara_blanca.getbbox()          # (143, 143, 881, 881) en el archivo entregado
interior = src.crop(caja)

# 2) El dibujo solo: dentro del cuadrado, sin las esquinas oscuras. Se recorta un
#    cuadrado central que las evita y se busca todo lo que no sea blanco.
w, h = interior.size
margen = int(w * 0.10)
centro = interior.crop((margen, margen, w - margen, h - margen))
no_blanco = ImageChops.difference(centro, Image.new('RGB', centro.size, BLANCO)).convert('L')
no_blanco = no_blanco.point(lambda v: 255 if v > 24 else 0)
bb = no_blanco.getbbox()
dibujo = centro.crop(bb)                  # el dibujo, a su resolucion nativa
dw, dh = dibujo.size


def colocar(lienzo_px, ancho_objetivo, fondo=BLANCO):
    """El dibujo centrado en un lienzo cuadrado, ocupando `ancho_objetivo` px."""
    escala = ancho_objetivo / max(dw, dh)
    d = dibujo.resize((round(dw * escala), round(dh * escala)), Image.LANCZOS)
    lienzo = Image.new('RGB', (lienzo_px, lienzo_px), fondo)
    lienzo.paste(d, ((lienzo_px - d.size[0]) // 2, (lienzo_px - d.size[1]) // 2))
    return lienzo


# icono de la app / bienvenida / App Store: el dibujo al 66 % del lado, sobre blanco
icono = colocar(1024, 676)
icono.save(os.path.join(IMAGES, 'icon.png'))
icono.save(os.path.join(IMAGES, 'ios-icon.png'))   # RGB: sin canal alfa (Apple lo exige)

# Android adaptativo: la zona segura es el circulo central del 66 %; el dibujo cabe
# en un cuadrado de ~600 px para que ninguna mascara (circulo, gota, cuadrado) lo corte
colocar(1024, 600).save(os.path.join(IMAGES, 'android-icon-foreground.png'))

# Monocromo: la silueta. La opacidad sale de lo oscuro que es cada punto: los
# blancos (ventana, ojos) quedan huecos, el negro y el ambar quedan llenos.
mono_fuente = colocar(1024, 600)
# Se usa el canal AZUL: el blanco lo tiene a 255 (hueco), el negro y el ambar lo
# tienen casi a 0 (lleno). Con la luminosidad el ambar salia a medio tono.
azul = mono_fuente.split()[2]
alfa = azul.point(lambda v: max(0, min(255, int((255 - v) * 1.15))))
# el color de un icono monocromo lo pone el sistema: aqui va blanco
mono_rgb = Image.new('RGBA', (1024, 1024), (255, 255, 255, 0))
mono_rgb.putalpha(alfa)
mono_rgb.save(os.path.join(IMAGES, 'android-icon-monochrome.png'))

# Pantalla de arranque: la ficha blanca redondeada sobre transparente (el fondo
# oscuro lo pone `app.config.ts`).
ficha = colocar(760, 760 * 0.66 + 0)  # dibujo al 66 % dentro de una ficha de 760 px
ficha_mask = Image.new('L', (760 * 4, 760 * 4), 0)
ImageDraw.Draw(ficha_mask).rounded_rectangle((0, 0, 760 * 4 - 1, 760 * 4 - 1), radius=int(760 * 4 * 0.2237), fill=255)
ficha_mask = ficha_mask.resize((760, 760), Image.LANCZOS)
splash = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
ficha_rgba = ficha.convert('RGBA')
ficha_rgba.putalpha(ficha_mask)
splash.paste(ficha_rgba, ((1024 - 760) // 2, (1024 - 760) // 2), ficha_rgba)
splash.save(os.path.join(IMAGES, 'splash-icon.png'))

# favicon
icono.resize((48, 48), Image.LANCZOS).save(os.path.join(IMAGES, 'favicon.png'))

print('dibujo recortado:', (dw, dh), 'caja blanca:', caja)
print('listo en', IMAGES)
