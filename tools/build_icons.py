"""TingUI icon set: white vector icons on a 24x24 grid, rendered to high-res PNGs (tinted in-game via ImageColor3).

Rebuild assets/icons:  pip install cairosvg pillow   then   python tools/build_icons.py
Add an icon: add an SVG body to ICONS (and its name to ICON_NAMES in TingUI.lua), rebuild, push.
"""
import math, os, sys, io
import cairosvg
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'icons')
SIZE = 96
W = 'stroke="#fff" fill="none" stroke-linecap="round" stroke-linejoin="round"'


def gear_path():
    # 8 rounded-ish teeth around a ring, built as one polygon
    pts = []
    teeth, r_out, r_in = 8, 10.2, 7.6
    for i in range(teeth * 4):
        a = (i / (teeth * 4)) * 2 * math.pi - math.pi / 2
        r = r_out if (i % 4) in (1, 2) else r_in
        pts.append((12 + r * math.cos(a), 12 + r * math.sin(a)))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


HEART = "M12 20.6 C 6.8 17 3.4 13.9 3.4 10.1 a4.3 4.3 0 0 1 8.6-1.4 a4.3 4.3 0 0 1 8.6 1.4 c0 3.8-3.4 6.9-8.6 10.5 z"

ICONS = {
    # browser-style window: frame, solid title bar, a small inset panel (matches the reference dock)
    'window': f'''
        <rect x="2.6" y="4" width="18.8" height="16" rx="3.2" {W} stroke-width="2"/>
        <path d="M2.6 7.2 a3.2 3.2 0 0 1 3.2-3.2 h12.4 a3.2 3.2 0 0 1 3.2 3.2 v2.1 h-18.8 z" fill="#fff"/>
        <rect x="12.2" y="12.4" width="6.2" height="4.4" rx="1.1" {W} stroke-width="1.8"/>''',
    # face scan: corner brackets around head and shoulders
    'scan': f'''
        <path d="M3 8.2 V5.4 a2.4 2.4 0 0 1 2.4-2.4 H8.2 M15.8 3 h2.8 a2.4 2.4 0 0 1 2.4 2.4 v2.8 M21 15.8 v2.8 a2.4 2.4 0 0 1-2.4 2.4 h-2.8 M8.2 21 H5.4 A2.4 2.4 0 0 1 3 18.6 v-2.8" {W} stroke-width="1.9"/>
        <circle cx="12" cy="9.6" r="2.7" {W} stroke-width="1.8"/>
        <path d="M7.3 17.6 c0-2.7 2.1-4.4 4.7-4.4 s4.7 1.7 4.7 4.4 z" {W} stroke-width="1.8"/>''',
    'keyboard': f'''
        <rect x="2" y="5.4" width="20" height="13.2" rx="2.8" {W} stroke-width="2"/>
        ''' + ''.join(f'<rect x="{x - 0.85:.2f}" y="{y - 0.85:.2f}" width="1.7" height="1.7" rx="0.45" fill="#fff"/>'
                      for y in (9.0, 12.0) for x in (6.0, 9.0, 12.0, 15.0, 18.0)) + '''
        <rect x="7.6" y="14.4" width="8.8" height="1.8" rx="0.9" fill="#fff"/>''',
    'command': f'<path d="M15 6 v12 a3 3 0 1 0 3-3 H6 a3 3 0 1 0 3 3 V6 a3 3 0 1 0-3 3 h12 a3 3 0 1 0-3-3" {W} stroke-width="1.9"/>',
    # a person with a heart: "the people behind this"
    'user': f'''
        
        <g>
            <circle cx="9.6" cy="7.4" r="3.9" fill="#fff"/>
            <path d="M2.4 20.6 v-0.9 c0-3.7 3.1-6.3 7.2-6.3 s7.2 2.6 7.2 6.3 v0.9 z" fill="#fff"/>
        </g>
''',
    'bell': '''
        <path d="M12 3.3 c-3.4 0-5.8 2.7-5.8 6.1 v3.3 l-1.7 2.7 c-0.45 0.75 0.1 1.6 0.95 1.6 h13.1 c0.85 0 1.4-0.85 0.95-1.6 l-1.7-2.7 v-3.3 c0-3.4-2.4-6.1-5.8-6.1 z" fill="#fff"/>
        <path d="M9.6 18.4 a2.4 2.4 0 0 0 4.8 0 z" fill="#fff"/>
        <circle cx="12" cy="2.6" r="1.25" fill="#fff"/>''',
    'check': f'<path d="M4.8 12.6 l4.6 4.6 L19.4 7" {W} stroke-width="2.8"/>',
    'cross': f'<path d="M6.4 6.4 l11.2 11.2 M17.6 6.4 l-11.2 11.2" {W} stroke-width="2.8"/>',
    'warn': f'''<path d="M12 4.2 v9.6" {W} stroke-width="3.2"/><circle cx="12" cy="19" r="2" fill="#fff"/>''',
    'info': f'''<circle cx="12" cy="4.9" r="2" fill="#fff"/>
        <path d="M9.6 10 h2.4 v9 M9 19 h6" {W} stroke-width="2.5"/>''',
    'discord': '''
        
        <g><path d="M7.4 5.6 C 9 5 10.4 4.8 12 4.8 S 15 5 16.6 5.6 C 18.8 8.4 19.9 11.6 19.8 15.4 C 18.4 16.6 16.9 17.5 15.3 18.1 L 14.3 16.4 C 12.8 16.9 11.2 16.9 9.7 16.4 L 8.7 18.1 C 7.1 17.5 5.6 16.6 4.2 15.4 C 4.1 11.6 5.2 8.4 7.4 5.6 Z" fill="#fff"/></g>''',
    'gear': f'''
        <g><path d="{gear_path()}" fill="#fff" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"/></g>''',
    'snow': f'''<g {W} stroke-width="1.9">''' + ''.join(
        f'<g transform="rotate({r} 12 12)"><path d="M12 2.8 v18.4 M9.4 4.6 l2.6 2.4 l2.6-2.4 M9.4 19.4 l2.6-2.4 l2.6 2.4"/></g>' for r in (0, 60, 120)) + '</g>',
    'list': f'''<path d="M8.6 6.5 h11.6 M8.6 12 h11.6 M8.6 17.5 h11.6" {W} stroke-width="2"/>
        <circle cx="4.4" cy="6.5" r="1.4" fill="#fff"/><circle cx="4.4" cy="12" r="1.4" fill="#fff"/><circle cx="4.4" cy="17.5" r="1.4" fill="#fff"/>''',
    'heart': f'<path d="{HEART}" fill="#fff"/>',
    'chevron': f'<path d="M6.2 9.2 l5.8 5.8 l5.8-5.8" {W} stroke-width="2.4"/>',
    'search': f'<circle cx="10.6" cy="10.6" r="6.2" {W} stroke-width="2.1"/><path d="M15.2 15.2 l5 5" {W} stroke-width="2.4"/>',
    'eye': f'''<path d="M2.4 12 c2.4-4.4 5.6-6.6 9.6-6.6 s7.2 2.2 9.6 6.6 c-2.4 4.4-5.6 6.6-9.6 6.6 s-7.2-2.2-9.6-6.6 z" {W} stroke-width="1.9"/>
        <circle cx="12" cy="12" r="3.1" fill="#fff"/>''',
    'sparkle': '<path d="M12 2.5 C 12.9 8.4 15.6 11.1 21.5 12 C 15.6 12.9 12.9 15.6 12 21.5 C 11.1 15.6 8.4 12.9 2.5 12 C 8.4 11.1 11.1 8.4 12 2.5 z" fill="#fff"/>',
    'lock': f'''<rect x="4.6" y="10.4" width="14.8" height="10.6" rx="2.6" fill="#fff"/>
        <path d="M8 10.4 V7.6 a4 4 0 0 1 8 0 v2.8" {W} stroke-width="2.1"/>''',
    'palette': f'''
        <g><path d="M12 2.8 c-5.3 0-9.4 4-9.4 9.2 c0 5.2 4.1 9.2 9.1 9.2 c1.4 0 2.3-0.8 2.3-1.9 c0-0.5-0.2-0.9-0.5-1.3 c-0.3-0.4-0.5-0.8-0.5-1.3 c0-1 0.8-1.8 1.9-1.8 h2.2 c2.9 0 5.3-2.4 5.3-5.3 C 22.4 6.4 17.8 2.8 12 2.8 z" fill="#fff"/></g>''',
}


# v0.0.9: a wider set for hubs and notifications
NEW_ICONS = {
    'home': f'''<path d="M3.2 11.2 L12 3.6 L20.8 11.2" {W} stroke-width="2.2"/>
        <path d="M5.6 9.6 V19.2 a1.4 1.4 0 0 0 1.4 1.4 h3.4 v-5.6 h3.2 v5.6 h3.4 a1.4 1.4 0 0 0 1.4-1.4 V9.6" {W} stroke-width="2.1"/>''',
    'star': '<path d="M12 2.6 l2.75 5.75 l6.3 0.8 l-4.6 4.4 l1.15 6.25 L12 16.8 l-5.6 3.0 l1.15-6.25 l-4.6-4.4 l6.3-0.8 z" fill="#fff" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"/>',
    'bolt': '<path d="M13.6 2.4 L4.8 13.4 h6.2 l-1.2 8.2 l8.8-11 h-6.2 z" fill="#fff" stroke="#fff" stroke-width="1.1" stroke-linejoin="round"/>',
    'shield': f'''<path d="M12 2.8 L19.6 5.6 V11.4 c0 4.6-3.2 8.2-7.6 9.8 c-4.4-1.6-7.6-5.2-7.6-9.8 V5.6 z" fill="#fff"/>''',
    'trophy': f'''<path d="M7 3.6 h10 v5.2 a5 5 0 0 1-10 0 z" fill="#fff"/>
        <path d="M7 5.4 H4.2 v1.6 a3.4 3.4 0 0 0 3.4 3.4 M17 5.4 h2.8 v1.6 a3.4 3.4 0 0 1-3.4 3.4" {W} stroke-width="1.8"/>
        <path d="M12 13.6 v3.4" {W} stroke-width="2.2"/><rect x="7.4" y="17.4" width="9.2" height="3" rx="1.2" fill="#fff"/>''',
    'crown': '<path d="M3.4 8.2 l4.4 3.8 L12 5 l4.2 7 l4.4-3.8 l-1.6 9.4 H5 z" fill="#fff" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"/><rect x="5" y="18.6" width="14" height="2.2" rx="1" fill="#fff"/>',
    'target': f'''<circle cx="12" cy="12" r="8.6" {W} stroke-width="1.9"/><circle cx="12" cy="12" r="4.6" {W} stroke-width="1.9"/>
        <circle cx="12" cy="12" r="1.6" fill="#fff"/><path d="M12 1.4 v3.2 M12 19.4 v3.2 M1.4 12 h3.2 M19.4 12 h3.2" {W} stroke-width="1.9"/>''',
    'pin': '<path d="M12 21.6 c-0.4 0-6.8-6.4-6.8-11.6 a6.8 6.8 0 0 1 13.6 0 c0 5.2-6.4 11.6-6.8 11.6 z" fill="#fff"/>',
    'globe': f'''<circle cx="12" cy="12" r="9" {W} stroke-width="1.9"/><ellipse cx="12" cy="12" rx="3.9" ry="9" {W} stroke-width="1.7"/>
        <path d="M3.4 9 h17.2 M3.4 15 h17.2" {W} stroke-width="1.7"/>''',
    'clock': f'''<circle cx="12" cy="12" r="9" {W} stroke-width="2"/><path d="M12 6.6 V12 l3.6 2.2" {W} stroke-width="2.1"/>''',
    'calendar': f'''<rect x="3.4" y="5" width="17.2" height="15.6" rx="2.8" {W} stroke-width="2"/>
        <path d="M3.4 9.6 h17.2" {W} stroke-width="2"/><path d="M8 3 v4 M16 3 v4" {W} stroke-width="2.1"/>''' + ''.join(
        f'<rect x="{x - 1:.1f}" y="{y - 1:.1f}" width="2" height="2" rx="0.5" fill="#fff"/>' for y in (13.2, 16.8) for x in (8, 12, 16)),
    'download': f'''<path d="M12 3.4 v11 M7.6 10.4 L12 14.8 L16.4 10.4" {W} stroke-width="2.2"/><path d="M4.4 15.6 v2.6 a2 2 0 0 0 2 2 h11.2 a2 2 0 0 0 2-2 v-2.6" {W} stroke-width="2.1"/>''',
    'upload': f'''<path d="M12 14.8 v-11 M7.6 7.8 L12 3.4 L16.4 7.8" {W} stroke-width="2.2"/><path d="M4.4 15.6 v2.6 a2 2 0 0 0 2 2 h11.2 a2 2 0 0 0 2-2 v-2.6" {W} stroke-width="2.1"/>''',
    'trash': f'''<path d="M4 6.6 h16 M9.4 6.6 V4.6 a1.2 1.2 0 0 1 1.2-1.2 h2.8 a1.2 1.2 0 0 1 1.2 1.2 v2" {W} stroke-width="2"/>
        <path d="M6.2 6.6 l0.9 12.6 a1.8 1.8 0 0 0 1.8 1.6 h6.2 a1.8 1.8 0 0 0 1.8-1.6 l0.9-12.6" {W} stroke-width="2"/><path d="M10.2 10.6 v6 M13.8 10.6 v6" {W} stroke-width="1.8"/>''',
    'copy': f'''<rect x="8.4" y="8.4" width="12" height="12" rx="2.4" {W} stroke-width="2"/><path d="M15.6 5.6 V5.2 a1.8 1.8 0 0 0-1.8-1.8 H5.2 a1.8 1.8 0 0 0-1.8 1.8 v8.6 a1.8 1.8 0 0 0 1.8 1.8 h0.4" {W} stroke-width="2"/>''',
    'edit': f'''<path d="M15.4 4.4 a2.1 2.1 0 0 1 3 0 l1.2 1.2 a2.1 2.1 0 0 1 0 3 L9.2 19 L4 20 L5 14.8 z" {W} stroke-width="2"/><path d="M13.6 6.2 l4.2 4.2" {W} stroke-width="2"/>''',
    'folder': '<path d="M2.8 7 a2 2 0 0 1 2-2 h4.6 l2.2 2.4 h7.6 a2 2 0 0 1 2 2 v8.8 a2 2 0 0 1-2 2 H4.8 a2 2 0 0 1-2-2 z" fill="#fff"/>',
    'flag': f'''<path d="M5.4 21.4 V3.2" {W} stroke-width="2.2"/><path d="M5.4 4 c3.6-1.6 6.2 1.6 9.6 0.2 c1.6-0.6 2.8-0.6 3.8-0.2 v9 c-1-0.4-2.2-0.4-3.8 0.2 c-3.4 1.4-6-1.8-9.6-0.2 z" fill="#fff"/>''',
    'fire': '<path d="M12 21.6 c-4.4 0-7.2-3-7.2-6.8 c0-3.2 2-5.4 3.6-7.2 c0.4 1.8 1.2 3 2.4 3.6 c-0.2-3.6 1.4-6.4 4.2-8.6 c0 3.4 1.8 5.2 3.4 7 c1.2 1.4 1.8 3 1.8 5.2 c0 3.8-3 6.8-8.2 6.8 z" fill="#fff"/>',
    'code': f'''<path d="M8.4 6.6 L3 12 l5.4 5.4 M15.6 6.6 L21 12 l-5.4 5.4" {W} stroke-width="2.2"/><path d="M13.6 4.4 l-3.2 15.2" {W} stroke-width="2"/>''',
    'link': f'''<path d="M10.2 13.8 a4 4 0 0 0 5.8 0.2 l3-3 a4 4 0 0 0-5.6-5.8 l-1.4 1.4" {W} stroke-width="2.1"/><path d="M13.8 10.2 a4 4 0 0 0-5.8-0.2 l-3 3 a4 4 0 0 0 5.6 5.8 l1.4-1.4" {W} stroke-width="2.1"/>''',
    'refresh': f'''<path d="M19.6 12 a7.6 7.6 0 1 1-2.2-5.4" {W} stroke-width="2.1"/><path d="M19.4 3.6 v4.4 h-4.4" {W} stroke-width="2.1"/>''',
    'play': '<path d="M7.4 4.8 v14.4 a1 1 0 0 0 1.5 0.85 l11.4-7.2 a1 1 0 0 0 0-1.7 L8.9 3.95 a1 1 0 0 0-1.5 0.85 z" fill="#fff"/>',
    'key': f'''<circle cx="7.6" cy="15.4" r="4.4" {W} stroke-width="2.1"/><path d="M10.8 12.2 L20.4 2.8 M17.2 6 l2.6 2.6 M14.8 8.4 l2 2" {W} stroke-width="2.1"/>''',
    'coin': f'''<circle cx="12" cy="12" r="9" fill="#fff"/>''',
    'gift': f'''<rect x="3.4" y="8.6" width="17.2" height="4" rx="1.2" fill="#fff"/><rect x="4.8" y="12.6" width="14.4" height="8.2" rx="1.4" fill="#fff"/>
        <path d="M12 8.6 c-1.2-3.4-4.6-4.8-5.6-3 c-0.8 1.6 1.6 3 5.6 3 c4 0 6.4-1.4 5.6-3 c-1-1.8-4.4-0.4-5.6 3" {W} stroke-width="1.8"/>''',
    'rocket': '<path d="M12 2.2 c3.6 2.4 5.2 6 5 10.2 l-1.4 4.2 H8.4 L7 12.4 c-0.2-4.2 1.4-7.8 5-10.2 z" fill="#fff"/><path d="M7.3 10.8 L4.2 14.2 v4.4 l4.6-2.4 z M16.7 10.8 l3.1 3.4 v4.4 l-4.6-2.4 z" fill="#fff" stroke="#fff" stroke-width="0.8" stroke-linejoin="round"/><path d="M10 17.8 h4 l-2 3.8 z" fill="#fff" stroke="#fff" stroke-width="0.8" stroke-linejoin="round"/>',
    'mail': f'''<rect x="2.8" y="5.2" width="18.4" height="13.6" rx="2.6" {W} stroke-width="2"/><path d="M3.6 6.6 l8.4 6.4 l8.4-6.4" {W} stroke-width="2"/>''',
    'wifi': f'''<path d="M2.6 9.2 a13.4 13.4 0 0 1 18.8 0 M5.8 12.6 a8.8 8.8 0 0 1 12.4 0 M9 16 a4.2 4.2 0 0 1 6 0" {W} stroke-width="2.2"/><circle cx="12" cy="19.4" r="1.7" fill="#fff"/>''',
    'chart': f'''<path d="M3.4 20.4 h17.2" {W} stroke-width="2"/><rect x="5" y="12" width="3.4" height="6.4" rx="1" fill="#fff"/><rect x="10.3" y="7.6" width="3.4" height="10.8" rx="1" fill="#fff"/><rect x="15.6" y="3.8" width="3.4" height="14.6" rx="1" fill="#fff"/>''',
    'sword': f'''<path d="M20.6 3.4 l-0.4 3.6 L9.6 17.6 L6.4 14.4 L17 3.8 z" fill="#fff"/><path d="M4.6 12.6 l6.8 6.8 M6.6 17.4 l-3 3" {W} stroke-width="2.2"/>''',
    'users': '''<circle cx="9" cy="7.6" r="3.6" fill="#fff"/><path d="M2.4 19.6 c0-3.6 2.8-6.2 6.6-6.2 s6.6 2.6 6.6 6.2 z" fill="#fff"/>
        <circle cx="16.6" cy="8.4" r="2.8" fill="#fff"/><path d="M16.6 13.4 c3 0 5 2 5 5 h-4.2" fill="#fff"/>''',
    'moon': '<path d="M20.2 14.4 A8.6 8.6 0 1 1 9.6 3.8 a6.8 6.8 0 0 0 10.6 10.6 z" fill="#fff"/>',
    'sun': f'''<circle cx="12" cy="12" r="4.2" fill="#fff"/>''' + ''.join(
        f'<path d="M{12 + 6.8 * __import__("math").cos(a):.2f} {12 + 6.8 * __import__("math").sin(a):.2f} L{12 + 9.2 * __import__("math").cos(a):.2f} {12 + 9.2 * __import__("math").sin(a):.2f}" {W} stroke-width="2.1"/>'
        for a in [k * 0.7853981634 for k in range(8)]),
    'bug': f'''<rect x="7" y="7.6" width="10" height="12.4" rx="5" fill="#fff"/><path d="M9.2 7.4 a2.8 2.8 0 0 1 5.6 0" {W} stroke-width="1.9"/>
        <path d="M7 11 H3.6 M17 11 h3.4 M7 15.4 H3.8 M17 15.4 h3.2 M8.4 19 l-2.6 2 M15.6 19 l2.6 2 M9.4 5 L7.8 3.2 M14.6 5 l1.6-1.8" {W} stroke-width="1.8"/>''',
    'plus': f'<path d="M12 4.6 v14.8 M4.6 12 h14.8" {W} stroke-width="2.6"/>',
}
NEW_CUTS = {
    'shield': f'<path d="M8.4 12 l2.6 2.6 l4.8-5" {W} stroke-width="2.2"/>',
    'pin': '<circle cx="12" cy="9.8" r="2.7" fill="#fff"/>',
    'coin': f'<circle cx="12" cy="12" r="6.4" {W} stroke-width="1.4"/><path d="M12 8 v8 M14.4 9.6 c-0.4-0.8-1.3-1.2-2.4-1.2 c-1.4 0-2.4 0.7-2.4 1.8 s1 1.5 2.4 1.8 s2.4 0.8 2.4 1.9 s-1 1.8-2.4 1.8 c-1.1 0-2-0.5-2.4-1.3" {W} stroke-width="1.5"/>',
    'rocket': '<circle cx="12" cy="9.2" r="1.9" fill="#fff"/>',
    'folder': f'<path d="M2.8 9.2 h18.4" {W} stroke-width="1.2"/>',
    'bug': f'<path d="M12 10 v9" {W} stroke-width="1.3"/>',
    'gift': f'<path d="M12 8.4 v12.6" {W} stroke-width="1.8"/><path d="M3.4 12.6 h17.2" {W} stroke-width="1"/>',
    'trophy': '',
}


CUTS = {
    'user': f'<path d="{HEART}" transform="translate(17.6 16.1) scale(0.5) translate(-12 -12)" fill="#fff" stroke="#fff" stroke-width="4.5"/>',
    'discord': '<ellipse cx="9.2" cy="12.9" rx="1.7" ry="1.9" fill="#fff"/><ellipse cx="14.8" cy="12.9" rx="1.7" ry="1.9" fill="#fff"/>',
    'gear': '<circle cx="12" cy="12" r="3.1" fill="#fff"/>',
    'palette': '<circle cx="7.6" cy="11.4" r="1.55" fill="#fff"/><circle cx="10.4" cy="7.2" r="1.55" fill="#fff"/><circle cx="15.2" cy="7.6" r="1.55" fill="#fff"/><circle cx="16.6" cy="15.4" r="2.5" fill="#fff"/>',
}
CUTS.update({k: v for k, v in NEW_CUTS.items() if v})
ICONS.update(NEW_ICONS)
OVERLAYS = {'user': f'<path d="{HEART}" transform="translate(17.6 16.1) scale(0.5) translate(-12 -12)" fill="#fff"/>'}


def render(name, body, size=SIZE):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="{size}" height="{size}">{body}</svg>'
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert('RGBA')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, body in ICONS.items():
        im = render(name, body)
        if name in CUTS:
            cut = render(name, CUTS[name]).getchannel('A')
            a = im.getchannel('A')
            a = Image.eval(a, lambda v: v).point(lambda v: v)
            from PIL import ImageChops
            a = ImageChops.multiply(a, ImageChops.invert(cut))
            im.putalpha(a)
        if name in OVERLAYS:
            ov = render(name, OVERLAYS[name])
            im = Image.alpha_composite(im, ov)
        # keep only the alpha shape on pure white so ImageColor3 tints exactly
        a = im.getchannel('A')
        white = Image.new('RGBA', im.size, (255, 255, 255, 0))
        white.putalpha(a)
        white.save(os.path.join(OUT, name + '.png'), optimize=True)
    print(len(ICONS), 'icons written to', OUT)
