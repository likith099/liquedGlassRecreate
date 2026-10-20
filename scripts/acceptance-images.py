#!/usr/bin/env python3
"""Pixel acceptance checks for 0.2.0 (G2 glyph, G2 replace transition, G11 badge tracking).

  acceptance-images.py glyph <screenshot.png> <x> <y> <w> <h> [--scale 3]
      Ink area (pt²), ink box and estimated stroke of a light glyph on glass.
  acceptance-images.py ink <name> --mark MARK --rect RECT [--window 0.8]
      Glyph ink in every frame of a recording window (a replace transition must never be empty).
  acceptance-images.py badge <name> --mark MARK --rect RECT [--window 1.6]
      Red badge centre against the glass circle's top-right edge in every frame of a hold.

<name> is a recording written by scripts/record-ios-ui-test.sh. PIL + ffmpeg, no numpy.
"""
import argparse
import json
import math
import re
import shutil
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / 'artifacts'
FFMPEG = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
FFPROBE = shutil.which('ffprobe') or '/opt/homebrew/bin/ffprobe'


def luma(px):
  return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]


def glyph(image, box, scale):
  """Coverage-weighted ink of the bright glyph; the glass background is estimated from the border."""
  x, y, w, h = [int(round(v * scale)) for v in box]
  crop = image.crop((x, y, x + w, y + h)).convert('RGB')
  px = crop.load(); cw, ch = crop.size
  # Background: median luma of the inner ring between the rim and the glyph.
  ring = sorted(luma(px[i, j]) for i in range(cw) for j in range(ch)
    if 0.28 < math.hypot(i - cw / 2, j - ch / 2) / (cw / 2) < 0.4)
  bg = ring[len(ring) // 2]
  fg = max(luma(px[i, j]) for i in range(int(cw * .3), int(cw * .7)) for j in range(int(ch * .3), int(ch * .7)))
  inner = [(i, j) for i in range(cw) for j in range(ch) if math.hypot(i - cw / 2, j - ch / 2) < cw * 0.3]
  coverage = {(i, j): max(0.0, min(1.0, (luma(px[i, j]) - bg) / max(1, fg - bg))) for (i, j) in inner}
  area = sum(coverage.values()) / scale ** 2
  ink = [(i, j) for (i, j), c in coverage.items() if c > 0.5]
  if not ink: return {'area': 0}
  xs = [p[0] for p in ink]; ys = [p[1] for p in ink]
  box_w = (max(xs) - min(xs) + 1) / scale; box_h = (max(ys) - min(ys) + 1) / scale
  # Two equal straight arms meeting at the apex: stroke ≈ area / total centre-line length.
  arm = math.hypot(box_w, box_h / 2)
  return {'area': round(area, 2), 'inkWidth': round(box_w, 2), 'inkHeight': round(box_h, 2),
    'strokeEstimate': round(area / (2 * arm), 2), 'background': round(bg, 1), 'foreground': round(fg, 1)}


def recording(name):
  log = (ROOT / f'{name}.log').read_text(errors='replace')
  start = float((ROOT / f'{name}.start').read_text())
  marks = {m[0]: float(m[1]) for m in re.findall(r'ALG-MARK (\S+) ([\d.]+)', log)}
  rects = {m[0]: tuple(map(float, m[1:])) for m in re.findall(r'ALG-RECT (\S+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)', log)}
  return start, marks, rects


def frames(name, box, t0, window, scale):
  """Yields (time, RGB crop) for every recorded frame in [t0, t0 + window]."""
  video = ROOT / f'{name}.mp4'
  vw, vh = map(int, subprocess.run([FFPROBE, '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height',
    '-of', 'csv=p=0', str(video)], capture_output=True, text=True, check=True).stdout.strip().strip(',').split(','))
  x, y, w, h = box
  cw = min(vw, int(w * scale) // 2 * 2); ch = min(vh, int(h * scale) // 2 * 2)
  cx = min(max(0, int(x * scale)), vw - cw); cy = min(max(0, int(y * scale)), vh - ch)
  times = [float(v.strip(',')) for v in subprocess.run([FFPROBE, '-v', 'error', '-select_streams', 'v', '-show_entries',
    'frame=pts_time', '-of', 'csv=p=0', str(video)], capture_output=True, text=True, check=True).stdout.split() if v.strip(',')]
  proc = subprocess.Popen([FFMPEG, '-v', 'error', '-i', str(video), '-fps_mode', 'passthrough', '-vf', f'crop={cw}:{ch}:{cx}:{cy}',
    '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE)
  size = cw * ch * 3
  for t in times:
    data = proc.stdout.read(size)
    if len(data) < size: break
    if t0 - 0.05 <= t <= t0 + window:
      yield t - t0, Image.frombytes('RGB', (cw, ch), data), (cx / scale, cy / scale)
  proc.stdout.close(); proc.wait()


def ink_trace(args):
  start, marks, rects = recording(args.name)
  t0 = marks[args.mark] - start
  x, y, w, h = rects[args.rect]
  out = []
  for t, img, _ in frames(args.name, (x + w * .25, y + h * .25, w * .5, h * .5), t0, args.window, args.scale):
    px = img.load()
    out.append({'t': round(t, 3), 'ink': sum(1 for i in range(img.width) for j in range(img.height) if luma(px[i, j]) > 150)})
  rest = sorted(f['ink'] for f in out[:3])[1] if len(out) >= 3 else max(f['ink'] for f in out)
  return {'mark': args.mark, 'frames': len(out), 'restingInk': rest, 'minInk': min(f['ink'] for f in out),
    'minInkRatio': round(min(f['ink'] for f in out) / max(1, rest), 3), 'trace': out}


def badge_trace(args):
  start, marks, rects = recording(args.name)
  t0 = marks[args.mark] - start
  x, y, w, h = rects[args.rect]
  pad = 22; s = args.scale; out = []
  for t, img, origin in frames(args.name, (x - pad, y - pad, w + 2 * pad, h + 2 * pad), t0, args.window, s):
    px = img.load(); W, H = img.size
    red = [(i, j) for i in range(W) for j in range(H) if px[i, j][0] > 170 and px[i, j][1] < 110 and px[i, j][2] < 110]
    if not red: out.append({'t': round(t, 3), 'badge': None}); continue
    bx = sum(p[0] for p in red) / len(red); by = sum(p[1] for p in red) / len(red)
    # Glass circle: the lit, non-red extent along the horizontal and vertical lines through its middle.
    def lit(i, j):
      r, g, b = px[i, j]
      return luma((r, g, b)) > 9 and not (r > 170 and g < 110)
    # Walk outward from the centre; only the run continuous with the button counts, so
    # neighbouring labels and the badge never inflate the circle.
    def run(fixed, start, horizontal):
      limit = W if horizontal else H
      at = (lambda k: lit(k, fixed)) if horizontal else (lambda k: lit(fixed, k))
      lo = start
      while lo > 0 and at(lo - 1): lo -= 1
      hi = start
      while hi < limit - 1 and at(hi + 1): hi += 1
      return lo, hi
    row = int(H / 2) + int(s * 6)  # below the glyph's centre, through glass on both sides
    left, right = run(row, W // 2, True)
    cxp = (left + right) / 2
    top, bottom = run(int(cxp) - int(s * 6), H // 2, False)  # left of the badge's column
    # Both runs are chords 6 pt off the centre lines: correct each to the circle's radius.
    offset = s * 6
    cyp = (top + bottom) / 2
    radius = (math.hypot((right - left + 1) / 2, offset) + math.hypot((bottom - top + 1) / 2, offset)) / 2
    corner = (cxp + radius * math.cos(math.pi / 4), cyp - radius * math.sin(math.pi / 4))
    out.append({'t': round(t, 3), 'diameter': round(2 * radius / s, 2),
      'offset': round(math.hypot(bx - corner[0], by - corner[1]) / s, 2),
      'radialError': round((math.hypot(bx - cxp, by - cyp) - radius) / s, 2)})
  valid = [f for f in out if f.get('badge', 1) is not None and 'offset' in f]
  return {'mark': args.mark, 'frames': len(out), 'missingBadge': sum(1 for f in out if f.get('badge', 1) is None),
    'maxOffset': max(f['offset'] for f in valid) if valid else None,
    'maxRadialError': max(abs(f['radialError']) for f in valid) if valid else None,
    'diameterRange': [min(f['diameter'] for f in valid), max(f['diameter'] for f in valid)] if valid else None, 'trace': out}


p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
sub = p.add_subparsers(dest='command', required=True)
g = sub.add_parser('glyph'); g.add_argument('image'); [g.add_argument(k, type=float) for k in ('x', 'y', 'w', 'h')]
g.add_argument('--scale', type=float, default=3)
for name in ('ink', 'badge'):
  q = sub.add_parser(name); q.add_argument('name'); q.add_argument('--mark', required=True); q.add_argument('--rect', required=True)
  q.add_argument('--window', type=float, default=0.8 if name == 'ink' else 1.6); q.add_argument('--scale', type=float, default=3)
args = p.parse_args()
if args.command == 'glyph':
  print(json.dumps(glyph(Image.open(args.image), (args.x, args.y, args.w, args.h), args.scale)))
elif args.command == 'ink':
  print(json.dumps(ink_trace(args)))
else:
  print(json.dumps(badge_trace(args)))
