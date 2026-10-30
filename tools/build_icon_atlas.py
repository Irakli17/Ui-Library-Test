"""TingUI icon atlas: real open-source icons packed into one image, so a big set costs a single download.

    npm pack lucide-static simple-icons     (in any folder, then unpack both .tgz files)
    python tools/build_icon_atlas.py <lucide-static/package/icons> <simple-icons/package/icons>

Writes assets/icons/atlas-v1.png (64 px cells, 16 per row, white on clear, tinted in game) and prints the Lua table
of names to cell indices for ATLAS_NAMES in TingUI.lua.

Lucide (https://lucide.dev, ISC licence) for the interface icons; Simple Icons (https://simpleicons.org, CC0) for
brand marks, drawn exactly from each brand's published logo. The Discord mark in assets/icons/discord.png comes from
the same source.
"""
import io, os, re, sys
import cairosvg
from PIL import Image

LUCIDE = [
    'settings', 'sliders-horizontal', 'toggle-left', 'toggle-right', 'crosshair', 'swords', 'skull', 'ghost', 'zap', 'flame',
    'droplet', 'snowflake', 'cloud', 'cloud-rain', 'cloud-lightning', 'wind', 'tree-pine', 'mountain', 'map', 'map-pin',
    'navigation', 'compass', 'footprints', 'car', 'bike', 'plane', 'anchor', 'ship', 'train-front', 'bus',
    'gamepad-2', 'joystick', 'dice-5', 'puzzle', 'medal', 'award', 'bomb', 'shield-check', 'shield-alert', 'shield-off',
    'lock-open', 'key-round', 'fingerprint', 'scan-face', 'eye-off', 'bell-ring', 'bell-off', 'message-circle', 'message-square', 'send',
    'at-sign', 'phone', 'video', 'camera', 'image', 'film', 'music', 'headphones', 'mic', 'mic-off',
    'volume-2', 'volume-x', 'radio', 'tv', 'monitor', 'laptop', 'smartphone', 'cpu', 'hard-drive', 'server',
    'database', 'wifi-off', 'bluetooth', 'battery', 'battery-charging', 'plug', 'power', 'refresh-cw', 'rotate-ccw', 'undo-2',
    'redo-2', 'history', 'timer', 'hourglass', 'alarm-clock', 'calendar-days', 'watch', 'sunrise', 'sunset', 'cloud-sun',
    'thermometer', 'activity', 'heart-pulse', 'brain', 'bot', 'sparkles', 'wand-sparkles', 'brush', 'pen-tool', 'pencil',
    'eraser', 'scissors', 'paperclip', 'clipboard', 'clipboard-check', 'file', 'file-text', 'file-code', 'folder-open', 'archive',
    'package', 'box', 'boxes', 'layers', 'layout-grid', 'layout-dashboard', 'columns-2', 'rows-2', 'table', 'list-checks',
    'list-ordered', 'filter', 'arrow-up', 'arrow-down', 'arrow-left', 'arrow-right', 'arrow-up-right', 'move', 'maximize-2', 'minimize-2',
    'expand', 'shrink', 'chevrons-up-down', 'external-link', 'link-2', 'unlink', 'share-2', 'save', 'trash-2', 'x',
    'circle-x', 'circle-check', 'circle-alert', 'circle-help', 'badge-check', 'badge-alert', 'ban', 'check-check', 'circle-plus', 'circle-minus',
    'minus', 'hash', 'percent', 'dollar-sign', 'coins', 'wallet', 'credit-card', 'shopping-cart', 'shopping-bag', 'store',
    'tag', 'tags', 'ticket', 'gem', 'diamond', 'star-half', 'thumbs-up', 'thumbs-down', 'smile', 'frown',
    'laugh', 'angry', 'user-plus', 'user-minus', 'user-check', 'user-x', 'users-round', 'contact', 'id-card', 'handshake',
    'hand', 'earth', 'languages', 'book', 'book-open', 'graduation-cap', 'lightbulb', 'terminal', 'code-xml', 'braces',
    'bug-off', 'git-branch', 'mouse', 'mouse-pointer-click', 'pointer', 'hand-metal', 'eye-closed', 'house', 'door-open', 'log-in',
    'log-out', 'menu', 'ellipsis', 'ellipsis-vertical', 'grip-vertical', 'sun-moon', 'moon-star', 'cookie', 'coffee', 'pizza',
    'apple', 'fish', 'feather', 'leaf', 'flower', 'sprout', 'paw-print', 'bird', 'cat', 'dog',
    'rabbit', 'sword', 'shield', 'heart', 'star', 'search', 'filter-x', 'refresh-ccw', 'loader', 'loader-circle',
]
BRANDS = ['discord', 'github', 'youtube', 'roblox', 'twitch', 'x', 'tiktok', 'telegram', 'reddit', 'steam', 'spotify', 'instagram', 'kick']
# names the core set already uses keep the core icon; the atlas copy gets a "lucide-" prefix instead
CORE = {'home', 'gift', 'crown', 'command', 'keyboard', 'info', 'sword', 'shield', 'heart', 'star', 'search', 'discord'}
CELL, COLS = 64, 16


def render_svg(svg, size, fill=False):
    svg = svg.replace('currentColor', '#ffffff')
    if fill:
        svg = svg.replace('<svg ', '<svg fill="#ffffff" ', 1)
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert('RGBA')


def main():
    lucide_dir, brand_dir = sys.argv[1], sys.argv[2]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'icons')
    entries = []
    for n in LUCIDE:
        svg = open(os.path.join(lucide_dir, n + '.svg')).read()
        svg = re.sub(r'<!--.*?-->', '', svg, flags=re.S)
        entries.append(('lucide-' + n if n in CORE else n, svg, False))
    for n in BRANDS:
        svg = open(os.path.join(brand_dir, n + '.svg')).read()
        entries.append(('brand-' + n, svg, True))
    rows = (len(entries) + COLS - 1) // COLS
    atlas = Image.new('RGBA', (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    pad = 6
    for i, (name, svg, fill) in enumerate(entries):
        im = render_svg(svg, CELL - pad * 2, fill)
        atlas.alpha_composite(im, ((i % COLS) * CELL + pad, (i // COLS) * CELL + pad))
    atlas.save(os.path.join(root, 'atlas-v1.png'), optimize=True)
    # the official Discord mark replaces the hand-drawn one
    disc = render_svg(open(os.path.join(brand_dir, 'discord.svg')).read(), 96 - 16, True)
    canvas = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    canvas.alpha_composite(disc, (8, 8))
    canvas.save(os.path.join(root, 'discord.png'), optimize=True)
    print('local ATLAS_NAMES = {')
    line = '\t'
    for i, (name, _, _) in enumerate(entries):
        item = '["%s"] = %d, ' % (name, i)
        if len(line) + len(item) > 120:
            print(line.rstrip())
            line = '\t'
        line += item
    print(line.rstrip())
    print('}')
    print('-- %d icons, atlas %dx%d' % (len(entries), atlas.width, atlas.height), file=sys.stderr)


if __name__ == '__main__':
    main()
