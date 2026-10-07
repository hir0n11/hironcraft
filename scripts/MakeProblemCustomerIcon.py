# Draws Media/ProblemCustomer.tga, the mark of a problem customer: a toy monkey
# that claps its cymbals. Plain Python, no libraries.
#   python scripts/MakeProblemCustomerIcon.py [preview.png]
# With a second argument a PNG of the same picture is written for looking at.
import struct
import sys
import zlib

SIZE = 64
SAMPLES = 4

OUTLINE = (38, 22, 12)
FUR = (132, 82, 44)
FUR_DARK = (104, 62, 32)
FACE = (236, 200, 152)
EAR = (226, 160, 128)
WHITE = (255, 255, 255)
BLACK = (20, 14, 10)
MOUTH = (150, 30, 30)
HAT = (206, 40, 40)
GOLD = (246, 204, 70)
GOLD_DARK = (176, 124, 26)
GOLD_LIGHT = (255, 240, 170)


def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def box(x0, y0, x1, y1):
    return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1


def outlined(shapes, cx, cy, rx, ry, color, edge=1.6):
    shapes.append((ellipse(cx, cy, rx + edge, ry + edge), OUTLINE))
    shapes.append((ellipse(cx, cy, rx, ry), color))


def picture():
    shapes = []
    # Body and arms, behind everything.
    outlined(shapes, 32, 55, 11, 10, HAT)
    shapes.append((box(30.5, 46, 33.5, 64), GOLD))
    outlined(shapes, 20, 47, 7, 3.4, FUR)
    outlined(shapes, 44, 47, 7, 3.4, FUR)
    # Ears.
    outlined(shapes, 14.5, 23, 6, 6.5, FUR)
    shapes.append((ellipse(14.5, 23, 3.3, 3.8), EAR))
    outlined(shapes, 49.5, 23, 6, 6.5, FUR)
    shapes.append((ellipse(49.5, 23, 3.3, 3.8), EAR))
    # Head.
    outlined(shapes, 32, 26, 16, 16, FUR)
    shapes.append((ellipse(32, 15, 9, 4), FUR_DARK))
    # Face: two rounds for the eyes and a muzzle.
    shapes.append((ellipse(26, 24, 7, 7.5), FACE))
    shapes.append((ellipse(38, 24, 7, 7.5), FACE))
    shapes.append((ellipse(32, 33.5, 11, 8), FACE))
    # Wide eyes that look at nothing.
    shapes.append((ellipse(26, 23.5, 4.6, 5), OUTLINE))
    shapes.append((ellipse(26, 23.5, 3.7, 4.1), WHITE))
    shapes.append((ellipse(26, 24, 1.6, 1.8), BLACK))
    shapes.append((ellipse(38, 23.5, 4.6, 5), OUTLINE))
    shapes.append((ellipse(38, 23.5, 3.7, 4.1), WHITE))
    shapes.append((ellipse(38, 24, 1.6, 1.8), BLACK))
    # Nose and a toothy grin.
    shapes.append((ellipse(30.6, 30.2, 0.9, 0.9), OUTLINE))
    shapes.append((ellipse(33.4, 30.2, 0.9, 0.9), OUTLINE))
    shapes.append((ellipse(32, 36, 7.4, 4.2), OUTLINE))
    shapes.append((ellipse(32, 36, 6.3, 3.2), MOUTH))
    shapes.append((box(26.5, 34.2, 37.5, 36.4), WHITE))
    shapes.append((box(31.7, 34.2, 32.3, 36.4), OUTLINE))
    # A fez.
    shapes.append((box(25.4, 1.4, 38.6, 11.6), OUTLINE))
    shapes.append((box(27, 3, 37, 10), HAT))
    shapes.append((box(27, 7.6, 37, 9.2), GOLD))
    # The cymbals, in front, about to meet.
    for cx in (11.5, 52.5):
        outlined(shapes, cx, 46, 9.5, 14, GOLD)
        shapes.append((ellipse(cx, 46, 6.6, 10.4), GOLD_DARK))
        shapes.append((ellipse(cx, 46, 5.4, 9), GOLD))
        shapes.append((ellipse(cx, 46, 2, 3), GOLD_LIGHT))
    # Hands on them.
    outlined(shapes, 13, 46, 2.6, 2.6, FUR)
    outlined(shapes, 51, 46, 2.6, 2.6, FUR)
    return shapes


def render(shapes):
    pixels = []
    step = 1.0 / SAMPLES
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            r = g = b = a = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    x = px + (sx + 0.5) * step
                    y = py + (sy + 0.5) * step
                    for inside, color in reversed(shapes):
                        if inside(x, y):
                            r += color[0]
                            g += color[1]
                            b += color[2]
                            a += 1
                            break
            total = SAMPLES * SAMPLES
            if a:
                row.append((r // a, g // a, b // a, 255 * a // total))
            else:
                row.append((0, 0, 0, 0))
        pixels.append(row)
    return pixels


def write_tga(path, pixels):
    # The format of Media/HironCraftIcon.tga: uncompressed, 32 bits, rows from the top.
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for row in pixels:
        for r, g, b, a in row:
            body += bytes((b, g, r, a))
    with open(path, 'wb') as handle:
        handle.write(header + bytes(body))


def write_png(path, pixels, scale=1, background=None):
    size = SIZE * scale
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            r, g, b, a = pixels[y // scale][x // scale]
            if background:
                r = (r * a + background[0] * (255 - a)) // 255
                g = (g * a + background[1] * (255 - a)) // 255
                b = (b * a + background[2] * (255 - a)) // 255
                a = 255
            raw += bytes((r, g, b, a))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, 'wb') as handle:
        handle.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


if __name__ == '__main__':
    image = render(picture())
    write_tga('Media/ProblemCustomer.tga', image)
    if len(sys.argv) > 1:
        write_png(sys.argv[1], image, 6, (28, 26, 24))
