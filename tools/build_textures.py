"""Lumen theme textures, generated procedurally (nothing copied from anywhere).

    python tools/build_textures.py [output folder]     (default: ../assets/textures next to this script)

Needs numpy and Pillow. Every texture is deterministic (fixed seeds), so rebuilding gives the same files.
Lumen loads them from <repo>/assets/textures/<name>.png, caches them on disk and draws them on windows
with the Style.Texture / Style.Lamp theme keys.

  nebula.png  1024 x 1024  violet / magenta / blue gas clouds with dark dust lanes (alpha = cloud density)
  stars.png   1024 x 1024  a deep star layer: thousands of points, colour temperatures, a few bright stars with spikes
  brick.png   1024 x 1024  a dark, grimy street wall: varied bricks, chipped edges, mortar, water streaks
  lamp.png     512 x 512   a cone of light from a street lamp (white, tinted in game)
  dorito.png   128 x 128   a seasoned corn chip for the MLG particles
"""
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'assets', 'textures')


def fbm(n, beta, seed):
    """Fractal noise from a 1/f^beta spectrum, normalised to 0..1 (FFT noise is naturally seamless)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    spec = (rng.normal(size=(n, n)) + 1j * rng.normal(size=(n, n))) / k ** beta
    spec[0, 0] = 0
    img = np.real(np.fft.ifft2(spec))
    img -= img.min()
    return img / img.max()


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, rgba):
    os.makedirs(OUT, exist_ok=True)
    arr = np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8)
    path = os.path.join(OUT, name + '.png')
    Image.fromarray(arr, 'RGBA').save(path, optimize=True)
    print(f'{name}.png  {os.path.getsize(path) // 1024} KB')


def nebula(n=1024):
    dens = fbm(n, 1.6, 1)
    detail = fbm(n, 1.35, 2)
    hue = fbm(n, 1.9, 3)
    lanes = fbm(n, 1.35, 4)
    # ridged noise -> thin dark filaments of dust
    ridge = 1 - np.abs(lanes * 2 - 1)
    d = smooth(dens * 0.8 + detail * 0.2, 0.40, 0.97)
    d *= 1 - 0.7 * smooth(ridge, 0.82, 0.97)
    palette = np.array([
        [0.36, 0.16, 0.86],   # violet
        [0.80, 0.22, 0.70],   # magenta
        [0.16, 0.42, 0.95],   # blue
        [0.20, 0.78, 0.86],   # teal
    ])
    h = hue * (len(palette) - 1)
    i0 = np.clip(np.floor(h).astype(int), 0, len(palette) - 2)
    t = (h - i0)[..., None]
    col = palette[i0] * (1 - t) + palette[i0 + 1] * t
    # bright cores where the gas is densest
    core = smooth(dens * 0.6 + detail * 0.4, 0.78, 1.0)[..., None]
    col = col * (0.55 + 0.45 * detail[..., None]) + core * 0.35
    alpha = np.clip(d ** 1.25 * 0.92, 0, 1)
    save('nebula', np.dstack([np.clip(col, 0, 1), alpha]))


def stars(n=1024, count=2600):
    rng = np.random.default_rng(7)
    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    temps = np.array([[0.70, 0.80, 1.00], [0.85, 0.90, 1.00], [1.00, 1.00, 1.00], [1.00, 0.93, 0.80], [1.00, 0.82, 0.65]])
    yy, xx = np.mgrid[-12:13, -12:13]
    for s in range(count):
        x, y = rng.integers(12, n - 12, size=2)
        mag = rng.pareto(2.6) * 0.18 + 0.12
        mag = min(mag, 1.0)
        r = 0.45 + mag * 1.4
        c = temps[rng.integers(len(temps))]
        g = np.exp(-(xx ** 2 + yy ** 2) / (2 * r * r)) * mag
        if mag > 0.62:
            # diffraction spikes on the brightest stars
            spike = (np.exp(-(yy ** 2) / 0.35) * np.exp(-np.abs(xx) / (4 + mag * 6))
                     + np.exp(-(xx ** 2) / 0.35) * np.exp(-np.abs(yy) / (4 + mag * 6))) * mag * 0.7
            g = np.maximum(g, spike)
        sl = (slice(y - 12, y + 13), slice(x - 12, x + 13))
        new = np.maximum(a[sl], g)
        mask = (g > a[sl])[..., None]
        rgb[sl] = np.where(mask, c, rgb[sl])
        a[sl] = new
    save('stars', np.dstack([rgb, np.clip(a, 0, 1)]))


def brick(n=1024, bw=128, bh=48, mortar=5):
    rng = np.random.default_rng(11)
    fine = fbm(n, 0.9, 12)
    mid = fbm(n, 1.5, 13)
    grime = fbm(n, 1.8, 14)
    y, x = np.mgrid[0:n, 0:n]
    row = y // bh
    xo = (x + (row % 2) * (bw // 2)) % n
    col = xo // bw
    bx, by = xo % bw, y % bh
    # distance to the brick's edge, for mortar and rounded / chipped edges
    edge = np.minimum(np.minimum(bx, bw - 1 - bx), np.minimum(by, bh - 1 - by)).astype(float)
    chip = (fine - 0.5) * 5
    is_mortar = edge + chip < mortar / 2
    # one colour per brick: dark red-browns through soot greys
    ids = row * 64 + col
    pal = np.array([[0.22, 0.12, 0.10], [0.19, 0.11, 0.09], [0.17, 0.13, 0.12], [0.15, 0.14, 0.14], [0.24, 0.14, 0.11], [0.13, 0.11, 0.10], [0.18, 0.16, 0.15]])
    pick = rng.integers(len(pal), size=ids.max() + 1)
    shade = rng.uniform(0.7, 1.12, size=ids.max() + 1)
    base = pal[pick[ids]] * shade[ids][..., None]
    base = base * (0.7 + 0.6 * fine[..., None]) * (0.85 + 0.3 * mid[..., None])
    # bevel: bricks darken toward their edges
    bevel = smooth(edge, 0, 7)[..., None]
    base = base * (0.6 + 0.4 * bevel)
    mortar_col = np.array([0.13, 0.125, 0.12]) * (0.7 + 0.6 * fine[..., None])
    img = np.where(is_mortar[..., None], mortar_col, base)
    # water and soot streaks running down the wall
    streak = fbm(n, 1.2, 15)
    sx = np.repeat(streak[:1, :], n, axis=0)
    runs = fbm(n, 2.2, 16)
    drip = smooth(sx, 0.6, 0.9) * smooth(runs, 0.35, 0.75) * (0.3 + 0.7 * (y / n) ** 0.6)
    img = img * (1 - 0.5 * drip[..., None]) * (0.6 + 0.5 * grime[..., None])
    # soot: pull colour toward grey in the dirtiest patches
    grey = img.mean(axis=2, keepdims=True)
    img = img + (grey - img) * smooth(grime, 0.45, 0.85)[..., None] * 0.6
    # damp, darker base of the wall
    img *= (1 - 0.3 * smooth(y / n, 0.6, 1.0))[..., None]
    save('brick', np.dstack([np.clip(img * 1.25, 0, 1), np.ones((n, n))]))


def lamp(n=512):
    y, x = np.mgrid[0:n, 0:n].astype(float)
    cx, cy = n / 2, -n * 0.05
    dx, dy = (x - cx) / n, (y - cy) / n
    ang = np.abs(np.arctan2(dx, dy))
    dist = np.sqrt(dx * dx + dy * dy)
    cone = smooth(0.62 - ang, 0, 0.35)
    fall = np.exp(-dist * 2.2)
    hot = np.exp(-((dx) ** 2 + (dy - 0.05) ** 2) / 0.004) * 0.6
    haze = fbm(n, 1.6, 21) * 0.25 + 0.75
    a = np.clip((cone * fall * haze + hot) * 0.9, 0, 1)
    save('lamp', np.dstack([np.ones((n, n, 3)), a]))


def dorito(n=128, ss=4):
    # drawn at 4x and downsampled for clean edges
    N = n * ss
    rng = np.random.default_rng(31)
    y, x = np.mgrid[0:N, 0:N].astype(float) / N
    # rounded triangle: intersection of three half-planes, softened
    pts = np.array([[0.5, 0.08], [0.94, 0.86], [0.06, 0.86]])
    inside = np.ones((N, N))
    dist = np.full((N, N), 1.0)
    for i in range(3):
        a, b = pts[i], pts[(i + 1) % 3]
        nx, ny = b[1] - a[1], -(b[0] - a[0])
        ln = np.hypot(nx, ny)
        d = ((x - a[0]) * nx + (y - a[1]) * ny) / ln
        dist = np.minimum(dist, -d)
    alpha = smooth(dist, 0.0, 0.02)
    edge = smooth(dist, 0.0, 0.08)
    grain = fbm(N, 1.1, 32)
    base = np.array([0.98, 0.55, 0.10])
    col = base * (0.78 + 0.3 * grain[..., None]) * (0.75 + 0.25 * edge[..., None])
    # cheese dust: red-orange specks
    specks = (rng.random((N, N)) > 0.9965).astype(float)
    k = np.ones((9, 9)) / 81
    from numpy.lib.stride_tricks import sliding_window_view
    pad = np.pad(specks, 4)
    blur = sliding_window_view(pad, (9, 9)).mean(axis=(2, 3))
    dust = np.clip(blur * 30, 0, 1)[..., None]
    col = col * (1 - dust) + np.array([0.85, 0.22, 0.05]) * dust
    img = np.dstack([np.clip(col, 0, 1), alpha])
    im = Image.fromarray((img * 255).astype(np.uint8), 'RGBA').resize((n, n), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'dorito.png')
    im.save(path, optimize=True)
    print(f'dorito.png  {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    nebula()
    stars()
    brick()
    lamp()
    dorito()
