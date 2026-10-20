"""Check for secondary brightening in a recorded native glass release.

Choose a stationary body patch clear of glyphs/badges and visually identify the
press-lighting peaks in seconds. This measures that patch, not the whole glass.
Requires ffmpeg and numpy. Decode before trimming to preserve Simulator VFR time.
"""
import argparse
import json
import subprocess

import numpy as np

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('video')
p.add_argument('--crop', type=int, nargs=4, required=True, metavar=('X', 'Y', 'W', 'H'))
p.add_argument('--peaks', type=float, nargs='+', required=True)
p.add_argument('--tail', type=float, nargs=2, default=(.2, .8))
p.add_argument('--max-rebound', type=float, default=2,
               help='Maximum rise above any preceding sample in the tail, RGB/255')
p.add_argument('--output', required=True)
args = p.parse_args()
x, y, w, h = args.crop
if min(x, y) < 0 or min(w, h) <= 0 or not 0 <= args.tail[0] < args.tail[1]:
    p.error('Invalid crop or tail interval')
result = subprocess.run(['ffmpeg', '-v', 'error', '-i', args.video,
    '-vf', f'fps=60,crop={w}:{h}:{x}:{y}', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
    stdout=subprocess.PIPE, check=True)
trace = np.frombuffer(result.stdout, np.uint8).reshape(-1, h, w, 3).mean(axis=(1, 2, 3))
checks = []
for peak in args.peaks:
    first, last = (round((peak + t) * 60) for t in args.tail)
    if first < 0 or last >= len(trace):
        p.error('Release interval is outside the recording')
    tail = trace[first:last + 1]
    rebound = float((tail - np.minimum.accumulate(tail)).max())
    checks.append({'peak_seconds': peak, 'max_rebound_rgb': rebound,
                   'passed': rebound <= args.max_rebound})
report = {'crop': args.crop, 'tail_after_peak': args.tail,
          'threshold_rgb': args.max_rebound, 'checks': checks,
          'samples': [{'time': i / 60, 'meanRGB': float(v)} for i, v in enumerate(trace)]}
with open(args.output, 'w') as output:
    json.dump(report, output)
print(json.dumps(checks))
raise SystemExit(0 if all(c['passed'] for c in checks) else 1)
