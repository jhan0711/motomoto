"""
Limpia la barra de estado de las capturas tomadas en un iPhone real (2026-11-10).

POR QUE. Las capturas de TestFlight llevan cosas del telefono de quien las
tomo: el icono de una reproduccion en la Dynamic Island, la bateria al 23 %, la
senal baja. Apple permite la barra de estado, pero una captura de tienda queda
mas profesional con la estandar de Apple (9:41, senal completa, bateria llena).

COMO. NO se toca el contenido de la app: solo la franja de arriba (150 px). Se
pinta con el color medio de esa franja -para que sobre un mapa no quede un
bloque de otro color-, con un degradado hacia abajo, y encima se dibuja una
barra de estado nueva. Todo lo que queda por debajo es la captura original.

USO:  python assets/brand/store-ios-clean-statusbar.py <salida> <entrada1> [entrada2 ...]
Entrada: PNG de 1320 x 2868 (iPhone 6,9"). Salida: carpeta; mismo nombre de archivo.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ANCHO, ALTO = 1320, 2868
FRANJA = 150          # alto de lo que se repinta
DEGRADADO = 40        # alto del desvanecido bajo la franja
BLANCO = (255, 255, 255)


def fuente(tam):
    for ruta in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\segoeuib.ttf"):
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tam)
    return ImageFont.load_default()


def color_medio(img):
    franja = img.crop((0, 0, ANCHO, FRANJA)).resize((1, 1), Image.LANCZOS)
    return franja.getpixel((0, 0))


def barra_de_estado(d):
    """Dibuja Dynamic Island, hora, senal, wifi y bateria."""
    cy = 75
    # Dynamic Island
    d.rounded_rectangle((ANCHO // 2 - 190, cy - 45, ANCHO // 2 + 190, cy + 45), radius=45, fill=(0, 0, 0))
    # Hora
    f = fuente(52)
    d.text((118, cy), "9:41", font=f, fill=BLANCO, anchor="lm")
    # Bateria (derecha)
    bx, by, bw, bh = 1178, cy - 19, 66, 38
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=11, outline=(255, 255, 255, 140), width=3)
    d.rounded_rectangle((bx + 5, by + 5, bx + bw - 5, by + bh - 5), radius=7, fill=BLANCO)
    d.rounded_rectangle((bx + bw + 4, cy - 8, bx + bw + 9, cy + 8), radius=2, fill=(255, 255, 255, 140))
    # Wifi
    wx, wy = 1118, cy + 12
    for r in (30, 20, 10):
        d.arc((wx - r, wy - r, wx + r, wy + r), start=225, end=315, fill=BLANCO, width=6)
    d.ellipse((wx - 5, wy - 5, wx + 5, wy + 5), fill=BLANCO)
    # Senal (4 barras)
    sx = 1020
    for i in range(4):
        h = 12 + i * 8
        d.rounded_rectangle((sx + i * 14, cy + 17 - h, sx + i * 14 + 9, cy + 17), radius=2, fill=BLANCO)


def procesar(entrada, salida_dir):
    img = Image.open(entrada).convert("RGB")
    if img.size != (ANCHO, ALTO):
        img = img.resize((ANCHO, ALTO), Image.LANCZOS)

    c = color_medio(img)

    capa = Image.new("RGBA", (ANCHO, ALTO), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    d.rectangle((0, 0, ANCHO, FRANJA), fill=c + (255,))
    for i in range(DEGRADADO):
        alpha = int(255 * (1 - (i + 1) / DEGRADADO))
        d.line((0, FRANJA + i, ANCHO, FRANJA + i), fill=c + (alpha,))
    barra_de_estado(d)

    out = Image.alpha_composite(img.convert("RGBA"), capa).convert("RGB")  # sin alfa
    os.makedirs(salida_dir, exist_ok=True)
    destino = os.path.join(salida_dir, os.path.basename(entrada))
    out.save(destino, "PNG")
    return destino


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    salida = sys.argv[1]
    for ruta in sys.argv[2:]:
        print(procesar(ruta, salida))
