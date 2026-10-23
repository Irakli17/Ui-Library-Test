"""TingUI theme previews for the docs, rendered from the themes themselves.

    python tools/build_previews.py            (writes docs/images/themes/*.png, scene GIFs, banner.png, anatomy.png,
                                               shell.png, studio.png and notifications.png; name one of them, or a theme, to draw only that)

Needs numpy and Pillow. Every colour, corner radius, border, tint, texture, font and particle style is read from the
Presets table in TingUI.lua, so a preview can't drift from the real theme: change a theme, run this again.
Fonts are the Google Fonts the Roblox fonts are based on, downloaded once into tools/.cache/fonts (falls back to
Inter / DejaVu when offline). Previews are stills of a living UI: particles, scenes and borders all move in game.
"""
import math
import os
import random
import re
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
OUT = os.path.join(ROOT, 'docs', 'images')
CACHE = os.path.join(HERE, '.cache', 'fonts')
SS = 2  # supersampling

# --------------------------------------------------------------------------------------------------------------
# reading the presets straight out of TingUI.lua
# --------------------------------------------------------------------------------------------------------------

TOKEN = re.compile(r'\s*(?:(--\[\[.*?\]\])|(--[^\n]*)|("(?:\\.|[^"\\])*")|([A-Za-z_][A-Za-z_0-9.]*)|(-?\d+\.?\d*(?:[eE][-+]?\d+)?)|(.))', re.S)


def tokens(src):
    out = []
    for m in TOKEN.finditer(src):
        if m.group(1) or m.group(2):
            continue
        if m.group(3):
            out.append(('str', m.group(3)[1:-1]))
        elif m.group(4):
            out.append(('name', m.group(4)))
        elif m.group(5):
            out.append(('num', float(m.group(5))))
        elif m.group(6) and not m.group(6).isspace():
            out.append(('sym', m.group(6)))
    return out


class Parser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else ('eof', None)

    def take(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def value(self):
        kind, v = self.take()
        if kind == 'num' or kind == 'str':
            return v
        if kind == 'sym' and v == '{':
            return self.table()
        if kind == 'sym' and v == '-':
            return -self.value()
        if kind == 'name':
            if v in ('true', 'false'):
                return v == 'true'
            if v == 'nil':
                return None
            if self.peek() == ('sym', '('):
                self.take()
                args = []
                while self.peek() != ('sym', ')'):
                    args.append(self.value())
                    if self.peek() == ('sym', ','):
                        self.take()
                self.take()
                if v == 'Color3.fromRGB':
                    return tuple(int(a) for a in args)
                if v == 'Color3.new':
                    return tuple(int(round(a * 255)) for a in args)
                return (v, args)
            return ('ref', v)
        raise ValueError('unexpected %r' % (v,))

    def table(self):
        d, arr = {}, []
        while self.peek() != ('sym', '}'):
            if self.peek()[0] == 'name' and self.peek(1) == ('sym', '='):
                key = self.take()[1]
                self.take()
                d[key] = self.value()
            else:
                arr.append(self.value())
            if self.peek()[1] in (',', ';'):
                self.take()
        self.take()
        if arr and not d:
            return arr
        return d


def load_presets():
    src = open(os.path.join(ROOT, 'TingUI.lua'), encoding='utf-8').read()
    start = src.index('\tTheme = {')
    theme = Parser(tokens(src[start + len('\tTheme = {'):]))
    defaults = theme.table()
    start = src.index('\tPresets = {')
    presets = Parser(tokens(src[start + len('\tPresets = {'):])).table()
    order = re.findall(r'^\t\t([A-Za-z]+) = \{ Accent', src[start:], re.M)
    descs = dict(re.findall(r'^\t\t\t([A-Za-z]+) = "([^"]+)",', src[src.index('local DESCRIPTIONS = {'):], re.M))
    return defaults, presets, order, descs


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def full_theme(defaults, p):
    """The derived colours TingUI:SetTheme fills in."""
    T = dict(defaults)
    T.update({k: v for k, v in p.items() if k != 'Style'})
    T['AccentBorder'] = p.get('AccentBorder', lerp(T['Accent'], T['Background'], 0.36))
    T['TabActive'] = p.get('TabActive', lerp(T['Accent'], T['Background'], 0.79))
    T['Toggle'] = p.get('Toggle', lerp(T['Accent'], T['Background'], 0.64))
    T['Chip'] = lerp(T['Control'], T['Background'], 0.08)
    if 'AccentText' not in p:
        T['AccentText'] = lerp(T['Accent'], (255, 255, 255), 0.02)
    style = {'Radius': 1, 'Glow': 1, 'TextScale': 1, 'Particles': 'Snow', 'ParticleColor': (255, 255, 255), 'Font': 'Inter'}
    style.update(p.get('Style', {}))
    return T, style


# --------------------------------------------------------------------------------------------------------------
# fonts
# --------------------------------------------------------------------------------------------------------------

GF = 'https://raw.githubusercontent.com/google/fonts/main/'
FONT_FILES = {
    'Michroma': ('ofl/michroma/Michroma-Regular.ttf', None),
    'Jura': ('ofl/jura/Jura%5Bwght%5D.ttf', 600),
    'Merriweather': ('ofl/merriweather/Merriweather%5Bopsz,wdth,wght%5D.ttf', 600),
    'FredokaOne': ('ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf', 600),
    'TitilliumWeb': ('ofl/titilliumweb/TitilliumWeb-SemiBold.ttf', None),
    'Oswald': ('ofl/oswald/Oswald%5Bwght%5D.ttf', 500),
    'PatrickHand': ('ofl/patrickhand/PatrickHand-Regular.ttf', None),
    'Sarpanch': ('ofl/sarpanch/Sarpanch-SemiBold.ttf', None),
    'Nunito': ('ofl/nunito/Nunito%5Bwght%5D.ttf', 650),
    'RobotoCondensed': ('ofl/robotocondensed/RobotoCondensed%5Bwght%5D.ttf', 600),
    'Ubuntu': ('ufl/ubuntu/Ubuntu-Medium.ttf', None),
    'JosefinSans': ('ofl/josefinsans/JosefinSans%5Bwght%5D.ttf', 600),
    'Mono': ('ofl/robotomono/RobotoMono%5Bwght%5D.ttf', 550),
    'Cartoon': ('ofl/comicneue/ComicNeue-Bold.ttf', None),
    'Arial': ('ofl/arimo/Arimo%5Bwght%5D.ttf', 400),
}
SYSTEM = ['/usr/share/fonts/opentype/inter/Inter-SemiBold.otf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
SYSTEM_BOLD = ['/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf', '/usr/share/fonts/opentype/inter/Inter-Bold.otf',
               '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
SYSTEM_MONO = ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf']
_fonts = {}


def font_path(name):
    if name in FONT_FILES:
        rel, _ = FONT_FILES[name]
        path = os.path.join(CACHE, name + '.ttf')
        if not os.path.exists(path):
            try:
                os.makedirs(CACHE, exist_ok=True)
                urllib.request.urlretrieve(GF + rel, path)
            except Exception:
                return None
        return path
    return None


def first(paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return None


def font(name, size, bold=False):
    key = (name, size, bold)
    if key in _fonts:
        return _fonts[key]
    path = font_path(name) if name else None
    if name == 'Code':
        path = first(SYSTEM_MONO)
    if not path:
        path = first(SYSTEM_BOLD if bold else SYSTEM)
    f = ImageFont.truetype(path, int(size * SS))
    weight = FONT_FILES.get(name, (None, None))[1]
    if weight:
        try:
            axes = f.get_variation_axes()
            f.set_variation_by_axes([weight if a['name'] in (b'Weight', 'Weight') else a['default'] for a in axes])
        except Exception:
            pass
    _fonts[key] = f
    return f


# --------------------------------------------------------------------------------------------------------------
# drawing helpers (all coordinates in logical pixels; layers are SS times larger)
# --------------------------------------------------------------------------------------------------------------

def S(v):
    return int(round(v * SS))


def box(x0, y0, x1, y1):
    return [S(x0), S(y0), S(x1), S(y1)]


def rgba(c, a=1.0):
    return (c[0], c[1], c[2], int(max(0, min(1, a)) * 255))


def layer(size):
    return Image.new('RGBA', (S(size[0]), S(size[1])), (0, 0, 0, 0))


def rrect_mask(size, b, r):
    m = Image.new('L', (S(size[0]), S(size[1])), 0)
    ImageDraw.Draw(m).rounded_rectangle(box(*b), radius=S(r), fill=255)
    return m


def fill_mask(img, mask, color, alpha=1.0):
    solid = Image.new('RGBA', img.size, rgba(color))
    a = mask.point(lambda v: int(v * alpha))
    solid.putalpha(a)
    img.alpha_composite(solid)


def gradient(size, stops, angle=90):
    """stops = [(t, (r, g, b, a))]; angle 90 = top to bottom, 0 = left to right."""
    w, h = S(size[0]), S(size[1])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rad = math.radians(angle)
    dx, dy = math.cos(rad), math.sin(rad)
    proj = xx * dx + yy * dy
    proj = (proj - proj.min()) / max(1e-6, proj.max() - proj.min())
    ts = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.array([s[1] for s in stops], dtype=np.float32)
    out = np.zeros((h, w, 4), np.float32)
    for c in range(4):
        out[..., c] = np.interp(proj, ts, cols[:, c])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')


def conic(size, center, colors, rotation=0.0, hard=False):
    w, h = S(size[0]), S(size[1])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ang = (np.arctan2(yy - S(center[1]), xx - S(center[0])) / (2 * np.pi) + 0.5 + rotation) % 1.0
    cols = np.array(colors, dtype=np.float32)
    n = len(colors)
    if hard:
        idx = np.minimum((ang * n).astype(int), n - 1)
        out = cols[idx]
    else:
        ts = np.linspace(0, 1, n)
        out = np.stack([np.interp(ang, ts, cols[:, c]) for c in range(3)], -1)
    a = np.full((h, w, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([out, a], -1).astype(np.uint8), 'RGBA')


def stripes(size, colors, angle=45, width=14):
    w, h = S(size[0]), S(size[1])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rad = math.radians(angle)
    proj = (xx * math.cos(rad) + yy * math.sin(rad)) / S(width)
    idx = (np.floor(proj).astype(int)) % len(colors)
    cols = np.array(colors, dtype=np.float32)[idx]
    a = np.full((h, w, 1), 255, np.float32)
    return Image.fromarray(np.concatenate([cols, a], -1).astype(np.uint8), 'RGBA')


def glow(img, draw_fn, radius, strength=1.0):
    g = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(g))
    g = g.filter(ImageFilter.GaussianBlur(S(radius)))
    if strength != 1.0:
        r, gg, b, a = g.split()
        a = a.point(lambda v: int(min(255, v * strength)))
        g = Image.merge('RGBA', (r, gg, b, a))
    img.alpha_composite(g)


def text(d, xy, s, f, color, alpha=1.0, anchor='lm'):
    d.text((S(xy[0]), S(xy[1])), s, font=f, fill=rgba(color, alpha), anchor=anchor)


def text_w(s, f):
    return f.getlength(s) / SS


def seg(d, a, b, color, alpha, width=1.0):
    d.line([S(a[0]), S(a[1]), S(b[0]), S(b[1])], fill=rgba(color, alpha), width=max(1, S(width)))


def texture(name):
    path = os.path.join(ROOT, 'assets', 'textures', name + '.png')
    return Image.open(path).convert('RGBA') if os.path.exists(path) else None


def tex_fill(size, name, zoom=1.0, alpha=0.5, color=None):
    im = texture(name)
    if im is None:
        return None
    w, h = S(size[0]), S(size[1])
    k = max(w, h) / (im.width * zoom) * 1.0
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    im = im.crop(((im.width - w) // 2, (im.height - h) // 2, (im.width - w) // 2 + w, (im.height - h) // 2 + h))
    if color:
        tint = Image.new('RGBA', im.size, rgba(color))
        im = ImageChops.multiply(im, tint)
    r, g, b, a = im.split()
    im.putalpha(a.point(lambda v: int(v * alpha)))
    return im


# --------------------------------------------------------------------------------------------------------------
# particles (one still frame of each style)
# --------------------------------------------------------------------------------------------------------------

def particles(img, size, kind, color, rng, count=70, t=0.0):
    d = ImageDraw.Draw(img)
    W, H = size
    if kind in ('Bokeh',):
        count = 26
    for i in range(count):
        x, y = rng.random() * W, rng.random() * H
        if kind in ('None',):
            return
        if kind in ('Snow', 'Stars', 'Starfield', 'Galaxy'):
            r = rng.choice([0.6, 0.8, 1, 1.2, 1.6, 2.2]) if kind != 'Snow' else rng.uniform(1, 3.2)
            a = rng.uniform(0.25, 0.75)
            d.ellipse(box(x - r, y - r, x + r, y + r), fill=rgba(color, a))
            if kind in ('Galaxy', 'Starfield') and rng.random() < 0.08:
                seg(d, (x - 6, y), (x + 6, y), color, 0.5)
                seg(d, (x, y - 6), (x, y + 6), color, 0.5)
        elif kind == 'Bubbles':
            kindb = rng.choice(['Fizz', 'Fizz', 'Glass', 'Glass', 'Glass', 'Glass', 'Big', 'Cluster', 'Pop'])
            white = (255, 255, 255)
            def bubble(bx, by, r):
                g = gradient((r * 2, r * 2), [(0, rgba(lerp(color, white, 0.55), 0.16)), (1, rgba(lerp(color, (0, 0, 0), 0.15), 0.12))], 90)
                m = Image.new('L', g.size, 0)
                ImageDraw.Draw(m).ellipse([0, 0, g.width - 1, g.height - 1], fill=255)
                g.putalpha(ImageChops.multiply(g.getchannel('A'), m))
                img.alpha_composite(g, (S(bx - r), S(by - r)))
                d.ellipse(box(bx - r, by - r, bx + r, by + r), outline=rgba(lerp(color, white, 0.3), 0.62), width=S(1.5 if r >= 10 else 1))
                hx, hy = bx - r * 0.36, by - r * 0.44
                d.ellipse(box(hx - r * 0.22, hy - r * 0.12, hx + r * 0.22, hy + r * 0.12), fill=rgba(white, 0.75))
                if r >= 5.5:
                    d.ellipse(box(bx + r * 0.36, by + r * 0.42, bx + r * 0.5, by + r * 0.56), fill=rgba(white, 0.45))
            if kindb == 'Fizz':
                for k in range(3):
                    r = max(0.6, 1.6 - k * 0.4)
                    d.ellipse(box(x - r, y + k * 5 - r, x + r, y + k * 5 + r), fill=rgba(lerp(color, white, 0.5), 0.7 - k * 0.2))
            elif kindb == 'Cluster':
                for ox, oy, r in ((0, 0, 5), (8, -3, 3), (6, 7, 3.5)):
                    bubble(x + ox, y + oy, r)
            elif kindb == 'Pop':
                r = rng.uniform(9, 15)
                d.ellipse(box(x - r, y - r, x + r, y + r), outline=rgba(lerp(color, white, 0.45), 0.35), width=S(1.5))
                for k in range(7):
                    ang = k / 7 * 6.283 + 0.3
                    dist = r * rng.uniform(1.1, 1.6)
                    px, py = x + math.cos(ang) * dist, y + math.sin(ang) * dist
                    d.ellipse(box(px - 1, py - 1, px + 1, py + 1), fill=rgba(lerp(color, white, 0.45), 0.6))
            else:
                r = rng.uniform(10, 17) if kindb == 'Big' else rng.uniform(4, 8.5)
                bubble(x, y, r)
        elif kind == 'Petals':
            # ovals, slender blades, notched hearts and the odd blossom, caught mid-tumble (some edge-on, some pale side up)
            pk = rng.choice(['Oval', 'Oval', 'Oval', 'Slender', 'Slender', 'Heart', 'Heart', 'Blossom'])
            turn = 0.22 + 0.78 * abs(math.cos(rng.uniform(0, 6.28)))
            c = lerp(color, (255, 255, 255), rng.random() * 0.3 + (0.3 if rng.random() < 0.3 else 0))
            a = rng.uniform(0.45, 0.85)
            ang = rng.uniform(0, 360)
            sz = rng.uniform(6, 12)
            if pk == 'Blossom':
                for k in range(5):
                    u = k * 1.2566 + math.radians(ang)
                    d.ellipse(box(x + math.cos(u) * sz * 0.24 * turn - sz * 0.2, y + math.sin(u) * sz * 0.24 - sz * 0.2,
                                  x + math.cos(u) * sz * 0.24 * turn + sz * 0.2, y + math.sin(u) * sz * 0.24 + sz * 0.2), fill=rgba(c, a))
                d.ellipse(box(x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=rgba((255, 226, 160), a))
            elif pk == 'Heart':
                for sx in (-1, 1):
                    d.polygon(ellipse_pts(x + sx * sz * 0.2 * turn, y, sz * 0.32 * turn, sz * 0.46, ang + sx * 20), fill=rgba(c, a))
            else:
                ww = sz * (2 if pk == 'Slender' else 1.45)
                hh = sz * (0.55 if pk == 'Slender' else 1) * 0.5
                d.polygon(ellipse_pts(x, y, ww / 2 * turn, hh, ang), fill=rgba(c, a))
        elif kind == 'Embers':
            # sparks, glowing embers with a halo, tumbling ash and thin streaks; cooling from white-gold to red as they climb
            ek = rng.choice(['Spark', 'Spark', 'Spark', 'Ember', 'Ember', 'Ember', 'Ash', 'Ash', 'Streak'])
            climb = 1 - y / H
            hot, deep = (255, 240, 190), (170, 46, 30)
            c = lerp(hot, color, climb / 0.4) if climb < 0.4 else lerp(color, deep, (climb - 0.4) / 0.6)
            a = max(0.1, 1 - climb * 0.8)
            if ek == 'Ash':
                g = lerp(color, (110, 100, 96), 0.75)
                r = rng.uniform(1.4, 2.4)
                d.polygon(ellipse_pts(x, y, r, r * 0.6, rng.uniform(0, 180), 6), fill=rgba(g, 0.4))
            elif ek == 'Streak':
                seg(d, (x, y), (x + rng.uniform(-1.5, 1.5), y + 8), c, a * 0.7, 1.4)
            elif ek == 'Ember':
                r = rng.uniform(1.6, 2.4)
                glow(img, lambda g, x=x, y=y, r=r, c=c, a=a: g.ellipse(box(x - r * 3, y - r * 3, x + r * 3, y + r * 3), fill=rgba(c, 0.35 * a)), 3)
                d.ellipse(box(x - r, y - r, x + r, y + r), fill=rgba(c, a))
            else:
                r = rng.uniform(0.7, 1.3)
                d.ellipse(box(x - r, y - r, x + r, y + r), fill=rgba(lerp(c, hot, 0.4), min(1, a + 0.2)))
        elif kind == 'Rain':
            # fine drops, heavy streaks and faint mist on one wind; heavy drops splash where they land
            rk = rng.choice(['Drop', 'Drop', 'Drop', 'Drop', 'Heavy', 'Mist', 'Mist'])
            slant = math.tan(math.radians(16))
            ln = {'Drop': rng.uniform(14, 28), 'Heavy': rng.uniform(28, 42), 'Mist': rng.uniform(6, 11)}[rk]
            a = {'Drop': rng.uniform(0.25, 0.5), 'Heavy': rng.uniform(0.45, 0.6), 'Mist': 0.15}[rk]
            wd = 2 if rk == 'Heavy' else 1
            for k in range(4):
                u0, u1 = k / 4, (k + 1) / 4
                seg(d, (x + slant * ln * u0, y + ln * u0), (x + slant * ln * u1, y + ln * u1), color, a * (0.25 + 0.75 * u1), wd)
            if rk == 'Heavy' and rng.random() < 0.6:
                sy = y + ln + rng.uniform(20, 60)
                sx = x + slant * (sy - y)
                d.ellipse(box(sx - 6, sy - 1.2, sx + 6, sy + 1.2), outline=rgba(color, 0.3), width=S(0.8))
                for s_ in (-1, 1):
                    d.ellipse(box(sx + s_ * 5 - 0.9, sy - 5 - 0.9, sx + s_ * 5 + 0.9, sy - 5 + 0.9), fill=rgba(color, 0.45))
        elif kind == 'Leaves':
            w, h = rng.uniform(6, 11), rng.uniform(4, 7)
            p = Image.new('RGBA', (S(w + 4), S(w + 4)), (0, 0, 0, 0))
            ImageDraw.Draw(p).ellipse(box(2, (w - h) / 2 + 2, w + 2, (w + h) / 2 + 2), fill=rgba(lerp(color, (255, 255, 255), rng.random() * 0.3), rng.uniform(0.45, 0.85)))
            p = p.rotate(rng.uniform(0, 360), resample=Image.BICUBIC)
            img.alpha_composite(p, (S(x), S(y)))
        elif kind == 'Sparks':
            r = rng.uniform(0.8, 2.2)
            c = lerp(color, (255, 235, 170), rng.random() * 0.6)
            if kind == 'Sparks':
                ang = rng.uniform(-2.6, -0.5)
                seg(d, (x, y), (x + math.cos(ang) * 7, y + math.sin(ang) * 7), c, 0.8, 1.2)
            else:
                d.rectangle(box(x, y, x + r * 1.6, y + r * 1.6), fill=rgba(c, 1 - y / H * 0.7))
        elif kind == 'Fireflies':
            glow(img, lambda g, x=x, y=y: g.ellipse(box(x - 5, y - 5, x + 5, y + 5), fill=rgba(color, 0.6)), 4)
            d.ellipse(box(x - 1.6, y - 1.6, x + 1.6, y + 1.6), fill=rgba(color, 0.9))
        elif kind == 'Glyphs':
            text(d, (x, y), rng.choice('0101AF73#*'), font('Mono', 11), color, rng.uniform(0.2, 0.6))
        elif kind == 'Confetti':
            c = rng.choice([(255, 128, 190), (130, 255, 210), (255, 220, 120), (150, 170, 255), (255, 160, 110)])
            p = Image.new('RGBA', (S(10), S(10)), (0, 0, 0, 0))
            ImageDraw.Draw(p).rectangle(box(2, 3.5, 8, 6.5), fill=rgba(c, 0.85))
            img.alpha_composite(p.rotate(rng.uniform(0, 360)), (S(x), S(y)))
        elif kind in ('Sparkles', 'Crystals'):
            r = rng.uniform(3, 7)
            a = rng.uniform(0.35, 0.9)
            arms = 3 if kind == 'Crystals' else 2
            for k in range(arms):
                ang = math.pi * k / arms + (0.3 if kind == 'Crystals' else 0)
                seg(d, (x - math.cos(ang) * r, y - math.sin(ang) * r), (x + math.cos(ang) * r, y + math.sin(ang) * r), color, a, 1)
        elif kind == 'Drafting':
            if rng.random() < 0.5:
                seg(d, (x - 4, y), (x + 4, y), color, 0.4)
                seg(d, (x, y - 4), (x, y + 4), color, 0.4)
            else:
                r = rng.uniform(6, 16)
                d.arc(box(x - r, y - r, x + r, y + r), rng.uniform(0, 180), rng.uniform(200, 340), fill=rgba(color, 0.3), width=S(1))
        elif kind == 'Bokeh':
            depth = rng.random()
            r = 8 + depth ** 1.4 * 46
            lights = [(255, 244, 228), (255, 210, 180), (180, 230, 255), (214, 196, 255), (190, 255, 226), (255, 226, 240)]
            c = lerp(color, rng.choice(lights), 0.55)
            soft = depth
            pad = int(r * 1.5) + 4
            disc = Image.new('RGBA', (S(pad * 2), S(pad * 2)), (0, 0, 0, 0))
            dd = ImageDraw.Draw(disc)
            cx = cy = pad
            dd.ellipse(box(cx - r * 1.3, cy - r * 1.3, cx + r * 1.3, cy + r * 1.3), fill=rgba(c, 0.035))
            if rng.random() < 0.22 and depth < 0.75:
                pts = [(cx + math.cos(k * 1.0472 + 0.5236) * r, cy + math.sin(k * 1.0472 + 0.5236) * r) for k in range(6)]
                dd.polygon([(S(px), S(py)) for px, py in pts], fill=rgba(c, 0.12))
            else:
                if depth < 0.6:
                    fr = r + 1.8
                    dd.ellipse(box(cx - fr, cy - fr, cx + fr, cy + fr), outline=rgba(lerp(c, (255, 120, 220), 0.5), 0.18), width=S(1))
                dd.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=rgba(c, 0.09 + (1 - soft) * 0.04),
                           outline=rgba(lerp(c, (255, 255, 255), 0.4), 0.5 - soft * 0.3), width=S(1.2))
                dd.ellipse(box(cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55), fill=rgba(lerp(c, (255, 255, 255), 0.3), 0.06))
            if soft > 0.35:
                disc = disc.filter(ImageFilter.GaussianBlur(S(soft * 2.2)))
            img.alpha_composite(disc, (S(x - pad), S(y - pad)))
        elif kind == 'FilmGrain':
            d.point((S(x), S(y)), fill=rgba(color, 0.3))
        elif kind == 'Bats':
            text(d, (x, y), 'v', font(None, 12, True), color, 0.5)
        elif kind == 'Neon':
            seg(d, (x, y), (x + rng.uniform(10, 30), y), color, 0.4, 1.5)
        elif kind == 'Holo':
            if rng.random() < 0.3:
                seg(d, (x - 3, y), (x + 3, y), color, 0.6)
                seg(d, (x, y - 3), (x, y + 3), color, 0.6)
            else:
                r = rng.choice([1, 1.5, 2])
                d.rectangle(box(x, y, x + r, y + r), fill=rgba(color, rng.uniform(0.3, 0.65)))
        elif kind == 'Static':
            if rng.random() < 0.25:
                px, py = x, y
                ang = rng.uniform(0, 6.28)
                for k in range(3):
                    nx = px + math.cos(ang) * 8 + math.cos(ang + 1.57) * (5 if k % 2 == 0 else -5)
                    ny = py + math.sin(ang) * 8 + math.sin(ang + 1.57) * (5 if k % 2 == 0 else -5)
                    seg(d, (px, py), (nx, ny), lerp(color, (255, 255, 255), 0.4), 0.9, 1)
                    px, py = nx, ny
        else:
            r = rng.uniform(1, 3)
            d.ellipse(box(x - r, y - r, x + r, y + r), fill=rgba(color, rng.uniform(0.3, 0.7)))


# --------------------------------------------------------------------------------------------------------------
# scenes: one moment of Hologram / Circuit / Abyss (t in seconds, for the animated previews)
# --------------------------------------------------------------------------------------------------------------

def scene_hologram(img, front, T, st, win, t):
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    acc = T['Accent']
    d = ImageDraw.Draw(img)
    lock = min(1.0, max(0.0, t / 0.5))
    c1 = 1.70158
    back = 1 + (c1 + 1) * (lock - 1) ** 3 + c1 * (lock - 1) ** 2
    D = 7 + 1.2 * math.sin(t * 2.1) + 30 * (1 - back)
    for cx, cy, dx, dy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        px, py = cx - dx * D, cy - dy * D
        a = 0.7 + (1 - lock) * 0.3
        glow(img, lambda g: (g.line([S(px), S(py), S(px + dx * 20), S(py)], fill=rgba(acc, 0.8), width=S(2)),
                             g.line([S(px), S(py), S(px), S(py + dy * 20)], fill=rgba(acc, 0.8), width=S(2))), 3)
        seg(d, (px, py), (px + dx * 20, py), acc, a, 2)
        seg(d, (px, py), (px, py + dy * 20), acc, a, 2)
        d.rectangle(box(px + dx * 5 - (0 if dx > 0 else 3), py + dy * 5 - (0 if dy > 0 else 3), px + dx * 5 + (3 if dx > 0 else 0), py + dy * 5 + (3 if dy > 0 else 0)), fill=rgba(acc, a * 0.7))
    # projector beam
    depth = 92
    for f in (0.8, 0.62, 0.46, 0.3, 0.14):
        bw = w * f
        bh = depth * (1 - f) + 8
        g = gradient((bw, bh), [(0, rgba(acc, 0.09)), (1, rgba(acc, 0))], 90)
        img.alpha_composite(g, (S(x0 + (w - bw) / 2), S(y1 + 2)))
    lx, ly = x0 + w / 2, y1 + depth + 6
    glow(img, lambda g: g.ellipse(box(lx - 65, ly - 7, lx + 65, ly + 7), fill=rgba(acc, 0.35)), 6)
    d.rounded_rectangle(box(lx - 26, ly - 1.5, lx + 26, ly + 1.5), radius=S(1.5), fill=rgba(lerp(acc, (255, 255, 255), 0.6), 0.95))
    rng = random.Random(int(t * 4))
    f9 = font('Code', 10)
    text(d, (x0 + 2, y1 + 15), 'HOLO//LINK  0x%04X  SIG %02d%%' % (rng.randint(0, 65535), rng.randint(94, 99)), f9, acc, 0.55)
    text(d, (x1 - 2, y1 + 15), '%s PROJECTING  %03d.%02d' % ('[*]' if int(t * 2) % 2 == 0 else '[ ]', rng.randint(0, 999), rng.randint(0, 99)), f9, acc, 0.55, 'rm')
    # scan sweep, over the content
    k = ((t - 0.3) % 2.6) / 1.15
    if 0 <= k < 1:
        e = k * k * (3 - 2 * k)
        sy = y0 + 6 + e * (h - 12)
        fade = math.sin(k * math.pi)
        g = gradient((w, 56), [(0, rgba(acc, 0)), (1, rgba(acc, 0.12 * fade))], 90)
        front.alpha_composite(g, (S(x0), S(max(y0, sy - 56))) if sy - 56 >= y0 else (S(x0), S(y0)))
        ImageDraw.Draw(front).line([S(x0 + 2), S(sy), S(x1 - 2), S(sy)], fill=rgba(lerp(acc, (255, 255, 255), 0.5), 0.6 * fade), width=S(1))


def circuit_layout(T, st, win):
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    rng = random.Random(7919 * 7 + 17)
    pads, traces = [], []
    sides = (('Top', w), ('Right', h), ('Bottom', w), ('Left', h))
    OUT = {'Top': (0, -1), 'Bottom': (0, 1), 'Left': (-1, 0), 'Right': (1, 0)}
    for name, length in sides:
        n = int(max(length, 240) // 30)
        o = OUT[name]
        for i in range(1, n + 1):
            f = i / (n + 1)
            if name in ('Bottom', 'Left'):
                f = 1 - f
            px, py = {'Top': (x0 + f * w, y0), 'Bottom': (x0 + f * w, y1), 'Left': (x0, y0 + f * h), 'Right': (x1, y0 + f * h)}[name]
            pads.append({'side': name, 'o': o, 'x': px, 'y': py})
    for pad in pads:
        if rng.random() < 0.42 and len(traces) < 26:
            o = pad['o']
            sgn = -1 if rng.random() < 0.5 else 1
            perp = (sgn if o[1] != 0 else 0, sgn if o[0] != 0 else 0)
            p0 = (o[0] * 9, o[1] * 9)
            a = rng.randint(8, 44)
            p1 = (p0[0] + o[0] * a, p0[1] + o[1] * a)
            dd = rng.randint(12, 38)
            p2 = (p1[0] + o[0] * dd + perp[0] * dd, p1[1] + o[1] * dd + perp[1] * dd)
            b = rng.randint(18, 110)
            p3 = (p2[0] + o[0] * b, p2[1] + o[1] * b)
            pts = [p0, p1, p2, p3]
            if rng.random() < 0.5:
                c = rng.randint(20, 90)
                pts.append((p3[0] + perp[0] * c, p3[1] + perp[1] * c))
            pts = [(pad['x'] + px, pad['y'] + py) for px, py in pts]
            pad['trace'] = pts
            traces.append(pts)
    return pads, traces


def point_on(pts, d):
    for a, b in zip(pts, pts[1:]):
        l = math.dist(a, b)
        if d <= l:
            k = d / l if l else 0
            return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        d -= l
    return pts[-1]


def scene_circuit(img, front, T, st, win, t):
    copper = st.get('TraceColor', T['Border'])
    energy = st.get('EnergyColor', T['Accent'])
    d = ImageDraw.Draw(img)
    pads, traces = circuit_layout(T, st, win)
    for i, pts in enumerate(traces):
        a = 0.44 + 0.1 * math.sin(t * 1.7 + i)
        for p, q in zip(pts, pts[1:]):
            seg(d, p, q, copper, a, 1.5)
        vx, vy = pts[-1]
        d.ellipse(box(vx - 3.5, vy - 3.5, vx + 3.5, vy + 3.5), outline=rgba(copper, 0.6), width=S(1.5))
    for pad in pads:
        o = pad['o']
        x, y = pad['x'] + o[0] * 2, pad['y'] + o[1] * 2
        if o[1] != 0:
            b = (x - 2, y if o[1] > 0 else y - 7, x + 2, y + 7 if o[1] > 0 else y)
        else:
            b = (x if o[0] > 0 else x - 7, y - 2, x + 7 if o[0] > 0 else x, y + 2)
        d.rectangle(box(*b), fill=rgba(copper, 0.65 if 'trace' in pad else 0.38))
    # pulses racing along a handful of traces
    rng = random.Random(3)
    for i, pts in enumerate(traces):
        if rng.random() < 0.45:
            total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
            speed = 230 + rng.random() * 110
            period = total / speed + 0.8 + rng.random() * 1.5
            ph = (t + rng.random() * period) % period
            dd = ph * speed
            if dd <= total:
                px, py = point_on(pts, dd if rng.random() < 0.5 else total - dd)
                glow(img, lambda g, px=px, py=py: g.ellipse(box(px - 8, py - 8, px + 8, py + 8), fill=rgba(energy, 0.8)), 4)
                d.ellipse(box(px - 2, py - 2, px + 2, py + 2), fill=rgba(lerp(energy, (255, 255, 255), 0.6), 1))
    x0, y0, x1, y1 = win
    d.ellipse(box(x0 - 15.5, y0 - 15.5, x0 - 10.5, y0 - 10.5), fill=rgba(copper, 0.65))
    text(d, (x1 - 4, y1 + 18), 'TINGUI  LX-%d  REV 6' % int(x1 - x0), font('Code', 9), copper, 0.55, 'rm')


def scene_ocean(img, front, T, st, win, t):
    """Waves along the bottom (over the content), caustic light across the header (behind it)."""
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    water = st.get('WaterColor', T['Accent'])
    foam = st.get('FoamColor', T['Text'])
    deep = lerp(water, T['Background'], 0.45)
    rng = random.Random(9)
    # caustics: soft light ovals drifting across the top of the window
    for i in range(7):
        cx = x0 + (rng.random() + math.sin(t * 0.25 + i) * 0.08) * w
        cy = y0 + 10 + rng.random() * 70
        cw = rng.uniform(60, 150)
        c = lerp(foam, water, 0.4)
        glow(img, lambda g, cx=cx, cy=cy, cw=cw, c=c: g.ellipse(box(cx - cw / 2, cy - cw * 0.16, cx + cw / 2, cy + cw * 0.16), fill=rgba(c, 0.12)), 8)
    # waves over the content, clipped to the window
    wv = layer(img.size)
    wd = ImageDraw.Draw(wv)
    for layer_i, (base, amp, col, alpha, ph) in enumerate(((15, 4.8, deep, 0.14, 1.3), (10, 4, water, 0.24, 0))):
        pts = []
        for k in range(0, int(w) + 9, 4):
            xx = k
            if layer_i == 0:
                hh = base + amp * (math.sin(xx * 0.022 + t * 1.1 + ph) * 0.7 + math.sin(xx * 0.05 - t * 0.6) * 0.3)
            else:
                hh = base + amp * (math.sin(xx * 0.034 - t * 1.7) * 0.6 + math.sin(xx * 0.012 + t * 0.85) * 0.4)
            pts.append((x0 + xx, y1 - hh))
        poly = pts + [(x1 + 8, y1 + 2), (x0, y1 + 2)]
        wd.polygon([(S(px), S(py)) for px, py in poly], fill=rgba(col, alpha))
        if layer_i == 1:
            for k in range(len(pts) - 1):
                a = 0.45 + 0.3 * (0.5 + 0.5 * math.sin(pts[k][0] * 0.09 + t * 2.2))
                wd.line([S(pts[k][0]), S(pts[k][1]), S(pts[k + 1][0]), S(pts[k + 1][1])], fill=rgba(foam, a), width=S(1.6))
    m = rrect_mask(img.size, win, 10 * st['Radius'])
    wv.putalpha(ImageChops.multiply(wv.getchannel('A'), m))
    front.alpha_composite(wv)
    # a click: one faint round ring, and a few small soft bubbles wobbling up beside the pointer
    rx, ry = x0 + w * 0.62, y0 + h * 0.58
    fd = ImageDraw.Draw(front)
    fd.ellipse(box(rx - 8, ry - 8, rx + 8, ry + 8), outline=rgba(foam, 0.3), width=S(1))
    for i, (ox, oy, r) in enumerate(((-9, -12, 3.2), (8, -20, 2.4), (-6, -30, 1.8), (11, -36, 3.6), (-2, -46, 2))):
        bx, by = rx + ox + math.sin(t * 7 + i) * 1.5, ry + oy - (t * 14 % 6)
        fd.ellipse(box(bx - r, by - r, bx + r, by + r), fill=rgba(foam, 0.12), outline=rgba(foam, 0.5), width=S(0.9))
        fd.ellipse(box(bx - r * 0.55, by - r * 0.62, bx - r * 0.1, by - r * 0.28), fill=rgba((255, 255, 255), 0.6))


SCENES = {'Hologram': scene_hologram, 'Circuit': scene_circuit, 'Ocean': scene_ocean}


def ellipse_pts(cx, cy, rx, ry, ang_deg, n=28):
    a = math.radians(ang_deg)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for k in range(n):
        u = k / n * 6.2832
        ex, ey = math.cos(u) * rx, math.sin(u) * ry
        pts.append((S(cx + ex * ca - ey * sa), S(cy + ex * sa + ey * ca)))
    return pts


def smooth01(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def clip_to(front_layer, size, win, radius):
    m = rrect_mask(size, win, radius)
    front_layer.putalpha(ImageChops.multiply(front_layer.getchannel('A'), m))
    return front_layer


def frost_max(x, w, top):
    edge = 22 if top else 12
    taper = smooth01(min(x - edge, w - edge - x) / 30)
    bumps = 0.72 + 0.16 * math.sin(x * 0.045 + 1.3) + 0.12 * math.sin(x * 0.13 + 0.4)
    return (3.2 if top else 5.5) * taper * bumps


def scene_frost(img, front, T, st, win, t):
    """The snow that settled after the first snowfall: a thin drift along the bottom, a dusting on top, a few flakes."""
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    snow = lerp(st.get('SnowColor', st.get('ParticleColor', T['Text'])), (255, 255, 255), 0.35)
    lay = layer(img.size)
    d = ImageDraw.Draw(lay)
    pts = [(x0 + k, y1 - frost_max(k, w, False) * 0.92) for k in range(0, int(w) + 1, 2)]
    d.polygon([(S(px), S(py)) for px, py in pts] + [(S(x1), S(y1 + 1)), (S(x0), S(y1 + 1))], fill=rgba(snow, 0.5))
    for k in range(len(pts) - 1):
        if y1 - pts[k][1] > 0.6:
            d.line([S(pts[k][0]), S(pts[k][1]), S(pts[k + 1][0]), S(pts[k + 1][1])], fill=rgba(snow, 0.85), width=S(1))
    rng = random.Random(5)
    for i in range(7):
        gx = x0 + 16 + rng.random() * (w - 32)
        hh = frost_max(gx - x0, w, False) * 0.92
        tw = max(0.0, math.sin(t * (0.6 + rng.random() * 1.2) + rng.random() * 6.28)) ** 6
        if hh > 1.5 and tw > 0.05:
            d.ellipse(box(gx - 1.2, y1 - hh - 0.2, gx + 1.2, y1 - hh + 2.2), fill=rgba((255, 255, 255), tw))
    # a few flakes still drifting down
    for i in range(14):
        fx = x0 + (rng.random() * w + math.sin(t * 1.3 + i) * 8)
        fy = y0 + ((rng.random() * h + t * (30 + i * 3)) % h)
        r = rng.choice([1, 1.2, 1.6, 2.2])
        d.ellipse(box(fx - r, fy - r, fx + r, fy + r), fill=rgba(snow, 0.55))
    front.alpha_composite(clip_to(lay, img.size, win, 10 * st['Radius']))
    # the dusting on top of the window (outside it, so not clipped)
    cap = [(x0 + k, y0 + 1 - frost_max(k, w, True) * 0.9) for k in range(0, int(w) + 1, 2)]
    ImageDraw.Draw(img).polygon([(S(px), S(py)) for px, py in cap] + [(S(x1), S(y0 + 2)), (S(x0), S(y0 + 2))], fill=rgba(snow, 0.7))


def bezier(p0, p1, p2, p3, u):
    v = 1 - u
    return tuple(p0[i] * v ** 3 + p1[i] * 3 * v * v * u + p2[i] * 3 * v * u * u + p3[i] * u ** 3 for i in range(2))


def scene_rose(img, front, T, st, win, t):
    """Climbing roses in both lower corners, blooms turned toward the pointer, a few petals on the breeze."""
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    bloom = st.get('BloomColor', st.get('ParticleColor', T['Accent']))
    stem = lerp(st.get('VineColor', (120, 150, 112)), T['Background'], 0.25)
    leafc = lerp(stem, (150, 196, 120), 0.35)
    lay = layer(img.size)
    d = ImageDraw.Draw(lay)
    ln = min(w * 0.36, 230)
    for side in (1, 2):
        m = 1 if side == 1 else -1
        ox = x0 if side == 1 else x1
        P = lambda x, y: (ox + x * m, y0 + y)
        p0, p1, p2, p3 = P(3, h - (70 if side == 1 else 50)), P(2, h - 6), P(30, h - 2), P(ln if side == 1 else ln * 0.72, h - 4)
        N = 30
        pts = []
        for i in range(N + 1):
            u = i / N
            px, py = bezier(p0, p1, p2, p3, u)
            pts.append((px, py - abs(math.sin(u * 13 + side) * 1.6 * smooth01(u * 4))))
        for i in range(1, N + 1):
            a, b = pts[i - 1], pts[i]
            d.line([S(a[0]), S(a[1]), S(b[0]), S(b[1])], fill=rgba(stem, 0.5), width=max(1, S(1.8 - i / N * 0.8)))
            if i % 4 == 2 and i < N - 1:
                ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])) + (-48 if i % 8 == 2 else 48) + math.sin(t * 1.6 + i * 0.7) * 5
                L = 8 + (i % 3) * 1.5
                cx, cy = b[0] + math.cos(math.radians(ang)) * L / 2, b[1] + math.sin(math.radians(ang)) * L / 2
                d.polygon(ellipse_pts(cx, cy, L / 2, 2.1, ang), fill=rgba(leafc, 0.55))
        for at in ((0.42, 0.74, 1) if side == 1 else (0.55, 1)):
            bx, by = pts[int(at * N + 0.5)]
            by -= 1
            sz = 1.1 if at == 1 else 0.9
            o = 0.55 + (0.4 if (side == 2 and at == 1) else 0)  # the one by the pointer is wide open
            for k in range(5):
                ang = k * 72 - 90 + (1 - o) * 26 + math.sin(t * 1.3 + k) * 3
                L = 7.5 * sz * (0.55 + 0.45 * o)
                cx, cy = bx + math.cos(math.radians(ang)) * L / 2, by + math.sin(math.radians(ang)) * L / 2
                d.polygon(ellipse_pts(cx, cy, L / 2, 2.7 * sz * (0.45 + 0.55 * o), ang), fill=rgba(lerp(bloom, (255, 255, 255), (k % 2) * 0.18), 0.6 + o * 0.15))
            r = 1.5 * sz * (0.4 + 0.6 * o)
            d.ellipse(box(bx - r, by - r, bx + r, by + r), fill=rgba(lerp(bloom, (255, 220, 160), 0.6), 0.8))
    # a breeze: petals of different shapes tumbling across
    rng = random.Random(11)
    for i in range(6):
        px = x0 + ((rng.random() * w * 0.9 + t * 70) % (w + 40)) - 20
        py = y0 + 30 + rng.random() * h * 0.55 + math.sin(t * 2 + i) * 8
        flip = abs(math.cos(t * (2 + i * 0.4) + i))
        turn = 0.22 + 0.78 * flip
        ang = rng.uniform(0, 360) + t * 60
        c = lerp(bloom, (255, 255, 255), 0.2 + (0.25 if math.cos(t * 2 + i) < 0 else 0))
        kind = ('Oval', 'Slender', 'Heart', 'Oval', 'Heart', 'Slender')[i]
        size = rng.uniform(6, 9)
        if kind == 'Heart':
            for sx in (-1, 1):
                d.polygon(ellipse_pts(px + sx * size * 0.2 * turn, py, size * 0.36 * turn, size * 0.46, ang + sx * 20), fill=rgba(c, 0.62))
        else:
            ww = size * (1.6 if kind == 'Slender' else 1.25)
            hh = size * (0.45 if kind == 'Slender' else 0.72)
            d.polygon(ellipse_pts(px, py, ww / 2 * turn, hh / 2, ang), fill=rgba(c, 0.62))
    front.alpha_composite(clip_to(lay, img.size, win, 10 * st['Radius']))


def scene_sunset(img, front, T, st, win, t):
    """A low banded sun with slow rays on the lower edge, and a small flock crossing."""
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    tl = st.get('TopLine') or [T['Accent'], T['Accent']]
    c1 = st.get('SunColor', tl[0])
    hot = lerp(c1, (255, 236, 170), 0.45)
    low = tl[-1]
    lay = layer(img.size)
    d = ImageDraw.Draw(lay)
    D = max(90, min(140, w * 0.24))
    cx, cy = x0 + w * 0.76, y1 - D * 0.18 + math.sin(t * 0.4) * 1.5
    for i, k in enumerate((2.3, 1.75, 1.32)):
        r = D * k / 2
        glow(lay, lambda g, r=r, i=i: g.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=rgba(c1, 0.05 + i * 0.03)), 10)
    rays = layer(img.size)
    rd = ImageDraw.Draw(rays)
    for i in range(7):
        ang = math.radians(196 + i * 24 + math.sin(t * 0.12 + i) * 4)
        L = w * 1.1
        th = 2 + (i % 3) * 2
        ca, sa = math.cos(ang), math.sin(ang)
        nx, ny = -sa * th / 2, ca * th / 2
        steps = 14
        for k in range(steps):
            u0, u1 = k / steps, (k + 1) / steps
            a_ = 0.09 * (1 - u0) ** 1.6
            q = [(cx + ca * L * u0 + nx, cy + sa * L * u0 + ny), (cx + ca * L * u1 + nx, cy + sa * L * u1 + ny),
                 (cx + ca * L * u1 - nx, cy + sa * L * u1 - ny), (cx + ca * L * u0 - nx, cy + sa * L * u0 - ny)]
            rd.polygon([(S(px), S(py)) for px, py in q], fill=rgba(hot, a_))
    lay.alpha_composite(rays)
    r = D / 2
    yy = 0.0
    while yy < D:
        v = yy / D
        gap = max(0.0, min(1.0, (v - 0.42) / 0.58)) * 0.55
        phase = (v * 9 - t * 0.35) % 1
        if not (gap > 0 and phase < gap):
            dy = yy + 1 - r
            half = math.sqrt(max(0.0, r * r - dy * dy))
            d.rectangle(box(cx - half, cy - r + yy, cx + half, cy - r + yy + 2), fill=rgba(lerp(hot, low, v), 0.24 - v * 0.05))
        yy += 2
    bird = st.get('BirdColor', lerp(T['Text'], low, 0.35))
    for i in range(4):
        row = (i + 1) // 2
        bx = x0 + ((w * 0.55 + t * 48) % (w + 60)) - 30 - row * 16
        by = y0 + 112 + ((-1) ** i) * row * 9 + math.sin(t * 1.3 + i) * 2
        a = math.radians(math.sin(t * 8 + i * 1.7) * 32)
        for s_ in (-1, 1):
            ex, ey = bx + s_ * math.cos(a) * 6, by - math.sin(a) * 6
            d.line([S(bx), S(by), S(ex), S(ey)], fill=rgba(bird, 0.55), width=S(1.4))
    front.alpha_composite(clip_to(lay, img.size, win, 10 * st['Radius']))


def bolt_path(a, b, depth, rough, rng):
    pts = [a, b]
    for _ in range(depth):
        out = [pts[0]]
        for i in range(1, len(pts)):
            p, q = pts[i - 1], pts[i]
            mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
            dx, dy = q[0] - p[0], q[1] - p[1]
            L = math.hypot(dx, dy) or 1
            off = (rng.random() - 0.5) * L * rough
            out += [(mx - dy / L * off, my + dx / L * off), q]
        pts = out
    return pts


def scene_storm(img, front, T, st, win, t):
    """Clouds along the top, drops beading and running on the glass, splashes at the bottom, a bolt now and then."""
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    rain = lerp(st.get('ParticleColor', T['Text']), (255, 255, 255), 0.25)
    boltc = st.get('BoltColor', (225, 236, 255))
    cloud = st.get('CloudColor', lerp(T['Group'], T['TextDim'], 0.28))
    phase = t % 3
    strike = 1.05 < phase < 1.4
    lay = layer(img.size)
    d = ImageDraw.Draw(lay)
    rng = random.Random(3)
    for i in range(8):
        cw = rng.uniform(110, 210)
        u = ((i / 8 + rng.random() * 0.08 + t * 0.01) % 1.3) - 0.15
        ccx, ccy = x0 + u * w, y0 - 4 + rng.random() * 12
        g = gradient((cw, cw * 0.32), [(0, rgba(lerp(cloud, boltc, 0.5) if strike else cloud, 0.34 if strike else 0.22)), (1, rgba(cloud, 0))], 90)
        m = Image.new('L', g.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, g.width - 1, g.height - 1], fill=255)
        g.putalpha(ImageChops.multiply(g.getchannel('A'), m))
        lay.alpha_composite(g, (S(ccx - cw / 2), S(ccy - cw * 0.16)))
    if strike:
        k = 1 - (phase - 1.05) / 0.35
        rb = random.Random(int(t / 3) + 8)
        a = (x0 + w * (0.3 + rb.random() * 0.4), y0 - 4)
        b = (a[0] + (rb.random() - 0.5) * w * 0.3, y0 + h * 0.6)
        main = bolt_path(a, b, 4, 0.55, rb)
        fork = bolt_path(main[len(main) // 2], (main[len(main) // 2][0] + 50, main[len(main) // 2][1] + 40), 3, 0.6, rb)
        for path, th in ((main, 2.0), (fork, 1.1)):
            glow(lay, lambda g, path=path, th=th: g.line([v for p in path for v in (S(p[0]), S(p[1]))], fill=rgba(boltc, 0.5 * k), width=S(th * 3)), 6)
            d.line([v for p in path for v in (S(p[0]), S(p[1]))], fill=rgba(boltc, 0.95 * k), width=S(th))
        d.rectangle(box(x0, y0, x1, y1), fill=rgba((215, 228, 255), 0.06 * k))
    # drops on the glass: beading, and a few running with a trail
    for i in range(9):
        dx, dy0 = x0 + 14 + rng.random() * (w - 28), y0 + 44 + rng.random() * (h - 90)
        r = rng.uniform(1.8, 3.6)
        run = i % 3 == 0
        dy = dy0 + ((t * 40 + i * 13) % 90 if run else 0)
        if run and dy - dy0 > 2:
            tr = gradient((max(1.2, r * 0.8), dy - dy0), [(0, rgba(rain, 0)), (1, rgba(rain, 0.16))], 90)
            lay.alpha_composite(tr, (S(dx - r * 0.4), S(dy0)))
        g = gradient((r * 2, r * 2), [(0, rgba(rain, 0.06)), (1, rgba(rain, 0.24))], 90)
        m = Image.new('L', g.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, g.width - 1, g.height - 1], fill=255)
        g.putalpha(ImageChops.multiply(g.getchannel('A'), m))
        lay.alpha_composite(g, (S(dx - r), S(dy - r)))
        d.ellipse(box(dx - r, dy - r, dx + r, dy + r), outline=rgba(rain, 0.4), width=S(0.7))
        d.ellipse(box(dx - r * 0.55, dy - r * 0.6, dx - r * 0.05, dy - r * 0.15), fill=rgba((255, 255, 255), 0.7))
        d.ellipse(box(dx - r * 0.2, dy + r * 0.45, dx + r * 0.6, dy + r * 0.8), fill=rgba((255, 255, 255), 0.4))
    for i in range(9):
        sx = x0 + 10 + rng.random() * (w - 20)
        k = ((t * 3 + i * 0.37) % 1)
        for s_ in (-1, 1):
            px, py = sx + s_ * k * 7, y1 - 1 - math.sin(k * math.pi) * 7
            d.ellipse(box(px - 0.9, py - 0.9, px + 0.9, py + 0.9), fill=rgba(rain, 0.5 * (1 - k)))
    front.alpha_composite(clip_to(lay, img.size, win, 10 * st['Radius']))


SCENES.update({'Frost': scene_frost, 'Rose': scene_rose, 'Sunset': scene_sunset, 'Storm': scene_storm})



# --------------------------------------------------------------------------------------------------------------
# the window
# --------------------------------------------------------------------------------------------------------------

def window(T, st, size, win, t=0.0, title='TingUI', compact=False, tabs=None, subtitle='Example Game',
           footer=('discord.gg/yourserver', 'RightShift to hide'), content=None, pills=None, close=False):
    """The window plus its scene. content(ctx) draws the page instead of the default two groups."""
    img = layer(size)
    front = layer(size)
    x0, y0, x1, y1 = win
    w, h = x1 - x0, y1 - y0
    R = 10 * st['Radius']
    scene = SCENES.get(st.get('Scene'))

    # drop shadow + glow of the window
    glow(img, lambda g: g.rounded_rectangle(box(x0, y0 + 10, x1, y1 + 14), radius=S(R + 4), fill=(0, 0, 0, 170)), 18)
    if st.get('Glow', 1) > 0:
        glow(img, lambda g: g.rounded_rectangle(box(x0 - 2, y0 - 2, x1 + 2, y1 + 2), radius=S(R + 2), fill=rgba(T['Accent'], 0.14 * st['Glow'])), 16)

    # body: tint gradient, see-through surface, textures, grid, scanlines
    body = layer(size)
    base = T['Background']
    tint, amt, place = st.get('Tint'), st.get('TintAmount', 0.15), st.get('TintPlace', 'Top')
    alpha = 1 - st.get('SurfaceTransparency', 0)
    if tint:
        tc = lerp(base, tint, amt)
        stops = {'Top': [(0, tc), (0.45, base), (1, base)], 'Bottom': [(0, base), (0.5, base), (1, tc)],
                 'Aurora': [(0, lerp(base, tint, amt * 0.5)), (0.1, tc), (0.32, base), (1, base)]}[place]
    else:
        stops = [(0, base), (1, base)]
    g = gradient((w, h), [(p, rgba(c, alpha)) for p, c in stops], 90)
    body.alpha_composite(g, (S(x0), S(y0)))
    for L in st.get('Texture', []) or []:
        if L.get('Mode') == 'Lamp':
            lamp = texture(L['Image'])
            if lamp is not None:
                lw, lh = S(w * 0.95), S(h * 0.9)
                lamp = lamp.resize((lw, lh), Image.LANCZOS)
                tint_img = Image.new('RGBA', lamp.size, rgba(L.get('Color', (255, 255, 255))))
                lamp = ImageChops.multiply(lamp, tint_img)
                lamp.putalpha(lamp.getchannel('A').point(lambda v: int(v * (1 - L.get('Transparency', 0.5)))))
                body.alpha_composite(lamp, (S(x0 + w * 0.025), S(y0)))
        else:
            tx = tex_fill((w, h), L['Image'], L.get('Zoom', 1), 1 - L.get('Transparency', 0.5), L.get('Color'))
            if tx is not None:
                body.alpha_composite(tx, (S(x0), S(y0)))
    bd = ImageDraw.Draw(body)
    if st.get('Grid'):
        gc = st.get('GridColor', (255, 255, 255))
        for i, gx in enumerate(range(0, int(w), 22)):
            seg(bd, (x0 + gx, y0), (x0 + gx, y1), gc, 0.09 if i % 4 == 0 else 0.04)
        for i, gy in enumerate(range(0, int(h), 22)):
            seg(bd, (x0, y0 + gy), (x1, y0 + gy), gc, 0.09 if i % 4 == 0 else 0.04)
    if st.get('Scanlines'):
        for gy in range(0, int(h), 3):
            seg(bd, (x0, y0 + gy), (x1, y0 + gy), (255, 255, 255), 0.028)
    mask = rrect_mask(size, win, R)
    body.putalpha(ImageChops.multiply(body.getchannel('A'), mask))

    # scene art behind the content sits under the body's content but over the backdrop
    if scene:
        scene(img, front, T, st, win, t)
    img.alpha_composite(body)

    # content
    d = ImageDraw.Draw(img)
    fname = st.get('Font', 'Inter')
    fname = None if fname in ('Inter', 'Gotham') else fname
    ts = st.get('TextScale', 1)
    f_title = font(fname, 13.5 * ts)
    f_lab = font(fname, 12 * ts)
    f_small = font(fname, 10.5 * ts)
    f_pill = font(None, 9.5)
    acc1, acc2 = (st['AccentGradient'][0], st['AccentGradient'][-1]) if st.get('AccentGradient') else (T['Accent'], T['Accent'])
    if st.get('AccentCycle'):
        acc1, acc2 = (255, 120, 120), (120, 200, 255)

    def accent_fill(b, r):
        bw, bh = b[2] - b[0], b[3] - b[1]
        if bw <= 0 or bh <= 0:
            return
        gg = gradient((bw, bh), [(0, rgba(acc1)), (1, rgba(acc2))], 0)
        m = Image.new('L', gg.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, gg.width - 1, gg.height - 1], radius=S(r), fill=255)
        gg.putalpha(m)
        img.alpha_composite(gg, (S(b[0]), S(b[1])))

    # header
    hy = y0 + 25
    text(d, (x0 + 18, hy), title, f_title, T['Text'])
    px = x0 + 18 + text_w(title, f_title) + 10
    for label, c in (pills if pills is not None else (('Pro', T['Success']), ('v0.0.9', T['Danger']))):
        pw = text_w(label, f_pill) + 14
        d.rounded_rectangle(box(px, hy - 9, px + pw, hy + 9), radius=S(5 * st['Radius']), fill=rgba(lerp(c, T['Background'], 0.78)), outline=rgba(lerp(c, T['Background'], 0.4)), width=S(1))
        text(d, (px + pw / 2, hy), label, f_pill, lerp(c, (255, 255, 255), 0.25), anchor='mm')
        px += pw + 4
    if close:
        cx = x1 - 24
        seg(d, (cx - 4, hy - 4), (cx + 4, hy + 4), T['TextDim'], 1, 1.5)
        seg(d, (cx - 4, hy + 4), (cx + 4, hy - 4), T['TextDim'], 1, 1.5)
    if not compact and subtitle:
        text(d, (x1 - (44 if close else 18), hy), subtitle, f_small, T['TextMuted'], anchor='rm')

    # tabs
    ty = y0 + 50
    tx = x0 + 17
    for i, name in enumerate(tabs or ('Main', 'Visuals', 'Players', 'Settings')):
        tw = text_w(name, f_lab) + 22
        if i == 0:
            d.rounded_rectangle(box(tx, ty, tx + tw, ty + 26), radius=S(7 * st['Radius']), fill=rgba(T['TabActive']), outline=rgba(T['AccentBorder'], 0.5), width=S(1))
            accent_fill((tx + tw * 0.29, ty + 21, tx + tw * 0.71, ty + 23), 1)
        text(d, (tx + tw / 2, ty + 13), name, f_lab, T['Text'] if i == 0 else T['TextDim'], anchor='mm')
        tx += tw + 5

    # groups (or the caller's own page)
    if content is not None:
        content(dict(img=img, d=d, T=T, st=st, win=win, f_lab=f_lab, f_small=f_small, f_title=f_title,
                     accent_fill=accent_fill, acc=(acc1, acc2)))
    else:
        gy0, gy1 = y0 + 88, y1 - 34
        gw = (w - 34 - 8) / 2
        cols = ((x0 + 17, 'Combat'), (x0 + 17 + gw + 8, 'Visuals'))
        for ci, (gx, gname) in enumerate(cols):
            gr = 6 * st['Radius']
            d.rounded_rectangle(box(gx, gy0, gx + gw, gy1), radius=S(gr), fill=rgba(T['Group']), outline=rgba(T['GroupBorder']), width=S(1))
            text(d, (gx + 12, gy0 + 17), gname, f_lab, T['Text'])
            seg(d, (gx + 12, gy0 + 31), (gx + gw - 12, gy0 + 31), T['GroupBorder'], 1)
            ry = gy0 + 50
            rows = [('toggle', 'Aimbot', True), ('toggle', 'Silent aim', False), ('slider', 'Field of view', 0.62), ('dropdown', 'Target part', 'Head'),
                    ('toggle', 'Team check', True), ('slider', 'Smoothness', 0.35), ('button', 'Reset settings', None)] if ci == 0 else \
                   [('toggle', 'Boxes', True), ('toggle', 'Tracers', False), ('color', 'Box colour', None), ('slider', 'Max distance', 0.8),
                    ('toggle', 'Names', True), ('progress', 'Loading assets', 0.68), ('dropdown', 'Font', 'Plex')]
            for kind, label, v in rows:
                if ry > gy1 - 20:
                    break
                lx = gx + 12
                if kind == 'toggle':
                    bx = lx
                    if v:
                        if st.get('Glow', 1) > 0:
                            glow(img, lambda g, bx=bx, ry=ry: g.rounded_rectangle(box(bx - 1, ry - 8, bx + 15, ry + 8), radius=S(4), fill=rgba(T['Accent'], 0.5 * st['Glow'])), 4)
                        accent_fill((bx, ry - 7, bx + 14, ry + 7), 3.5 * st['Radius'])
                        seg(d, (bx + 3.5, ry), (bx + 6, ry + 3), (255, 255, 255), 0.95, 1.6)
                        seg(d, (bx + 6, ry + 3), (bx + 10.5, ry - 3), (255, 255, 255), 0.95, 1.6)
                    else:
                        d.rounded_rectangle(box(bx, ry - 7, bx + 14, ry + 7), radius=S(3.5 * st['Radius']), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
                    text(d, (lx + 22, ry), label, f_lab, T['Label'] if v else T['TextDim'])
                    ry += 27
                elif kind == 'slider':
                    text(d, (lx, ry - 3), label, f_lab, T['Label'])
                    val = '%d' % int(v * 120) if 'view' in label else ('%.2f' % v if 'Smooth' in label else '%d m' % int(v * 500))
                    text(d, (gx + gw - 12, ry - 3), val, f_small, T['TextDim'], anchor='rm')
                    sy = ry + 12
                    d.rounded_rectangle(box(lx, sy - 3, gx + gw - 12, sy + 3), radius=S(3), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
                    fx = lx + (gx + gw - 24 - lx) * v
                    accent_fill((lx, sy - 3, fx, sy + 3), 3)
                    d.ellipse(box(fx - 5, sy - 5, fx + 5, sy + 5), fill=rgba(lerp(acc2, (255, 255, 255), 0.6)))
                    ry += 36
                elif kind == 'dropdown':
                    text(d, (lx, ry - 3), label, f_lab, T['Label'])
                    by = ry + 7
                    d.rounded_rectangle(box(lx, by, gx + gw - 12, by + 22), radius=S(5 * st['Radius']), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
                    text(d, (lx + 9, by + 11), v, f_small, T['Text'])
                    cx = gx + gw - 24
                    seg(d, (cx - 3, by + 9), (cx, by + 12.5), T['TextDim'], 1, 1.4)
                    seg(d, (cx, by + 12.5), (cx + 3, by + 9), T['TextDim'], 1, 1.4)
                    ry += 42
                elif kind == 'button':
                    d.rounded_rectangle(box(lx, ry - 10, gx + gw - 12, ry + 12), radius=S(5 * st['Radius']), fill=rgba(T['ControlHover']), outline=rgba(T['Outline']), width=S(1))
                    text(d, ((lx + gx + gw - 12) / 2, ry + 1), label, f_lab, T['Label'], anchor='mm')
                    ry += 32
                elif kind == 'color':
                    text(d, (lx, ry), label, f_lab, T['Label'])
                    for k, c in enumerate(((255, 80, 90), T['Accent'])):
                        sx = gx + gw - 12 - (k + 1) * 22 + 4
                        d.rounded_rectangle(box(sx, ry - 7, sx + 18, ry + 7), radius=S(4), fill=rgba(c), outline=rgba(T['Outline']), width=S(1))
                    ry += 27
                elif kind == 'progress':
                    text(d, (lx, ry - 3), label, f_lab, T['Label'])
                    text(d, (gx + gw - 12, ry - 3), '%d%%' % int(v * 100), f_small, T['TextDim'], anchor='rm')
                    py = ry + 11
                    d.rounded_rectangle(box(lx, py - 2.5, gx + gw - 12, py + 2.5), radius=S(2.5), fill=rgba(T['Control']))
                    accent_fill((lx, py - 2.5, lx + (gx + gw - 12 - lx) * v, py + 2.5), 2.5)
                    ry += 32

    # footer
    if footer:
        text(d, (x0 + 18, y1 - 17), footer[0], f_small, T['TextMuted'])
        if footer[1]:
            text(d, (x1 - 18, y1 - 17), footer[1], f_small, T['TextMuted'], anchor='rm')

    # border: aura gradient, hazard stripes, or the soft top-lit edge
    ring = rrect_mask(size, win, R)
    th = st.get('AuraThickness', 1.5) if st.get('Aura') else 1
    inner = rrect_mask(size, (x0 + th, y0 + th, x1 - th, y1 - th), max(R - th, 0))
    ring = ImageChops.subtract(ring, inner)
    if st.get('Aura'):
        cols = st['Aura']
        if st.get('AuraHard'):
            src = stripes(size, cols, st.get('AuraRotation', 45), 10)
        else:
            src = conic(size, ((x0 + x1) / 2, (y0 + y1) / 2), cols, rotation=t * st.get('AuraSpeed', 0.3))
        edge = lerp(T['Border'], (255, 255, 255), 0.1)
        src.putalpha(ring)
        img.alpha_composite(src)
        if not st.get('AuraHard'):
            glow(img, lambda g: g.rounded_rectangle(box(*win), radius=S(R), outline=rgba(cols[0], 0.45), width=S(2)), 6)
    else:
        top = lerp(T['Border'], (255, 255, 255), 0.1)
        bot = lerp(T['Border'], T['Background'], 0.45)
        src = gradient(size, [(0, rgba(top)), (y0 / size[1], rgba(top)), (y1 / size[1], rgba(bot)), (1, rgba(bot))], 90)
        src.putalpha(ring)
        img.alpha_composite(src)
    if st.get('InnerLine'):
        ImageDraw.Draw(img).rounded_rectangle(box(x0 + 4, y0 + 4, x1 - 4, y1 - 4), radius=S(max(R - 3, 2)), outline=rgba(st['InnerLine'], 0.45), width=S(1))
    if st.get('TopLine'):
        c1, c2 = st['TopLine'][0], st['TopLine'][-1]
        lw = w * 0.72
        line = gradient((lw, 1), [(0, rgba(c1, 0)), (0.5, rgba(lerp(c1, c2, 0.5), 1)), (1, rgba(c2, 0))], 0)
        img.alpha_composite(line, (S(x0 + (w - lw) / 2), S(y0)))
        leak = gradient((w * 0.6, 22), [(0, rgba(c1, 0.14)), (1, rgba(c1, 0))], 90)
        fade = np.sin(np.linspace(0, math.pi, leak.width)) ** 1.5
        a = (np.asarray(leak.getchannel('A'), dtype=np.float32) * fade[None, :]).astype(np.uint8)
        leak.putalpha(Image.fromarray(a, 'L'))
        img.alpha_composite(leak, (S(x0 + w * 0.2), S(y0 + 1)))
    if st.get('Glitch'):
        gd = ImageDraw.Draw(front)
        rng = random.Random(int(t * 10) + 3)
        for c in ((255, 40, 70), (40, 220, 255), (255, 255, 255)):
            bw = w * rng.uniform(0.25, 0.8)
            bx = x0 + rng.random() * (w - bw)
            by = y0 + rng.random() * h
            gd.rectangle(box(bx, by, bx + bw, by + rng.randint(1, 5)), fill=rgba(c, 0.2))
    img.alpha_composite(front)
    return img


def backdrop(T, st, size, t=0.0, seed=1, motes=True):
    W, H = size
    bg = lerp(T['Background'], (0, 0, 0), 0.35)
    img = gradient(size, [(0, rgba(lerp(bg, T['Accent'], 0.06))), (1, rgba(bg))], 90)
    bt = st.get('BackdropTexture')
    if bt:
        tx = tex_fill(size, bt['Image'], bt.get('Zoom', 1), (1 - bt.get('Transparency', 0.85)) * 1.6)
        if tx is not None:
            img.alpha_composite(tx)
    # soft accent light behind the window
    glow(img, lambda g: g.ellipse(box(W * 0.22, H * 0.15, W * 0.78, H * 0.95), fill=rgba(T['Accent'], 0.12)), 60)
    if motes:
        particles(img, size, st.get('Particles', 'Snow'), st.get('ParticleColor', (255, 255, 255)), random.Random(seed + int(t * 3)), 80, t)
    if st.get('Vignette'):
        v = Image.new('L', img.size, 0)
        ImageDraw.Draw(v).rectangle([0, 0, img.width, img.height], fill=0)
        yy, xx = np.mgrid[0:img.height, 0:img.width].astype(np.float32)
        dist = np.sqrt(((xx / img.width) - 0.5) ** 2 + ((yy / img.height) - 0.5) ** 2)
        a = np.clip((dist - 0.35) / 0.4, 0, 1) * 190
        shade = Image.new('RGBA', img.size, (0, 0, 0, 0))
        shade.putalpha(Image.fromarray(a.astype(np.uint8), 'L'))
        img.alpha_composite(shade)
    return img


def render(T, st, size=(960, 600), t=0.0, seed=1, caption=None):
    W, H = size
    win = (W / 2 - 250, 58, W / 2 + 250, H - 98)
    img = backdrop(T, st, size, t, seed)
    if st.get('Blur'):
        # glass: the world behind the window is blurred
        blurred = img.filter(ImageFilter.GaussianBlur(S(st['Blur'] * 0.6)))
        m = rrect_mask(size, win, 10 * st['Radius'])
        img.paste(blurred, (0, 0), m)
    img.alpha_composite(window(T, st, size, win, t))
    if caption:
        theme_caption(img, caption[0], caption[1], T)
    return img.resize((W, H), Image.LANCZOS)


# --------------------------------------------------------------------------------------------------------------

def save_png(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert('RGB').save(path, optimize=True)
    print('%-40s %4d KB' % (os.path.relpath(path, ROOT), os.path.getsize(path) // 1024))


def save_gif(frames, path, fps=12):
    pal = frames[len(frames) // 2].convert('RGB').quantize(colors=255, method=Image.MEDIANCUT)
    q = [f.convert('RGB').quantize(palette=pal, dither=Image.FLOYDSTEINBERG) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(1000 / fps), loop=0, optimize=True, disposal=1)
    print('%-40s %4d KB' % (os.path.relpath(path, ROOT), os.path.getsize(path) // 1024))


# --------------------------------------------------------------------------------------------------------------
# editorial showcase pieces: split dark panels, a plain bold headline, a plain subtitle, one pill. No gradient text.
# --------------------------------------------------------------------------------------------------------------

INTER = '/usr/share/fonts/opentype/inter/'


def ifont(weight, size, display=False):
    key = ('inter', weight, size, display)
    if key not in _fonts:
        name = ('InterDisplay-' if display else 'Inter-') + weight + '.otf'
        path = INTER + name if os.path.exists(INTER + name) else first(SYSTEM_BOLD if weight in ('Bold', 'SemiBold') else SYSTEM)
        _fonts[key] = ImageFont.truetype(path, int(size * SS))
    return _fonts[key]


def mono(size, weight=500):
    key = ('jbm', size, weight)
    if key not in _fonts:
        path = os.path.join(CACHE, 'JetBrainsMono.ttf')
        if not os.path.exists(path):
            try:
                os.makedirs(CACHE, exist_ok=True)
                urllib.request.urlretrieve(GF + 'ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf', path)
            except Exception:
                path = first(SYSTEM_MONO)
        f = ImageFont.truetype(path, int(size * SS))
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
        _fonts[key] = f
    return _fonts[key]


INK = (8, 8, 10)
PANEL_L = (13, 13, 15)
PANEL_R = (19, 19, 23)


def grain(img, amount=5, seed=1):
    """Fine monochrome grain, so large dark areas don't band or look flat."""
    rng = np.random.default_rng(seed)
    n = rng.normal(0, amount, (img.height, img.width)).astype(np.float32)
    a = np.asarray(img, dtype=np.float32)
    a[..., :3] = np.clip(a[..., :3] + n[..., None], 0, 255)
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


def panel(img, b, fill, radius=20, edge=0.05):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box(*b), radius=S(radius), fill=rgba(fill), outline=rgba((255, 255, 255), edge), width=S(1))


def pill(d, x, y, label, f, dark=False):
    w_ = text_w(label, f) + 40
    if dark:
        d.rounded_rectangle(box(x, y, x + w_, y + 44), radius=S(22), fill=(255, 255, 255, 18), outline=(255, 255, 255, 40), width=S(1))
        text(d, (x + w_ / 2, y + 22), label, f, (236, 236, 240), anchor='mm')
    else:
        d.rounded_rectangle(box(x, y, x + w_, y + 44), radius=S(22), fill=(246, 246, 248, 255))
        text(d, (x + w_ / 2, y + 22.5), label, f, (14, 14, 16), anchor='mm')
    return w_


def check_mark(d, cx, cy, r, color):
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=rgba(color))
    seg(d, (cx - r * 0.42, cy + r * 0.02), (cx - r * 0.1, cy + r * 0.34), (10, 10, 12), 1, r * 0.2)
    seg(d, (cx - r * 0.1, cy + r * 0.34), (cx + r * 0.45, cy - r * 0.3), (10, 10, 12), 1, r * 0.2)


def headline(d, x, y, lines, size=64, lh=1.08, color=(246, 246, 248)):
    f = ifont('Bold', size, True)
    for i, ln in enumerate(lines):
        text(d, (x, y + i * size * lh), ln, f, color, anchor='ls')
    return y + (len(lines) - 1) * size * lh


def subtitle(d, x, y, lines, size=20, color=(150, 150, 160), lh=1.5):
    f = ifont('Regular', size)
    for i, ln in enumerate(lines):
        text(d, (x, y + i * size * lh), ln, f, color, anchor='ls')
    return y + (len(lines) - 1) * size * lh


LUAU_KW = {'local', 'function', 'end', 'return', 'if', 'then', 'else', 'for', 'in', 'do', 'not', 'and', 'or', 'true', 'false', 'nil'}
SYN = {'kw': (199, 146, 255), 'str': (163, 214, 140), 'num': (247, 168, 108), 'call': (125, 178, 255), 'key': (226, 226, 234),
       'cls': (240, 200, 122), 'pun': (132, 132, 146), 'com': (96, 96, 108), 'id': (206, 206, 216)}


def luau_tokens(line):
    out = []
    i = 0
    while i < len(line):
        c = line[i]
        if line.startswith('--', i):
            out.append((line[i:], 'com'))
            break
        if c == '"':
            j = line.find('"', i + 1)
            j = len(line) - 1 if j < 0 else j
            out.append((line[i:j + 1], 'str'))
            i = j + 1
        elif c.isdigit():
            j = i
            while j < len(line) and (line[j].isdigit() or line[j] == '.'):
                j += 1
            out.append((line[i:j], 'num'))
            i = j
        elif c.isalpha() or c == '_':
            j = i
            while j < len(line) and (line[j].isalnum() or line[j] == '_'):
                j += 1
            word = line[i:j]
            rest = line[j:].lstrip()
            prev = line[:i].rstrip()[-1:] if line[:i].rstrip() else ''
            if word in LUAU_KW:
                kind = 'kw'
            elif rest.startswith('(') or (prev in (':',) and rest[:1] in ('(', '{', '"')):
                kind = 'call'
            elif rest.startswith('=') and not rest.startswith('=='):
                kind = 'key' if prev in ('{', ',', '') and line[:i].strip() == '' or prev in ('{', ',') else 'id'
            elif word[0].isupper():
                kind = 'cls'
            else:
                kind = 'id'
            out.append((word, kind))
            i = j
        else:
            out.append((c, 'pun' if not c.isspace() else 'id'))
            i += 1
    return out


def code_image(lines, size=21, lh=1.62, active=None, accent=(159, 150, 193)):
    """Syntax-highlighted Luau with line numbers, on a transparent layer."""
    f = mono(size)
    fn = mono(size * 0.86, 400)
    cw = text_w('M', f)
    gutter = cw * 3.6
    W = gutter + cw * (max(len(l) for l in lines) + 2)
    H = size * lh * (len(lines) + 1)
    img = layer((W, H))
    d = ImageDraw.Draw(img)
    for n, ln in enumerate(lines):
        y = size * lh * (n + 0.9)
        if active is not None and n == active:
            d.rectangle(box(0, y - size * 1.05, W, y + size * 0.55), fill=rgba(accent, 0.09))
            d.rectangle(box(0, y - size * 1.05, 2.5, y + size * 0.55), fill=rgba(accent, 0.9))
        text(d, (gutter - cw * 1.2, y), str(n + 1), fn, (84, 84, 96), anchor='rs')
        x = gutter
        for tok, kind in luau_tokens(ln):
            text(d, (x, y), tok, f, SYN[kind], anchor='ls')
            x += text_w(tok, f)
        if active is not None and n == active:
            d.rectangle(box(x + 2, y - size * 0.92, x + 4, y + size * 0.3), fill=rgba((236, 236, 244), 0.9))
    return img


def fade_edges(img, left=0.0, right=0.0, top=0.0, bottom=0.0):
    w, h = img.size
    xx = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    m = np.ones((h, w), np.float32)
    if left:
        m *= np.clip(xx / left, 0, 1) ** 1.5
    if right:
        m *= np.clip((1 - xx) / right, 0, 1) ** 1.5
    if top:
        m *= np.clip(yy / top, 0, 1) ** 1.5
    if bottom:
        m *= np.clip((1 - yy) / bottom, 0, 1) ** 1.5
    a = np.asarray(img.getchannel('A'), dtype=np.float32) * m
    img.putalpha(Image.fromarray(a.astype(np.uint8), 'L'))
    return img


def slant(img, angle=-8, shear=0.16):
    """Lean a flat layer back a little: a horizontal shear, then a small turn."""
    w, h = img.size
    sheared = img.transform((int(w + abs(shear) * h), h), Image.AFFINE, (1, shear, -abs(shear) * h if shear > 0 else 0, 0, 1, 0), resample=Image.BICUBIC)
    return sheared.rotate(angle, resample=Image.BICUBIC, expand=True)


def paste_clipped(dst, src, pos, clip_box, radius):
    """alpha_composite src at pos (logical px), only inside the rounded clip_box."""
    tmp = layer((dst.width / SS, dst.height / SS))
    tmp.alpha_composite(src, (S(pos[0]), S(pos[1])))
    m = rrect_mask((dst.width / SS, dst.height / SS), clip_box, radius)
    tmp.putalpha(ImageChops.multiply(tmp.getchannel('A'), m))
    dst.alpha_composite(tmp)


def mini_toggle_card(img, T, st, x, y, w):
    """A small TingUI group with one toggle switched on: what the code on the banner makes."""
    d = ImageDraw.Draw(img)
    R = 10 * st.get('Radius', 1)
    h = 106
    glow(img, lambda g: g.rounded_rectangle(box(x, y + 12, x + w, y + h + 14), radius=S(R), fill=(0, 0, 0, 190)), 18)
    d.rounded_rectangle(box(x, y, x + w, y + h), radius=S(R), fill=rgba(T['Group']), outline=rgba(T['GroupBorder']), width=S(1))
    ft, fl, fs = ifont('SemiBold', 14), ifont('Medium', 14), ifont('Regular', 12)
    text(d, (x + 16, y + 22), 'Combat', ft, T['Text'])
    seg(d, (x + 16, y + 38), (x + w - 16, y + 38), T['Outline'], 1)
    acc = T['Accent']
    cy = y + 64
    d.rounded_rectangle(box(x + 16, cy - 9, x + 34, cy + 9), radius=S(5), fill=rgba(acc))
    seg(d, (x + 20.5, cy), (x + 24, cy + 3.6), T['Background'], 1, 2)
    seg(d, (x + 24, cy + 3.6), (x + 30, cy - 3.8), T['Background'], 1, 2)
    text(d, (x + 44, cy), 'Auto farm', fl, T['Text'])
    text(d, (x + 44, cy + 22), 'Farm.Enabled = true', mono(11.5, 400), T['TextMuted'])
    # a keybind chip on the right, the way :AddKeybind shows it
    kw = 34
    d.rounded_rectangle(box(x + w - 16 - kw, cy - 10, x + w - 16, cy + 10), radius=S(5), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
    text(d, (x + w - 16 - kw / 2, cy), 'F', ifont('Medium', 11), T['TextDim'], anchor='mm')
    return h


def banner(defaults, presets):
    """docs/images/banner.png: what TingUI is, plainly. Left: the claim. Right: the code, and what it makes."""
    W, H = 1600, 560
    T, st = full_theme(defaults, presets['Lavender'])
    img = layer((W, H))
    img.alpha_composite(Image.new('RGBA', img.size, rgba(INK)))
    L = (16, 16, 700, H - 16)
    R = (712, 16, W - 16, H - 16)
    panel(img, L, PANEL_L)
    panel(img, R, PANEL_R)
    d = ImageDraw.Draw(img)
    # left: status line, headline, subtitle, one button
    check_mark(d, 76, 84, 10, T['Success'])
    text(d, (96, 84), 'TingUI v0.0.9 loaded', ifont('Medium', 16), (210, 210, 218))
    headline(d, 64, 214, ['Interfaces for', 'Roblox scripts.', 'One file.'], size=62)
    subtitle(d, 66, 398, ['Windows, themes, notifications and living scenes.', 'Load it with loadstring or require.'], size=19)
    bw = pill(d, 64, 452, 'Read the docs', ifont('SemiBold', 16))
    text(d, (64 + bw + 22, 474), 'github.com/Irakli17/Ui-Library-Test', mono(13, 400), (108, 108, 120))
    # right: the code that builds a window, leaning back
    code = [
        'local TingUI = loadstring(game:HttpGet(URL))()',
        '',
        'local Window = TingUI:CreateWindow({',
        '    Title = "Example Hub",',
        '})',
        'local Main = Window:AddTab("Main")',
        'local Combat = Main:AddGroup("Combat", "Left")',
        '',
        'Combat:AddToggle({',
        '    Text = "Auto farm",',
        '    Callback = function(on)',
        '        Farm.Enabled = on',
        '    end,',
        '})',
        '',
        'TingUI:Notify({ Title = "Ready", Type = "Success" })',
    ]
    ci = slant(code_image(code, 19, active=9, accent=T['Accent']), -7, 0.04)
    ci = fade_edges(ci, left=0.02, right=0.2, top=0.04, bottom=0.26)
    glow(img, lambda g: g.ellipse(box(900, 60, 1500, 520), fill=rgba(T['Accent'], 0.06)), 90)
    paste_clipped(img, ci, (R[0] + 18, R[1] + 2), R, 20)
    # what it makes, sitting over the code
    mini_toggle_card(img, T, st, 1236, 300, 300)
    notify_card2(img, T, 1236, 424, 300, 'Success', 'Ready', 'Auto farm is on.', progress=0.64)
    out = grain(img, 3.2, 7).resize((W, H), Image.LANCZOS)
    save_png(out, os.path.join(OUT, 'banner.png'))


def editorial(size, left_w, eyebrow, head, sub, stage_fn, head_size=48, seed=3, accent=None):
    """The shared showcase layout: a narrow text panel on the left, the product on a dark stage on the right."""
    W, H = size
    img = layer((W, H))
    img.alpha_composite(Image.new('RGBA', img.size, rgba(INK)))
    L = (16, 16, 16 + left_w, H - 16)
    R = (28 + left_w, 16, W - 16, H - 16)
    panel(img, L, PANEL_L)
    panel(img, R, PANEL_R)
    d = ImageDraw.Draw(img)
    ex, ey = L[0] + 40, L[1] + 62
    if accent:
        d.rounded_rectangle(box(ex, ey - 7, ex + 14, ey + 7), radius=S(4), fill=rgba(accent))
        text(d, (ex + 24, ey), eyebrow, ifont('Medium', 15), (196, 196, 206))
    else:
        text(d, (ex, ey), eyebrow, ifont('Medium', 15), (196, 196, 206))
    y = headline(d, ex - 2, ey + 92, head, size=head_size)
    subtitle(d, ex, y + 52, sub, size=17)
    stage = layer((R[2] - R[0], R[3] - R[1]))
    stage_fn(stage, (R[2] - R[0], R[3] - R[1]))
    paste_clipped(img, stage, (R[0], R[1]), R, 20)
    return grain(img, 3, seed).resize((W, H), Image.LANCZOS)


def stage_light(img, size, color, cx=0.5, cy=0.45, k=0.42, a=0.08):
    W, H = size
    glow(img, lambda g: g.ellipse(box(W * (cx - k), H * (cy - k * 1.1), W * (cx + k), H * (cy + k * 1.1)), fill=rgba(color, a)), 80)


def stage_base(T, size, light=0.07):
    """A clean dark stage for a showcase: no particles, one soft light in the theme's accent."""
    img = layer(size)
    img.alpha_composite(Image.new('RGBA', img.size, rgba(PANEL_R)))
    stage_light(img, size, T['Accent'], a=light)
    return img


def framed(stage_img, size, left_w, eyebrow, head, sub, path, accent=None, head_size=46):
    """Put a finished stage (exactly the stage size) into the editorial frame and save it."""
    W, H = size
    out = editorial((W + left_w + 44, H + 32), left_w, eyebrow, head, sub, lambda st_, sz: st_.alpha_composite(stage_img),
                    head_size=head_size, accent=accent)
    save_png(out, path)


TAGLINES = {
    'Lavender': 'The reference look. Soft lilac, snow.',
    'Ocean': 'Waves along the bottom, a tide on switching, bubbles that pop.',
    'Rose': 'Climbing roses that open toward the cursor, petals on the breeze.',
    'Sunset': 'A low banded sun, birds crossing, embers cooling as they rise.',
    'Mono': 'Sharp, flat, monospace. Scanlines and glyph rain.',
    'Frost': 'Pale ice and crystals. The first snowfall settles and stays.',
    'Royal': 'Midnight navy and gold, serif type, a gilded border.',
    'Cosmos': 'Nebula, parallax stars, comets and a turning aurora.',
    'Storm': 'Rain on the glass, clouds that light up, bolts that fork through.',
    'Blueprint': 'Drafting paper, a ruled border and handwritten labels.',
    'Hazard': 'Yellow and black warning tape, square corners.',
    'Glass': 'Frosted, see-through surfaces over a blurred world.',
    'Hologram': 'A cyan projection that locks on, scans and tears.',
    'Circuit': 'A chip on a board, current racing down its traces.',
    'Serotonin': 'A crisp classic menu. Hairline teal, square corners.',
}


def theme_caption(img, name, desc, T):
    """A quiet caption under a theme preview: the name, one line about it, and the theme's main colours."""
    W, H = img.width / SS, img.height / SS
    d = ImageDraw.Draw(img)
    shade = gradient((W, 120), [(0, rgba((0, 0, 0), 0)), (1, rgba((0, 0, 0), 0.55))], 90)
    img.alpha_composite(shade, (0, S(H - 120)))
    text(d, (32, H - 52), name, ifont('Bold', 20, True), (246, 246, 248), anchor='ls')
    line = TAGLINES.get(name, desc.split('. ')[0])
    f = ifont('Regular', 13.5)
    text(d, (32, H - 28), line, f, (176, 176, 188), anchor='ls')
    x = W - 32
    for key in ('Text', 'Accent', 'Control', 'Background'):
        c = T[key]
        d.ellipse(box(x - 16, H - 52, x, H - 36), fill=rgba(c), outline=(255, 255, 255, 60), width=S(1))
        x -= 22


def anatomy(defaults, presets):
    """docs/images/anatomy.png: the Lavender window with numbered callouts for each part."""
    W, H = 1280, 640
    T, st = full_theme(defaults, presets['Lavender'])
    st = dict(st, Particles='Snow')
    win = (390, 96, 890, 540)
    x0, y0, x1, y1 = win
    img = stage_base(T, (W, H))
    img.alpha_composite(window(T, st, (W, H), win, 0.6))
    gw = (500 - 34 - 8) / 2
    gy0 = y0 + 88
    rgx = x0 + 17 + gw + 8
    callouts = [
        ('L', 'Title, Tag and Version', 'CreateWindow{Title, Tag, Version}', (x0 + 11, y0 + 25)),
        ('L', 'Tabs', 'one pill slides between them', (x0 + 12, y0 + 63)),
        ('L', 'Group', 'Tab:AddGroup(title, side)', (x0 + 17, gy0 + 40)),
        ('L', 'Toggle', 'add :AddKeybind / :AddColorPicker', (x0 + 24, gy0 + 50)),
        ('L', 'Button', 'ripple, Confirm, sub-buttons', (x0 + 29, gy0 + 246)),
        ('L', 'Footer', 'drag strip, Footer text', (x0 + 12, y1 - 17)),
        ('R', 'Subtitle', 'or the game name', (x1 - 11, y0 + 25)),
        ('R', 'Colour pickers', 'hue bar, square, hex', (x1 - 25, gy0 + 104)),
        ('R', 'Slider', 'click the value to type one', (x1 - 25, gy0 + 143)),
        ('R', 'Progress', 'animated sheen, :Increment(n)', (x1 - 25, gy0 + 205)),
        ('R', 'Dropdown', 'search, multi-select, players', (x1 - 29, gy0 + 244)),
        ('R', 'Resize grip', 'drag the corner', (x1 - 4, y1 - 4)),
    ]
    lay = layer((W, H))
    d = ImageDraw.Draw(lay)
    fl, fs, fn = font(None, 18, True), font('Mono', 13.5), font(None, 12, True)
    acc = T['Accent']
    rows = {'L': 0, 'R': 0}
    count = {'L': sum(1 for c in callouts if c[0] == 'L'), 'R': sum(1 for c in callouts if c[0] == 'R')}
    for i, (side, title, sub, (px, py)) in enumerate(callouts):
        k = rows[side]
        rows[side] += 1
        ly = 70 + k * (H - 140) / max(count[side] - 1, 1)
        lx = 352 if side == 'L' else 928
        ex = lx + (14 if side == 'L' else -14)
        seg(d, (px, py), (ex, ly), acc, 0.55, 1.2)
        seg(d, (ex, ly), (lx, ly), acc, 0.55, 1.2)
        d.ellipse(box(px - 3, py - 3, px + 3, py + 3), fill=rgba(acc, 1))
        n = str(i + 1)
        bx = lx - 12 if side == 'L' else lx + 12
        d.ellipse(box(bx - 11, ly - 11, bx + 11, ly + 11), fill=rgba(lerp(acc, T['Background'], 0.55)), outline=rgba(acc), width=S(1.3))
        text(d, (bx, ly), n, fn, (240, 238, 250), anchor='mm')
        tx = bx - 20 if side == 'L' else bx + 20
        anchor = 'r' if side == 'L' else 'l'
        text(d, (tx, ly - 9), title, fl, (232, 230, 244), anchor=anchor + 'm')
        text(d, (tx, ly + 13), sub, fs, (160, 156, 182), anchor=anchor + 'm')
    img.alpha_composite(lay)
    framed(img, (W, H), 400, 'Anatomy', ['Every part,', 'named.'],
           ['What each piece of a window is called,', 'and the call that makes it.'], os.path.join(OUT, 'anatomy.png'), accent=T['Accent'])



# --------------------------------------------------------------------------------------------------------------
# docs/images/shell.png and docs/images/studio.png: v0.0.7's Shell and Theme Studio
# --------------------------------------------------------------------------------------------------------------

def luminance(c):
    def ch(v):
        v = v / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def group_box(d, T, st, gx, gy, gw, gh, title, f):
    d.rounded_rectangle(box(gx, gy, gx + gw, gy + gh), radius=S(6 * st['Radius']), fill=rgba(T['Group']), outline=rgba(T['GroupBorder']), width=S(1))
    text(d, (gx + 12, gy + 17), title, f, T['Text'])
    seg(d, (gx + 12, gy + 31), (gx + gw - 12, gy + 31), T['GroupBorder'], 1)
    return gy + 48


def swatch_row(d, T, gx, gw, ry, label, color, f):
    text(d, (gx + 12, ry), label, f, T['Label'])
    sx = gx + gw - 12 - 18
    d.rounded_rectangle(box(sx, ry - 7, sx + 18, ry + 7), radius=S(4), fill=rgba(color), outline=rgba(T['Outline']), width=S(1))


def glyph(d, kind, cx, cy, color, alpha=1.0):
    """The dock's built-in icons, drawn as simple strokes."""
    if kind == 'window':
        d.rounded_rectangle(box(cx - 7, cy - 6, cx + 7, cy + 6), radius=S(2.5), outline=rgba(color, alpha), width=S(1.4))
        seg(d, (cx - 7, cy - 2), (cx + 7, cy - 2), color, alpha, 1.4)
    elif kind == 'keyboard':
        d.rounded_rectangle(box(cx - 8, cy - 5, cx + 8, cy + 5), radius=S(2), outline=rgba(color, alpha), width=S(1.4))
        for k in range(4):
            d.ellipse(box(cx - 5.2 + k * 3.4 - 0.8, cy - 2 - 0.8, cx - 5.2 + k * 3.4 + 0.8, cy - 2 + 0.8), fill=rgba(color, alpha))
        seg(d, (cx - 4, cy + 2), (cx + 4, cy + 2), color, alpha, 1.4)
    elif kind == 'command':
        d.ellipse(box(cx - 6, cy - 6, cx + 3, cy + 3), outline=rgba(color, alpha), width=S(1.5))
        seg(d, (cx + 2, cy + 2), (cx + 6.5, cy + 6.5), color, alpha, 1.7)


def notify_card(img, T, st, x, y, w, kind, source, title, body, actions=()):
    """One notification card, as TingUI draws it. Returns its height."""
    d = ImageDraw.Draw(img)
    col = {'Success': T['Success'], 'Warning': T.get('Caution', T['Warning']), 'Info': T['Info']}[kind]
    fs, ft, fb, fa = font(None, 8.5, True), font(None, 12.5), font(None, 11), font(None, 10)
    lines = body if isinstance(body, (list, tuple)) else [body]
    h = 20 + (13 if source else 0) + 17 + 15 * len(lines) + (28 if actions else 0) + 6
    glow(img, lambda g: g.rounded_rectangle(box(x, y + 6, x + w, y + h + 6), radius=S(9), fill=(0, 0, 0, 120)), 10)
    d.rounded_rectangle(box(x, y, x + w, y + h), radius=S(9), fill=rgba(T['Background']), outline=rgba(T['Outline']), width=S(1))
    living_card(img, T, x, y, w, h, col)
    d.rounded_rectangle(box(x, y + 6, x + 3, y + h - 6), radius=S(2), fill=rgba(col))
    # badge: circle for success and info, diamond for warnings
    bx, by = x + 26, y + 10 + (13 if source else 0) + 16
    glow(img, lambda g: g.ellipse(box(bx - 13, by - 13, bx + 13, by + 13), fill=rgba(col, 0.45)), 6)
    if kind == 'Warning':
        d.polygon([(S(bx), S(by - 11)), (S(bx + 11), S(by)), (S(bx), S(by + 11)), (S(bx - 11), S(by))], fill=rgba(lerp(col, T['Background'], 0.7)), outline=rgba(col))
        seg(d, (bx, by - 5), (bx, by + 1.5), col, 1, 1.8)
        d.ellipse(box(bx - 1.1, by + 3.6, bx + 1.1, by + 5.8), fill=rgba(col))
    else:
        d.ellipse(box(bx - 10, by - 10, bx + 10, by + 10), fill=rgba(lerp(col, T['Background'], 0.7)), outline=rgba(col), width=S(1.2))
        seg(d, (bx - 4.5, by), (bx - 1.2, by + 3.5), col, 1, 1.8)
        seg(d, (bx - 1.2, by + 3.5), (bx + 4.8, by - 3.5), col, 1, 1.8)
    tx = x + 48
    ty = y + 16
    if source:
        text(d, (tx, ty), source.upper(), fs, T['TextMuted'])
        ty += 14
    text(d, (tx, ty + 2), title, ft, T['Text'])
    ty += 18
    for ln in lines:
        text(d, (tx, ty + 1), ln, fb, T['TextDim'])
        ty += 15
    if actions:
        ax = tx
        for a in actions:
            aw = text_w(a, fa) + 18
            d.rounded_rectangle(box(ax, ty + 3, ax + aw, ty + 23), radius=S(6), fill=rgba(lerp(col, T['Background'], 0.82)), outline=rgba(lerp(col, T['Background'], 0.5)), width=S(1))
            text(d, (ax + aw / 2, ty + 13), a, fa, lerp(col, (255, 255, 255), 0.3), anchor='mm')
            ax += aw + 6
    # the countdown bar along the bottom
    d.rounded_rectangle(box(x + 10, y + h - 4, x + 10 + (w - 20) * 0.62, y + h - 2.5), radius=S(1), fill=rgba(col, 0.9))
    return h


NOTE_KINDS = {'Success': ('Success', 'circle'), 'Warning': ('Caution', 'diamond'), 'Error': ('Error', 'square'), 'Info': ('Info', 'circle'),
              'Download': ('Info', 'circle'), 'Upload': ('Info', 'circle'), 'Message': ('Accent', 'square'), 'Friend': ('Success', 'circle'),
              'Achievement': ('Caution', 'diamond'), 'Security': ('Error', 'square'), 'Update': ('Accent', 'circle'), 'Heart': ('Error', 'circle'),
              'Teleport': ('Info', 'circle'), 'ServerHop': ('Info', 'circle'), 'Reward': ('Caution', 'square'), 'Currency': ('Caution', 'circle'),
              'LevelUp': ('Success', 'diamond'), 'Timer': ('Accent', 'circle'), 'Connection': ('Success', 'circle'), 'Target': ('Error', 'circle'),
              'Invite': ('Accent', 'square'), 'Streak': ('Caution', 'diamond'), 'Boost': ('Accent', 'circle'), 'Protected': ('Success', 'square'),
              'Key': ('Caution', 'circle'), 'Party': ('Accent', 'circle'), 'MVP': ('Caution', 'diamond'), 'Combat': ('Error', 'square'),
              'Copied': ('Info', 'square'), 'Deleted': ('Error', 'square'), 'Sync': ('Info', 'circle'), 'AFK': ('Accent', 'circle')}
# the high-res icon each newer type uses (assets/icons); the older ones are drawn by note_glyph
NOTE_ICONS = {'Teleport': 'pin', 'ServerHop': 'globe', 'Reward': 'gift', 'Currency': 'coin', 'LevelUp': 'trophy', 'Timer': 'clock',
              'Connection': 'wifi', 'Target': 'target', 'Invite': 'mail', 'Streak': 'fire', 'Boost': 'rocket', 'Protected': 'shield',
              'Key': 'key', 'Party': 'users', 'MVP': 'crown', 'Combat': 'sword', 'Copied': 'copy', 'Deleted': 'trash', 'Sync': 'refresh',
              'AFK': 'moon', 'Security': 'lock', 'Update': 'gear', 'Heart': 'heart', 'Info': 'info'}
_icons = {}


def icon_glyph(img, name, cx, cy, size, col, alpha=1.0):
    """One of TingUI's 96px icons (white on clear), tinted and placed centred on (cx, cy)."""
    path = os.path.join(ROOT, 'assets', 'icons', name + '.png')
    if not os.path.exists(path):
        return False
    key = (name, size)
    if key not in _icons:
        _icons[key] = Image.open(path).convert('RGBA').resize((S(size), S(size)), Image.LANCZOS)
    ic = _icons[key]
    solid = Image.new('RGBA', ic.size, rgba(col))
    solid.putalpha(ic.getchannel('A').point(lambda v: int(v * alpha)))
    img.alpha_composite(solid, (S(cx - size / 2), S(cy - size / 2)))
    return True


def living_card(img, T, x, y, w, h, col):
    """The card background: two tints of its colour on a slow diagonal, never one flat fill (matches the game)."""
    twin = lerp(lerp(col, T['Accent'], 0.5), T['Text'], 0.15)
    g = gradient((w - 2, h - 2), [(0, rgba(col, 0.15)), (0.5, rgba(T['Background'], 0)), (1, rgba(twin, 0.09))], 22)
    m = Image.new('L', g.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=S(8), fill=255)
    g.putalpha(ImageChops.multiply(g.getchannel('A'), m))
    img.alpha_composite(g, (S(x + 1), S(y + 1)))


def note_glyph(d, kind, bx, by, col):
    if kind in ('Success',):
        seg(d, (bx - 4.5, by), (bx - 1.2, by + 3.5), col, 1, 1.8)
        seg(d, (bx - 1.2, by + 3.5), (bx + 4.8, by - 3.5), col, 1, 1.8)
    elif kind in ('Warning',):
        seg(d, (bx, by - 5), (bx, by + 1.5), col, 1, 1.8)
        d.ellipse(box(bx - 1.1, by + 3.6, bx + 1.1, by + 5.8), fill=rgba(col))
    elif kind in ('Error',):
        seg(d, (bx - 4, by - 4), (bx + 4, by + 4), col, 1, 1.8)
        seg(d, (bx + 4, by - 4), (bx - 4, by + 4), col, 1, 1.8)
    elif kind in ('Download', 'Upload'):
        up = kind == 'Upload'
        seg(d, (bx, by - 6 + (2 if up else 0)), (bx, by + 2 + (2 if up else 0)), col, 1, 1.8)
        tip = by - 5 if up else by + 3
        for s_ in (-1, 1):
            seg(d, (bx, tip), (bx + s_ * 3.4, tip + (3.4 if up else -3.4)), col, 1, 1.8)
        seg(d, (bx - 6, by + 6), (bx + 6, by + 6), col, 1, 1.8)
    elif kind == 'Message':
        d.rounded_rectangle(box(bx - 7, by - 6, bx + 7, by + 3), radius=S(3), fill=rgba(col))
        d.polygon([(S(bx - 4), S(by + 2)), (S(bx - 1), S(by + 2)), (S(bx - 4), S(by + 6))], fill=rgba(col))
        for k in range(3):
            d.ellipse(box(bx - 4.2 + k * 3.6, by - 2.4 - (1 if k == 1 else 0), bx - 2.6 + k * 3.6, by - 0.8 - (1 if k == 1 else 0)), fill=(14, 14, 18, 255))
    elif kind == 'Achievement':
        pts = []
        for k in range(8):
            r = 7 if k % 2 == 0 else 2.4
            a = k * math.pi / 4 - math.pi / 2
            pts.append((S(bx + math.cos(a) * r), S(by + math.sin(a) * r)))
        d.polygon(pts, fill=rgba(col))
    elif kind == 'Friend':
        d.ellipse(box(bx - 2.8, by - 6, bx + 2.8, by - 0.4), fill=rgba(col))
        d.rounded_rectangle(box(bx - 5.5, by + 0.8, bx + 5.5, by + 6), radius=S(3), fill=rgba(col))
    else:
        d.ellipse(box(bx - 2, by - 2, bx + 2, by + 2), fill=rgba(col))


def notify_card2(img, T, x, y, w, kind, title, body, source=None, actions=(), value=None, reply=None, details=None,
                 count=None, tools=False, undo=None, progress=0.62, image=None):
    """A v0.0.8 notification card with its extras. Returns its height."""
    d = ImageDraw.Draw(img)
    key, shape = NOTE_KINDS[kind]
    col = T.get(key, T['Accent'])
    fs, ft, fb, fa = font(None, 8.5, True), font(None, 12.5), font(None, 11.5), font(None, 10)
    lines = body if isinstance(body, (list, tuple)) else [body]
    h = 18 + (13 if source else 0) + 17 + 16 * len(lines)
    if value is not None:
        h += 16
    if reply:
        h += 30
    if actions or undo:
        h += 28
    if details:
        h += 16 * len(details) + 14
    h += 8
    glow(img, lambda g: g.rounded_rectangle(box(x, y + 6, x + w, y + h + 6), radius=S(9), fill=(0, 0, 0, 120)), 10)
    d.rounded_rectangle(box(x, y, x + w, y + h), radius=S(9), fill=rgba(T['Background']), outline=rgba(lerp(col, T['Background'], 0.55)), width=S(1))
    living_card(img, T, x, y, w, h, col)
    d.rounded_rectangle(box(x, y + 6, x + 3, y + h - 6), radius=S(2), fill=rgba(col))
    bx, by = x + 25, y + 22 + (13 if source else 0)
    glow(img, lambda g: g.ellipse(box(bx - 13, by - 13, bx + 13, by + 13), fill=rgba(col, 0.4)), 6)
    plate = rgba(lerp(col, T['Background'], 0.78))
    edge = rgba(lerp(col, T['Background'], 0.35))
    if image:
        d.rounded_rectangle(box(bx - 16, by - 16, bx + 16, by + 16), radius=S(9), fill=rgba(image), outline=rgba(col, 0.7), width=S(1))
        d.ellipse(box(bx - 6, by - 11, bx + 6, by + 1), fill=rgba(lerp(image, (255, 255, 255), 0.5)))
        d.rounded_rectangle(box(bx - 11, by + 3, bx + 11, by + 16), radius=S(6), fill=rgba(lerp(image, (255, 255, 255), 0.5)))
        d.ellipse(box(bx + 8, by + 8, bx + 20, by + 20), fill=plate, outline=edge)
        note_glyph(d, 'Success', bx + 14, by + 14, col)
    elif shape == 'diamond':
        d.polygon([(S(bx), S(by - 12)), (S(bx + 12), S(by)), (S(bx), S(by + 12)), (S(bx - 12), S(by))], fill=plate, outline=edge)
    elif shape == 'square':
        d.rounded_rectangle(box(bx - 12, by - 12, bx + 12, by + 12), radius=S(7), fill=plate, outline=edge, width=S(1))
    else:
        d.ellipse(box(bx - 12, by - 12, bx + 12, by + 12), fill=plate, outline=edge, width=S(1))
    if not image:
        if kind not in NOTE_ICONS or not icon_glyph(img, NOTE_ICONS[kind], bx, by, 14, col):
            note_glyph(d, kind, bx, by, col)
    if kind == 'Achievement':
        for k in range(10):
            a = k / 10 * 6.283
            seg(d, (bx + math.cos(a) * 17, by + math.sin(a) * 17), (bx + math.cos(a) * 21, by + math.sin(a) * 21), lerp(col, (255, 255, 255), 0.35), 0.6, 1.4)
    tx = x + 49
    ty = y + 13
    tw = w - 49 - 14 - 34
    if source:
        text(d, (tx, ty + 2), source.upper(), fs, T['TextMuted'])
        ty += 13
    text(d, (tx, ty + 6), title, ft, col)
    ty += 18
    for ln in lines:
        text(d, (tx, ty + 6), ln, fb, T['Label'])
        ty += 16
    if value is not None:
        bw = w - 49 - 14 - 34 - 38 + 34
        d.rounded_rectangle(box(tx, ty + 7, tx + bw, ty + 11), radius=S(2), fill=rgba(T['Outline']))
        d.rounded_rectangle(box(tx, ty + 7, tx + bw * value, ty + 11), radius=S(2), fill=rgba(col))
        sw = gradient((bw * value * 0.35, 4), [(0, rgba((255, 255, 255), 0)), (0.5, rgba((255, 255, 255), 0.5)), (1, rgba((255, 255, 255), 0))], 0)
        img.alpha_composite(sw, (S(tx + bw * value * 0.5), S(ty + 7)))
        text(d, (tx + bw + 34, ty + 9), '%d%%' % round(value * 100), font(None, 11, True), T['Label'], anchor='rm')
        ty += 16
    if reply:
        rw = w - 49 - 14 - 58
        d.rounded_rectangle(box(tx, ty + 6, tx + rw, ty + 30), radius=S(6), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
        text(d, (tx + 9, ty + 18), reply, fb, T['TextMuted'])
        sx = tx + rw + 6
        d.rounded_rectangle(box(sx, ty + 8, sx + 46, ty + 28), radius=S(6), fill=rgba(col))
        text(d, (sx + 23, ty + 18), 'Send', fa, T['Background'], anchor='mm')
        ty += 30
    if actions or undo:
        ax = tx
        allacts = ([('Undo  %d' % undo, 'Primary')] if undo else []) + list(actions)
        for a in allacts:
            label, style = a if isinstance(a, tuple) else (a, None)
            aw = text_w(label, fa) + 18
            if style == 'Primary':
                d.rounded_rectangle(box(ax, ty + 6, ax + aw, ty + 26), radius=S(6), fill=rgba(col))
                text(d, (ax + aw / 2, ty + 16), label, fa, T['Background'], anchor='mm')
            else:
                tone = T['Error'] if style == 'Danger' else col
                d.rounded_rectangle(box(ax, ty + 6, ax + aw, ty + 26), radius=S(6), fill=rgba(lerp(tone, T['Background'], 0.82)), outline=rgba(lerp(tone, T['Background'], 0.5)), width=S(1))
                text(d, (ax + aw / 2, ty + 16), label, fa, lerp(tone, (255, 255, 255), 0.25) if style != 'Copied' else T['Success'], anchor='mm')
            ax += aw + 6
        ty += 28
    if details:
        dh = 16 * len(details) + 10
        d.rounded_rectangle(box(tx, ty + 4, x + w - 14, ty + 4 + dh), radius=S(6), fill=rgba(T['Group']), outline=rgba(T['Outline']), width=S(1))
        for i, ln in enumerate(details):
            text(d, (tx + 8, ty + 13 + i * 16), ln, font('Code', 10.5), T['TextDim'])
        ty += dh + 4
    if tools or count:
        rx = x + w - 8
        if tools:
            d.rounded_rectangle(box(rx - 18, y + 6, rx, y + 24), radius=S(5), fill=rgba(T['ControlHover']))
            seg(d, (rx - 13, y + 11), (rx - 5, y + 19), T['TextDim'], 1, 1.5)
            seg(d, (rx - 5, y + 11), (rx - 13, y + 19), T['TextDim'], 1, 1.5)
            rx -= 21
            d.rounded_rectangle(box(rx - 18, y + 6, rx, y + 24), radius=S(5), fill=rgba(T['ControlHover']))
            d.ellipse(box(rx - 11, y + 9, rx - 4, y + 16), fill=rgba(T['TextDim']))
            seg(d, (rx - 9, y + 16), (rx - 11, y + 21), T['TextDim'], 1, 1.6)
            rx -= 21
        if count:
            cw = text_w('x%d' % count, font(None, 10, True)) + 12
            d.rounded_rectangle(box(rx - cw, y + 7, rx, y + 23), radius=S(8), fill=rgba(T['Control']))
            text(d, (rx - cw / 2, y + 15), 'x%d' % count, font(None, 10, True), T['Text'], anchor='mm')
    if progress is not None:
        d.rounded_rectangle(box(x + 10, y + h - 4, x + 10 + (w - 20) * progress, y + h - 2.5), radius=S(1), fill=rgba(col, 0.9))
    return h


def notifications_image(defaults, presets):
    """docs/images/notifications.png: the cards, old and new types, tightly arranged on a clean stage."""
    W, H = 1020, 540
    T, st = full_theme(defaults, presets['Lavender'])
    img = stage_base(T, (W, H))
    cw = 300
    cols = [36, 36 + cw + 24, 36 + (cw + 24) * 2]
    ys = [36, 64, 28]

    def put(ci, **kw):
        h = notify_card2(img, T, cols[ci], ys[ci], cw, **kw)
        ys[ci] += h + 12

    put(0, kind='Download', title='Downloading', body='assets.pak  14 / 24 MB', value=0.58, progress=None)
    put(0, kind='Teleport', title='Teleported', body='Moved to Spawn (124, 8, -37).', actions=('Go back',), progress=0.7)
    put(0, kind='Message', title='builderman', body='gg, want to run it back?', reply='Reply...', progress=None)
    put(0, kind='Currency', title='+250 coins', body='Balance: 4,180.', progress=0.45)
    put(0, kind='Streak', title='5-day streak', body='Come back tomorrow to keep it going.', progress=0.8)
    put(1, kind='Error', title='Request failed', body='The server answered 503.', actions=('Hide details', ('Copied', 'Copied')),
        details=['POST /api/v1/sync', 'status: 503 Service Unavailable', 'request-id: 7f3c-91aa-02de'], tools=True, progress=None)
    put(1, kind='Invite', title='Party invite', body='builderman invited you to their party.', actions=(('Join', 'Primary'), 'Decline'), progress=0.55)
    put(1, kind='Deleted', title='Config deleted', body='"pvp" was removed.', undo=4, progress=0.66)
    put(1, kind='Sync', title='Syncing', body='Saving your config to the cloud...', value=0.4, progress=None)
    put(2, kind='LevelUp', title='Level 24', body='1,450 / 12,000 XP to the next one.', value=0.12, progress=None)
    put(2, kind='Reward', title='Daily reward', body='You got 3 crates.', actions=(('Open', 'Primary'),), progress=0.72)
    put(2, kind='Friend', title='Player joined', body='The server is filling up.', count=3, tools=True, progress=0.9)
    put(2, kind='Protected', title='Spawn protection', body="You can't be damaged for 10 seconds.", progress=0.35)
    put(2, kind='AFK', title='AFK detected', body="You'll be kicked in 2 minutes.", actions=(("I'm here", 'Primary'),), progress=0.5)
    d = ImageDraw.Draw(img)
    fc = font(None, 11)
    label = 'Clear all (14)'
    pw = text_w(label, fc) + 22
    px, py = cols[2] + cw - pw, ys[2]
    d.rounded_rectangle(box(px, py, px + pw, py + 22), radius=S(11), fill=rgba(T['Control']), outline=rgba(T['Outline']), width=S(1))
    text(d, (px + pw / 2, py + 11), label, fc, T['TextDim'], anchor='mm')
    framed(img, (W, H), 400, 'Notifications', ['Say what', 'happened.'],
           ['Over thirty types, each with its own', 'animated badge. Progress, replies, undo,', 'details, buttons, merging and a history.', 'The cards never sit still.'],
           os.path.join(OUT, 'notifications.png'), accent=T['Accent'])


def shell_image(defaults, presets):
    W, H = 1280, 700
    T, st = full_theme(defaults, presets['Lavender'])
    st = dict(st, Particles='Snow')
    T2, st2 = full_theme(defaults, presets['Ocean'])
    img = stage_base(T, (W, H))
    host = (64, 150, 524, 662)
    member = (556, 176, 956, 662)
    img.alpha_composite(window(T2, st2, (W, H), member, 0.9, title='Second Hub', compact=True,
                               tabs=('Farm', 'Teleports', 'Misc'), footer=('Second Hub v2', 'Insert to hide')))
    img.alpha_composite(window(T, st, (W, H), host, 0.6, title='My Hub'))
    d = ImageDraw.Draw(img)

    # the host's dock with its taskbar: menu, hotkeys, palette | Second Hub (open), Auto Farm
    items = [('window', True), ('keyboard', False), ('command', False), None, ('SH', True), ('AF', False)]
    bw, gap = 31, 4
    dw = 10 + sum(9 if it is None else bw + gap for it in items) - gap + 10
    dx0, dy0 = W / 2 - dw / 2, 30
    glow(img, lambda g: g.rounded_rectangle(box(dx0, dy0 + 4, dx0 + dw, dy0 + 46), radius=S(11), fill=(0, 0, 0, 140)), 10)
    d.rounded_rectangle(box(dx0, dy0, dx0 + dw, dy0 + 40), radius=S(11), fill=rgba(T['Background']), outline=rgba(T['Border']), width=S(1))
    x = dx0 + 10
    fi = font(None, 11, True)
    sh_center = None
    for it in items:
        if it is None:
            seg(d, (x + 3, dy0 + 11), (x + 3, dy0 + 29), T['Outline'], 1)
            x += 9
            continue
        name, on = it
        cx, cy = x + bw / 2, dy0 + 20
        if on:
            d.rounded_rectangle(box(x, dy0 + 5, x + bw, dy0 + 35), radius=S(8), fill=rgba(T['TabActive']))
        if name in ('window', 'keyboard', 'command'):
            glyph(d, name, cx, cy, T['AccentText'] if on else T['TextDim'])
        else:
            text(d, (cx, cy), name, fi, T['AccentText'] if on else T['Label'], anchor='mm')
            dc = T['Success'] if on else T['TextMuted']
            d.ellipse(box(x + bw - 9, dy0 + 26, x + bw - 4, dy0 + 31), fill=rgba(dc, 1 if on else 0.65))
            if name == 'SH':
                sh_center = (cx, dy0 + 35)
        x += bw + gap

    # the hover hint under the Second Hub button
    hx, hy = sh_center[0] - 20, sh_center[1] + 12
    hw = text_w('Click to show or hide it. Right-click for more.', font(None, 10.5)) + 26
    glow(img, lambda g: g.rounded_rectangle(box(hx, hy + 4, hx + hw, hy + 52), radius=S(8), fill=(0, 0, 0, 120)), 8)
    d.rounded_rectangle(box(hx, hy, hx + hw, hy + 48), radius=S(8), fill=rgba(T['Group']), outline=rgba(T['Outline']), width=S(1))
    text(d, (hx + 12, hy + 15), 'Second Hub', font(None, 12), T['Text'])
    text(d, (hx + 12, hy + 33), 'Click to show or hide it. Right-click for more.', font(None, 10.5), T['TextDim'])

    # one notification stack for every script, each card naming its sender
    nx, nw = W - 314, 294
    ny = 24
    ny += notify_card(img, T, st, nx, ny, nw, 'Warning', 'My Hub', 'Menu key clash',
                      ['My Hub and Second Hub both open', 'with Right Shift.'], ('Move Second Hub to Right Control', 'Leave it')) + 8
    ny += notify_card(img, T, st, nx, ny, nw, 'Success', 'Second Hub', 'Auto farm', 'Collected 120 coins.') + 8
    notify_card(img, T, st, nx, ny, nw, 'Info', 'Auto Farm', 'Ready', 'Press End to open the menu.')

    # two quiet captions
    lay = layer((W, H))
    ld = ImageDraw.Draw(lay)
    acc = T['Accent']
    fc, fcs = font(None, 13, True), font('Mono', 11)
    cx0 = dx0 - 26
    seg(ld, (dx0 + 2, dy0 + 20), (cx0 + 6, dy0 + 20), acc, 0.55, 1.2)
    d2 = ImageDraw.Draw(lay)
    d2.ellipse(box(dx0 - 1, dy0 + 17, dx0 + 5, dy0 + 23), fill=rgba(acc))
    text(d2, (cx0, dy0 + 12), 'One dock for every script', fc, (232, 230, 244), anchor='rm')
    text(d2, (cx0, dy0 + 30), 'a button per script, lit while it is open', fcs, (160, 156, 182), anchor='rm')
    img.alpha_composite(lay)
    framed(img, (W, H), 400, 'Shell', ['Many scripts.', 'One dock.'],
           ['Every TingUI script shares one dock,', 'one notification stack and one', 'set of hotkeys, and they sort out', 'clashes between them.'],
           os.path.join(OUT, 'shell.png'), accent=T['Accent'])


def studio_image(defaults, presets):
    W, H = 1240, 700
    T, st = full_theme(defaults, presets['Frost'])
    img = stage_base(T, (W, H))
    main = (60, 78, 520, 652)
    studio = (548, 52, 1180, 668)
    img.alpha_composite(window(T, st, (W, H), main, 0.6, title='My Hub'))

    def page(c):
        d, x0, y0, x1, y1 = c['d'], *c['win']
        f, fs = c['f_lab'], c['f_small']
        gw = (x1 - x0 - 34 - 8) / 2
        lx, rx = x0 + 17, x0 + 17 + gw + 8
        top = y0 + 88
        # left column: Surfaces, then Status colours
        rows = [('Window', 'Background'), ('Panels', 'Group'), ('Panel borders', 'GroupBorder'), ('Controls', 'Control'),
                ('Controls under the mouse', 'ControlHover'), ('Outlines', 'Outline'), ('Borders', 'Border')]
        gh = 48 + len(rows) * 27 - 6
        ry = group_box(d, T, st, lx, top, gw, gh, 'Surfaces', f)
        for label, key in rows:
            swatch_row(d, T, lx, gw, ry, label, T[key], f)
            ry += 27
        sy = top + gh + 8
        status = [('Success', 'Success'), ('Warning', 'Warning'), ('Danger', 'Danger'), ('Info', 'Info'), ('Caution', 'Caution'), ('Error', 'Error')]
        ry = group_box(d, T, st, lx, sy, gw, y1 - 34 - sy, 'Status colours', f)
        for label, key in status:
            if ry > y1 - 48:
                break
            swatch_row(d, T, lx, gw, ry, label, T.get(key, T['Accent']), f)
            ry += 27
        # right column: Text and accent, then Readability
        rows = [('Accent', 'Accent'), ('Text', 'Text'), ('Labels', 'Label'), ('Dim text', 'TextDim'), ('Faint text', 'TextMuted')]
        gh = 48 + len(rows) * 27 - 6
        ry = group_box(d, T, st, rx, top, gw, gh, 'Text and accent', f)
        for label, key in rows:
            swatch_row(d, T, rx, gw, ry, label, T[key], f)
            ry += 27
        sy = top + gh + 8
        ry = group_box(d, T, st, rx, sy, gw, y1 - 34 - sy, 'Readability', f)
        for ln in ('How easy text is to read on its background.', '4.5 to 1 reads well; dim text and accents', 'need 3 to 1.'):
            text(d, (rx + 12, ry - 6), ln, fs, T['TextDim'])
            ry += 15
        ry += 10
        checks = [('Text on the window', 'Text', 'Background', 4.5), ('Labels on panels', 'Label', 'Group', 4.5),
                  ('Text on controls', 'Text', 'Control', 4.5), ('Dim text on panels', 'TextDim', 'Group', 3),
                  ('Accent on the window', 'Accent', 'Background', 3)]
        for label, a, b, need in checks:
            r = contrast(T[a], T[b])
            ok = r >= need
            col = T['Success'] if ok else T.get('Caution', T['Warning'])
            d.ellipse(box(rx + 12, ry - 3.5, rx + 19, ry + 3.5), fill=rgba(col))
            text(d, (rx + 27, ry), '%s: %.1f to 1%s' % (label, r, '' if ok else '  (hard to read)'), fs, col)
            ry += 22
        ry += 6
        d.rounded_rectangle(box(rx + 12, ry - 10, rx + gw - 12, ry + 14), radius=S(5 * st['Radius']), fill=rgba(T['ControlHover']), outline=rgba(T['Outline']), width=S(1))
        text(d, (rx + gw / 2, ry + 2), 'Fix contrast', f, T['Label'], anchor='mm')

    img.alpha_composite(window(T, st, (W, H), studio, 0.6, title='Theme Studio', tabs=('Colours', 'Shape', 'Light', 'Motion', 'Share'),
                               subtitle='edits show live', footer=('Save or share it from the Share tab', None), content=page, pills=(), close=True))
    framed(img, (W, H), 400, 'Theme Studio', ['Make it yours,', 'live.'],
           ['Edit every colour, corner, light and', 'motion while the window updates.', 'Readability is checked as you go;', 'save it or share it as a code.'],
           os.path.join(OUT, 'studio.png'), accent=T['Accent'])


def main():
    defaults, presets, order, descs = load_presets()
    only = sys.argv[1:]
    extras = (['banner'], ['anatomy'], ['shell'], ['studio'], ['notifications'])
    for name in order:
        if only and name not in only and only not in extras:
            continue
        T, st = full_theme(defaults, presets[name])
        if only in extras:
            break
        save_png(render(T, st, t=1.2, seed=sum(map(ord, name)) % 1000, caption=(name, descs.get(name, ''))), os.path.join(OUT, 'themes', name.lower() + '.png'))
        if st.get('Scene'):
            frames = [render(T, st, size=(720, 450), t=0.05 + i / 12, seed=7) for i in range(36)]
            save_gif(frames, os.path.join(OUT, 'themes', name.lower() + '.gif'))
    if not only or only == ['banner']:
        banner(defaults, presets)
    if not only or only == ['anatomy']:
        anatomy(defaults, presets)
    if not only or only == ['shell']:
        shell_image(defaults, presets)
    if not only or only == ['studio']:
        studio_image(defaults, presets)
    if not only or only == ['notifications']:
        notifications_image(defaults, presets)


if __name__ == '__main__':
    main()
