#!/usr/bin/env python3
"""Trace a glass control's horizontal extent through a simulator recording.

Usage:
  trace-glass.py <name> --mark MARK --rect RECT [--window 1.2] [--pad 60] [--scale 3]

<name> refers to the files written by scripts/record-ios-ui-test.sh (artifacts/<name>.mp4,
.log, .start). MARK is an ALG-MARK printed by the test right before its action; RECT is an
ALG-RECT (element frame in points) that bounds the control. Every decoded frame keeps its own
timestamp (simulator recordings are variable rate). On the dark acceptance page the glass
reads brighter than the black background; a column is glass when most rows of a band through
the control's centre exceed --threshold.

Prints JSON: per-frame trace plus settle time, overshoot, trailing-edge drift and whether a
glass shape was present in every frame. Requires ffmpeg/ffprobe; no numpy.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'artifacts'
p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument('name')
p.add_argument('--mark', required=True)
p.add_argument('--rect', required=True)
p.add_argument('--window', type=float, default=1.2)
p.add_argument('--pad', type=float, default=60, help='points added left and right of RECT')
p.add_argument('--scale', type=float, default=3)
p.add_argument('--threshold', type=int, default=9, help='luma above the black page')
p.add_argument('--anchor', choices=['trailing', 'leading', 'center'], default='trailing')
args = p.parse_args()
ffmpeg = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
ffprobe = shutil.which('ffprobe') or '/opt/homebrew/bin/ffprobe'

log = (root / f'{args.name}.log').read_text(errors='replace')
start = float((root / f'{args.name}.start').read_text())
marks = {m[0]: float(m[1]) for m in re.findall(r'ALG-MARK (\S+) ([\d.]+)', log)}
rects = {m[0]: tuple(map(float, m[1:])) for m in re.findall(r'ALG-RECT (\S+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)', log)}
if args.mark not in marks or args.rect not in rects:
  sys.exit(f'missing mark/rect; marks={sorted(marks)} rects={sorted(rects)}')
x, y, w, h = rects[args.rect]
s = args.scale
video_w, video_h = map(int, subprocess.run([ffprobe, '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height',
  '-of', 'csv=p=0', str(root / f'{args.name}.mp4')], capture_output=True, text=True, check=True).stdout.strip().strip(',').split(','))
crop_w = min(video_w, int((w + 2 * args.pad) * s) // 2 * 2)
crop_x = min(max(0, int((x - args.pad) * s)), video_w - crop_w)  # ffmpeg clamps the same way
crop_y = int((y + h * 0.3) * s); crop_h = max(2, int(h * 0.4 * s) // 2 * 2)
t0 = marks[args.mark] - start

times = [float(v.strip(',')) for v in subprocess.run([ffprobe, '-v', 'error', '-select_streams', 'v', '-show_entries', 'frame=pts_time',
  '-of', 'csv=p=0', str(root / f'{args.name}.mp4')], capture_output=True, text=True, check=True).stdout.split() if v.strip(',')]
proc = subprocess.Popen([ffmpeg, '-v', 'error', '-i', str(root / f'{args.name}.mp4'), '-fps_mode', 'passthrough',
  '-vf', f'crop={crop_w}:{crop_h}:{crop_x}:{crop_y},format=gray', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE)
size = crop_w * crop_h
trace = []
for t in times:
  frame = proc.stdout.read(size)
  if len(frame) < size: break
  if t < t0 - 0.05 or t > t0 + args.window: continue
  columns = []
  for cx in range(crop_w):
    lit = sum(1 for cy in range(crop_h) if frame[cy * crop_w + cx] > args.threshold)
    columns.append(lit * 2 > crop_h)
  if True in columns:
    left = columns.index(True); right = crop_w - 1 - columns[::-1].index(True)
    trace.append({'t': round(t - t0, 4), 'left': round((crop_x + left) / s, 2), 'right': round((crop_x + right + 1) / s, 2),
      'width': round((right - left + 1) / s, 2)})
  else:
    trace.append({'t': round(t - t0, 4), 'left': None, 'right': None, 'width': 0})
proc.stdout.close(); proc.wait()
if not trace: sys.exit('no frames in window')
present = [f for f in trace if f['width'] > 0]
tail = present[-5:] if len(present) >= 5 else present
final = sorted(f['width'] for f in tail)[len(tail) // 2]
edge = 'right' if args.anchor == 'trailing' else 'left'
final_edge = sorted(f[edge] for f in tail)[len(tail) // 2]
initial = present[0]['width'] if present else 0
settle = 0.0
for f in trace:
  if f['width'] == 0 or abs(f['width'] - final) > max(1.0, 0.015 * final): settle = f['t']
after = [f for f in trace if f['t'] >= 0]
summary = {
  'name': args.name, 'mark': args.mark, 'frames': len(trace), 'initialWidth': initial, 'finalWidth': final,
  'settleSeconds': round(max(0.0, settle), 3),
  'maxWidthRatio': round(max(f['width'] for f in present) / final, 4) if final else None,
  'minWidthRatio': round(min(f['width'] for f in after if f['width'] > 0) / final, 4) if final and after else None,
  'trailingDrift': round(max(abs(f[edge] - final_edge) for f in present), 2) if present else None,
  'glassEveryFrame': all(f['width'] >= min(initial, final) * 0.25 for f in after) if after else False,
  'emptyFrames': sum(1 for f in after if f['width'] == 0),
}
print(json.dumps({'summary': summary, 'trace': trace}))
