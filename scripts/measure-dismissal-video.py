#!/usr/bin/env python3
"""Sample the glass ring of toolbar controls in a simulator recording.

Usage: measure-dismissal-video.py <video.mp4> <xcodebuild.log> [scale=3]

Reads the `ALG-FRAME id midX midY width` lines printed by
testToolbarDismissalMaterial, decodes every recorded frame with its own
timestamp (simulator recordings are variable-rate and skip static periods), and
prints the mean luminance of an annulus between the icon and the rim of each
control. On the dark demo background resting glass measures about 20-30 and the
reported opaque disk measures 0-3, so a run of near-zero samples right after a
dismissal is the defect.
"""
import math
import re
import subprocess
import sys

from PIL import Image

video, log = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
controls = [(m[0], float(m[1]) * scale, float(m[2]) * scale, float(m[3]) * scale)
  for m in re.findall(r'ALG-FRAME (\S+) ([\d.]+) ([\d.]+) ([\d.]+)', open(log).read())]
if not controls:
  sys.exit('no ALG-FRAME lines in log')
probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v', '-show_entries',
  'stream=width,height', '-of', 'csv=p=0', video], capture_output=True, text=True, check=True)
width, height = map(int, probe.stdout.strip().split(','))
times = [float(t.strip(',')) for t in subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v',
  '-show_entries', 'frame=pts_time', '-of', 'csv=p=0', video],
  capture_output=True, text=True, check=True).stdout.split()]
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-fps_mode', 'passthrough', '-f', 'rawvideo',
  '-pix_fmt', 'gray', '-'], capture_output=True, check=True).stdout
frame_size = width * height
points = []
for _, cx, cy, w in controls:
  r0, r1 = w * 0.32, w * 0.44
  ring = [(int(cx + r * math.cos(a)), int(cy + r * math.sin(a)))
    for r in (r0, (r0 + r1) / 2, r1) for a in [i * math.pi / 24 for i in range(48)]]
  points.append(ring)
print('time ' + ' '.join(c[0].replace('native-toolbar-', '') for c in controls))
for index in range(len(raw) // frame_size):
  frame = Image.frombytes('L', (width, height), raw[index * frame_size:(index + 1) * frame_size])
  pixels = frame.load()
  values = [sum(pixels[x, y] for x, y in ring) / len(ring) for ring in points]
  print(f'{times[index]:6.2f} ' + '  '.join(f'{v:8.1f}' for v in values))
