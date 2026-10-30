"""Flames theme textures: a looping flame flipbook and glowing corner fissures, generated from noise (no stock art).

    python tools/build_fire.py        writes assets/textures/flames.png, flames-core.png and fissures.png

flames.png: 20 frames of a 512 x 96 flame strip in a 2 x 10 grid (1024 x 960). Every frame tiles left to right and the
frames loop, so a strip of any width burns forever. Brightness is heat and alpha is flame plus a soft glow; the theme
tints it with ImageColor3. flames-core.png holds the white-hot middle of the same frames, drawn on top in the core colour.
Needs numpy, scipy and Pillow.
"""
import os
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'textures')
rng = np.random.default_rng(7)


def periodic_noise(w, h, power=2.2, seed=0):
    """Smooth random field that wraps in both directions (built in frequency space)."""
    r = np.random.default_rng(seed)
    fx = np.fft.fftfreq(w)[None, :]
    fy = np.fft.fftfreq(h)[:, None]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spec = (r.normal(size=(h, w)) + 1j * r.normal(size=(h, w))) / f ** power
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    n = (n - n.min()) / (n.max() - n.min())
    return n


def sample(field, x, y):
    h, w = field.shape
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x0 %= w
    y0 %= h
    x1, y1 = (x0 + 1) % w, (y0 + 1) % h
    a = field[y0, x0] * (1 - fx) + field[y0, x1] * fx
    b = field[y1, x0] * (1 - fx) + field[y1, x1] * fx
    return a * (1 - fy) + b * fy


def flames():
    """A burning gas simulation rather than drawn shapes: tens of thousands of hot particles leave a fuel bed along
    the bottom, rise on a swirling (curl-noise) wind, gather into tongues over the richest fuel and cool as they climb.
    Their glow is accumulated with motion blur, tone-mapped to heat, and the last stretch of the run is crossfaded
    with the first so the 20 frames loop seamlessly. The strip wraps left to right, so it tiles."""
    global rng
    SS = 2
    W, H = 512*SS, 96*SS
    L, N = 1.6, 20
    rng = np.random.default_rng(5)
    psi = periodic_noise(256, 256, 2.4, 90)   # stream function, tiles
    psi2 = periodic_noise(256, 256, 1.8, 91)
    fuelmap = periodic_noise(512, 512, 1.25, 92)    # x: along the strip, y: slow time; richer fuel = taller tongues
    def Fuel(x, t):
        f = sample(fuelmap, x / W * 512, np.full_like(x, 0.0) + t * 30)
        return np.clip((f - 0.5) * 2.4 + 0.5, 0, 1)

    def vel(x, y, t):
        # curl of a scrolling stream function: swirling, incompressible motion
        e = 1.0
        def P(xx, yy):
            u = xx/W*256*1.0
            v = (yy/H*96*0.9 + t*40)
            return sample(psi, u, v)*1.0 + sample(psi2, u*2, v*2)*0.35
        dpdy = (P(x, y+e*SS) - P(x, y-e*SS))/(2*e)
        dpdx = (P(x+e*SS, y) - P(x-e*SS, y))/(2*e)
        return dpdy*2600*SS, -dpdx*1300*SS

    def simulate(T, dt=1/120):
        px = np.empty(0); py = np.empty(0); age = np.empty(0); life = np.empty(0); vy0 = np.empty(0); hot=np.empty(0)
        snaps = {}
        want = [round(k*L/N/dt) for k in range(2*N+1)]
        steps = int(T/dt)+1
        rate = 42000
        for s in range(steps):
            t = s*dt
            n = rng.poisson(rate*dt)
            # fuel varies slowly along the base, so tongues form where it's richer
            xs = rng.uniform(0, W, n)
            fuel = Fuel(xs, t)
            keep = rng.uniform(0,1,n) < 0.25 + 0.75*fuel
            xs = xs[keep]; m = len(xs)
            px = np.concatenate([px, xs]); py = np.concatenate([py, H-1-rng.uniform(0, 4*SS, m)])
            fk = fuel[keep]
            age = np.concatenate([age, np.zeros(m)]); life = np.concatenate([life, rng.uniform(0.18, 0.42, m) + fk*0.4])
            vy0 = np.concatenate([vy0, (rng.uniform(40, 70, m) + fk*70)*SS]); hot = np.concatenate([hot, rng.uniform(0.6,1.0,m)])
            vx, vy = vel(px, py, t)
            k = np.clip(age/life, 0, 1)
            # rising gas pulls in toward the richest fuel nearby, so tongues narrow to a point
            g = (Fuel(px + 6*SS, t) - Fuel(px - 6*SS, t)) / (12*SS)
            px = (px + (vx*(0.3+k) + g*k*5000*SS)*dt) % W
            py = py + (-vy0*(1+k*0.6) + vy*(0.3+k)*0.4)*dt
            age = age + dt
            alive = (age < life) & (py > 1)
            px, py, age, life, vy0, hot = px[alive], py[alive], age[alive], life[alive], vy0[alive], hot[alive]
            # motion blur: every step close before a snapshot adds to it, so fast flame shows as streaks
            for w_ in want:
                if 0 <= w_ - s < 6:
                    acc = snaps.setdefault(('acc', w_), [np.zeros((H, W)), np.zeros((H, W))])
                    splat(acc, px, py, age/life, hot)
            if s in want:
                a, b = snaps.pop(('acc', s))
                snaps[s] = gaussian_filter(a, 1.9*SS, mode=('nearest','wrap')) + gaussian_filter(b, 3.2*SS, mode=('nearest','wrap'))
        return [snaps[w] for w in want]

    def splat(acc, px, py, k, hot):
        xi = np.clip(px.astype(int), 0, W-1); yi = np.clip(py.astype(int), 0, H-1)
        w = hot*(1-k)**1.5
        young = k < 0.45
        np.add.at(acc[0], (yi[young], xi[young]), w[young])
        np.add.at(acc[1], (yi[~young], xi[~young]), w[~young])

    def render(px, py, k, hot):
        img = np.zeros((H, W))
        xi = np.clip(px.astype(int), 0, W-1); yi = np.clip(py.astype(int), 0, H-1)
        w = hot*(1-k)**1.5
        young = k < 0.45
        a = np.zeros((H, W)); b = np.zeros((H, W))
        np.add.at(a, (yi[young], xi[young]), w[young])
        np.add.at(b, (yi[~young], xi[~young]), w[~young])
        img = gaussian_filter(a, 2.2*SS, mode=('nearest','wrap')) + gaussian_filter(b, 3.4*SS, mode=('nearest','wrap'))
        return img

    snaps = simulate(2*L + 0.1)
    frames = []
    for k in range(N):
        # crossfade only over the last stretch, so most frames are pure simulation (crisp), yet it still loops
        wgt = min(1, max(0, (k/N - 0.6) / 0.4))
        f = (1-wgt)*snaps[N+k] + wgt*snaps[k]
        frames.append(f)

    frames = np.array(frames)
    scale = np.percentile(frames, 99.5)
    FW, FH = W // SS, H // SS
    outer = np.zeros((1024, 1024, 4), np.float32)
    inner = np.zeros((1024, 1024, 4), np.float32)
    for k, f in enumerate(frames):
        h = 1 - np.exp(-f / scale * 1.6)
        glow = gaussian_filter(h, 7 * SS, mode=('nearest', 'wrap'))
        a = np.clip(np.maximum(h * 1.9, glow * 0.7), 0, 1)
        lum = np.clip(0.5 + h * 0.6, 0, 1)
        core = np.clip((h - 0.32) / 0.45, 0, 1) ** 1.1
        def down(x):
            return np.asarray(Image.fromarray((x * 255).clip(0, 255).astype(np.uint8)).resize((FW, FH), Image.LANCZOS)) / 255.0
        a, lum, core = down(a), down(lum), down(core)
        cx, cy = (k % 2) * FW, (k // 2) * FH
        for c in range(3):
            outer[cy:cy + FH, cx:cx + FW, c] = lum
            inner[cy:cy + FH, cx:cx + FW, c] = 1
        outer[cy:cy + FH, cx:cx + FW, 3] = a
        inner[cy:cy + FH, cx:cx + FW, 3] = core
    Image.fromarray((outer * 255).astype(np.uint8), 'RGBA').save(os.path.join(ROOT, 'flames.png'), optimize=True)
    Image.fromarray((inner * 255).astype(np.uint8), 'RGBA').save(os.path.join(ROOT, 'flames-core.png'), optimize=True)


def cracks():
    """Glowing fissures for the window's lower corners: cracks that wander and fork like split rock (random walks
    steered by noise, tapering as they go), each with a white-hot middle, a soft glow and a dark charred border for
    depth. Left half: cracks for the bottom-left corner; right half: the bottom-right. 1024 x 256, grey + alpha."""
    from PIL import ImageDraw
    SS = 3
    W, H = 512, 256
    r = np.random.default_rng(77)
    steer = periodic_noise(256, 256, 2.2, 80)
    out = np.zeros((H, W * 2, 4), np.float32)
    for half in range(2):
        line = Image.new('L', (W * SS, H * SS), 0)
        core = Image.new('L', (W * SS, H * SS), 0)
        dl, dc = ImageDraw.Draw(line), ImageDraw.Draw(core)
        corner_x = 0 if half == 0 else W
        stack = []
        for _ in range(4):
            x0 = abs(r.normal(0, 90)) if half == 0 else W - abs(r.normal(0, 90))
            ang = -np.pi / 2 + (0.55 if half == 0 else -0.55) * r.uniform(0.2, 1.0)
            stack.append([x0, H - 1, ang, r.uniform(8, 11), r.uniform(70, 120)])
        # a couple running up the side edge too
        for _ in range(0):
            y0 = r.uniform(H * 0.55, H * 0.85)
            stack.append([1 if half == 0 else W - 1, y0, (-0.25 if half == 0 else -np.pi + 0.25) + r.normal(0, 0.15), r.uniform(3.6, 4.6), r.uniform(60, 100)])
        while stack:
            x, y, a, w, length = stack.pop()
            travelled = 0
            kink = 0
            while travelled < length and w > 0.45 and 0 <= x < W and 0 <= y < H:
                # rock splits in short straight runs with sudden kinks, not smooth curves
                kink -= 2.2
                if kink <= 0:
                    kink = r.uniform(5, 15)
                    a += r.normal(0, 0.42)
                    target = -np.pi / 2 + (0.45 if half == 0 else -0.45)
                    a += (target - a) * 0.25
                a += r.normal(0, 0.03)
                step = 2.2
                nx, ny = x + np.cos(a) * step, y + np.sin(a) * step
                dl.line([x * SS, y * SS, nx * SS, ny * SS], fill=255, width=max(1, int(w * SS)))
                dc.line([x * SS, y * SS, nx * SS, ny * SS], fill=255, width=max(1, int(w * 0.45 * SS)))
                x, y = nx, ny
                travelled += step
                w *= 0.978
                if r.uniform() < 0.02 and w > 2.5:
                    stack.append([x, y, a + r.choice([-1, 1]) * r.uniform(0.45, 1.0), w * 0.62, (length - travelled) * r.uniform(0.4, 0.8)])
        L = np.asarray(line.resize((W, H), Image.LANCZOS), np.float32) / 255
        C = np.asarray(core.resize((W, H), Image.LANCZOS), np.float32) / 255
        glow = gaussian_filter(L, 3.2)
        wide = gaussian_filter(L, 9)
        char = np.clip(gaussian_filter((gaussian_filter(L, 2.5) > 0.04).astype(np.float32), 2.2) * 1.2, 0, 1)
        heat = np.clip(L * 0.7 + C * 0.5 + glow * 0.6 + wide * 0.4, 0, 1)
        alpha = np.clip(np.maximum(char * 0.7, np.maximum(heat * 1.2, wide * 0.9)), 0, 1)
        # where only the charred border shows, the colour is near black: tinting can't brighten it
        lum = np.clip(heat / np.maximum(alpha, 1e-3), 0, 1) ** 0.8
        sl = slice(half * W, (half + 1) * W)
        for ch in range(3):
            out[:, sl, ch] = lum
        out[:, sl, 3] = alpha
    Image.fromarray((out * 255).astype(np.uint8), 'RGBA').save(os.path.join(ROOT, 'fissures.png'), optimize=True)


if __name__ == '__main__':
    import sys
    os.makedirs(ROOT, exist_ok=True)
    only = sys.argv[1:] or ['flames', 'cracks']
    if 'flames' in only: flames()
    if 'cracks' in only: cracks()
    print('wrote flames.png, flames-core.png and fissures.png')
